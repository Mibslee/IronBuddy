//
//  SetConfirmSheet.swift
//  IronBuddy
//

import Observation
import SwiftUI

struct SetConfirmSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.restSecondsBetweenSets) private var restSecondsStorage: Int = AppDefaults.restSecondsBetweenSets
    @State private var reps = 0
    @State private var weight = ""
    @State private var showRest = false

    /// 智能休息时间：优先使用用户设置，否则按运动类型推荐。
    private var restDuration: Int {
        if restSecondsStorage > 0, restSecondsStorage != AppDefaults.restSecondsBetweenSets {
            // 用户手动设置过
            return max(30, restSecondsStorage)
        }
        // 使用运动类型推荐值
        return appState.trainingExercise.recommendedRestSeconds
    }

    var body: some View {
        Form {
            Section("本组数据") {
                Stepper("次数 \(reps)", value: $reps, in: 0...200)
                    .listRowBackground(Theme.bgCard)
                TextField("重量 (kg)", text: $weight)
                    .keyboardType(.decimalPad)
                    .listRowBackground(Theme.bgCard)
            }

            if !appState.lastSetReplayRecordings.isEmpty,
               UserDefaults.standard.object(forKey: UserDefaultsKeys.replayEnabled) as? Bool ?? true {
                Section {
                    Button {
                        appState.path.append(AppRoute.actionReplay)
                    } label: {
                        Label("查看本组动作回放（慢动作）", systemImage: "play.rectangle.on.rectangle")
                            .foregroundStyle(Theme.techCyan)
                    }
                    .listRowBackground(Theme.bgCard)
                }
            }

            if let suggestion = appState.nextSetSuggestion,
               UserDefaults.standard.object(forKey: UserDefaultsKeys.adaptiveIntensityEnabled) as? Bool ?? true {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: suggestionIcon(suggestion.level))
                                .foregroundStyle(suggestionColor(suggestion.level))
                            Text(suggestion.title)
                                .font(.headline)
                        }
                        Text(suggestion.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Text(suggestion.suggestion)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.primaryText)
                        Button("忽略此建议") {
                            appState.nextSetSuggestion = nil
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Theme.bgCard)
                } header: {
                    Text("下一组建议")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Section {
                Button("下一组（组间休息）") {
                    appendCurrentSet()
                    showRest = true
                }
                .listRowBackground(Theme.bgCard)

                PrimaryButton(title: "结束训练") {
                    appendCurrentSet()
                    appState.path.append(AppRoute.done)
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bgPrimary)
        .foregroundStyle(Theme.primaryText)
        .navigationTitle("确认本组")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reps = max(0, appState.lastSetRepCount)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .sheet(isPresented: $showRest) {
            NavigationStack {
                RestTimerView(
                    totalSeconds: restDuration,
                    restAdvice: appState.trainingExercise.restAdvice,
                    onSkip: {
                        showRest = false
                        dismiss()
                    },
                    onFinished: { elapsed in
                        updateLastRestDuration(TimeInterval(elapsed))
                    }
                )
                .navigationTitle("休息")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            showRest = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func notesFromWeight() -> String? {
        let t = weight.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let idx = appState.draftSets.count + 1
        return "组\(idx) 重量 \(t) kg"
    }

    private func appendCurrentSet() {
        if let n = notesFromWeight() {
            if !appState.accumulatedSessionNotes.isEmpty { appState.accumulatedSessionNotes += "；" }
            appState.accumulatedSessionNotes += n
        }
        appState.draftSets.append(
            TrainingDraftSet(repCount: reps, confirmedAt: Date(), restAfterSeconds: nil)
        )
    }

    private func suggestionIcon(_ level: IntensityLevel) -> String {
        switch level {
        case .tooLight: return "arrow.up.circle.fill"
        case .moderate: return "checkmark.seal.fill"
        case .tooHard:  return "arrow.down.circle.fill"
        }
    }

    private func suggestionColor(_ level: IntensityLevel) -> Color {
        switch level {
        case .tooLight: return Theme.techCyan
        case .moderate: return .green
        case .tooHard:  return .orange
        }
    }

    private func updateLastRestDuration(_ seconds: TimeInterval) {
        guard !appState.draftSets.isEmpty else { return }
        let i = appState.draftSets.count - 1
        var last = appState.draftSets[i]
        last.restAfterSeconds = seconds
        appState.draftSets[i] = last
        appState.noteTrainingResumeAfterRest()
    }
}
