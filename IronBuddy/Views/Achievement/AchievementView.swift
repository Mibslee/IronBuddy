//
//  AchievementView.swift
//  IronBuddy
//

import SwiftUI

struct AchievementView: View {
    @State private var sessions: [TrainingSessionRecord] = []

    private var unlockedIds: Set<String> {
        Set(Achievement.all.filter { $0.check(sessions) }.map(\.id))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Achievement.all) { a in
                    let unlocked = unlockedIds.contains(a.id)
                    achievementCard(a, unlocked: unlocked)
                }
            }
            .padding()
        }
        .background(Theme.bgPrimary)
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func achievementCard(_ a: Achievement, unlocked: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: a.icon)
                .font(.largeTitle)
                .foregroundStyle(unlocked ? Theme.accent : Theme.tertiaryText)
                .shadow(color: unlocked ? Theme.accent.opacity(0.5) : .clear, radius: 8)

            Text(a.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(unlocked ? Theme.primaryText : Theme.tertiaryText)

            Text(a.description)
                .font(.caption2)
                .foregroundStyle(unlocked ? Theme.secondaryText : Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(unlocked ? Theme.bgCard : Theme.bgCard.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    unlocked ? Theme.cardBorderGradient : Theme.subtleBorder,
                    lineWidth: 1
                )
        }
    }

    private func reload() {
        do {
            sessions = try DatabaseService.loadSessionsInRange(days: 9999)
        } catch {
            sessions = []
        }
    }
}

#Preview {
    NavigationStack {
        AchievementView()
    }
}
