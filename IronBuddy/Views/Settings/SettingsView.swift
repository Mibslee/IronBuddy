//
//  SettingsView.swift
//  IronBuddy
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(UserDefaultsKeys.ttsEnabled) private var ttsEnabled = true
    @AppStorage(UserDefaultsKeys.restSecondsBetweenSets) private var restSeconds: Int = AppDefaults.restSecondsBetweenSets
    @AppStorage(UserDefaultsKeys.appearanceMode) private var appearanceMode = 1
    @AppStorage(UserDefaultsKeys.userLevel) private var userLevel = UserLevel.beginner.rawValue
    @AppStorage(UserDefaultsKeys.warmupEnabled) private var warmupEnabled = true
    @AppStorage(UserDefaultsKeys.replayEnabled) private var replayEnabled = true
    @AppStorage(UserDefaultsKeys.adaptiveIntensityEnabled) private var adaptiveIntensityEnabled = true

    var body: some View {
        Form {
            Section {
                Picker("训练水平", selection: $userLevel) {
                    ForEach(UserLevel.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Theme.bgCard)
                Text(UserLevel(rawValue: userLevel)?.detail ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Theme.bgCard)
            } header: {
                Text("训练水平")
                    .foregroundStyle(Theme.secondaryText)
            } footer: {
                Text("老手模式会显著降低语音提醒和建议的频率。")
                    .foregroundStyle(Theme.secondaryText)
            }

            Section {
                Toggle("热身/拉伸引导", isOn: $warmupEnabled)
                    .tint(Theme.accent)
                    .listRowBackground(Theme.bgCard)
                Toggle("动作回放 (训练后)", isOn: $replayEnabled)
                    .tint(Theme.accent)
                    .listRowBackground(Theme.bgCard)
                Toggle("自适应强度建议", isOn: $adaptiveIntensityEnabled)
                    .tint(Theme.accent)
                    .listRowBackground(Theme.bgCard)
            } header: {
                Text("智能辅助 (V2.0)")
                    .foregroundStyle(Theme.secondaryText)
            }

            Section {
                Toggle("训练语音播报 (TTS)", isOn: $ttsEnabled)
                    .tint(Theme.accent)
                    .listRowBackground(Theme.bgCard)
            } header: {
                Text("语音播报")
                    .foregroundStyle(Theme.secondaryText)
            }

            Section {
                Stepper("组间休息 \(restSeconds) 秒", value: $restSeconds, in: 30...300, step: 15)
                    .tint(Theme.accent)
                    .listRowBackground(Theme.bgCard)
            } header: {
                Text("训练设置")
                    .foregroundStyle(Theme.secondaryText)
            }

            Section {
                Picker("外观模式", selection: $appearanceMode) {
                    Text("跟随系统").tag(0)
                    Text("深色").tag(1)
                    Text("浅色").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Theme.bgCard)
            } header: {
                Text("外观")
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bgPrimary)
        .foregroundStyle(Theme.primaryText)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
