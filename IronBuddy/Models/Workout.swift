//
//  Workout.swift
//  IronBuddy
//

import Foundation

struct Workout: Identifiable, Hashable {
    let id: UUID
    var exerciseType: ExerciseType
    var startedAt: Date
    var endedAt: Date?
}
