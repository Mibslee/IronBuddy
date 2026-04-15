//
//  PoseLandmarkMath.swift
//  IronBuddy
//
//  仅保留 NormalizedLandmark → PoseLandmarkData 的转换；
//  其余几何辅助、PoseIndex、AngleThresholds 已迁至 IronBuddyHelpers。
//

import Foundation
import IronBuddyHelpers
import MediaPipeTasksVision

enum PoseLandmarkBridge {
    static func toPoseData(_ landmarks: [NormalizedLandmark]) -> [PoseLandmarkData] {
        landmarks.map {
            PoseLandmarkData(
                x: $0.x,
                y: $0.y,
                visibility: $0.visibility?.floatValue ?? 1.0
            )
        }
    }
}
