//
//  AppState.swift
//  IronBuddy
//

import Observation
import SwiftUI

enum AppRoute: Hashable {
    case actionSelect
    case flexibilityTest
    case cameraPrepare
    case train
    case setConfirm
    case done
    case history
    case workoutDetail(Int64)
    case profile
    case settings
    case trainingPlan
    case stats
    case achievements
    case actionReplay
    case warmup
}

@Observable
@MainActor
final class AppState {
    var path = NavigationPath()
    var trainingExercise: ExerciseType = .pushup

    /// 当前训练开始时间（首次进入 `TrainView` 时设置）。
    var trainingSessionStart: Date?
    /// 计数页结束本组时的识别次数，供确认页预填。
    var lastSetRepCount: Int = 0
    /// 已确认组（含组间休息结果）；结束训练时写入数据库。
    var draftSets: [TrainingDraftSet] = []
    /// 各组重量等备注，写入 `training_sessions.notes`。
    var accumulatedSessionNotes: String = ""
    /// 从组间休息返回计数页时递增，驱动相机重启。
    var trainingResumeCount: Int = 0

    /// 最近一组的动作回放（慢动作 + 调整建议）。本组结束时从 TrainingController 转存。
    var lastSetReplayRecordings: [RepRecording] = []
    /// 最近一组每次 rep 的时长（秒），用于自适应强度建议。
    var lastSetRepDurations: [TimeInterval] = []
    /// 由 AdaptiveIntensity 生成的下一组建议（nil 表示无建议 / 已被忽略）。
    var nextSetSuggestion: IntensitySuggestion?

    /// 训练计划流转：当前活动计划
    var activePlan: TrainingPlan?
    /// 训练计划流转：当前步骤索引
    var activePlanStepIndex: Int = 0

    func resetTrainingDraftForNewWorkout() {
        trainingSessionStart = nil
        lastSetRepCount = 0
        draftSets = []
        accumulatedSessionNotes = ""
        trainingResumeCount = 0
    }

    /// 检查当前训练计划是否还有下一个动作
    var hasNextPlanStep: Bool {
        guard let plan = activePlan else { return false }
        return activePlanStepIndex + 1 < plan.steps.count
    }

    /// 推进到训练计划的下一个动作
    func advancePlanStep() {
        guard let plan = activePlan else { return }
        activePlanStepIndex += 1
        guard activePlanStepIndex < plan.steps.count else {
            activePlan = nil
            return
        }
        trainingExercise = plan.steps[activePlanStepIndex].exercise
    }

    func noteTrainingResumeAfterRest() {
        trainingResumeCount += 1
    }
}
