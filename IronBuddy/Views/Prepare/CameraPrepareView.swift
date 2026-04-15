//
//  CameraPrepareView.swift
//  IronBuddy

import AVFoundation
import MediaPipeTasksVision
import Observation
import SwiftUI

/// AI 引导拍摄阶段
private enum GuidePhase: Equatable {
    /// 扫描场地中
    case scanning
    /// 已检测到人，引导调整站位
    case adjusting
    /// 位置合适，准备就绪
    case ready
}

struct CameraPrepareView: View {
    @Environment(AppState.self) private var appState

    @State private var camera = CameraService()
    @State private var engine = PoseDetectionEngine()
    @State private var tts = LocalTTSService()
    @State private var cameraDenied = false

    @State private var guidePhase: GuidePhase = .scanning
    @State private var guidanceText = "正在扫描运动场地…"
    @State private var guidanceIcon = "viewfinder"
    @State private var lastGuidanceTime: Date = .distantPast
    @State private var readySeconds: Int = 0
    @State private var readyTimer: Timer?

    /// 骨架覆盖层
    @State private var overlayPoints: [CGPoint] = []
    @State private var overlayVisibilities: [Float] = []

    /// 自动变焦目标
    @State private var currentZoom: CGFloat = 1.0

    /// 建议信息
    @State private var placementTip: String?

    @AppStorage(UserDefaultsKeys.warmupEnabled) private var warmupEnabled = true

    var body: some View {
        VStack(spacing: 12) {
            if warmupEnabled {
                Button {
                    appState.path.append(AppRoute.warmup)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.cooldown")
                            .foregroundStyle(Theme.techCyan)
                        Text("训练前热身（可跳过）")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
            }
            // 标题与阶段指示
            HStack(spacing: 8) {
                Image(systemName: guidanceIcon)
                    .foregroundStyle(guidePhase == .ready ? .green : .orange)
                    .font(.title3)
                Text(guidanceText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(guidePhase == .ready ? .green : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // 摄像头预览
            ZStack {
                CameraPreviewView(session: camera.session)
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                guidePhase == .ready ? Color.green.opacity(0.6) : Color.secondary.opacity(0.3),
                                lineWidth: guidePhase == .ready ? 2 : 1
                            )
                    }

                PoseOverlayView(
                    normalizedPoints: overlayPoints,
                    visibilities: overlayVisibilities
                )
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if cameraDenied {
                    ContentUnavailableView(
                        "无相机权限",
                        systemImage: "camera.fill",
                        description: Text("请在设置中允许相机，用于 AI 引导拍摄")
                    )
                }

            }
            .padding(.horizontal)

            // 放置建议
            if let tip = placementTip {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            Spacer(minLength: 8)

            // 按钮区
            PrimaryButton(title: guidePhase == .ready ? "位置合适，进入训练" : "跳过引导，直接训练") {
                cleanup()
                appState.path.append(AppRoute.train)
            }
            .padding(.horizontal)

            if guidePhase != .ready {
                Text("请根据语音提示调整站位")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom)
        .navigationTitle("AI 拍摄引导")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await startGuide()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            cleanup()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Camera & Pose Setup

    private func startGuide() async {
        // AI 扫描场地始终使用后置摄像头
        camera.applyCameraPosition(.back)

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
            // 模型缺失时仍允许进入训练
        }

        // 开始语音引导
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            tts.speak("请用摄像头扫描运动场地，我来帮您选择最佳站位")
            let ex = appState.trainingExercise
            placementTip = "建议将手机放在距离您 1.5 到 3 米处，\(ex.usesFrontCameraByDefault ? "正对面" : "侧面")角度拍摄"
        }

        engine.onLandmarks = { [self] landmarks, _ in
            Task { @MainActor in
                self.handleGuidanceLandmarks(landmarks: landmarks)
            }
        }

        camera.onFrame = { [engine] sampleBuffer, connection in
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let orient = connection.uiImageOrientation
            let sec = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            let ms = Int(sec * 1000.0)
            engine.detectAsync(pixelBuffer: pixelBuffer, orientation: orient, timestampMs: ms)
        }

        camera.configureAndStart()
    }

    // MARK: - Guidance Logic

    private func handleGuidanceLandmarks(landmarks: [NormalizedLandmark]) {
        let exercise = appState.trainingExercise
        let mirrorX = exercise.usesFrontCameraByDefault

        let data = landmarks.map {
            (x: CGFloat($0.x), y: CGFloat($0.y), vis: $0.visibility?.floatValue ?? 0)
        }
        guard data.count >= 33 else { return }

        // 更新骨架覆盖
        overlayPoints = data.map { pt in
            CGPoint(x: mirrorX ? (1.0 - pt.x) : pt.x, y: pt.y)
        }
        overlayVisibilities = data.map { Float($0.vis) }

        let now = Date()
        guard now.timeIntervalSince(lastGuidanceTime) >= 3.0 else { return }

        let visiblePoints = data.filter { $0.vis > 0.25 }
        guard visiblePoints.count >= 10 else {
            guidePhase = .scanning
            guidanceText = "正在扫描运动场地…"
            guidanceIcon = "viewfinder"
            readySeconds = 0
            stopReadyTimer()
            return
        }

        // 人体包围盒
        let xs = visiblePoints.map(\.x)
        let ys = visiblePoints.map(\.y)
        let minX = xs.min()!
        let maxX = xs.max()!
        let minY = ys.min()!
        let maxY = ys.max()!
        let bodyHeight = maxY - minY
        let centerX = (minX + maxX) / 2.0

        guidePhase = .adjusting
        guidanceIcon = "person.fill.viewfinder"

        // 检查关键身体部分是否可见（头、肩、髋、膝、踝）
        let keyIndices = [0, 11, 12, 23, 24, 25, 26, 27, 28]
        let visibleKeyCount = keyIndices.filter { i in
            i < data.count && data[i].vis > 0.25
        }.count

        var issues: [String] = []

        // 距离判断
        if bodyHeight > 0.88 {
            issues.append("太近了，请后退一步")
            // 缩小变焦
            let targetZoom = max(currentZoom - 0.2, 1.0)
            if targetZoom != currentZoom {
                currentZoom = targetZoom
                camera.rampZoom(to: currentZoom)
            }
        } else if bodyHeight < 0.3 {
            issues.append("太远了，请靠近一些")
            // 尝试自动变焦拉近
            let targetZoom = min(currentZoom + 0.3, 3.0)
            if targetZoom != currentZoom {
                currentZoom = targetZoom
                camera.rampZoom(to: currentZoom)
            }
        }

        // 左右位置
        if centerX < 0.3 {
            issues.append(mirrorX ? "请向左移动" : "请向右移动")
        } else if centerX > 0.7 {
            issues.append(mirrorX ? "请向右移动" : "请向左移动")
        }

        // 上下位置
        if minY < 0.02 {
            issues.append("头部超出画面上方")
        }
        if maxY > 0.95 {
            issues.append("脚部被画面截断，请后退")
        }

        // 关键部位可见性
        if visibleKeyCount < 6 {
            issues.append("部分身体被遮挡，请确保全身入镜")
        }

        if issues.isEmpty {
            // 位置合适
            guidePhase = .ready
            guidanceText = "位置很好！人物已居中"
            guidanceIcon = "checkmark.circle.fill"
            placementTip = "手机放在当前位置即可，\(exercise.rawValue)建议\(exercise.usesFrontCameraByDefault ? "正面" : "侧面")拍摄"

            if readySeconds == 0 {
                tts.speak("位置很好，可以开始训练了")
                lastGuidanceTime = now
            }
            startReadyTimer()
        } else {
            readySeconds = 0
            stopReadyTimer()
            let firstIssue = issues[0]
            guidanceText = firstIssue
            tts.speak(firstIssue)
            lastGuidanceTime = now
        }
    }

    // MARK: - Ready Timer

    private func startReadyTimer() {
        guard readyTimer == nil else { return }
        readyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                readySeconds += 1
            }
        }
    }

    private func stopReadyTimer() {
        readyTimer?.invalidate()
        readyTimer = nil
    }

    // MARK: - Cleanup

    private func cleanup() {
        camera.stop()
        camera.onFrame = nil
        engine.onLandmarks = nil
        stopReadyTimer()
        // 重置变焦
        if currentZoom != 1.0 {
            camera.setZoomFactor(1.0)
            currentZoom = 1.0
        }
    }
}

#Preview {
    NavigationStack {
        CameraPrepareView()
            .environment(AppState())
    }
}
