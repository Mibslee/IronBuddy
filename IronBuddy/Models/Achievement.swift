//
//  Achievement.swift
//  IronBuddy
//

import Foundation

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let check: ([TrainingSessionRecord]) -> Bool
}

extension Achievement {
    static let all: [Achievement] = [
        Achievement(
            id: "first_workout",
            name: "初出茅庐",
            description: "完成第一次训练",
            icon: "star.fill",
            check: { $0.count >= 1 }
        ),
        Achievement(
            id: "ten_workouts",
            name: "持之以恒",
            description: "累计完成 10 次训练",
            icon: "flame.fill",
            check: { $0.count >= 10 }
        ),
        Achievement(
            id: "fifty_workouts",
            name: "铁人精神",
            description: "累计完成 50 次训练",
            icon: "trophy.fill",
            check: { $0.count >= 50 }
        ),
        Achievement(
            id: "hundred_reps",
            name: "百次突破",
            description: "单次训练完成 100 次动作",
            icon: "bolt.fill",
            check: { sessions in
                sessions.contains { $0.totalReps >= 100 }
            }
        ),
        Achievement(
            id: "all_exercises",
            name: "全面发展",
            description: "尝试过所有 4 种运动",
            icon: "figure.strengthtraining.traditional",
            check: { sessions in
                let types = Set(sessions.map(\.exerciseType))
                return types.count >= ExerciseType.allCases.count
            }
        ),
        Achievement(
            id: "streak_7",
            name: "一周不断",
            description: "连续 7 天训练",
            icon: "calendar.badge.checkmark",
            check: { sessions in
                streakDays(sessions) >= 7
            }
        ),
        Achievement(
            id: "streak_30",
            name: "月度坚持",
            description: "连续 30 天训练",
            icon: "medal.fill",
            check: { sessions in
                streakDays(sessions) >= 30
            }
        ),
        Achievement(
            id: "calories_1000",
            name: "千卡燃烧",
            description: "累计消耗 1000 kcal",
            icon: "flame.circle.fill",
            check: { sessions in
                sessions.map(\.calories).reduce(0, +) >= 1000
            }
        ),
    ]

    private static func streakDays(_ sessions: [TrainingSessionRecord]) -> Int {
        let cal = Calendar.current
        let days = Set(sessions.map { cal.startOfDay(for: $0.endTime) }).sorted(by: >)
        guard let first = days.first else { return 0 }
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        guard first >= yesterday else { return 0 }
        var streak = 1
        for i in 1..<days.count {
            let expected = cal.date(byAdding: .day, value: -1, to: days[i - 1])!
            if days[i] == expected { streak += 1 } else { break }
        }
        return streak
    }
}
