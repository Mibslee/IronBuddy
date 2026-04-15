//
//  ExerciseCard.swift
//  IronBuddy

import SwiftUI

struct ExerciseCard: View {
    let exercise: ExerciseType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: exercise.symbolName)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 30, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.rawValue)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text(exercise.englishName)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Text(exercise.muscleGroupLabel)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(Theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.subtleBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
