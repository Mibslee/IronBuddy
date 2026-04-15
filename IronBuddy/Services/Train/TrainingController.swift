//
//  TrainingController.swift
//  IronBuddy
//

import AVFoundation
import Foundation
import IronBuddyHelpers
import MediaPipeTasksVision
import Observation
import UIKit

@Observable
@MainActor
final class TrainingController {
    var repCount = 0
    var formWarningText: String?
    var formRiskText: String?
    var modelMissing = false
    var cameraDenied = false
    /// 暂停姿态识别（倒计时准备期间）
    var isPaused = true
    /// 归一化骨架点（已按当前练习做 mirror-X），与 `visibilities` 等长；用于 `PoseOverlayView`。
    var overlayNormalizedPoints: [CGPoint] = []
    var overlayVisibilities: [Float] = []
    /// 多角度识别：当前推断的摄像头视角
    var detectedAngle: CameraAngle = .unknown

    private let camera = CameraService()
    private let engine = PoseDetectionEngine()
    private let tts = LocalTTSService()
    private let pushup = PushupCounter()
    private let squat = SquatCounter()
    private let deadlift = DeadliftCounter()
    private let benchPress = BenchPressCounter()
    /// 动作回放录制器：对每一次 rep 保留最近 2.5s 的骨架帧。
    let replayRecorder = RepReplayRecorder()
    /// 每次 rep 的持续时间（秒）— 供自适应强度建议分析。
    private(set) var repDurations: [TimeInterval] = []
    private var lastRepTime: Date = .distantPast

    private var exercise: ExerciseType = .pushup
    private var mirrorLandmarks = false

    /// 警告冷却：同类型警告间隔至少 5 秒
    private var lastWarningTime: Date = .distantPast
    private var lastWarningType: String = ""
    /// 训练开始后的静默期（秒），给用户摆好姿势的时间
    private let warningGracePeriod: TimeInterval = 5.0
    private var trainingStartTime: Date = .distantFuture

    var captureSession: AVCaptureSession { camera.session }

    func start(exercise: ExerciseType) async {
        resetCounters()
        repCount = 0
        formWarningText = nil
        formRiskText = nil
        overlayNormalizedPoints = []
        overlayVisibilities = []
        modelMissing = false
        cameraDenied = false
        replayRecorder.reset()
        repDurations = []
        lastRepTime = .distantPast

        isPaused = true
        self.exercise = exercise
        mirrorLandmarks = exercise.mirrorLandmarksForPose
        // 运动时默认前摄 + 最大广角，近距离拍摄更容易拍到全身
        camera.preferUltraWide = true
        camera.applyCameraPosition(exercise.usesFrontCameraByDefault ? .front : .back)

        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { ok in
                c.resume(returning: ok)
            }
        }
        guard granted else {
            cameraDenied = true
            return
        }

        do {
            try engine.loadModelIfNeeded()
        } catch {
            modelMissing = true
            return
        }

        trainingStartTime = Date()
        lastWarningTime = .distantPast
        lastWarningType = ""

        wireCounters()

        engine.onLandmarks = { [weak self] landmarks, _ in
            Task { @MainActor in
                self?.handle(landmarks: landmarks)
            }
        }

        camera.onFrame = { [weak engine] sampleBuffer, connection in
            guard let engine else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let orient = connection.uiImageOrientation
            let sec = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            let ms = Int(sec * 1000.0)
            engine.detectAsync(pixelBuffer: pixelBuffer, orientation: orient, timestampMs: ms)
        }

        camera.configureAndStart()
    }

    /// 结束准备倒计时，开始识别
    func resume() {
        isPaused = false
        trainingStartTime = Date()
    }

    func stop() {
        camera.onFrame = nil
        engine.onLandmarks = nil
        camera.stop()
    }

    func toggleCamera() {
        camera.useFrontCamera.toggle()
        mirrorLandmarks = camera.useFrontCamera
    }

    private func resetCounters() {
        pushup.reset()
        squat.reset()
        deadlift.reset()
        benchPress.reset()
    }

    private func wireCounters() {
        let handleWarning: (FormWarning) -> Void = { [weak self] w in
            self?.handleFormWarning(w)
        }
        let handleRep: (Int) -> Void = { [weak self] n in
            guard let self else { return }
            self.repCount = n
            self.tts.speak("\(n)")
            // 记录 rep 时长
            let now = Date()
            if self.lastRepTime != .distantPast {
                self.repDurations.append(now.timeIntervalSince(self.lastRepTime))
            }
            self.lastRepTime = now
            // 提交本次 rep 的录像（滚动窗口内的帧 + 警告）
            self.replayRecorder.commitRep(index: n)
        }

        pushup.onRep = handleRep
        pushup.onFormWarning = handleWarning

        squat.onRep = handleRep
        squat.onFormWarning = handleWarning

        deadlift.onRep = handleRep
        deadlift.onFormWarning = handleWarning

        benchPress.onRep = handleRep
        benchPress.onFormWarning = handleWarning
    }

    private func handleFormWarning(_ w: FormWarning) {
        let now = Date()

        // 训练开始后静默期：给用户摆好姿势的时间
        guard now.timeIntervalSince(trainingStartTime) > warningGracePeriod else { return }

        // 老手模式：只播报"高风险"警告，其它静默
        let level = UserLevel(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.userLevel)) ?? .beginner
        if level == .expert {
            let severe = w.risk.contains("伤") || w.risk.contains("严重") || w.type.contains("hips_sagging") || w.type.contains("knee_valgus")
            guard severe else {
                formWarningText = w.message
                formRiskText = w.risk
                return
            }
        }

        // 只在有效运动状态下发出警告（已完成至少一次动作后，或已进入非 idle 状态）
        let isActive: Bool
        switch exercise {
        case .pushup:   isActive = pushup.state != .idle
        case .squat:    isActive = squat.state != .idle
        case .deadlift: isActive = deadlift.phase != .idle
        case .benchPress: isActive = benchPress.state != .idle
        }
        guard isActive else { return }

        // 同类型警告冷却 5 秒，不同类型冷却 3 秒
        let cooldown: TimeInterval = (w.type == lastWarningType) ? 5.0 : 3.0
        guard now.timeIntervalSince(lastWarningTime) > cooldown else {
            // 仍更新文字但不语音播报
            formWarningText = w.message
            formRiskText = w.risk
            return
        }

        lastWarningTime = now
        lastWarningType = w.type
        formWarningText = w.message
        formRiskText = w.risk
        tts.speak(w.message)
        // 同步喂给回放录制器，作为"本 rep 发现的问题"
        replayRecorder.recordWarning(type: w.type, message: w.message, risk: w.risk)
    }

    private func updatePoseOverlay(data: [PoseLandmarkData]) {
        guard data.count >= 33 else {
            overlayNormalizedPoints = []
            overlayVisibilities = []
            return
        }
        overlayNormalizedPoints = data.map { PoseLandmarkMath.point(from: $0, mirrorX: mirrorLandmarks) }
        overlayVisibilities = data.map { PoseLandmarkMath.visibility($0) }
        // 喂给回放录制器（滚动窗口）
        replayRecorder.appendFrame(points: overlayNormalizedPoints, visibilities: overlayVisibilities)
    }

    private func handle(landmarks: [NormalizedLandmark]) {
        let data = PoseLandmarkBridge.toPoseData(landmarks)
        // 暂停时不更新骨架也不计数
        guard !isPaused else { return }
        updatePoseOverlay(data: data)
        detectedAngle = CameraAngleDetector.detect(landmarks: data)
        switch exercise {
        case .pushup:
            pushup.process(landmarks: data, mirrorX: mirrorLandmarks)
        case .squat:
            squat.process(landmarks: data, mirrorX: false)
        case .deadlift:
            deadlift.process(landmarks: data, mirrorX: false)
        case .benchPress:
            benchPress.process(landmarks: data, mirrorX: false)
        }
    }
}
