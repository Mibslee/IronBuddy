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
                    guard !UserDefaults.standard.bool(forKey: UserDefaultsKeys.healthKitAuthRequested) else { return }
                    let hk = HealthKitService()
                    guard hk.isHealthDataAvailable() else { return }
                    await hk.requestWorkoutWriteAuthorizationIfNeeded()
                }
        }
    }
}
