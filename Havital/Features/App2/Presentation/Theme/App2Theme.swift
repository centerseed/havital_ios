import SwiftUI

// MARK: - App2Theme
/// Presentation Layer — 2.0 改版的卡片語彙。
///
/// 只放 2.0 專屬的視覺常數（頁面底色／狀態色階）。間距、圓角、陰影一律走
/// `PacerizTokens`（`Havital/Theme/GeneratedTokens.swift`），品牌色走
/// `PacerizTokens.color.brand`，這裡不重定義第二份。
///
/// 設計來源：`docs/designs/DESIGN-app2-decision-chain-api.md` §3 的畫面對照
/// ＋ 2026-08-24 的 2.0 設計截圖（淺藍底、白卡、大數字、膠囊徽章）。
enum App2Theme {

    // MARK: - Surface（2.0 專屬：現行 tokens 的 surface.card 是灰底，2.0 是白卡浮在藍灰底上）

    /// 頁面底色：偏藍的極淺灰，讓白卡浮起來。
    static let pageBackground = Color(hex: "#EEF3FA")

    /// 卡片底色。
    static let cardBackground = Color.white

    /// 卡片內的次級區塊（卡中卡）。
    static let insetBackground = Color(hex: "#F5F8FD")

    /// 目標賽事卡的藍色調底。
    static let goalCardBackground = Color(hex: "#EAF2FE")

    // MARK: - Ink

    static let inkPrimary = Color(hex: "#12213A")
    static let inkSecondary = Color(hex: "#5B6B85")
    static let inkTertiary = Color(hex: "#93A2B8")

    // MARK: - Accent

    /// 主動作／主要數字。
    static let accentBlue = PacerizTokens.color.brand.primary

    /// 預估值（設計稿把「預估完賽」畫成橘色，與「目標」的藍區隔）。
    static let accentOrange = Color(hex: "#F26B3A")

    static let accentGreen = Color(hex: "#2FA36B")

    /// 軌道條三段：落後／正常軌道／超乎預期（§3.1a 三色帶）。
    static let trackBehind = Color(hex: "#F4A261")
    static let trackOnTrack = Color(hex: "#2FA36B")
    static let trackAhead = Color(hex: "#5AA9F5")

    /// stub 標記色（畫面上明示「這格還沒有後端」）。
    static let stubTint = Color(hex: "#9A7B00")
    static let stubBackground = Color(hex: "#FFF6D9")

    // MARK: - Metrics（語意別名，值來自 PacerizTokens）

    static let cardCornerRadius = PacerizTokens.radius.xl        // 20
    static let insetCornerRadius = PacerizTokens.radius.medium   // 12
    static let cardPadding = PacerizTokens.spacing.l             // 16
    static let sectionSpacing = PacerizTokens.spacing.m          // 12
    static let pagePadding = PacerizTokens.spacing.l             // 16

    static let shadowColor = Color(hex: "#12213A").opacity(0.06)
    static let shadowRadius = PacerizTokens.elevation.cardSoft   // 8
    static let shadowY: CGFloat = 4
}

// MARK: - Typography

extension Font {
    /// 大數字（`2:34:00`／`124`）。等寬數字，避免逐項更新時抖版。
    static func app2Numeric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// 卡片小標題（`目標賽事`／`訓練狀況`）。
    static let app2SectionLabel = Font.system(size: 13, weight: .semibold)

    /// 欄位標籤（`目標`／`預估完賽`／`週次`）。
    static let app2FieldLabel = Font.system(size: 11, weight: .medium)

    static let app2CardTitle = Font.system(size: 22, weight: .bold)
    static let app2Body = Font.system(size: 14, weight: .regular)
    static let app2Caption = Font.system(size: 12, weight: .regular)
}
