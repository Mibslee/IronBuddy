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

public enum AngleThresholds {
    public static let pushupElbowReady = 170.0
    public static let pushupElbowDown = 140.0
    public static let pushupElbowUp = 165.0

    public static let squatStandingHip = 160.0
    public static let squatStandingKnee = 160.0
    public static let squatBottomKnee = 100.0
    public static let squatStandingAfterBottomKnee = 150.0
    public static let squatStandingAfterBottomHip = 140.0

    public static let deadliftStartAnkle = 30.0
    public static let deadliftStartHip = 70.0
    public static let deadliftPullHip = 100.0
    public static let deadliftPullKnee = 80.0
    public static let deadliftLockHip = 165.0
    public static let deadliftLockKnee = 170.0

    public static let benchElbowReady = 150.0
    public static let benchElbowDown = 90.0
    public static let benchElbowUp = 150.0

    public static let backLinearityThreshold = 0.08
    public static let kneeValgusRatio = 1.1
}

// MARK: - FormWarning

public struct FormWarning: Equatable {
    public let type: String
    public let message: String
    public let risk: String

    public init(type: String, message: String, risk: String) {
        self.type = type
        self.message = message
        self.risk = risk
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
        if visAvg < 0.3 {
            if lowVisibilitySince == nil { lowVisibilitySince = now }
            if let t = lowVisibilitySince, now.timeIntervalSince(t) > 2.0 {
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

        // Compute hip angle (shoulder→hip→ankle) for form checks
        let hipAngle = PoseLandmarkMath.angleDegrees(a: p(PoseIndex.leftShoulder), b: p(PoseIndex.leftHip), c: p(PoseIndex.leftAnkle))

        // Form warnings
        if state == .down, elbowMin > 110.0 {
            emitWarning(FormWarning(type: "insufficient_depth", message: "⚠️ 再往下一点，手肘弯曲不够", risk: "胸肌刺激不足"))
        }
        if (state == .down || state == .ready), hipAngle < 150.0 {
            emitWarning(FormWarning(type: "hips_sagging", message: "⚠️ 收紧核心，臀部不要下沉", risk: "腰椎压力过大"))
        }
        let shoulderY = Double(p(PoseIndex.leftShoulder).y)
        let hipY = Double(p(PoseIndex.leftHip).y)
        if hipAngle > 175.0, shoulderY > hipY + 0.05 {
            emitWarning(FormWarning(type: "hips_too_high", message: "⚠️ 臀部不要翘太高", risk: "训练效果下降"))
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
                state = (duration > 0.8 && duration < 4.0) ? .up : .idle
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
    private var standingSince: Date?
    private var cameFromBottom = false
    private var warnedThisFrame = false

    public var onRep: ((Int) -> Void)?
    public var onFormWarning: ((FormWarning) -> Void)?

    public init() {}

    public func reset() {
        state = .idle
        completedReps = 0
        standingSince = nil
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
            emitWarning(FormWarning(type: "knee_valgus", message: "⚠️ 膝盖朝向脚尖方向", risk: "前十字韧带承压"))
        }
        if state == .bottom, kneeAngle > 110.0 {
            emitWarning(FormWarning(type: "not_deep_enough", message: "⚠️ 再蹲深一些", risk: "臀腿刺激不足"))
        }
        let shoulderX = Double(p(PoseIndex.leftShoulder).x)
        let ankleX = Double(p(PoseIndex.leftAnkle).x)
        if abs(shoulderX - ankleX) > 0.08 {
            emitWarning(FormWarning(type: "forward_lean", message: "⚠️ 上身保持直立", risk: "腰椎压力过大"))
        }

        switch state {
        case .idle:
            if hipAngle > AngleThresholds.squatStandingHip && kneeAngle > AngleThresholds.squatStandingKnee {
                state = .standing
                standingSince = now
                cameFromBottom = false
            }
        case .standing:
            if kneeAngle < AngleThresholds.squatBottomKnee {
                state = .bottom
            } else if cameFromBottom, let since = standingSince, now.timeIntervalSince(since) > 2.0 {
                completedReps += 1
                onRep?(completedReps)
                state = .idle
                cameFromBottom = false
                standingSince = nil
            }
        case .bottom:
            if kneeAngle > AngleThresholds.squatStandingAfterBottomKnee && hipAngle > AngleThresholds.squatStandingAfterBottomHip {
                state = .standing
                standingSince = now
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
    }

    public func process(landmarks: [PoseLandmarkData], mirrorX: Bool) {
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

        if let w = checkStaticForm(p: p, backLinearity: backLinearity) {
            emitWarning(w)
        }

        let hipX = p(PoseIndex.leftHip).x
        let ankleWidth = abs(p(PoseIndex.leftAnkle).x - p(PoseIndex.rightAnkle).x)
        if let prev = lastHipX, ankleWidth > 0.02, abs(hipX - prev) > ankleWidth * 0.2 {
            emitWarning(FormWarning(type: "bar_path", message: "⚠️ 贴近小腿拉起", risk: "髋关节撞击"))
        }
        lastHipX = hipX

        if phase == .pull, let ph = prevHipAngle, let pk = prevKneeAngle {
            let dHip = hipAngle - ph
            let dKnee = kneeAngle - pk
            if dKnee > 2 && dHip < dKnee - 3 {
                emitWarning(FormWarning(type: "hip_hinge", message: "⚠️ 臀部先发力", risk: "下背代偿"))
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
            if hipAngle < 45, !warnedLowHipThisStart {
                warnedLowHipThisStart = true
                emitWarning(FormWarning(type: "hips_too_low", message: "⚠️ 臀部稍抬高", risk: "腰椎过度弯曲"))
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
                phase = .idle
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

    private func checkStaticForm(p: (Int) -> CGPoint, backLinearity: Double) -> FormWarning? {
        if backLinearity > AngleThresholds.backLinearityThreshold {
            return FormWarning(type: "back_rounded", message: "⚠️ 请挺直背部，避免腰椎损伤", risk: "腰椎间盘剪切力过大")
        }

        let kneeOffset = abs(Double(p(PoseIndex.rightKnee).x - p(PoseIndex.rightAnkle).x))
        let ankleOffset = abs(Double(p(PoseIndex.leftAnkle).x - p(PoseIndex.rightAnkle).x))
        if ankleOffset > 1e-4, kneeOffset > ankleOffset * AngleThresholds.kneeValgusRatio {
            return FormWarning(type: "knee_valgus", message: "⚠️ 膝盖朝向脚尖，减少膝关节压力", risk: "前十字韧带承压过大")
        }

        let earX = Double(p(PoseIndex.leftEar).x)
        let shoulderX = Double(p(PoseIndex.leftShoulder).x)
        if earX - shoulderX > 0.05 {
            return FormWarning(type: "head_forward", message: "⚠️ 头部保持中立", risk: "颈椎压力")
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
        if visAvg < 0.3 {
            if lowVisibilitySince == nil { lowVisibilitySince = now }
            if let t = lowVisibilitySince, now.timeIntervalSince(t) > 2.0 {
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
        if state == .down, elbowFlex > 100.0 {
            emitWarning(FormWarning(type: "insufficient_depth", message: "⚠️ 再往下放一点", risk: "胸肌行程不足"))
        }
        if abs(leftFlex - rightFlex) > 25.0 {
            emitWarning(FormWarning(type: "asymmetric_press", message: "⚠️ 两侧用力不均匀", risk: "肌肉发展不平衡"))
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
                state = (duration > 0.5 && duration < 5.0) ? .up : .idle
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
