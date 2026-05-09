//
//  CountDisplayView.swift
//  IronBuddy

import SwiftUI

struct CountDisplayView: View {
    let repCount: Int

    var body: some View {
        Text("\(repCount)")
            .font(.system(size: 112, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(Theme.primaryText)
            .shadow(color: Theme.techCyan.opacity(0.6), radius: 18, x: 0, y: 0)
            .shadow(color: Theme.techCyan.opacity(0.3), radius: 40, x: 0, y: 0)
            .accessibilityLabel("重复次数")
            .accessibilityValue("\(repCount)")
    }
}

#Preview {
    CountDisplayView(repCount: 8)
        .padding()
        .background(Color.black)
}
