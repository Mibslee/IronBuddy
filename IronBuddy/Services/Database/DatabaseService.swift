//
//  DatabaseService.swift
//  IronBuddy
//

import Foundation
import SQLite

/// `training_sessions` / `exercise_records` 与 CRUD。
enum DatabaseService {
    private static let sessions = Table("training_sessions")
    private static let sid = Expression<Int64>("id")
    private static let exerciseTypeCol = Expression<String>("exercise_type")
    private static let startTimeCol = Expression<Double>("start_time")
    private static let endTimeCol = Expression<Double>("end_time")
    private static let totalRepsCol = Expression<Int>("total_reps")
    private static let totalSetsCol = Expression<Int>("total_sets")
    private static let caloriesCol = Expression<Int>("calories")
    private static let notesCol = Expression<String?>("notes")

    private static let records = Table("exercise_records")
    private static let rid = Expression<Int64>("id")
    private static let exSessionId = Expression<Int64>("session_id")
    private static let repCountCol = Expression<Int>("rep_count")
    private static let restDurationCol = Expression<Double?>("rest_duration")
    private static let timestampCol = Expression<Double>("timestamp")

    private static var didMigrate = false
    private static let migrationLock = NSLock()

    private static func openConnection() throws -> Connection {
        let path = try DatabasePath.sqliteFileURL().path
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let db = try Connection(path)
        try db.execute("PRAGMA foreign_keys = ON")
        migrationLock.lock()
        defer { migrationLock.unlock() }
        if !didMigrate {
            try migrate(db)
            didMigrate = true
        }
        return db
    }

    private static func migrate(_ db: Connection) throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS training_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                exercise_type TEXT NOT NULL,
                start_time REAL NOT NULL,
                end_time REAL NOT NULL,
                total_reps INTEGER NOT NULL,
                total_sets INTEGER NOT NULL,
                calories INTEGER NOT NULL,
                notes TEXT
            );
        """)
        try db.run("""
            CREATE TABLE IF NOT EXISTS exercise_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                rep_count INTEGER NOT NULL,
                rest_duration REAL,
                timestamp REAL NOT NULL,
                FOREIGN KEY(session_id) REFERENCES training_sessions(id) ON DELETE CASCADE
            );
        """)
    }

    /// 写入一次完整训练（会话 + 各组明细），返回新会话 id。
    static func saveTrainingSession(
        exerciseType: ExerciseType,
        start: Date,
        end: Date,
        sets: [TrainingDraftSet],
        totalCalories: Int,
        notes: String?
    ) throws -> Int64 {
        let db = try openConnection()
        let totalReps = sets.map(\.repCount).reduce(0, +)
        let totalSets = sets.count

        var newSessionId: Int64 = 0
        try db.transaction {
            let insertSession = sessions.insert(
                exerciseTypeCol <- exerciseType.rawValue,
                startTimeCol <- start.timeIntervalSince1970,
                endTimeCol <- end.timeIntervalSince1970,
                totalRepsCol <- totalReps,
                totalSetsCol <- totalSets,
                caloriesCol <- totalCalories,
                notesCol <- notes
            )
            try db.run(insertSession)
            newSessionId = db.lastInsertRowid

            for s in sets {
                let ins = records.insert(
                    exSessionId <- newSessionId,
                    repCountCol <- s.repCount,
                    restDurationCol <- s.restAfterSeconds,
                    timestampCol <- s.confirmedAt.timeIntervalSince1970
                )
                try db.run(ins)
            }
        }
        return newSessionId
    }

    static func loadSession(id: Int64) throws -> TrainingSessionRecord? {
        let db = try openConnection()
        let q = sessions.filter(sid == id)
        for row in try db.prepare(q) {
            guard let exercise = ExerciseType(rawValue: row[exerciseTypeCol]) else { return nil }
            return TrainingSessionRecord(
                id: row[sid],
                exerciseType: exercise,
                startTime: Date(timeIntervalSince1970: row[startTimeCol]),
                endTime: Date(timeIntervalSince1970: row[endTimeCol]),
                totalReps: row[totalRepsCol],
                totalSets: row[totalSetsCol],
                calories: row[caloriesCol],
                notes: row[notesCol]
            )
        }
        return nil
    }

    static func loadTrainingHistory() throws -> [TrainingSessionRecord] {
        let db = try openConnection()
        var result: [TrainingSessionRecord] = []
        for row in try db.prepare(sessions.order(endTimeCol.desc)) {
            guard let exercise = ExerciseType(rawValue: row[exerciseTypeCol]) else { continue }
            result.append(
                TrainingSessionRecord(
                    id: row[sid],
                    exerciseType: exercise,
                    startTime: Date(timeIntervalSince1970: row[startTimeCol]),
                    endTime: Date(timeIntervalSince1970: row[endTimeCol]),
                    totalReps: row[totalRepsCol],
                    totalSets: row[totalSetsCol],
                    calories: row[caloriesCol],
                    notes: row[notesCol]
                )
            )
        }
        return result
    }

    static func loadExerciseRecords(sessionId: Int64) throws -> [ExerciseSetRecord] {
        let db = try openConnection()
        let q = records.filter(exSessionId == sessionId).order(timestampCol.asc)
        var result: [ExerciseSetRecord] = []
        for row in try db.prepare(q) {
            let rest = row[restDurationCol]
            result.append(
                ExerciseSetRecord(
                    id: row[rid],
                    sessionId: row[exSessionId],
                    repCount: row[repCountCol],
                    restDuration: rest,
                    timestamp: Date(timeIntervalSince1970: row[timestampCol])
                )
            )
        }
        return result
    }

    static func deleteSession(id: Int64) throws {
        let db = try openConnection()
        let row = sessions.filter(sid == id)
        try db.run(row.delete())
    }

    /// Load sessions from the last N days for charting
    static func loadSessionsInRange(days: Int) throws -> [TrainingSessionRecord] {
        let db = try openConnection()
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        var result: [TrainingSessionRecord] = []
        for row in try db.prepare(sessions.filter(endTimeCol >= cutoff).order(endTimeCol.asc)) {
            guard let exercise = ExerciseType(rawValue: row[exerciseTypeCol]) else { continue }
            result.append(TrainingSessionRecord(
                id: row[sid], exerciseType: exercise,
                startTime: Date(timeIntervalSince1970: row[startTimeCol]),
                endTime: Date(timeIntervalSince1970: row[endTimeCol]),
                totalReps: row[totalRepsCol], totalSets: row[totalSetsCol],
                calories: row[caloriesCol], notes: row[notesCol]
            ))
        }
        return result
    }

    /// Export all sessions as CSV string
    static func exportCSV() throws -> String {
        let all = try loadTrainingHistory()
        var csv = "日期,运动,组数,次数,卡路里,备注\n"
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        for s in all {
            let date = fmt.string(from: s.endTime)
            let note = (s.notes ?? "").replacingOccurrences(of: ",", with: "，")
            csv += "\(date),\(s.exerciseType.rawValue),\(s.totalSets),\(s.totalReps),\(s.calories),\(note)\n"
        }
        return csv
    }
}
