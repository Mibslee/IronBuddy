//
//  Constants.swift
//  IronBuddy
//

import Foundation

// AngleThresholds 已迁至 IronBuddyHelpers/PoseCounters.swift。

enum METValues {
    static let pushup = 4.8
    static let squat = 5.0
    static let deadlift = 6.0
    static let benchPress = 5.0
}

enum UserDefaultsKeys {
    static let profileWeightKg = "profileWeightKg"
    /// 组间休息默认秒数（设置页可改）。
    static let restSecondsBetweenSets = "restSecondsBetweenSets"
    static let healthKitAuthRequested = "healthKitAuthRequested"
    /// 体态/柔韧性评估是否已完成（`FlexibilityTestView` 写入）。
    static let flexibilityTestCompleted = "flexibilityTestCompleted"
    /// 训练时是否启用 TTS 语音播报（设置页 Toggle）。
    static let ttsEnabled = "ttsEnabled"
    /// 外观模式：0=跟随系统，1=深色，2=浅色
    static let appearanceMode = "appearanceMode"
    /// 用户水平：0=新手（更多提示/引导），1=老手（更少打扰）
    static let userLevel = "userLevel"
    /// 是否启用热身/拉伸引导
    static let warmupEnabled = "warmupEnabled"
    /// 是否启用动作回放（训练结束后进入回放）
    static let replayEnabled = "replayEnabled"
    /// 是否启用自适应强度建议
    static let adaptiveIntensityEnabled = "adaptiveIntensityEnabled"
}

/// 用户水平：影响警告播报频率、引导详尽程度、强度建议显示策略。
enum UserLevel: Int, CaseIterable, Identifiable {
    case beginner = 0
    case expert = 1
    var id: Int { rawValue }
    var title: String { self == .beginner ? "新手" : "老手" }
    var detail: String {
        self == .beginner
            ? "更多动作引导、警告提醒、强度建议"
            : "更自由，仅在重大风险时提醒"
    }
}

enum AppDefaults {
    static let restSecondsBetweenSets = 60
}
