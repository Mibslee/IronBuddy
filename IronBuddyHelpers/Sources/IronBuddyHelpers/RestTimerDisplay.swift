//
//  RestTimerDisplay.swift
//

import Foundation

public enum RestTimerDisplay {
    public static func clockString(totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    public static func hint(remaining: Int) -> String {
        if remaining == 30 { return "还剩 30 秒" }
        if remaining <= 10, remaining > 0 { return "即将继续" }
        return "放松呼吸，准备下一组"
    }

    public static func normalizedTotalSeconds(_ totalSeconds: Int) -> Int {
        max(1, totalSeconds)
    }
}
