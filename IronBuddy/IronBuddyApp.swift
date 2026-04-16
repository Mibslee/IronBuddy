//
//  IronBuddyApp.swift
//  IronBuddy
//

import SwiftUI

@main
struct IronBuddyApp: App {
    @State private var appState = AppState()
    @AppStorage(UserDefaultsKeys.appearanceMode) private var appearanceMode = 1

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: .dark
        case 2: .light
        default: nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .environment(appState)
                .preferredColorScheme(colorScheme)
                .task {
                    #if DEBUG
                    // 截图/调试：从启动参数跳转到指定路由 e.g. `-screen settings`
                    if let idx = CommandLine.arguments.firstIndex(of: "-screen"),
                       idx + 1 < CommandLine.arguments.count {
                        let target = CommandLine.arguments[idx + 1]
                        let route: AppRoute? = switch target {
                        case "actionSelect": .actionSelect
                        case "settings":     .settings
                        case "plan":         .trainingPlan
                        case "stats":        .stats
                        case "achievements": .achievements
                        case "history":      .history
                        case "profile":      .profile
                        default: nil
                        }
                        if let r = route { appState.path.append(r) }
                    }
                    #endif
                    guard !UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitAuthRequested) else { return }
                    let hk = HealthKitService()
                    guard hk.isHealthDataAvailable() else { return }
                    await hk.requestWorkoutWriteAuthorizationIfNeeded()
                }
        }
    }
}
