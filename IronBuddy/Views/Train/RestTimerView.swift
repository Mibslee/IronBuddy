//
//  RestTimerView.swift
//  IronBuddy
//

import AudioToolbox
import IronBuddyHelpers
import SwiftUI
import UIKit

struct RestTimerView: View {
    let totalSeconds: Int
    var restAdvice: String?
    var onSkip: () -> Void
    var onFinished: (_ elapsedSeconds: Int) -> Void

    @State private var remaining: Int
    @State private var timerToken: Timer?
    @State private var tts = LocalTTSService()

  init(totalSeconds: Int, restAdvice: String? = nil, onSkip: @escaping () -> Void, onFinished: @escaping (_ elapsedSeconds: Int) -> Void) {
        self.totalSeconds = RestTimerDisplay.normalizedTotalSeconds(totalSeconds)
        self.restAdvice = restAdvice
        self.onSkip = onSkip
        self.onFinished = onFinished
        _remaining = State(initialValue: self.totalSeconds)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("组间休息")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            Text(RestTimerDisplay.clockString(totalSeconds: remaining))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
            Text(RestTimerDisplay.hint(remaining: remaining))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            // 智能休息建议
            if let advice = restAdvice {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                    Text(advice)
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button("跳过休息") {
                stopTimer()
                let elapsed = totalSeconds - remaining
                onFinished(elapsed)
                onSkip()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgPrimary)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            startTimer()
        }
        .onDisappear {
            stopTimer()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func startTimer() {
        // 防止 onAppear 重入造成定时器叠加 / 倒计时倍速。
        stopTimer()
        tts.speak("休息 \(totalSeconds) 秒")
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if remaining > 0 {
                    remaining -= 1
                    if remaining == 30 {
                        tts.speak("还剩 30 秒")
                    }
                }
                if remaining == 0 {
                    stopTimer()
                    playEndFeedback()
                    tts.speak("休息结束")
                    onFinished(totalSeconds)
                    onSkip()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timerToken = t
    }

    private func stopTimer() {
        timerToken?.invalidate()
        timerToken = nil
    }

    private func playEndFeedback() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
}
