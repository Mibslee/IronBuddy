//
//  PrimaryButton.swift
//  IronBuddy

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primaryGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.subtleOverlayBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .shadow(color: Theme.warningOrange.opacity(0.2), radius: 10, y: 4)
    }
}

#Preview {
    PrimaryButton(title: "开始") {}
        .padding()
        .background(Theme.bgPrimary)
}
