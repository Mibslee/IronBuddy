//
//  RootView.swift
//  IronBuddy
//

import Observation
import SwiftUI

struct RootView: View {
    @Bindable var appState: AppState

    var body: some View {
        NavigationStack(path: $appState.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .actionSelect:
                        ActionSelectView()
                    case .flexibilityTest:
                        FlexibilityTestView()
                    case .cameraPrepare:
                        CameraPrepareView()
                    case .train:
                        TrainView()
                    case .setConfirm:
                        SetConfirmSheet()
                    case .done:
                        CompletionView()
                    case .history:
                        HistoryView()
                    case .workoutDetail(let id):
                        WorkoutDetailView(workoutId: id)
                    case .profile:
                        ProfileView()
                    case .settings:
                        SettingsView()
                    case .trainingPlan:
                        TrainingPlanView()
                    case .stats:
                        StatsView()
                    case .achievements:
                        AchievementView()
                    case .actionReplay:
                        ActionReplayView(recordings: appState.lastSetReplayRecordings)
                    case .warmup:
                        WarmupGuideView()
                    }
                }
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()
    RootView(appState: appState)
        .environment(appState)
}
