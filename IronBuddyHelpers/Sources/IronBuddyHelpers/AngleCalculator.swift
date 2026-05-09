//
//  AngleCalculator.swift
//

import CoreGraphics

public enum AngleCalculator {
    /// 计算三个关键点形成的角度（0–180°），`b` 为顶点。
    public static func calculateAngle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let vectorBA = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let vectorBC = CGPoint(x: c.x - b.x, y: c.y - b.y)
        let dot = vectorBA.x * vectorBC.x + vectorBA.y * vectorBC.y
        let magBA = sqrt(vectorBA.x * vectorBA.x + vectorBA.y * vectorBA.y)
        let magBC = sqrt(vectorBC.x * vectorBC.x + vectorBC.y * vectorBC.y)
        guard magBA > 0, magBC > 0 else { return Double.nan }
        let cosAngle = dot / (magBA * magBC)
        let angle = acos(min(max(cosAngle, -1), 1)) * 180 / .pi
        return angle
    }
}
