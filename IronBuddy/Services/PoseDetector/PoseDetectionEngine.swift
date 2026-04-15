//
//  PoseDetectionEngine.swift
//  IronBuddy
//

import CoreVideo
import Foundation
import MediaPipeTasksVision
import UIKit

enum PoseEngineError: Error {
    case modelMissing
    case landmarkerInitFailed(String)
}

/// MediaPipe Pose 实时流；每 2 帧推理 1 次（与作业书一致）。
final class PoseDetectionEngine {
    private var landmarker: PoseLandmarker?
    private let delegateProxy = PoseStreamDelegateProxy()
    private var lastTimestampMs: Int = 0
    private var frameTick = 0

    /// 第一副人体 33 点；已在 MediaPipe 内部队列调用。
    var onLandmarks: (([NormalizedLandmark], Int) -> Void)?

    init() {
        delegateProxy.onResult = { [weak self] result, timestampMs, error in
            guard let self, error == nil, let result else { return }
            let outer = result.landmarks as NSArray
            guard outer.count > 0,
                  let inner = outer.object(at: 0) as? NSArray else { return }
            let pts = inner.compactMap { $0 as? NormalizedLandmark }
            guard pts.count >= 33 else { return }
            self.onLandmarks?(pts, timestampMs)
        }
    }

    func loadModelIfNeeded() throws {
        guard landmarker == nil else { return }
        guard let path = Bundle.main.path(forResource: "pose_landmarker", ofType: "task") else {
            throw PoseEngineError.modelMissing
        }
        let base = BaseOptions()
        base.modelAssetPath = path
        let options = PoseLandmarkerOptions()
        options.baseOptions = base
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.poseLandmarkerLiveStreamDelegate = delegateProxy
        do {
            landmarker = try PoseLandmarker(options: options)
        } catch {
            throw PoseEngineError.landmarkerInitFailed(error.localizedDescription)
        }
    }

    func detectAsync(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation, timestampMs: Int) {
        frameTick += 1
        if frameTick % 2 != 0 { return }
        guard let landmarker else { return }
        let image: MPImage
        do {
            image = try MPImage(pixelBuffer: pixelBuffer, orientation: orientation)
        } catch {
            return
        }
        let ts = max(timestampMs, lastTimestampMs + 1)
        lastTimestampMs = ts
        do {
            try landmarker.detectAsync(image: image, timestampInMilliseconds: ts)
        } catch {
            return
        }
    }
}
