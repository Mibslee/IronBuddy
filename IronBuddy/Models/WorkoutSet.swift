//
//  WorkoutSet.swift
//  IronBuddy
//

import Foundation

struct WorkoutSet: Identifiable, Hashable {
    let id: UUID
    var setNumber: Int
    var reps: Int
    var weightKg: Double?
}
