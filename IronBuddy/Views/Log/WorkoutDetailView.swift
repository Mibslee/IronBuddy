//
//  WorkoutDetailView.swift
//  IronBuddy
//

import SwiftUI

struct WorkoutDetailView: View {
    let workoutId: Int64

    @State private var session: TrainingSessionRecord?
    @State private var sets: [ExerciseSetRecord] = []
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("加载失败", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let session {
                List {
                    Section("概要") {
                        LabeledContent("动作", value: session.exerciseType.rawValue)
                        LabeledContent("组数", value: "\(session.totalSets)")
                        LabeledContent("总次数", value: "\(session.totalReps)")
                        LabeledContent(
                            "时长",
                            value: formatDuration(session.endTime.timeIntervalSince(session.startTime))
                        )
                        LabeledContent("估算热量", value: "\(session.calories) kcal")
                        if let notes = session.notes, !notes.isEmpty {
                            LabeledContent("备注", value: notes)
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    if !sets.isEmpty {
                        Section("各组") {
                            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, row in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("第 \(idx + 1) 组 · \(row.repCount) 次")
                                        .font(.subheadline.weight(.medium))
                                    if let rest = row.restDuration {
                                        Text(rest > 0 ? "休息 \(Int(rest)) 秒" : "未记录休息")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                    Text(row.timestamp, format: .dateTime.hour().minute().second())
                                        .font(.caption2)
                                        .foregroundStyle(Theme.tertiaryText)
                                }
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.bgPrimary)
                .foregroundStyle(Theme.primaryText)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("训练详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: workoutId) {
            await load()
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return "\(m) 分 \(s) 秒"
    }

    @MainActor
    private func load() async {
        loadError = nil
        session = nil
        sets = []
        do {
            guard let s = try DatabaseService.loadSession(id: workoutId) else {
                loadError = "找不到该条记录"
                return
            }
            session = s
            sets = try DatabaseService.loadExerciseRecords(sessionId: workoutId)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workoutId: 1)
    }
}
