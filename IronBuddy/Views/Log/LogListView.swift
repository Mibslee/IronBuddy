//
//  HistoryView（训练历史列表，文件沿用工程内路径 Log/LogListView.swift）
//

import Observation
import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var sessions: [TrainingSessionRecord] = []
    @State private var loadError: String?
    @State private var showStats = false
    @State private var csvText: String?
    @State private var showShareSheet = false

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView("无法加载", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if sessions.isEmpty {
                ContentUnavailableView("暂无记录", systemImage: "calendar", description: Text("完成一次训练后会出现在这里"))
            } else {
                List {
                    ForEach(sessions) { session in
                        Button {
                            appState.path.append(AppRoute.workoutDetail(session.id))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: session.exerciseType.symbolName)
                                    .font(.title3)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 36, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.exerciseType.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(Theme.primaryText)
                                    Text(session.endTime, format: .dateTime.year().month().day().hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                    Text("\(session.totalSets) 组 · \(session.totalReps) 次 · \(session.calories) kcal")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }
                    .onDelete(perform: deleteSessions)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.bgPrimary)
            }
        }
        .navigationTitle("训练历史")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .refreshable { reload() }
    }

    private func reload() {
        loadError = nil
        do {
            sessions = try DatabaseService.loadTrainingHistory()
        } catch {
            loadError = error.localizedDescription
            sessions = []
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        var deleteError: String?
        for i in offsets {
            let id = sessions[i].id
            do {
                try DatabaseService.deleteSession(id: id)
            } catch {
                deleteError = "删除失败：\(error.localizedDescription)"
            }
        }
        reload()
        if let deleteError { loadError = deleteError }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(AppState())
    }
}
