//
//  IntensitySuggestion.swift
//  IronBuddy
//
//  自适应强度建议：基于本组 rep 时长的均值与后半段斜率判断"费力 / 轻松"，
//  给出下一组的重量或组数调整建议。
//

import Foundation

enum IntensityLevel {
    case tooLight    // 太轻松 → 加量
    case moderate    // 合适 → 保持
    case tooHard     // 太吃力 → 减量
}

struct IntensitySuggestion: Equatable {
    let level: IntensityLevel
    let title: String
    let detail: String
    /// 相对第一组的变化量（+1 组、-1 组、+2.5kg 等，用文字表达）
    let suggestion: String

    static func == (lhs: IntensitySuggestion, rhs: IntensitySuggestion) -> Bool {
        lhs.title == rhs.title && lhs.detail == rhs.detail && lhs.suggestion == rhs.suggestion
    }
}

enum AdaptiveIntensityAnalyzer {
    /// 根据一组 rep 的时长序列（秒）判断强度。
    /// - 前半段平均 vs 后半段平均：若后半段显著更慢 → 出现疲劳
    /// - 整体平均：过快（<1.5s）= 太轻；过慢（>3.5s）= 太重
    static func analyze(repDurations: [TimeInterval]) -> IntensitySuggestion? {
        guard repDurations.count >= 3 else { return nil }
        let half = repDurations.count / 2
        let firstHalf = Array(repDurations.prefix(half))
        let secondHalf = Array(repDurations.suffix(repDurations.count - half))
        let avg1 = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let avg2 = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let overall = repDurations.reduce(0, +) / Double(repDurations.count)

        // 显著变慢：后半段比前半段慢 > 40%
        let fatigueRatio = avg2 / max(avg1, 0.01)

        if fatigueRatio > 1.4 || overall > 3.5 {
            return IntensitySuggestion(
                level: .tooHard,
                title: "本组较吃力",
                detail: String(format: "整体节奏 %.1fs/次，后半段明显变慢 (×%.2f)。", overall, fatigueRatio),
                suggestion: "下一组建议减少 2 次或降低 2.5 kg 重量。"
            )
        } else if overall < 1.5 && fatigueRatio < 1.15 {
            return IntensitySuggestion(
                level: .tooLight,
                title: "本组较轻松",
                detail: String(format: "整体节奏 %.1fs/次，后半段几乎无变化。", overall),
                suggestion: "下一组可以尝试增加 2 次或增加 2.5 kg 重量。"
            )
        } else {
            return IntensitySuggestion(
                level: .moderate,
                title: "强度合适",
                detail: String(format: "整体节奏 %.1fs/次，节奏稳定。", overall),
                suggestion: "保持当前重量和次数。"
            )
        }
    }
}
