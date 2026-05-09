//
//  ActionReplayView.swift
//  IronBuddy
//
//  动作回放：选中 rep → 慢动作骨架播放 + 调整建议。
//  帧数据来自 TrainingController.replayRecorder（内存）。
//

import Combine
import SwiftUI

struct ActionReplayView: View {
    let recordings: [RepRecording]
    @State private var selectedRepIndex: Int = 0
    @State private var isPlaying = true
    @State private var playbackSpeed: Double = 0.5  // 默认 0.5x 慢动作
    @State private var currentTime: TimeInterval = 0
    @State private var lastTick: Date = Date()
    @Environment(\.dismiss) private var dismiss

    @State private var isTimerActive = true
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var current: RepRecording? {
        guard selectedRepIndex >= 0, selectedRepIndex < recordings.count else { return nil }
        return recordings[selectedRepIndex]
    }

    private var interpolatedFrame: RepKeyframe? {
        guard let rec = current, !rec.frames.isEmpty else { return nil }
        // 找到 currentTime 前后最近的两帧，直接用最近的一帧（避免点位漂移）
        var chosen = rec.frames.first!
        for f in rec.frames {
            if f.t <= currentTime {
                chosen = f
            } else {
                break
            }
        }
        return chosen
    }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                // 顶部：rep 选择器
                repPicker

                // 中部：骨架回放
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.overlayBlack.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Theme.techCyan.opacity(0.25), lineWidth: 1)
                        )

                    if let frame = interpolatedFrame {
                        PoseOverlayView(
                            normalizedPoints: frame.points,
                            visibilities: frame.visibilities
                        )
                        .padding(8)
                    } else {
                        Text("无回放数据")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    // 左上：时间戳
                    if let rec = current {
                        VStack {
                            HStack {
                                Text(String(format: "%.2fs / %.2fs", currentTime, rec.duration))
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .foregroundStyle(Theme.primaryText)
                                Spacer()
                                Text(String(format: "%.2fx", playbackSpeed))
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Theme.techCyan.opacity(0.2), in: Capsule())
                                    .foregroundStyle(Theme.techCyan)
                            }
                            .padding(12)
                            Spacer()
                        }
                    }
                }
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                // 控制条
                controls

                // 调整建议
                if let rec = current {
                    tipsSection(rec: rec)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .navigationTitle("动作回放")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
        .onReceive(timer) { _ in
            if isPlaying { advanceIfPlaying() }
        }
        .onChange(of: isPlaying) { _, newValue in
            isTimerActive = newValue
            if newValue { lastTick = Date() }
        }
        .onChange(of: selectedRepIndex) { _, _ in
            currentTime = 0
            isPlaying = true
        }
    }

    // MARK: - Sub views

    private var repPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(recordings.enumerated()), id: \.offset) { idx, rec in
                    Button {
                        selectedRepIndex = idx
                    } label: {
                        VStack(spacing: 2) {
                            Text("#\(rec.repIndex)")
                                .font(.headline)
                            Text(String(format: "%.1fs", rec.duration))
                                .font(.caption2.monospaced())
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                selectedRepIndex == idx
                                ? Theme.techCyan.opacity(0.25)
                                : Theme.bgCard
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedRepIndex == idx ? Theme.techCyan : Color.clear,
                                lineWidth: 1.5
                            )
                        )
                        .foregroundStyle(Theme.primaryText)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Button {
                    currentTime = 0
                    isPlaying = true
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .accessibilityLabel("从头播放")
                Button {
                    isPlaying.toggle()
                    lastTick = Date()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Theme.techCyan.opacity(0.25)))
                }
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
                Button {
                    playbackSpeed = playbackSpeed <= 0.26 ? 1.0 : max(0.25, playbackSpeed - 0.25)
                } label: {
                    Text(String(format: "%.2fx", playbackSpeed))
                        .font(.body.monospaced())
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.bgCard))
                }
                .accessibilityLabel("调整播放速度")
            }
            .foregroundStyle(Theme.primaryText)

            if let rec = current {
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { newVal in
                            currentTime = newVal
                            isPlaying = false
                        }
                    ),
                    in: 0...max(rec.duration, 0.01)
                )
                .tint(Theme.techCyan)
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    private func tipsSection(rec: RepRecording) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("调整建议")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            ForEach(rec.adjustmentTips, id: \.self) { tip in
                Text(tip)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bgCard))
        .padding(.horizontal)
    }

    private func advanceIfPlaying() {
        guard isPlaying, let rec = current else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastTick) * playbackSpeed
        lastTick = now
        currentTime += dt
        if currentTime >= rec.duration {
            currentTime = 0  // loop
        }
    }
}

#Preview {
    NavigationStack {
        ActionReplayView(recordings: [])
    }
}
