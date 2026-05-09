//
//  PoseCounters.swift
//  IronBuddyHelpers
//
//  纯 Swift 计数器：脱离 MediaPipe，仅消费 PoseLandmarkData，便于单元测试。
//

import CoreGraphics
import Foundation

// MARK: - Data

/// 与 MediaPipe `NormalizedLandmark` 对齐的最小数据载体。
public struct PoseLandmarkData: Equatable, Sendable {
    public let x: Float
    public let y: Float
    public let visibility: Float

    public init(x: Float, y: Float, visibility: Float = 1.0) {
        self.x = x
        self.y = y
        self.visibility = visibility
    }
}

public enum PoseIndex {
    public static let nose = 0
    public static let leftEar = 7
    public static let rightEar = 8
    public static let leftShoulder = 11
    public static let rightShoulder = 12
    public static let leftElbow = 13
    public static let rightElbow = 14
    public static let leftWrist = 15
    public static let rightWrist = 16
    public static let leftHip = 23
    public static let rightHip = 24
    public static let leftKnee = 25
    public static let rightKnee = 26
    public static let leftAnkle = 27
    public static let rightAnkle = 28
    public static let leftFootIndex = 31
    public static let rightFootIndex = 32
}

public enum PoseLandmarkMath {
    public static func point(from landmark: PoseLandmarkData, mirrorX: Bool) -> CGPoint {
        let x = mirrorX ? CGFloat(1.0 - landmark.x) : CGFloat(landmark.x)
        return CGPoint(x: x, y: CGFloat(landmark.y))
    }

    public static func visibility(_ landmark: PoseLandmarkData) -> Float {
        landmark.visibility
    }

    public static func angleDegrees(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        AngleCalculator.calculateAngle(a, b, c)
    }
}

// MARK: - Thresholds

public enum AngleThresholds {
    // Pushup
    public static let pushupElbowReady = 170.0
    public static let pushupElbowDown = 140.0
    public static let pushupElbowUp = 165.0
    public static let pushupInsufficientDepth = 110.0
    public static let pushupHipsSagging = 150.0
    public static let pushupHipsTooHigh = 175.0
    public static let pushupHipsTooHighShoulderOffset = 0.05
    public static let pushupMinDuration: TimeInterval = 0.8
    public static let pushupMaxDuration: TimeInterval = 4.0

    // Squat
    public static let squatStandingHip = 160.0
    public static let squatStandingKnee = 160.0
    public static let squatBottomKnee = 100.0
    public static let squatStandingAfterBottomKnee = 150.0
    public static let squatStandingAfterBottomHip = 140.0
    public static let squatNotDeepEnough = 110.0
    public static let squatForwardLeanThreshold = 0.08

    // Deadlift
    public static let deadliftStartAnkle = 30.0
    public static let deadliftStartHip = 70.0
    public static let deadliftPullHip = 100.0
    public static let deadliftPullKnee = 80.0
    public static let deadliftLockHip = 165.0
    public static let deadliftLockKnee = 170.0
    public static let deadliftHipsTooLow = 45.0
    public static let deadliftHeadForward = 0.05
    public static let deadliftHipHingeKneeDelta = 5.0
    public static let deadliftHipHingeDiffThreshold = 3.0

    // Bench
    public static let benchElbowReady = 160.0
    public static let benchElbowDown = 90.0
    public static let benchElbowUp = 150.0
    public static let benchInsufficientDepth = 100.0
    public static let benchAsymmetricThreshold = 25.0
    public static let benchMinDuration: TimeInterval = 0.5
    public static let benchMaxDuration: TimeInterval = 5.0

    // Shared
    public static let backLinearityThreshold = 0.08
    public static let kneeValgusRatio = 1.1
    public static let visibilityResetTimeout: TimeInterval = 2.0
    public static let lowVisibilityThreshold: Float = 0.3
}

// MARK: - FormWarning

public enum WarningSeverity: String, Equatable, Sendable {
    case high    // 受伤风险
    case medium  // 训练效果不足
    case low     // 效率提示
}

public enum WarningType: String, Equatable, Sendable {
    // Pushup
    case insufficientDepth
    case hipsSagging
    case hipsTooHigh
    case repTooFast
    case repTooSlow
    // Squat
    case kneeValgus
    case notDeepEnough
    case forwardLean
    // Deadlift
    case backRounded
    case barPath
    case hipHinge
    case hipsTooLow
    case headForward
    // Bench
    case asymmetricPress
}

public struct FormWarning: Equatable {
    public let type: WarningType
    public let message: String
    public let risk: String
    public let severity: WarningSeverity

    public init(type: WarningType, message: String, risk: String, severity: WarningSeverity = .medium) {
        self.type = type
        self.message = message
        self.risk = risk
        self.severity = severity
    }
}

// MARK: - PushupCounter

public final class PushupCounter {
    public enum State: Equatable {
        case idle, ready, down, up
    }

    public var state: State = .idle
    public private(set) var completedReps: Int = 0
    private var lastDownTimestamp: Date?
    private var lowVisibilitySince: Date?
    private var warnedThisFrame = false

    public var onRep: ((Int) -> Void)?
    public var onFormWarning: ((FormWarning) -> Void)?

    public init() {}

    public func reset() {
        state = .idle
        completedReps = 0
        lastDownTimestamp = nil
        lowVisibilitySince = nil
    }

    public func process(landmarks: [PoseLandmarkData], mirrorX: Bool, now: Date = Date()) {
        guard landmarks.count > PoseIndex.rightAnkle else { return }
        warnedThisFrame = false

        let keyIdx = [PoseIndex.leftShoulder, PoseIndex.leftElbow, PoseIndex.rightShoulder, PoseIndex.rightElbow]
        let visAvg = keyIdx.map { PoseLandmarkMath.visibility(landmarks[$0]) }.reduce(0, +) / Float(keyIdx.count)
        if visAvg < AngleThresholds.lowVisibilityThreshold {
            if lowVisibilitySince == nil { lowVisibilitySince = now }
            if let t = lowVisibilitySince, now.timeIntervalSince(t) > AngleThresholds.visibilityResetTimeout {
                state = .idle
                lowVisibilitySince = nil
            }
            return
        } else {
            lowVisibilitySince = nil
        }

        let p = { (i: Int) in PoseLandmarkMath.point(from: landmarks[i], mirrorX: mirrorX) }
        let leftElbow = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftShoulder), b: p(PoseIndex.leftElbow), c: p(PoseIndex.leftWrist))
        let rightElbow = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.rightShoulder), b: p(PoseIndex.rightElbow), c: p(PoseIndex.rightWrist))
        let elbowMin = min(leftElbow, rightElbow)

        let hipAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftShoulder), b: p(PoseIndex.leftHip), c: p(PoseIndex.leftAnkle))

        // Form warnings
        if state == .down, elbowMin > AngleThresholds.pushupInsufficientDepth {
            emitWarning(FormWarning(type: .insufficientDepth, message: "⚠️ 再往下一点，手肘弯曲不够", risk: "胸肌刺激不足", severity: .medium))
        }
        if (state == .down || state == .ready), hipAngle < AngleThresholds.pushupHipsSagging {
            emitWarning(FormWarning(type: .hipsSagging, message: "⚠️ 收紧核心，臀部不要下沉", risk: "腰椎压力过大", severity: .high))
        }
        let shoulderY = Double(p(PoseIndex.leftShoulder).y)
        let hipY = Double(p(PoseIndex.leftHip).y)
        if hipAngle > AngleThresholds.pushupHipsTooHigh, shoulderY > hipY + AngleThresholds.pushupHipsTooHighShoulderOffset {
            emitWarning(FormWarning(type: .hipsTooHigh, message: "⚠️ 臀部不要翘太高", risk: "训练效果下降", severity: .medium))
        }

        switch state {
        case .idle:
            if elbowMin > AngleThresholds.pushupElbowReady { state = .ready }
        case .ready:
            if elbowMin < AngleThresholds.pushupElbowDown {
                state = .down
                lastDownTimestamp = now
            }
        case .down:
            if elbowMin > AngleThresholds.pushupElbowUp {
                let duration = now.timeIntervalSince(lastDownTimestamp ?? now)
                if duration > AngleThresholds.pushupMinDuration && duration < AngleThresholds.pushupMaxDuration {
                    state = .up
                } else {
                    state = .idle
                    if duration >= AngleThresholds.pushupMaxDuration {
                        emitWarning(FormWarning(type: .repTooSlow, message: "⚠️ 动作偏慢，注意保持节奏", risk: "可能疲劳", severity: .low))
                    } else {
                        emitWarning(FormWarning(type: .repTooFast, message: "⚠️ 动作偏快，放慢离心阶段", risk: "刺激不足", severity: .low))
                    }
                }
            }
        case .up:
            state = .idle
            completedReps += 1
            onRep?(completedReps)
        }
    }

    private func emitWarning(_ w: FormWarning) {
        guard !warnedThisFrame else { return }
        warnedThisFrame = true
        onFormWarning?(w)
    }
}

// MARK: - SquatCounter

public final class SquatCounter {
    public enum State: Equatable {
        case idle, standing, bottom
    }

    public var state: State = .idle
    public private(set) var completedReps: Int = 0
    private var cameFromBottom = false
    private var warnedThisFrame = false

    public var onRep: ((Int) -> Void)?
    public var onFormWarning: ((FormWarning) -> Void)?

    public init() {}

    public func reset() {
        state = .idle
        completedReps = 0
        cameFromBottom = false
    }

    public func process(landmarks: [PoseLandmarkData], mirrorX: Bool, now: Date = Date()) {
        guard landmarks.count > PoseIndex.rightAnkle else { return }
        warnedThisFrame = false
        let p = { (i: Int) in PoseLandmarkMath.point(from: landmarks[i], mirrorX: mirrorX) }
        let hipAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftShoulder), b: p(PoseIndex.leftHip), c: p(PoseIndex.leftKnee))
        let kneeAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftHip), b: p(PoseIndex.leftKnee), c: p(PoseIndex.leftAnkle))

        // Form warnings
        let kneeOffset = abs(Double(p(PoseIndex.rightKnee).x - p(PoseIndex.rightAnkle).x))
        let ankleOffset = abs(Double(p(PoseIndex.leftAnkle).x - p(PoseIndex.rightAnkle).x))
        if ankleOffset > 1e-4, kneeOffset > ankleOffset * AngleThresholds.kneeValgusRatio {
            emitWarning(FormWarning(type: .kneeValgus, message: "⚠️ 膝盖朝向脚尖方向", risk: "前十字韧带承压", severity: .high))
        }
        if state == .bottom, kneeAngle > AngleThresholds.squatNotDeepEnough {
            emitWarning(FormWarning(type: .notDeepEnough, message: "⚠️ 再蹲深一些", risk: "臀腿刺激不足", severity: .medium))
        }
        let shoulderX = Double(p(PoseIndex.leftShoulder).x)
        let ankleX = Double(p(PoseIndex.leftAnkle).x)
        if abs(shoulderX - ankleX) > AngleThresholds.squatForwardLeanThreshold {
            emitWarning(FormWarning(type: .forwardLean, message: "⚠️ 上身保持直立", risk: "腰椎压力过大", severity: .medium))
        }

        switch state {
        case .idle:
            if hipAngle > AngleThresholds.squatStandingHip && kneeAngle > AngleThresholds.squatStandingKnee {
                state = .standing
                cameFromBottom = false
            }
        case .standing:
            if kneeAngle < AngleThresholds.squatBottomKnee {
                state = .bottom
            }
        case .bottom:
            if kneeAngle > AngleThresholds.squatStandingAfterBottomKnee && hipAngle > AngleThresholds.squatStandingAfterBottomHip {
                if cameFromBottom {
                    completedReps += 1
                    onRep?(completedReps)
                    cameFromBottom = false
                }
                state = .standing
            } else if !cameFromBottom {
                cameFromBottom = true
            }
        }
    }

    private func emitWarning(_ w: FormWarning) {
        guard !warnedThisFrame else { return }
        warnedThisFrame = true
        onFormWarning?(w)
    }
}

// MARK: - DeadliftCounter

public final class DeadliftCounter {
    public enum Phase: Equatable {
        case idle, start, pull, lock, lower
    }

    public var phase: Phase = .idle
    public private(set) var completedReps: Int = 0
    private var prevHipAngle: Double?
    private var prevKneeAngle: Double?
    private var lastHipX: CGFloat?
    private var warnedThisFrame = false
    private var warnedLowHipThisStart = false
    private var lastStaticWarningTime: Date?
    private let staticWarningCooldown: TimeInterval = 2.0

    public var onRep: ((Int) -> Void)?
    public var onFormWarning: ((FormWarning) -> Void)?

    public init() {}

    public func reset() {
        phase = .idle
        completedReps = 0
        prevHipAngle = nil
        prevKneeAngle = nil
        lastHipX = nil
        warnedLowHipThisStart = false
        lastStaticWarningTime = nil
    }

    public func process(landmarks: [PoseLandmarkData], mirrorX: Bool, now: Date = Date()) {
        guard landmarks.count > PoseIndex.rightFootIndex else { return }
        warnedThisFrame = false
        let p = { (i: Int) in PoseLandmarkMath.point(from: landmarks[i], mirrorX: mirrorX) }

        let hipAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftShoulder), b: p(PoseIndex.leftHip), c: p(PoseIndex.leftKnee))
        let kneeAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftHip), b: p(PoseIndex.leftKnee), c: p(PoseIndex.leftAnkle))
        let ankleAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftKnee), b: p(PoseIndex.leftAnkle), c: p(PoseIndex.leftFootIndex))

        let shoulderY = Double(p(PoseIndex.leftShoulder).y)
        let hipY = Double(p(PoseIndex.leftHip).y)
        let kneeY = Double(p(PoseIndex.leftKnee).y)
        let backLinearity = abs(shoulderY - 2 * hipY + kneeY)

        if let w = checkStaticForm(p: p, backLinearity: backLinearity, now: now) {
            emitWarning(w)
        }

        let hipX = p(PoseIndex.leftHip).x
        let ankleWidth = abs(p(PoseIndex.leftAnkle).x - p(PoseIndex.rightAnkle).x)
        if let prev = lastHipX, ankleWidth > 0.02, abs(hipX - prev) > ankleWidth * 0.2 {
            emitWarning(FormWarning(type: .barPath, message: "⚠️ 贴近小腿拉起", risk: "髋关节撞击", severity: .medium))
        }
        lastHipX = hipX

        if phase == .pull, let ph = prevHipAngle, let pk = prevKneeAngle {
            let dHip = hipAngle - ph
            let dKnee = kneeAngle - pk
            if dKnee > AngleThresholds.deadliftHipHingeKneeDelta && dHip < dKnee - AngleThresholds.deadliftHipHingeDiffThreshold {
                emitWarning(FormWarning(type: .hipHinge, message: "⚠️ 臀部先发力", risk: "下背代偿", severity: .high))
            }
        }
        prevHipAngle = hipAngle
        prevKneeAngle = kneeAngle

        switch phase {
        case .idle:
            if ankleAngle < AngleThresholds.deadliftStartAnkle && hipAngle < AngleThresholds.deadliftStartHip {
                phase = .start
                warnedLowHipThisStart = false
            }
        case .start:
            if hipAngle < AngleThresholds.deadliftHipsTooLow, !warnedLowHipThisStart {
                warnedLowHipThisStart = true
                emitWarning(FormWarning(type: .hipsTooLow, message: "⚠️ 臀部稍抬高", risk: "腰椎过度弯曲", severity: .high))
            }
            if hipAngle > AngleThresholds.deadliftPullHip && kneeAngle > AngleThresholds.deadliftPullKnee {
                phase = .pull
            }
        case .pull:
            if hipAngle > AngleThresholds.deadliftLockHip && kneeAngle > AngleThresholds.deadliftLockKnee {
                phase = .lock
            }
        case .lock:
            if hipAngle < AngleThresholds.deadliftLockHip {
                phase = .lower
            }
        case .lower:
            if ankleAngle < AngleThresholds.deadliftStartAnkle && hipAngle < AngleThresholds.deadliftStartHip {
                phase = .start
                completedReps += 1
                onRep?(completedReps)
            }
        }
    }

    private func emitWarning(_ w: FormWarning) {
        guard !warnedThisFrame else { return }
        warnedThisFrame = true
        onFormWarning?(w)
    }

    private func checkStaticForm(p: (Int) -> CGPoint, backLinearity: Double, now: Date) -> FormWarning? {
        if let last = lastStaticWarningTime, now.timeIntervalSince(last) < staticWarningCooldown {
            return nil
        }

        if backLinearity > AngleThresholds.backLinearityThreshold {
            lastStaticWarningTime = now
            return FormWarning(type: .backRounded, message: "⚠️ 请挺直背部，避免腰椎损伤", risk: "腰椎间盘剪切力过大", severity: .high)
        }

        let kneeOffset = abs(Double(p(PoseIndex.rightKnee).x - p(PoseIndex.rightAnkle).x))
        let ankleOffset = abs(Double(p(PoseIndex.leftAnkle).x - p(PoseIndex.rightAnkle).x))
        if ankleOffset > 1e-4, kneeOffset > ankleOffset * AngleThresholds.kneeValgusRatio {
            lastStaticWarningTime = now
            return FormWarning(type: .kneeValgus, message: "⚠️ 膝盖朝向脚尖，减少膝关节压力", risk: "前十字韧带承压过大", severity: .high)
        }

        let earX = Double(p(PoseIndex.leftEar).x)
        let shoulderX = Double(p(PoseIndex.leftShoulder).x)
        if earX - shoulderX > AngleThresholds.deadliftHeadForward {
            lastStaticWarningTime = now
            return FormWarning(type: .headForward, message: "⚠️ 头部保持中立", risk: "颈椎压力", severity: .medium)
        }

        return nil
    }
}

// MARK: - BenchPressCounter

public final class BenchPressCounter {
    public enum State: Equatable {
        case idle, ready, down, up
    }

    public var state: State = .idle
    public private(set) var completedReps: Int = 0
    private var lastDownTimestamp: Date?
    private var lowVisibilitySince: Date?
    private var warnedThisFrame = false

    public var onRep: ((Int) -> Void)?
    public var onFormWarning: ((FormWarning) -> Void)?

    public init() {}

    public func reset() {
        state = .idle
        completedReps = 0
        lastDownTimestamp = nil
        lowVisibilitySince = nil
    }

    public func process(landmarks: [PoseLandmarkData], mirrorX: Bool, now: Date = Date()) {
        guard landmarks.count > PoseIndex.rightWrist else { return }
        warnedThisFrame = false

        let keyIdx = [PoseIndex.leftShoulder, PoseIndex.leftElbow, PoseIndex.rightShoulder, PoseIndex.rightElbow]
        let visAvg = keyIdx.map { PoseLandmarkMath.visibility(landmarks[$0]) }.reduce(0, +) / Float(keyIdx.count)
        if visAvg < AngleThresholds.lowVisibilityThreshold {
            if lowVisibilitySince == nil { lowVisibilitySince = now }
            if let t = lowVisibilitySince, now.timeIntervalSince(t) > AngleThresholds.visibilityResetTimeout {
                state = .idle
                lowVisibilitySince = nil
            }
            return
        } else {
            lowVisibilitySince = nil
        }

        let p = { (i: Int) in PoseLandmarkMath.point(from: landmarks[i], mirrorX: mirrorX) }
        let leftFlex = PoseLandmarkMath.angleDegrees(
            a: p(PoseIndex.leftShoulder),
            b: p(PoseIndex.leftElbow),
            c: p(PoseIndex.leftWrist)
        )
        let rightFlex = PoseLandmarkMath.angleDegrees(
            a: p(PoseIndex.rightShoulder),
            b: p(PoseIndex.rightElbow),
            c: p(PoseIndex.rightWrist)
        )
        let elbowFlex = min(leftFlex, rightFlex)

        // Form warnings
        if state == .down, elbowFlex > AngleThresholds.benchInsufficientDepth {
            emitWarning(FormWarning(type: .insufficientDepth, message: "⚠️ 再往下放一点", risk: "胸肌行程不足", severity: .medium))
        }
        if abs(leftFlex - rightFlex) > AngleThresholds.benchAsymmetricThreshold {
            emitWarning(FormWarning(type: .asymmetricPress, message: "⚠️ 两侧用力不均匀", risk: "肌肉发展不平衡", severity: .medium))
        }

        switch state {
        case .idle:
            if elbowFlex > AngleThresholds.benchElbowReady { state = .ready }
        case .ready:
            if elbowFlex < AngleThresholds.benchElbowDown {
                state = .down
                lastDownTimestamp = now
            }
        case .down:
            if elbowFlex > AngleThresholds.benchElbowUp {
                let duration = now.timeIntervalSince(lastDownTimestamp ?? now)
                if duration > AngleThresholds.benchMinDuration && duration < AngleThresholds.benchMaxDuration {
                    state = .up
                } else {
                    state = .idle
                    if duration >= AngleThresholds.benchMaxDuration {
                        emitWarning(FormWarning(type: .repTooSlow, message: "⚠️ 动作偏慢，注意保持节奏", risk: "可能疲劳", severity: .low))
                    } else {
                        emitWarning(FormWarning(type: .repTooFast, message: "⚠️ 动作偏快，放慢离心阶段", risk: "刺激不足", severity: .low))
                    }
                }
            }
        case .up:
            state = .idle
            completedReps += 1
            onRep?(completedReps)
        }
    }

    private func emitWarning(_ w: FormWarning) {
        guard !warnedThisFrame else { return }
        warnedThisFrame = true
        onFormWarning?(w)
    }
}
