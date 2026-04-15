//
//  RepReplayRecorder.swift
//  IronBuddy
//
//  录制最近 N 秒的骨架帧，在检测到 onRep 触发时把时间窗口内的帧
//  打包成一个 `RepRecording`，供训练结束后回放使用。
//

import Foundation

@MainActor
final class RepReplayRecorder {
    /// 每个 rep 最多保留多少秒的帧（覆盖 rep 前的准备 + rep 执行本身）。
    private let windowSeconds: TimeInterval = 2.5
    /// 采样上限（避免内存爆炸）：按 ~15fps 估算 2.5s ≈ 38 帧，放大到 60 做安全边界。
    private let maxFramesPerRep = 60

    /// 滚动缓冲：最近的帧（时间升序）。
    private var buffer: [RepKeyframe] = []
    /// 缓冲期间已捕获的警告（滚动窗口内）。
    private var pendingWarnings: [ReplayWarning] = []

    /// 已完成的 rep 录像（按 rep 顺序）。
    private(set) var recordings: [RepRecording] = []

    private var tStart: Date = Date()

    func reset() {
        buffer.removeAll()
        pendingWarnings.removeAll()
        recordings.removeAll()
        tStart = Date()
    }

    /// 追加一帧（归一化坐标，已做 mirror-X）。
    func appendFrame(points: [CGPoint], visibilities: [Float], now: Date = Date()) {
        let t = now.timeIntervalSince(tStart)
        buffer.append(RepKeyframe(t: t, points: points, visibilities: visibilities))
        // 丢弃超出窗口的旧帧
        let cutoff = t - windowSeconds
        while let first = buffer.first, first.t < cutoff {
            buffer.removeFirst()
        }
        if buffer.count > maxFramesPerRep {
            buffer.removeFirst(buffer.count - maxFramesPerRep)
        }
    }

    /// 滚动窗口内捕获到的警告（rep 完成时一起打包）。
    func recordWarning(type: String, message: String, risk: String) {
        pendingWarnings.append(ReplayWarning(type: type, message: message, risk: risk))
    }

    /// 在 rep 完成时调用：把窗口内的帧 + 警告打包成一条录像。
    func commitRep(index: Int) {
        guard !buffer.isEmpty else { return }
        let t0 = buffer.first!.t
        let normalized = buffer.map { f in
            RepKeyframe(t: f.t - t0, points: f.points, visibilities: f.visibilities)
        }
        let duration = normalized.last?.t ?? 0
        let rec = RepRecording(
            repIndex: index,
            startAt: Date(),
            duration: duration,
            frames: normalized,
            warnings: pendingWarnings
        )
        recordings.append(rec)
        pendingWarnings.removeAll()
        // 不清 buffer：下一 rep 可能与当前 rep 共享少量收尾帧，windowSeconds 会自动滑动丢弃。
    }
}
