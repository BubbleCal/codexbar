import AppKit
import SwiftUI

/// 菜单弹窗的统一设计令牌。
///
/// 弹窗悬浮在半透明材质上,系统的 `.secondary` 在小字号下对比度不足;
/// 这里的颜色全部走 `NSColor` 动态提供者,保证明暗两种外观下都可读。
enum MenuDesign {
    // MARK: - Colors

    /// 面板底色,叠在 NSVisualEffectView 之上,压住壁纸透色。
    /// 菜单面板强制深色外观,深色值按"近实底炭黑"调,浅色壁纸下也稳。
    static let panelBaseTint = NSColor(name: nil) { appearance in
        appearance.isDarkAppearance
            ? NSColor(calibratedWhite: 0.10, alpha: 0.84)
            : NSColor(calibratedWhite: 1.0, alpha: 0.58)
    }

    /// 悬浮小面板(成本详情)的实底背景,与菜单面板同一深色语言。
    static let panelSolidFill = dynamicColor(
        light: NSColor(calibratedWhite: 0.99, alpha: 1),
        dark: NSColor(calibratedWhite: 0.13, alpha: 1)
    )

    static let textPrimary = dynamicColor(
        light: NSColor(calibratedWhite: 0.08, alpha: 1),
        dark: NSColor(calibratedWhite: 0.96, alpha: 1)
    )

    /// 比系统 secondaryLabelColor 更实的次级文字色,专治小字号看不清。
    static let textSecondary = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.62),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.70)
    )

    static let textTertiary = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.46),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.50)
    )

    static let cardFill = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.05),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.08)
    )

    static let cardStroke = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.09),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.12)
    )

    /// 卡片内部嵌套行的底色。
    static let insetRowFill = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.035),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.06)
    )

    static let chipFill = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.06),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.10)
    )

    static let chipStroke = dynamicColor(
        light: NSColor(calibratedWhite: 0.0, alpha: 0.10),
        dark: NSColor(calibratedWhite: 1.0, alpha: 0.14)
    )

    // MARK: - Typography

    /// 面板标题(codexbar)。
    static let panelTitleFont = Font.system(size: 13, weight: .semibold)
    /// 行主文字(账号名、provider 名)。
    static let rowTitleFont = Font.system(size: 12, weight: .semibold)
    static let bodyFont = Font.system(size: 12)
    /// 次级说明文字,最小正文字号。
    static let secondaryFont = Font.system(size: 11)
    /// 徽章、胶囊标签,全局最小字号。
    static let badgeFont = Font.system(size: 10, weight: .semibold)
    static let captionFont = Font.system(size: 10)
    static let sectionHeaderFont = Font.system(size: 11, weight: .semibold)

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 8
    static let rowCornerRadius: CGFloat = 7
    static let badgeCornerRadius: CGFloat = 4

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDarkAppearance ? dark : light
        })
    }
}

extension NSAppearance {
    var isDarkAppearance: Bool {
        self.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - Reusable pieces

extension View {
    /// 菜单里的标准卡片:填充 + 描边 + 圆角。
    func menuCard(
        fill: Color = MenuDesign.cardFill,
        stroke: Color = MenuDesign.cardStroke
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: MenuDesign.cardCornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MenuDesign.cardCornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
    }

    /// 章节标题样式(OpenAI / Providers)。
    func menuSectionHeaderStyle() -> some View {
        self
            .font(MenuDesign.sectionHeaderFont)
            .foregroundColor(MenuDesign.textSecondary)
            .tracking(0.2)
    }
}

/// 彩色小徽章(计划类型、可用数、运行中等)。
struct MenuBadge: View {
    let text: String
    let color: Color
    var filled = false

    var body: some View {
        Text(self.text)
            .font(MenuDesign.badgeFont)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: MenuDesign.badgeCornerRadius, style: .continuous)
                    .fill(self.filled ? self.color : self.color.opacity(0.17))
            )
            .foregroundColor(self.filled ? .white : self.color)
    }
}
