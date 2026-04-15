//
//  ActionSelectView.swift
//  IronBuddy
//

import Observation
import SwiftUI

struct ActionSelectView: View {
    @Environment(AppState.self) private var appState
    @State private var showFlexibilityGate = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ExerciseType.allCases) { exercise in
                    ExerciseCard(exercise: exercise) {
                        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.flexibilityTestCompleted) {
                            startTraining(exercise)
                        } else {
                            showFlexibilityGate = true
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Theme.bgPrimary)
        .navigationTitle("选择动作")
        .navigationBarTitleDisplayMode(.inline)
        .alert("先完成体态评估", isPresented: $showFlexibilityGate) {
            Button("去评估") {
                appState.path.append(AppRoute.flexibilityTest)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("首次训练前请先完成柔韧性测试，帮助我们更安全地定制训练。")
        }
    }

    private func startTraining(_ exercise: ExerciseType) {
        appState.resetTrainingDraftForNewWorkout()
        appState.trainingExercise = exercise
        appState.path.append(AppRoute.cameraPrepare)
    }
}

#Preview {
    NavigationStack {
        ActionSelectView()
            .environment(AppState())
    }
}
