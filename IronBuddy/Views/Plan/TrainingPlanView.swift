//
//  TrainingPlanView.swift
//  IronBuddy
//

import SwiftUI

struct TrainingPlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(TrainingPlan.presets) { plan in
                    planCard(plan)
                }
            }
            .padding()
        }
        .background(Theme.bgPrimary)
        .navigationTitle("训练计划")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func planCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: plan.icon)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text(plan.description)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Text(plan.difficulty.rawValue)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor(plan.difficulty).opacity(0.15))
                    .foregroundStyle(difficultyColor(plan.difficulty))
                    .clipShape(Capsule())
            }

            Divider()
                .overlay(Theme.subtleOverlayBorder)

            ForEach(plan.steps) { step in
                HStack(spacing: 10) {
                    Image(systemName: step.exercise.symbolName)
                        .font(.caption)
                        .foregroundStyle(Theme.techCyan)
                        .frame(width: 24)
                    Text(step.exercise.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Text("\(step.targetSets)组 × \(step.targetReps)次")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Button {
                startPlan(plan)
            } label: {
                Text("开始训练")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.primaryGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.subtleBorder, lineWidth: 1)
        }
    }

    private func difficultyColor(_ d: TrainingPlan.Difficulty) -> Color {
        switch d {
        case .beginner: Theme.successGreen
        case .intermediate: Theme.warningOrange
        case .advanced: Theme.dangerRed
        }
    }

    private func startPlan(_ plan: TrainingPlan) {
        guard let first = plan.steps.first else { return }
        appState.resetTrainingDraftForNewWorkout()
        appState.activePlan = plan
        appState.activePlanStepIndex = 0
        appState.trainingExercise = first.exercise
        appState.path.append(AppRoute.cameraPrepare)
    }
}

#Preview {
    NavigationStack {
        TrainingPlanView()
            .environment(AppState())
    }
}
