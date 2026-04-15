//
//  TrainingSessionRecord.swift
//  IronBuddy
//

import Foundation

struct TrainingSessionRecord: Identifiable, Hashable, Sendable {
    let id: Int64
    let exerciseType: ExerciseType
    let startTime: Date
    let endTime: Date
    let totalReps: Int
    let totalSets: Int
    let calories: Int
    let notes: String?
}

struct ExerciseSetRecord: Identifiable, Hashable, Sendable {
    let id: Int64
    let sessionId: Int64
    let repCount: Int
    let restDuration: TimeInterval?
    let timestamp: Date
}
