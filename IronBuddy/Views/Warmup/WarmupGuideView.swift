//
//  WarmupGuideView.swift
//  IronBuddy
//
//  训练前的热身/拉伸引导：几个经典动作轮播 + 每组倒计时，
//  用户可随时跳过。当前为轻量版本（未接姿态识别）。
//

import Combine
import SwiftUI

struct WarmupExercise: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    let seconds: Int
}

struct WarmupGuideView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var remaining: Int = 0
    @State private var isPaused = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let exercises: [WarmupExercise] = [
        .init(title: "颈部环绕",
              detail: "缓慢向左转 4 次、向右转 4 次，幅度自然。",
              symbol: "arrow.triangle.2.circlepath",
              seconds: 20),
        .init(title: "肩胛活动",
              detail: "双臂绕肩向前 / 向后各转 10 圈，活动肩关节。",
              symbol: "figure.arms.open",
              seconds: 30),
        .init(title: "髋部环绕",
              detail: "双手叉腰，髋部画圆，左右各 8 次。",
              symbol: "figure.cooldown",
              seconds: 30),
        .init(title: "动态深蹲",
              detail: "空手深蹲 10 次，注意膝盖与脚尖方向一致。",
              symbol: "figure.strengthtraining.functional",
              seconds: 40),
        .init(title: "侧弓步",
              detail: "左右各 6 次，拉伸腿内侧。",
              symbol: "figure.run",
              seconds: 40),
    ]

    private var current: WarmupExercise { exercises[currentIndex] }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                // 进度条
                HStack(spacing: 6) {
                    ForEach(exercises.indices, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentIndex ? Theme.techCyan : Theme.bgCard)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Image(systemName: current.symbol)
                    .font(.system(size: 96, weight: .medium))
                    .foregroundStyle(Theme.techCyan)
                    .frame(width: 180, height: 180)
                    .background(Circle().fill(Theme.bgCard))
                    .shadow(color: Theme.techCyan.opacity(0.25), radius: 30)

                VStack(spacing: 10) {
                    Text(current.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.primaryText)
                    Text(current.detail)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 32)
                }

                // 倒计时
                Text("\(remaining)")
                    .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
                    .contentTransition(.numericText())

                Spacer()

                // 控制按钮
                HStack(spacing: 14) {
                    Button {
                        isPaused.toggle()
                    } label: {
                        Label(isPaused ? "继续" : "暂停", systemImage: isPaused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bgCard))
                            .foregroundStyle(Theme.primaryText)
                    }
                    Button {
                        advance()
                    } label: {
                        Label("下一个", systemImage: "forward.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.techCyan.opacity(0.25)))
                            .foregroundStyle(Theme.techCyan)
                    }
                }
                .padding(.horizontal)

                Button("跳过热身") {
                    finish()
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .padding(.bottom, 12)
            }
            .padding(.top, 24)
        }
        .navigationTitle("热身引导")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            remaining = current.seconds
        }
        .onReceive(timer) { _ in
            guard !isPaused else { return }
            if remaining > 0 {
                remaining -= 1
            } else {
                advance()
            }
        }
    }

    private func advance() {
        if currentIndex + 1 < exercises.count {
            currentIndex += 1
            remaining = current.seconds
        } else {
            finish()
        }
    }

    private func finish() {
        // 返回原来位置（热身入口通常在 CameraPrepare 前）
        if !appState.path.isEmpty {
            appState.path.removeLast()
        } else {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        WarmupGuideView()
            .environment(AppState())
    }
}
