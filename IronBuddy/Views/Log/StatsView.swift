//
//  StatsView.swift
//  IronBuddy
//

import Charts
import SwiftUI

struct StatsView: View {
    @State private var days: Int = 30
    @State private var sessions: [TrainingSessionRecord] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Time range picker
                Picker("时间范围", selection: $days) {
                    Text("7天").tag(7)
                    Text("30天").tag(30)
                    Text("90天").tag(90)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "暂无训练记录",
                        systemImage: "chart.bar.xaxis",
                        description: Text("完成一次训练后，数据将显示在这里")
                    )
                    .padding(.top, 40)
                } else {

                // MARK: - Volume chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("每日训练量")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)

                    Chart(dailyData, id: \.date) { item in
                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("次数", item.reps)
                        )
                        .foregroundStyle(by: .value("运动", item.exercise))
                    }
                    .chartForegroundStyleScale(exerciseColorMapping)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: max(days / 7, 1))) {
                            AxisValueLabel(format: .dateTime.month().day())
                                .foregroundStyle(Theme.secondaryText)
                            AxisGridLine()
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .foregroundStyle(Theme.secondaryText)
                            AxisGridLine()
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                    .chartLegend(.visible)
                    .frame(height: 220)
                }
                .padding()
                .background(Theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // MARK: - Summary cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    summaryCard(title: "训练次数", value: "\(sessions.count)", icon: "flame.fill")
                    summaryCard(title: "总次数", value: "\(totalReps)", icon: "repeat")
                    summaryCard(title: "总卡路里", value: "\(totalCalories) kcal", icon: "bolt.fill")
                    summaryCard(title: "连续天数", value: "\(streakDays)", icon: "calendar.badge.checkmark")
                }
                .padding(.horizontal)

                } // end else (sessions not empty)

                Spacer(minLength: 24)
            }
            .padding(.top)
        }
        .background(Theme.bgPrimary)
        .navigationTitle("训练统计")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: days) { _, _ in reload() }
    }

    // MARK: - Data helpers

    private struct DailyItem {
        let date: Date
        let exercise: String
        let reps: Int
    }

    private var dailyData: [DailyItem] {
        let cal = Calendar.current
        var grouped: [DateComponents: [String: Int]] = [:]
        for s in sessions {
            let dc = cal.dateComponents([.year, .month, .day], from: s.endTime)
            grouped[dc, default: [:]][s.exerciseType.rawValue, default: 0] += s.totalReps
        }
        var items: [DailyItem] = []
        for (dc, exercises) in grouped {
            guard let date = cal.date(from: dc) else { continue }
            for (name, reps) in exercises {
                items.append(DailyItem(date: date, exercise: name, reps: reps))
            }
        }
        return items.sorted { $0.date < $1.date }
    }

    private var exerciseColorMapping: KeyValuePairs<String, Color> {
        // Build a fixed-order mapping for all exercise types
        let types = ExerciseType.allCases
        switch types.count {
        case 1:
            return [types[0].rawValue: Theme.accent]
        case 2:
            return [
                types[0].rawValue: Theme.accent,
                types[1].rawValue: Theme.techCyan,
            ]
        case 3:
            return [
                types[0].rawValue: Theme.accent,
                types[1].rawValue: Theme.techCyan,
                types[2].rawValue: Theme.successGreen,
            ]
        default:
            return [
                types[0].rawValue: Theme.accent,
                types[1].rawValue: Theme.techCyan,
                types[2].rawValue: Theme.successGreen,
                types[3].rawValue: .purple,
            ]
        }
    }

    private var totalReps: Int {
        sessions.map(\.totalReps).reduce(0, +)
    }

    private var totalCalories: Int {
        sessions.map(\.calories).reduce(0, +)
    }

    private var streakDays: Int {
        let cal = Calendar.current
        let uniqueDays = Set(sessions.map { cal.startOfDay(for: $0.endTime) }).sorted(by: >)
        guard let first = uniqueDays.first else { return 0 }
        // streak must include today or yesterday to count
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        guard first >= yesterday else { return 0 }
        var streak = 1
        for i in 1..<uniqueDays.count {
            let expected = cal.date(byAdding: .day, value: -1, to: uniqueDays[i - 1])!
            if uniqueDays[i] == expected {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func reload() {
        do {
            sessions = try DatabaseService.loadSessionsInRange(days: days)
        } catch {
            sessions = []
        }
    }

    // MARK: - Summary card

    private func summaryCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.primaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatsView()
}
