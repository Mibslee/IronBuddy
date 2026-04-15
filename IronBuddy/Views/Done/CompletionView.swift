//
//  CompletionView.swift
//  IronBuddy
//

import IronBuddyHelpers
import Observation
import SwiftUI

private struct CompletionSummary {
    let start: Date
    let end: Date
    let exercise: ExerciseType
    let sets: [TrainingDraftSet]
    let notes: String?
}

struct CompletionView: View {
    @Environment(AppState.self) private var appState
    @State private var summary: CompletionSummary?
    @State private var saveError: String?
    @State private var didSave = false

    var body: some View {
        List {
            if let summary {
                Section("本次训练") {
                    LabeledContent("动作", value: summary.exercise.rawValue)
                    LabeledContent("组数", value: "\(summary.sets.count)")
                    LabeledContent("总次数", value: "\(totalReps(summary))")
                    LabeledContent("时长", value: formatDuration(summary.end.timeIntervalSince(summary.start)))
                    LabeledContent("估算热量", value: "\(estimatedCalories(summary)) kcal")
                }
                .listRowBackground(Theme.bgCard)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(.red)
                }
                .listRowBackground(Theme.bgCard)
            }

            if appState.hasNextPlanStep, let plan = appState.activePlan {
                let nextIdx = appState.activePlanStepIndex + 1
                let nextStep = plan.steps[nextIdx]
                Section("训练计划") {
                    HStack {
                        Text("下一动作：\(nextStep.exercise.rawValue)")
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Text("\(nextStep.targetSets)组×\(nextStep.targetReps)次")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .listRowBackground(Theme.bgCard)

                    PrimaryButton(title: "开始下一动作") {
                        appState.advancePlanStep()
                        appState.resetTrainingDraftForNewWorkout()
                        appState.path = NavigationPath()
                        appState.path.append(AppRoute.actionSelect)
                        appState.path.append(AppRoute.cameraPrepare)
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                PrimaryButton(title: "查看历史") {
                    appState.activePlan = nil
                    appState.path = NavigationPath()
                    appState.path.append(AppRoute.history)
                }
                .listRowBackground(Color.clear)

                Button("回首页") {
                    appState.activePlan = nil
                    appState.path = NavigationPath()
                }
                .listRowBackground(Theme.bgCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bgPrimary)
        .foregroundStyle(Theme.primaryText)
        .navigationTitle("训练完成")
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if summary == nil {
                let note = appState.accumulatedSessionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                summary = CompletionSummary(
                    start: appState.trainingSessionStart ?? Date(),
                    end: Date(),
                    exercise: appState.trainingExercise,
                    sets: appState.draftSets,
                    notes: note.isEmpty ? nil : note
                )
            }
        }
        .task(id: summary?.end.timeIntervalSince1970) {
            await persistIfNeeded()
        }
    }

    private func totalReps(_ s: CompletionSummary) -> Int {
        s.sets.map(\.repCount).reduce(0, +)
    }

    private func estimatedCalories(_ s: CompletionSummary) -> Int {
        let w = UserDefaults.standard.double(forKey: UserDefaultsKeys.profileWeightKg)
        let weight = w > 0 ? w : 70
        let sec = s.end.timeIntervalSince(s.start)
        let minutes = max(1, Int(ceil(sec / 60.0)))
        return CalorieEstimator.estimateCalories(mets: s.exercise.metValue, weightKg: weight, durationMinutes: minutes)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return "\(m) 分 \(sec) 秒"
    }

    private func persistIfNeeded() async {
        guard let summary, !didSave else { return }
        guard !summary.sets.isEmpty else {
            saveError = "没有可保存的组数据"
            return
        }
        let kcal = estimatedCalories(summary)
        do {
            _ = try DatabaseService.saveTrainingSession(
                exerciseType: summary.exercise,
                start: summary.start,
                end: summary.end,
                sets: summary.sets,
                totalCalories: kcal,
                notes: summary.notes
            )
            didSave = true
            appState.resetTrainingDraftForNewWorkout()
            let hk = HealthKitService()
            do {
                try await hk.saveWorkout(
                    type: summary.exercise.rawValue,
                    start: summary.start,
                    end: summary.end,
                    calories: Double(kcal),
                    notes: summary.notes ?? ""
                )
            } catch {
                // HealthKit 失败不阻塞
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CompletionView()
            .environment(AppState())
    }
}
