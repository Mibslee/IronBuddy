//
//  ExerciseType.swift
//  IronBuddy
//

import Foundation

enum ExerciseType: String, CaseIterable, Identifiable {
    case pushup = "俯卧撑"
    case squat = "深蹲"
    case deadlift = "硬拉"
    case benchPress = "卧推"

    var id: String { rawValue }

    var englishName: String {
        switch self {
        case .pushup: "Push-up"
        case .squat: "Squat"
        case .deadlift: "Deadlift"
        case .benchPress: "Bench press"
        }
    }

    /// SF Symbol 名（列表、首页卡片）
    var symbolName: String {
        switch self {
        case .pushup: "figure.highintensity.intervaltraining"
        case .squat: "figure.stand"
        case .deadlift: "figure.strengthtraining.traditional"
        case .benchPress: "dumbbell.fill"
        }
    }

    /// 训练部位（展示用小字）
    var muscleGroupLabel: String {
        switch self {
        case .pushup: "胸、肩、三头肌"
        case .squat: "下肢、臀腿"
        case .deadlift: "后链、臀、背"
        case .benchPress: "胸、肩、三头肌"
        }
    }

    var metValue: Double {
        switch self {
        case .pushup: METValues.pushup
        case .squat: METValues.squat
        case .deadlift: METValues.deadlift
        case .benchPress: METValues.benchPress
        }
    }

    /// 姿态管线是否镜像 X（与俯卧撑相同：仅前摄默认动作）。
    var mirrorLandmarksForPose: Bool {
        self == .pushup
    }

    /// 默认使用前置摄像头（否则后置）。
    var usesFrontCameraByDefault: Bool {
        self == .pushup
    }

    /// 根据运动类型推荐的默认休息时间（秒）。
    var recommendedRestSeconds: Int {
        switch self {
        case .pushup: 60
        case .squat: 120
        case .deadlift: 180
        case .benchPress: 120
        }
    }

    /// 休息时间建议说明。
    var restAdvice: String {
        switch self {
        case .pushup: "俯卧撑属于自重训练，60 秒恢复即可"
        case .squat: "深蹲负荷较大，建议休息 2 分钟"
        case .deadlift: "硬拉是高强度复合动作，建议充分休息 3 分钟"
        case .benchPress: "卧推中等强度，建议休息 2 分钟"
        }
    }
}
