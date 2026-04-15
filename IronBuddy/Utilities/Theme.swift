//
//  Theme.swift
//  IronBuddy

import SwiftUI
import UIKit

enum Theme {
    // MARK: - 基础色（自适应深色/浅色）

    /// 页面背景
    static let bgPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)
            : UIColor.systemGroupedBackground
    })
    /// 卡片背景
    static let bgCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    })
    /// 卡片悬浮背景
    static let bgCardElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.14, blue: 0.20, alpha: 1)
            : UIColor.tertiarySystemGroupedBackground
    })

    /// 主色：活力橙
    static let primary = Color.orange
    /// 强调色
    static let accent = Color.orange
    /// 科技蓝（骨架、扫描效果）
    static let techCyan = Color(red: 0.0, green: 0.85, blue: 1.0)

    /// 文字层次（自适应）
    static let primaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .label
    })
    static let secondaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.6)
            : UIColor.secondaryLabel
    })
    static let tertiaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.35)
            : UIColor.tertiaryLabel
    })

    /// 卡片背景（兼容旧代码）
    static let cardBackground = bgCard

    // MARK: - 渐变

    /// 主 CTA 渐变
    static let primaryGradient = LinearGradient(
        colors: [Color.orange, Color(red: 0.95, green: 0.25, blue: 0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 卡片边框渐变（科技感光边）
    static let cardBorderGradient = LinearGradient(
        colors: [
            Color.orange.opacity(0.5),
            Color.orange.opacity(0.1),
            Color.clear,
            techCyan.opacity(0.1),
            techCyan.opacity(0.3),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 微光边框（自适应）
    static let subtleBorder = LinearGradient(
        colors: [
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.12)
                    : UIColor.separator
            }),
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.04)
                    : UIColor.separator.withAlphaComponent(0.3)
            }),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
