//
//  RepRecording.swift
//  IronBuddy
//
//  动作回放数据模型：每一次 rep 记录若干关键帧 (33 点骨架 + 时间)。
//  仅存在内存中，用于训练结束后的慢动作回放与调整建议。
//

import Foundation

/// 单个关键帧：时间相对 rep 起点 (秒) + 33 个归一化骨架点 (已做 mirror-X) + visibility。
struct RepKeyframe: Identifiable {
    let id = UUID()
    let t: TimeInterval
    let points: [CGPoint]
    let visibilities: [Float]
}

/// 单个 rep 的录像：若干关键帧 + 期间捕获到的警告 + rep 索引。
struct RepRecording: Identifiable {
    let id = UUID()
    let repIndex: Int
    let startAt: Date
    let duration: TimeInterval
    let frames: [RepKeyframe]
    /// 期间 onFormWarning 捕获到的警告（可能 0-N 条）。
    let warnings: [ReplayWarning]

    /// 给用户的"改进建议"：基于 warnings 聚合 + rep 时长判断。
    var adjustmentTips: [String] {
        var tips: [String] = []
        for w in warnings {
            tips.append("• \(w.message)：\(w.risk)")
        }
        if duration > 4.5 {
            tips.append("• 本次动作耗时较长（\(String(format: "%.1f", duration))s），可能出现疲劳，注意保持节奏。")
        } else if duration < 1.2 {
            tips.append("• 本次动作偏快（\(String(format: "%.1f", duration))s），建议放慢离心阶段以获得更好刺激。")
        }
        if tips.isEmpty {
            tips.append("• 动作标准，保持这个节奏！")
        }
        return tips
    }
}

/// 简化的警告记录（与 IronBuddyHelpers.FormWarning 平行，但不依赖 Helpers 以便在 View 层使用）。
struct ReplayWarning: Hashable {
    let type: String
    let message: String
    let risk: String
}
