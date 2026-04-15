//
//  PoseOverlayView.swift
//  IronBuddy

import SwiftUI

/// MediaPipe BlazePose 33 点连线（与官方 `POSE_CONNECTIONS` 一致），归一化坐标系 0…1，左上角为原点。
///
/// 坐标变换自动匹配 `CameraPreviewView` 的 `.resizeAspectFill` 视频填充模式，
/// 确保骨架点与摄像头画面中的人体精确对齐。
struct PoseOverlayView: View {
    var normalizedPoints: [CGPoint]
    var visibilities: [Float]
    var visibilityThreshold: Float = 0.15
    /// 视频画面的宽高比（竖屏旋转后）。`.high` 预设竖屏 = 1080×1920 → 9:16。
    var videoAspectRatio: CGFloat = 9.0 / 16.0

    private static let connections: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 7),
        (0, 4), (4, 5), (5, 6), (6, 8),
        (9, 10),
        (11, 12), (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
        (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
        (11, 23), (12, 24), (23, 24),
        (23, 25), (25, 27), (27, 29), (27, 31),
        (24, 26), (26, 28), (28, 30), (28, 32),
    ]

    var body: some View {
        Canvas { context, size in
            guard normalizedPoints.count >= 33, visibilities.count >= 33 else { return }

            // ── AspectFill 坐标变换 ──
            // CameraPreviewView 使用 .resizeAspectFill：视频被等比放大直到
            // 完全覆盖视图，多余部分被裁剪。归一化坐标需要做相同的缩放+偏移。
            let viewAspect = size.width / size.height
            let displayedW: CGFloat
            let displayedH: CGFloat
            if videoAspectRatio > viewAspect {
                // 视频相对更宽 → 高度刚好填满，宽度超出两侧裁剪
                displayedH = size.height
                displayedW = size.height * videoAspectRatio
            } else {
                // 视频相对更窄 → 宽度刚好填满，高度超出上下裁剪
                displayedW = size.width
                displayedH = size.width / videoAspectRatio
            }
            let offsetX = (displayedW - size.width) / 2
            let offsetY = (displayedH - size.height) / 2

            let toScreen: (CGPoint) -> CGPoint = { p in
                CGPoint(
                    x: p.x * displayedW - offsetX,
                    y: p.y * displayedH - offsetY
                )
            }

            // 光晕层（粗线低透明度）
            var glowPath = Path()
            for (a, b) in Self.connections {
                guard a < normalizedPoints.count, b < normalizedPoints.count,
                      a < visibilities.count, b < visibilities.count,
                      visibilities[a] >= visibilityThreshold,
                      visibilities[b] >= visibilityThreshold
                else { continue }
                let pa = toScreen(normalizedPoints[a])
                let pb = toScreen(normalizedPoints[b])
                glowPath.move(to: pa)
                glowPath.addLine(to: pb)
            }
            context.stroke(glowPath, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.25)), lineWidth: 6)

            // 主线条
            var linePath = Path()
            for (a, b) in Self.connections {
                guard a < normalizedPoints.count, b < normalizedPoints.count,
                      a < visibilities.count, b < visibilities.count,
                      visibilities[a] >= visibilityThreshold,
                      visibilities[b] >= visibilityThreshold
                else { continue }
                let pa = toScreen(normalizedPoints[a])
                let pb = toScreen(normalizedPoints[b])
                linePath.move(to: pa)
                linePath.addLine(to: pb)
            }
            context.stroke(linePath, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.9)), lineWidth: 2)

            // 关键点
            for i in normalizedPoints.indices where i < visibilities.count && visibilities[i] >= visibilityThreshold {
                let c = toScreen(normalizedPoints[i])
                // 外圈光晕
                let glow = Circle().path(in: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
                context.fill(glow, with: .color(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.3)))
                // 内圈实心
                let dot = Circle().path(in: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(.white.opacity(0.95)))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    PoseOverlayView(normalizedPoints: [], visibilities: [])
        .frame(height: 320)
        .background(.black)
}
