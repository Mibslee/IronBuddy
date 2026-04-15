//
//  PoseDetector.swift
//  IronBuddy
//

import Foundation

/// Phase 1：在此封装 `PoseLandmarker` 实时流（与 `MediaPipeLinkProbe.m` 共同验证 CocoaPods 链接）。
enum PoseDetectorBootstrap {
    static var modelBundled: Bool {
        Bundle.main.path(forResource: "pose_landmarker", ofType: "task") != nil
    }
}
