//
//  DoneView.swift
//  IronBuddy
//

import Observation
import SwiftUI

struct DoneView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Text("训练完成")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.primaryText)
            Text("训练完成，数据已保存")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "查看历史") {
                appState.path = NavigationPath()
                appState.path.append(AppRoute.history)
            }
            .padding(.horizontal)
            Button("回首页") {
                appState.path = NavigationPath()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgPrimary)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        DoneView()
            .environment(AppState())
    }
}
