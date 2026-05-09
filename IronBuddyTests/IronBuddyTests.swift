//
//  IronBuddyTests.swift
//  IronBuddyTests
//
//  计数器实现已迁至 IronBuddyHelpers（脱离 MediaPipe），可直接驱动状态机。
//

import CoreGraphics
import Foundation
import IronBuddyHelpers
import Testing

// MARK: - 测试辅助：合成 33 点 Pose 序列

private enum PoseFixtures {
    /// 生成 33 个默认可见的点（visibility = 1.0），全部位于 (0.5, 0.5)。
    static func base(visibility: Float = 1.0) -> [PoseLandmarkData] {
        Array(repeating: PoseLandmarkData(x: 0.5, y: 0.5, visibility: visibility), count: 33)
    }

    /// 设置某索引的点。
    static func with(_ pts: [PoseLandmarkData], _ index: Int, x: Float, y: Float, vis: Float = 1.0) -> [PoseLandmarkData] {
        var arr = pts
        arr[index] = PoseLandmarkData(x: x, y: y, visibility: vis)
        return arr
    }

    /// 俯卧撑：直臂（肘 ≈180°）。肩、肘、腕共线水平。
    static func pushupArmsExtended() -> [PoseLandmarkData] {
        var pts = base()
        // 左侧
        pts[PoseIndex.leftShoulder] = .init(x: 0.4, y: 0.5)
        pts[PoseIndex.leftElbow] = .init(x: 0.4, y: 0.7)
        pts[PoseIndex.leftWrist] = .init(x: 0.4, y: 0.9)
        // 右侧
        pts[PoseIndex.rightShoulder] = .init(x: 0.6, y: 0.5)
        pts[PoseIndex.rightElbow] = .init(x: 0.6, y: 0.7)
        pts[PoseIndex.rightWrist] = .init(x: 0.6, y: 0.9)
        return pts
    }

    /// 俯卧撑/卧推：屈臂到底（肘角 ≈63°，低于俯卧撑 down=140 与卧推 down=90 阈值）。
    static func pushupArmsBent() -> [PoseLandmarkData] {
        var pts = base()
        pts[PoseIndex.leftShoulder] = .init(x: 0.4, y: 0.5)
        pts[PoseIndex.leftElbow] = .init(x: 0.4, y: 0.7)
        pts[PoseIndex.leftWrist] = .init(x: 0.6, y: 0.6)
        pts[PoseIndex.rightShoulder] = .init(x: 0.6, y: 0.5)
        pts[PoseIndex.rightElbow] = .init(x: 0.6, y: 0.7)
        pts[PoseIndex.rightWrist] = .init(x: 0.4, y: 0.6)
        return pts
    }

    /// 深蹲：站立（髋角、膝角 ≈180°）。整条左腿与上身竖直。
    static func squatStanding() -> [PoseLandmarkData] {
        var pts = base()
        pts[PoseIndex.leftShoulder] = .init(x: 0.5, y: 0.1)
        pts[PoseIndex.leftHip] = .init(x: 0.5, y: 0.4)
        pts[PoseIndex.leftKnee] = .init(x: 0.5, y: 0.7)
        pts[PoseIndex.leftAnkle] = .init(x: 0.5, y: 1.0)
        return pts
    }

    /// 深蹲：底部（膝角 ≈90°）。
    static func squatBottom() -> [PoseLandmarkData] {
        var pts = base()
        pts[PoseIndex.leftShoulder] = .init(x: 0.5, y: 0.4)
        pts[PoseIndex.leftHip] = .init(x: 0.5, y: 0.7)
        pts[PoseIndex.leftKnee] = .init(x: 0.7, y: 0.7)
        pts[PoseIndex.leftAnkle] = .init(x: 0.7, y: 1.0)
        return pts
    }

    /// 硬拉：起始姿势。需满足 ankleAngle < 30 且 hipAngle < 70。
    /// （这些是合成像素坐标，不要求生理上可行——只要计算结果跨越阈值。）
    static func deadliftStart() -> [PoseLandmarkData] {
        var pts = base()
        // hipAngle 用 shoulder-hip-knee：让两向量共线（同方向）→ 角度小
        pts[PoseIndex.leftShoulder] = .init(x: 0.7, y: 0.7)
        pts[PoseIndex.leftHip] = .init(x: 0.5, y: 0.6)
        pts[PoseIndex.leftKnee] = .init(x: 0.6, y: 0.8)
        // ankleAngle 用 knee-ankle-foot：让两向量近平行 → 角度小
        pts[PoseIndex.leftAnkle] = .init(x: 0.5, y: 0.95)
        pts[PoseIndex.leftFootIndex] = .init(x: 0.55, y: 0.81)
        pts[PoseIndex.rightAnkle] = .init(x: 0.45, y: 0.95)
        pts[PoseIndex.rightKnee] = .init(x: 0.45, y: 0.8)
        pts[PoseIndex.rightFootIndex] = .init(x: 0.5, y: 0.81)
        return pts
    }

    /// 硬拉：锁定姿势（hip / knee 角都接近 180°）。
    static func deadliftLockout() -> [PoseLandmarkData] {
        var pts = base()
        pts[PoseIndex.leftShoulder] = .init(x: 0.5, y: 0.1)
        pts[PoseIndex.leftHip] = .init(x: 0.5, y: 0.4)
        pts[PoseIndex.leftKnee] = .init(x: 0.5, y: 0.7)
        pts[PoseIndex.leftAnkle] = .init(x: 0.5, y: 0.95)
        pts[PoseIndex.leftFootIndex] = .init(x: 0.55, y: 0.96)
        pts[PoseIndex.rightAnkle] = .init(x: 0.45, y: 0.95)
        pts[PoseIndex.rightKnee] = .init(x: 0.45, y: 0.7)
        pts[PoseIndex.rightFootIndex] = .init(x: 0.4, y: 0.96)
        return pts
    }
}

@Suite(.serialized)
struct IronBuddyTests {

    // MARK: AngleCalculator / CalorieEstimator / RestTimer（基线）

    @Test func angleCalculator_rightAngle() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 0, y: 1)
        let c = CGPoint(x: 1, y: 1)
        let angle = AngleCalculator.calculateAngle(a, b, c)
        #expect(abs(angle - 90) < 0.01)
    }

    @Test func calorieEstimator_matchesFormula() {
        let kcal = CalorieEstimator.estimateCalories(mets: 6, weightKg: 70, durationMinutes: 60)
        #expect(kcal == 420)
    }

    @Test func angleCalculator_straightLine() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 1, y: 0)
        let c = CGPoint(x: 2, y: 0)
        let angle = AngleCalculator.calculateAngle(a, b, c)
        #expect(abs(angle - 180) < 0.1)
    }

    @Test func restTimer_calculatesDuration() {
        #expect(RestTimerDisplay.normalizedTotalSeconds(0) == 1)
        #expect(RestTimerDisplay.normalizedTotalSeconds(-5) == 1)
        #expect(RestTimerDisplay.normalizedTotalSeconds(90) == 90)
        #expect(RestTimerDisplay.clockString(totalSeconds: 125) == "2:05")
        #expect(RestTimerDisplay.clockString(totalSeconds: 65) == "1:05")
        #expect(RestTimerDisplay.hint(remaining: 30) == "还剩 30 秒")
        #expect(RestTimerDisplay.hint(remaining: 5) == "即将继续")
        #expect(RestTimerDisplay.hint(remaining: 60).contains("放松"))
    }

    // MARK: PushupCounter

    @Test func pushup_completesOneRep() {
        let counter = PushupCounter()
        let extended = PoseFixtures.pushupArmsExtended()
        let bent = PoseFixtures.pushupArmsBent()

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        counter.process(landmarks: extended, mirrorX: false, now: t0)              // idle → ready
        #expect(counter.state == .ready)
        counter.process(landmarks: bent, mirrorX: false, now: t0.addingTimeInterval(0.1))  // ready → down
        #expect(counter.state == .down)
        counter.process(landmarks: extended, mirrorX: false, now: t0.addingTimeInterval(1.5))  // down → up
        #expect(counter.state == .up)
        counter.process(landmarks: extended, mirrorX: false, now: t0.addingTimeInterval(1.6))  // up → idle (rep++)
        #expect(counter.completedReps == 1)
        #expect(counter.state == .idle)
    }

    @Test func pushup_tooFastIsRejected() {
        let counter = PushupCounter()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false, now: t0)
        counter.process(landmarks: PoseFixtures.pushupArmsBent(), mirrorX: false, now: t0.addingTimeInterval(0.1))
        // 仅 0.2s 就回到伸直 → 视为无效
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false, now: t0.addingTimeInterval(0.3))
        #expect(counter.completedReps == 0)
        #expect(counter.state == .idle)
    }

    @Test func pushup_lowVisibilityResets() {
        let counter = PushupCounter()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false, now: t0)
        #expect(counter.state == .ready)

        // 关键关节可见度极低
        var blocked = PoseFixtures.pushupArmsExtended()
        for i in [PoseIndex.leftShoulder, PoseIndex.leftElbow, PoseIndex.rightShoulder, PoseIndex.rightElbow] {
            blocked[i] = PoseLandmarkData(x: blocked[i].x, y: blocked[i].y, visibility: 0.0)
        }
        counter.process(landmarks: blocked, mirrorX: false, now: t0.addingTimeInterval(0.1))
        counter.process(landmarks: blocked, mirrorX: false, now: t0.addingTimeInterval(3.0))
        #expect(counter.state == .idle)
    }

    @Test func pushup_resetClearsState() {
        let counter = PushupCounter()
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false)
        counter.reset()
        #expect(counter.state == .idle)
        #expect(counter.completedReps == 0)
    }

    // MARK: SquatCounter

    @Test func squat_fullCycleProducesRep() {
        let counter = SquatCounter()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        // idle → standing
        counter.process(landmarks: PoseFixtures.squatStanding(), mirrorX: false, now: t0)
        #expect(counter.state == .standing)
        // standing → bottom
        counter.process(landmarks: PoseFixtures.squatBottom(), mirrorX: false, now: t0.addingTimeInterval(1.0))
        #expect(counter.state == .bottom)
        // bottom → standing: state returns to standing
        counter.process(landmarks: PoseFixtures.squatStanding(), mirrorX: false, now: t0.addingTimeInterval(2.0))
        #expect(counter.state == .standing)
    }

    @Test func squat_resetClears() {
        let counter = SquatCounter()
        counter.process(landmarks: PoseFixtures.squatStanding(), mirrorX: false)
        counter.reset()
        #expect(counter.state == .idle)
        #expect(counter.completedReps == 0)
    }

    // MARK: DeadliftCounter

    @Test func deadlift_fullCycleProducesRep() {
        let counter = DeadliftCounter()
        // idle → start
        counter.process(landmarks: PoseFixtures.deadliftStart(), mirrorX: false)
        #expect(counter.phase == .start)
        // start → pull → lock
        counter.process(landmarks: PoseFixtures.deadliftLockout(), mirrorX: false)
        // 一帧内可能只跨一阶段，连推几帧
        counter.process(landmarks: PoseFixtures.deadliftLockout(), mirrorX: false)
        counter.process(landmarks: PoseFixtures.deadliftLockout(), mirrorX: false)
        #expect(counter.phase == .lock || counter.phase == .pull)
        // 回到起始
        counter.process(landmarks: PoseFixtures.deadliftStart(), mirrorX: false)
        counter.process(landmarks: PoseFixtures.deadliftStart(), mirrorX: false)
        #expect(counter.completedReps >= 1)
    }

    @Test func deadlift_backRoundedWarningTriggers() {
        let counter = DeadliftCounter()
        var warnings: [WarningType] = []
        counter.onFormWarning = { warnings.append($0.type) }

        // 制造一个明显非线性的脊柱：肩 y=0.1, 髋 y=0.5, 膝 y=0.6
        // backLinearity = |0.1 - 1.0 + 0.6| = 0.3 > 0.08
        var pts = PoseFixtures.deadliftStart()
        pts[PoseIndex.leftShoulder] = .init(x: 0.5, y: 0.1)
        pts[PoseIndex.leftHip] = .init(x: 0.5, y: 0.5)
        pts[PoseIndex.leftKnee] = .init(x: 0.5, y: 0.6)
        counter.process(landmarks: pts, mirrorX: false)
        #expect(warnings.contains(.backRounded))
    }

    @Test func deadlift_resetClears() {
        let counter = DeadliftCounter()
        counter.process(landmarks: PoseFixtures.deadliftStart(), mirrorX: false)
        counter.reset()
        #expect(counter.phase == .idle)
        #expect(counter.completedReps == 0)
    }

    // MARK: BenchPressCounter

    @Test func benchPress_completesOneRep() {
        let counter = BenchPressCounter()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false, now: t0)
        #expect(counter.state == .ready)
        counter.process(landmarks: PoseFixtures.pushupArmsBent(), mirrorX: false, now: t0.addingTimeInterval(0.1))
        #expect(counter.state == .down)
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false, now: t0.addingTimeInterval(1.0))
        #expect(counter.state == .up)
        counter.process(landmarks: PoseFixtures.pushupArmsExtended(), mirrorX: false, now: t0.addingTimeInterval(1.1))
        #expect(counter.completedReps == 1)
    }
}

