//
//  CameraAngleDetector.swift
//  IronBuddy
//
//  多角度自适应：根据肩/髋水平间距与双侧 visibility 差判断当前是
//  正面 / 侧面 / 斜角拍摄，供 UI 展示提示或供计数器选择最佳侧。
//

import CoreGraphics
import Foundation
import IronBuddyHelpers

enum CameraAngle: String {
    case frontal = "正面"
    case side = "侧面"
    case diagonal = "斜角"
    case unknown = "扫描中"

    var tip: String {
        switch self {
        case .frontal:  return "正面视角 · 推荐：深蹲/俯卧撑"
        case .side:     return "侧面视角 · 推荐：硬拉/卧推"
        case .diagonal: return "斜角视角 · 所有动作通用"
        case .unknown:  return ""
        }
    }
}

enum CameraAngleDetector {
    /// 输入 33 点骨架，返回推断角度。
    static func detect(landmarks: [PoseLandmarkData]) -> CameraAngle {
        guard landmarks.count >= 33 else { return .unknown }

        let lSh = landmarks[PoseIndex.leftShoulder]
        let rSh = landmarks[PoseIndex.rightShoulder]
        let lHip = landmarks[PoseIndex.leftHip]
        let rHip = landmarks[PoseIndex.rightHip]

        // 至少一侧肩髋必须清晰可见
        let leftVis = min(lSh.visibility, lHip.visibility)
        let rightVis = min(rSh.visibility, rHip.visibility)
        guard max(leftVis, rightVis) > 0.5 else { return .unknown }

        // 双侧 visibility 差异大 → 侧面（另一侧被身体遮挡）
        let visDelta = abs(leftVis - rightVis)

        // 肩膀水平间距（归一化 0-1）
        let shoulderSpread = abs(CGFloat(lSh.x - rSh.x))
        // 参考：肩到髋的竖直距离，用作尺度归一
        let torsoHeight = abs(CGFloat((lSh.y + rSh.y) / 2.0 - (lHip.y + rHip.y) / 2.0))
        guard torsoHeight > 0.05 else { return .unknown }
        let ratio = shoulderSpread / torsoHeight  // 正面 ≈ 0.8-1.2，侧面 ≈ 0.1-0.3

        if visDelta > 0.35 || ratio < 0.35 {
            return .side
        } else if ratio > 0.75 {
            return .frontal
        } else {
            return .diagonal
        }
    }
}
