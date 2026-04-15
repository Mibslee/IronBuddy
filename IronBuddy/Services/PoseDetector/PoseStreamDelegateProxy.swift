//
//  PoseStreamDelegateProxy.swift
//  IronBuddy
//

import Foundation
import MediaPipeTasksVision

/// MediaPipe 在私有队列回调；将结果转发给闭包（由上层派发到主线程）。
final class PoseStreamDelegateProxy: NSObject, PoseLandmarkerLiveStreamDelegate {
    var onResult: ((PoseLandmarkerResult?, Int, Error?) -> Void)?

    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?
    ) {
        onResult?(result, timestampInMilliseconds, error)
    }
}
