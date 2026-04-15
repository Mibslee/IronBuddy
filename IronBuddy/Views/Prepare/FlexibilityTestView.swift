//
//  FlexibilityTestView.swift
//  IronBuddy

import AVFoundation
import IronBuddyHelpers
import MediaPipeTasksVision
import Observation
import SwiftUI

private enum FlexibilityPhase {
    case intro
    case camera
    case result
}

private struct MovementState {
    let name: String
    let detail: String
    let voiceGuide: String
    let maxScore: Int = 25
    var attemptScores: [Int] = []
    var currentBestAngle: Double = 0
    /// 连续满足合格条件的时间起点
    var holdStart: Date?
    /// 上次检测到合格姿势的时间（用于宽容判定）
    var lastQualifiedTime: Date?

    var bestScore: Int { attemptScores.max() ?? 0 }
    var attemptsCompleted: Int { attemptScores.count }
    var maxAttempts: Int { 3 }
}

struct FlexibilityTestView: View {
    @Environment(AppState.self) private var appState
    @State private var phase: FlexibilityPhase = .intro
    @State private var camera = CameraService()
    @State private var cameraDenied = false
    @State private var usingFrontCamera = true

    @State private var tts = LocalTTSService()
    @State private var engine = PoseDetectionEngine()
    @State private var guidanceText = "请站在相机前，全身保持在画面内"
    @State private var lastGuidanceTime: Date = .distantPast

    @State private var overlayPoints: [CGPoint] = []
    @State private var overlayVisibilities: [Float] = []

    @State private var currentIndex: Int = 0
    @State private var movements: [MovementState] = [
        MovementState(name: "肩部伸展", detail: "双臂向两侧平举，尽量展开，保持 1.5 秒。", voiceGuide: "请双臂向两侧平举，尽量向后展开"),
        MovementState(name: "髋部灵活性", detail: "单腿站立，屈膝尽量抬高至胸部，保持 1.5 秒。", voiceGuide: "请单腿站立，屈膝抬腿至胸部"),
        MovementState(name: "脊柱旋转", detail: "双脚站稳，上身向左或向右旋转，保持 1.5 秒。", voiceGuide: "请上身向一侧旋转"),
        MovementState(name: "体前屈", detail: "双腿伸直站立，缓慢前屈触地，保持 1.5 秒。", voiceGuide: "请双腿伸直，缓慢前屈触地"),
    ]

    /// 当前实时检测到的分数（用于 UI 显示）
    @State private var liveScore: Int = 0
    /// 保持进度（0.0 ~ 1.0）
    @State private var holdProgress: Double = 0

    private let holdDuration: TimeInterval = 1.5
    /// 帧间宽容时间：连续 0.4 秒未检测到合格才重置
    private let gracePeriod: TimeInterval = 0.4

    var body: some View {
        Group {
            switch phase {
            case .intro: introContent
            case .camera: cameraContent
            case .result: resultContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgPrimary)
        .navigationTitle("体态评估")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { handleBack() } label: {
                    HStack(spacing: 4) { Image(systemName: "chevron.backward"); Text("返回") }
                }
            }
            if phase == .intro {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("跳过") {
                        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.flexibilityTestCompleted)
                        if !appState.path.isEmpty { appState.path.removeLast() }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Intro

    private var introContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("请依次完成以下 4 个动作，每个动作做 3 遍，系统自动识别并取最佳成绩。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)

                ForEach(Array(movements.enumerated()), id: \.offset) { i, item in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.techCyan)
                            .frame(width: 24, height: 24)
                            .background(Theme.techCyan.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.primaryText)
                            Text(item.detail).font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.subtleBorder, lineWidth: 1) }
                }

                PrimaryButton(title: "开始测试") { phase = .camera }
            }
            .padding()
        }
    }

    // MARK: - Camera

    private var cameraContent: some View {
        VStack(spacing: 0) {
            // 固定高度顶部信息区，防止布局抖动
            VStack(spacing: 6) {
                if currentIndex < movements.count {
                    let m = movements[currentIndex]
                    HStack {
                        Text("\(currentIndex + 1)/\(movements.count)  \(m.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Text("第 \(m.attemptsCompleted + 1)/\(m.maxAttempts) 遍")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                } else {
                    Text("所有动作已完成！")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }

                // 引导提示 + 实时分数（固定高度）
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(Theme.techCyan)
                        .font(.caption)
                    Text(guidanceText)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                    Spacer()
                    if liveScore > 0, currentIndex < movements.count {
                        Text("\(liveScore)分")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(liveScore >= 15 ? .green : .orange)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(height: 70)

            // 摄像头 + 骨架（固定高度，不受其他元素影响）
            ZStack(alignment: .bottom) {
                CameraPreviewView(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                PoseOverlayView(
                    normalizedPoints: overlayPoints,
                    visibilities: overlayVisibilities
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 边框
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        holdProgress > 0 ? Theme.techCyan.opacity(0.6) : Color.white.opacity(0.08),
                        lineWidth: holdProgress > 0 ? 2 : 1
                    )

                // 底部保持进度条
                if holdProgress > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.techCyan)
                                .frame(width: geo.size.width * holdProgress, height: 4)
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                    }
                }

                if cameraDenied {
                    ContentUnavailableView("无相机权限", systemImage: "camera.fill",
                                           description: Text("请在设置中允许相机后进行体态评估"))
                }
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)

            // 底部分数 + 操作（固定高度）
            VStack(spacing: 10) {
                // 四项分数条
                HStack(spacing: 8) {
                    ForEach(Array(movements.enumerated()), id: \.offset) { i, m in
                        VStack(spacing: 2) {
                            Text(String(m.name.prefix(2)))
                                .font(.system(size: 10).weight(.medium))
                                .foregroundStyle(i == currentIndex ? Theme.techCyan : Theme.tertiaryText)
                            Text(m.bestScore > 0 ? "\(m.bestScore)" : "--")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(m.bestScore > 0 ? (m.bestScore >= 19 ? .green : .orange) : Theme.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(i == currentIndex ? Theme.techCyan.opacity(0.08) : Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if i == currentIndex {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Theme.techCyan.opacity(0.3), lineWidth: 1)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                HStack {
                    Button {
                        usingFrontCamera.toggle()
                        camera.useFrontCamera = usingFrontCamera
                    } label: {
                        Label("切换摄像头", systemImage: "camera.rotate")
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                PrimaryButton(title: currentIndex >= movements.count ? "查看结果" : "结束评估") {
                    finishTest()
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
            .frame(height: 150)
        }
        .task { await startCameraIfNeeded() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            camera.stop(); engine.onLandmarks = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Result

    private var resultContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                let totalScore = movements.reduce(0) { $0 + $1.bestScore }

                // 大分数显示
                VStack(spacing: 4) {
                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(totalScore >= 75 ? .green : .orange)
                    Text("/ 100")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Text("柔韧性综合评分")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.top, 12)

                // 各项明细
                VStack(spacing: 10) {
                    ForEach(Array(movements.enumerated()), id: \.offset) { _, m in
                        HStack {
                            Text(m.name)
                                .font(.subheadline)
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            if m.attemptScores.count > 1 {
                                HStack(spacing: 4) {
                                    ForEach(Array(m.attemptScores.enumerated()), id: \.offset) { _, s in
                                        Text("\(s)")
                                            .font(.system(size: 10).monospacedDigit())
                                            .foregroundStyle(Theme.tertiaryText)
                                    }
                                }
                            }
                            Text("\(m.bestScore)/\(m.maxScore)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(m.bestScore >= 19 ? .green : .orange)
                        }
                        .padding(12)
                        .background(Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.subtleBorder, lineWidth: 1) }
                    }
                }
                .padding(.horizontal)

                PrimaryButton(title: "完成") {
                    if !appState.path.isEmpty { appState.path.removeLast() }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }

    // MARK: - Camera Setup

    private func startCameraIfNeeded() async {
        cameraDenied = false
        usingFrontCamera = true
        camera.preferUltraWide = true
        camera.applyCameraPosition(.front)

        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .video) { ok in c.resume(returning: ok) }
        }
        guard granted else { cameraDenied = true; return }

        do { try engine.loadModelIfNeeded() } catch {}

        currentIndex = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if currentIndex < movements.count {
                tts.speak("请开始第一项，\(movements[0].voiceGuide)，做三遍，取最佳成绩")
            }
        }

        engine.onLandmarks = { [self] landmarks, _ in
            Task { @MainActor in self.processLandmarks(landmarks) }
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

    // MARK: - Pose Analysis

    private func processLandmarks(_ landmarks: [NormalizedLandmark]) {
        let data = landmarks.map {
            PoseLandmarkData(x: $0.x, y: $0.y, visibility: $0.visibility?.floatValue ?? 0)
        }
        guard data.count >= 33 else { return }

        let mirrorX = usingFrontCamera
        overlayPoints = data.map { pt in
            CGPoint(x: mirrorX ? CGFloat(1.0 - pt.x) : CGFloat(pt.x), y: CGFloat(pt.y))
        }
        overlayVisibilities = data.map { $0.visibility }

        guard currentIndex < movements.count else { return }

        let now = Date()
        if now.timeIntervalSince(lastGuidanceTime) >= 4.0 {
            checkPositionGuidance(data: data, now: now)
        }

        let angle = measureMovement(index: currentIndex, data: data)
        guard angle > 0 else {
            // 宽容判定：角度为 0 但在宽容期内不重置
            if let lastQ = movements[currentIndex].lastQualifiedTime,
               now.timeIntervalSince(lastQ) > gracePeriod {
                movements[currentIndex].holdStart = nil
                movements[currentIndex].lastQualifiedTime = nil
                holdProgress = 0
                liveScore = 0
            }
            return
        }

        let score = angleToScore(movementIndex: currentIndex, angle: angle)
        liveScore = score

        // 合格门槛：得分 >= 10 才开始计时（满分 25）
        if score >= 10 {
            movements[currentIndex].lastQualifiedTime = now
            if movements[currentIndex].holdStart == nil {
                movements[currentIndex].holdStart = now
                movements[currentIndex].currentBestAngle = angle
            } else {
                if angle > movements[currentIndex].currentBestAngle {
                    movements[currentIndex].currentBestAngle = angle
                }
                let elapsed = now.timeIntervalSince(movements[currentIndex].holdStart!)
                holdProgress = min(elapsed / holdDuration, 1.0)

                if elapsed >= holdDuration {
                    let bestAngle = movements[currentIndex].currentBestAngle
                    completeAttempt(score: angleToScore(movementIndex: currentIndex, angle: bestAngle))
                }
            }
        } else {
            // 低分但在宽容期内不重置
            if let lastQ = movements[currentIndex].lastQualifiedTime,
               now.timeIntervalSince(lastQ) > gracePeriod {
                movements[currentIndex].holdStart = nil
                movements[currentIndex].lastQualifiedTime = nil
                holdProgress = 0
            }
        }
    }

    private func checkPositionGuidance(data: [PoseLandmarkData], now: Date) {
        let visiblePoints = data.filter { $0.visibility > 0.15 }
        guard visiblePoints.count >= 8 else {
            guidanceText = "未检测到人体，请进入画面"
            tts.speak("未检测到人体，请站到摄像头前")
            lastGuidanceTime = now
            return
        }
        let ys = visiblePoints.map { CGFloat($0.y) }
        let bodyHeight = ys.max()! - ys.min()!
        let xs = visiblePoints.map { CGFloat($0.x) }
        let centerX = (xs.min()! + xs.max()!) / 2.0

        if bodyHeight > 0.92 {
            guidanceText = "太近了，请后退一步"
            tts.speak("请离屏幕远一点")
            lastGuidanceTime = now
        } else if bodyHeight < 0.30 {
            guidanceText = "太远了，请靠近一些"
            tts.speak("请靠近屏幕一些")
            lastGuidanceTime = now
        } else if centerX < 0.3 {
            guidanceText = "请向右移动"
            tts.speak("请向右移动一些")
            lastGuidanceTime = now
        } else if centerX > 0.7 {
            guidanceText = "请向左移动"
            tts.speak("请向左移动一些")
            lastGuidanceTime = now
        } else {
            let m = movements[currentIndex]
            guidanceText = "\(m.voiceGuide)，第 \(m.attemptsCompleted + 1) 遍"
        }
    }

    private func measureMovement(index: Int, data: [PoseLandmarkData]) -> Double {
        func pt(_ i: Int) -> CGPoint { CGPoint(x: CGFloat(data[i].x), y: CGFloat(data[i].y)) }
        func vis(_ i: Int) -> Bool { data[i].visibility > 0.15 }

        switch index {
        case 0:
            guard vis(11), vis(15), vis(12), vis(16), vis(23), vis(24) else { return 0 }
            let left = AngleCalculator.calculateAngle(pt(23), pt(11), pt(15))
            let right = AngleCalculator.calculateAngle(pt(24), pt(12), pt(16))
            return (left + right) / 2.0
        case 1:
            guard vis(23), vis(25), vis(24), vis(26) else { return 0 }
            let leftHip = AngleCalculator.calculateAngle(pt(11), pt(23), pt(25))
            let rightHip = AngleCalculator.calculateAngle(pt(12), pt(24), pt(26))
            return max(0, 170.0 - min(leftHip, rightHip))
        case 2:
            guard vis(11), vis(12), vis(23), vis(24) else { return 0 }
            let sDx = data[12].x - data[11].x
            let hDx = data[24].x - data[23].x
            guard abs(hDx) > 0.01 else { return 0 }
            return abs(1.0 - Double(abs(sDx / hDx))) * 90.0
        case 3:
            guard vis(11), vis(23), vis(25), vis(12), vis(24), vis(26) else { return 0 }
            let left = AngleCalculator.calculateAngle(pt(11), pt(23), pt(25))
            let right = AngleCalculator.calculateAngle(pt(12), pt(24), pt(26))
            return max(0, 170.0 - (left + right) / 2.0)
        default:
            return 0
        }
    }

    private func angleToScore(movementIndex: Int, angle: Double) -> Int {
        let s: Double
        switch movementIndex {
        // 肩部伸展：手臂-躯干角度，普通人 80-120°，优秀 ≥160°
        case 0: s = mapRange(angle, inMin: 80, inMax: 170, outMin: 0, outMax: 25)
        // 髋部灵活性：170-hip 角，普通人 30-50°，优秀 ≥90°
        case 1: s = mapRange(angle, inMin: 20, inMax: 100, outMin: 0, outMax: 25)
        // 脊柱旋转：肩髋比差异×90，普通人 5-10°，优秀 ≥20°
        case 2: s = mapRange(angle, inMin: 5, inMax: 30, outMin: 0, outMax: 25)
        // 体前屈：170-hip 角，普通人 30-50°，优秀 ≥90°
        case 3: s = mapRange(angle, inMin: 20, inMax: 100, outMin: 0, outMax: 25)
        default: s = 0
        }
        return min(25, max(0, Int(s)))
    }

    private func mapRange(_ v: Double, inMin: Double, inMax: Double, outMin: Double, outMax: Double) -> Double {
        let c = min(max(v, inMin), inMax)
        return outMin + (c - inMin) / (inMax - inMin) * (outMax - outMin)
    }

    // MARK: - Auto-Advance

    private func completeAttempt(score: Int) {
        guard currentIndex < movements.count else { return }
        movements[currentIndex].attemptScores.append(score)
        movements[currentIndex].currentBestAngle = 0
        movements[currentIndex].holdStart = nil
        movements[currentIndex].lastQualifiedTime = nil
        holdProgress = 0
        liveScore = 0

        let attempt = movements[currentIndex].attemptsCompleted
        let best = movements[currentIndex].bestScore

        if attempt < movements[currentIndex].maxAttempts {
            tts.speak("第\(attempt)遍完成，\(score)分。准备第\(attempt + 1)遍")
            guidanceText = "第\(attempt)遍 \(score)分，准备第\(attempt + 1)遍"
        } else {
            tts.speak("\(movements[currentIndex].name)完成，最佳\(best)分")
            if currentIndex < movements.count - 1 {
                currentIndex += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let m = movements[currentIndex]
                    tts.speak("请开始第\(currentIndex + 1)项，\(m.voiceGuide)")
                    guidanceText = m.voiceGuide
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { finishTest() }
            }
        }
    }

    private func finishTest() {
        camera.stop(); engine.onLandmarks = nil
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.flexibilityTestCompleted)
        phase = .result
    }

    private func handleBack() {
        switch phase {
        case .result: if !appState.path.isEmpty { appState.path.removeLast() }
        case .camera: camera.stop(); engine.onLandmarks = nil; phase = .intro
        case .intro: if !appState.path.isEmpty { appState.path.removeLast() }
        }
    }
}

#Preview {
    NavigationStack {
        FlexibilityTestView()
            .environment(AppState())
    }
}
