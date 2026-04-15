//
//  NavCard.swift
//  IronBuddy

import Observation
import SwiftUI

struct NavCard: View {
    @Environment(AppState.self) private var appState
    let icon: String
    let title: String
    let destination: AppRoute

    var body: some View {
        Button {
            appState.path.append(destination)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.subtleBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
