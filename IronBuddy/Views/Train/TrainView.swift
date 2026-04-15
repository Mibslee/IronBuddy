//
//  TrainView.swift
//  IronBuddy
//

import Observation
import SwiftUI

struct TrainView: View {
    @Environment(AppState.self) private var appState
    @State private var training = TrainingController()
    @State private var voice = VoiceCommandService()
    @State private var voiceEnabled = false
    @State private var savedBrightness: CGFloat = 1.0
    @State private var countdown: Int = 0

    var body: some View {
        ZStack {
            // Black background for when camera isn't loaded yet
            Color.black
                .ignoresSafeArea()

            // Full-screen camera preview
            CameraPreviewView(session: training.captureSession)
                .ignoresSafeArea()

            // Pose overlay (same size as camera)
            PoseOverlayView(
                normalizedPoints: training.overlayNormalizedPoints,
                visibilities: training.overlayVisibilities
            )
            .ignoresSafeArea()

            // Error states
            if training.modelMissing {
                ContentUnavailableView("缺少模型", systemImage: "exclamationmark.triangle",
                                       description: Text("请将 pose_landmarker.task 加入 App 资源"))
            } else if training.cameraDenied {
                ContentUnavailableView("无相机权限", systemImage: "camera.fill",
                                       description: Text("请在设置中允许相机，用于本地姿态识别"))
            }

            // 倒计时准备覆盖层
            if countdown > 0 {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("\(countdown)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: Theme.techCyan.opacity(0.6), radius: 20)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: countdown)
                        Text("准备就绪")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .zIndex(10)
            }

            // Floating UI overlays
            VStack {
                // Top bar
                HStack {
                    Text(appState.trainingExercise.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)

                    Spacer()

                    Button {
                        voiceEnabled.toggle()
                        if voiceEnabled {
                            Task { await startVoice() }
                        } else {
                            voice.stopListening()
                        }
                    } label: {
                        Image(systemName: voiceEnabled ? "mic.fill" : "mic.slash")
                            .font(.body.weight(.medium))
                            .foregroundStyle(voiceEnabled ? Theme.techCyan : Theme.primaryText)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Button {
                        training.toggleCamera()
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.primaryText)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Spacer()

                // Floating rep counter (centered pill)
                CountDisplayView(repCount: training.repCount)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: Capsule())

                // 多角度识别：摄像头视角提示
                if training.detectedAngle != .unknown {
                    Text(training.detectedAngle.rawValue + " · " + training.detectedAngle.tip)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                }

                Spacer()

                // Form warning (if present)
                if let tip = training.formWarningText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                        if let risk = training.formRiskText {
                            Text(risk)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Bottom action bar
                VStack(spacing: 0) {
                    PrimaryButton(title: "本组结束，确认") {
                        appState.lastSetRepCount = training.repCount
                        stashReplayAndDurations()
                        training.stop()
                        appState.path.append(AppRoute.setConfirm)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            savedBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = max(savedBrightness, 0.6)
        }
        .task(id: appState.trainingResumeCount) {
            if appState.trainingSessionStart == nil {
                appState.trainingSessionStart = Date()
            }
            await training.start(exercise: appState.trainingExercise)
            // 3-2-1 倒计时
            countdown = 3
            for i in stride(from: 3, through: 1, by: -1) {
                countdown = i
                try? await Task.sleep(for: .seconds(1))
            }
            countdown = 0
            training.resume()
        }
        .onDisappear {
            training.stop()
            voice.stopListening()
            UIApplication.shared.isIdleTimerDisabled = false
            UIScreen.main.brightness = savedBrightness
        }
        .onChange(of: training.repCount) { _, _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .onChange(of: training.formWarningText) { _, newValue in
            if newValue != nil {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        }
    }

    private func stashReplayAndDurations() {
        appState.lastSetReplayRecordings = training.replayRecorder.recordings
        appState.lastSetRepDurations = training.repDurations
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.adaptiveIntensityEnabled) as? Bool ?? true {
            appState.nextSetSuggestion = AdaptiveIntensityAnalyzer.analyze(repDurations: training.repDurations)
        } else {
            appState.nextSetSuggestion = nil
        }
    }

    private func startVoice() async {
        let ok = await voice.requestPermission()
        guard ok else {
            voiceEnabled = false
            return
        }
        voice.onCommand = { [weak appState] cmd in
            switch cmd {
            case .stop, .nextSet:
                appState?.lastSetRepCount = training.repCount
                stashReplayAndDurations()
                training.stop()
                appState?.path.append(AppRoute.setConfirm)
            case .start:
                break // already training
            case .skip:
                break
            }
        }
        voice.startListening()
    }
}

#Preview {
    NavigationStack {
        TrainView()
            .environment(AppState())
    }
}
