//
//  TrainingDraftSet.swift
//  IronBuddy
//

import Foundation

struct TrainingDraftSet: Equatable, Sendable {
    var repCount: Int
    var confirmedAt: Date
    /// 本组结束后实际休息秒数（跳过为 0）。
    var restAfterSeconds: TimeInterval?
}
