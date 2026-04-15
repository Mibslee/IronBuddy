//
//  TrainingPlan.swift
//  IronBuddy
//

import Foundation

struct TrainingPlanStep: Identifiable {
    let id = UUID()
    let exercise: ExerciseType
    let targetSets: Int
    let targetReps: Int
}

struct TrainingPlan: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let difficulty: Difficulty
    let steps: [TrainingPlanStep]

    enum Difficulty: String {
        case beginner = "入门"
        case intermediate = "进阶"
        case advanced = "高级"

        var color: String {
            switch self {
            case .beginner: "green"
            case .intermediate: "orange"
            case .advanced: "red"
            }
        }
    }
}

// MARK: - Presets

extension TrainingPlan {
    static let presets: [TrainingPlan] = [
        TrainingPlan(
            name: "上肢力量",
            icon: "figure.arms.open",
            description: "俯卧撑 + 卧推，打造胸肩三头肌",
            difficulty: .beginner,
            steps: [
                TrainingPlanStep(exercise: .pushup, targetSets: 3, targetReps: 15),
                TrainingPlanStep(exercise: .benchPress, targetSets: 3, targetReps: 10),
            ]
        ),
        TrainingPlan(
            name: "下肢爆发",
            icon: "figure.run",
            description: "深蹲 + 硬拉，强化臀腿后链",
            difficulty: .intermediate,
            steps: [
                TrainingPlanStep(exercise: .squat, targetSets: 4, targetReps: 12),
                TrainingPlanStep(exercise: .deadlift, targetSets: 3, targetReps: 8),
            ]
        ),
        TrainingPlan(
            name: "全身训练",
            icon: "figure.strengthtraining.traditional",
            description: "四大动作全覆盖，均衡发展",
            difficulty: .advanced,
            steps: [
                TrainingPlanStep(exercise: .pushup, targetSets: 3, targetReps: 20),
                TrainingPlanStep(exercise: .squat, targetSets: 3, targetReps: 15),
                TrainingPlanStep(exercise: .deadlift, targetSets: 3, targetReps: 8),
                TrainingPlanStep(exercise: .benchPress, targetSets: 3, targetReps: 10),
            ]
        ),
        TrainingPlan(
            name: "新手入门",
            icon: "star.fill",
            description: "低组数低次数，适合初次训练",
            difficulty: .beginner,
            steps: [
                TrainingPlanStep(exercise: .pushup, targetSets: 2, targetReps: 10),
                TrainingPlanStep(exercise: .squat, targetSets: 2, targetReps: 10),
            ]
        ),
    ]
}
