import SwiftUI

// MARK: - App2Theme
/// Presentation Layer — 2.0 改版的卡片語彙。
///
/// **值的 SSOT 是設計包本身**：`docs/designs/assets/app2-design-package/Paceriz Home.dc.html`
/// （40 個 390×844 畫面框，顏色／間距／字級／圓角寫在 inline style 裡）。
/// 這裡的每個常數都對得回那份 markup 的某一條宣告，不是肉眼取樣。
///
/// 為什麼不繼續走 `PacerizTokens`：1.x 的 token 表是為 1.x 的視覺定的
/// （radius.xl = 20、spacing.l = 16），2.0 設計用的是另一組刻度（card 22、
/// page padding 18、day card 16）。硬套會處處差 2–4pt，整頁看起來就「不像設計稿」。
/// 品牌藍仍與 `PacerizTokens.color.brand.primary` 同值（#1890FF），不是第二個藍。
enum App2Theme {

    // MARK: - Surface

    /// 頁面底：`linear-gradient(180deg,#f3f6fa 0%, #eef2f7 100%)`。
    static let pageTop = Color(hex: "#F3F6FA")
    static let pageBottom = Color(hex: "#EEF2F7")

    static var pageGradient: LinearGradient {
        LinearGradient(colors: [pageTop, pageBottom], startPoint: .top, endPoint: .bottom)
    }

    /// 舊呼叫點的單色別名（載入態／空狀態底色）。
    static let pageBackground = pageTop

    static let cardBackground = Color.white
    /// `1px solid rgba(15,23,42,0.07)`
    static let cardBorder = Color(hex: "#0F172A").opacity(0.07)

    /// 卡中卡：`#f5f7fa` / `#f7f9fc`，邊 `rgba(15,23,42,0.06)`。
    static let insetBackground = Color(hex: "#F5F7FA")
    static let insetBackgroundCool = Color(hex: "#F7F9FC")
    static let insetBorder = Color(hex: "#0F172A").opacity(0.06)

    /// 強調卡（目標賽事／本週跑量／紀錄 hero／成就 hero）：
    /// `linear-gradient(150deg, rgba(24,144,255,0.12), rgba(24,144,255,0.02) 60%, #ffffff)`。
    /// SwiftUI 沒有 CSS 的 150deg 語意，用等效的左上→右下對角。
    static func accentCardGradient(strength: Double = 0.12) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: accentBlue.opacity(strength), location: 0),
                .init(color: accentBlue.opacity(0.02), location: 0.6),
                .init(color: .white, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// `1px solid rgba(24,144,255,0.28)`
    static let accentCardBorder = Color(hex: "#1890FF").opacity(0.28)

    /// 深藍 hero（訓練計畫總覽的目標賽事卡，設計 frame-20）：
    /// `linear-gradient(150deg,#0b5fb0 0%, #123a72 58%, #0b0d16 100%)`。
    /// 與 `accentCardGradient`（淺藍→白）不是同一張卡的兩種寫法：那是白底卡上的強調色，
    /// 這是整張深色卡，字全部是白的。
    static var heroDarkGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#0B5FB0"), location: 0),
                .init(color: Color(hex: "#123A72"), location: 0.58),
                .init(color: Color(hex: "#0B0D16"), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 深藍 hero 的光暈：`0 20px 44px -18px rgba(11,95,176,0.75)`。
    static let shadowHeroColor = Color(hex: "#0B5FB0").opacity(0.6)

    /// 舊呼叫點別名。
    static let goalCardBackground = Color(hex: "#EAF2FE")

    // MARK: - Ink

    static let inkPrimary = Color(hex: "#10151C")      // 標題／大數字
    static let inkSecondary = Color(hex: "#4A5561")    // 內文
    static let inkTertiary = Color(hex: "#8A929C")     // 次要說明
    static let inkMuted = Color(hex: "#94A0AD")        // section 小標
    static let inkFaint = Color(hex: "#A2ABB6")        // evidence 級小字
    static let inkSubtle = Color(hex: "#6B7581")       // 設定列右側值、賽事日期
    static let chevron = Color(hex: "#C2CAD3")

    // MARK: - Accent

    static let accentBlue = Color(hex: "#1890FF")      // 主動作、選中態
    static let accentBlueDeep = Color(hex: "#1677D6")  // 文字上的藍
    static let accentBlueDark = Color(hex: "#0B5FB0")  // 徽章漸層深端
    static let accentBlueLight = Color(hex: "#5BB0FF") // 徽章漸層淺端

    static let accentOrange = Color(hex: "#E8590C")    // 預估完賽、力量
    static let accentOrangeText = Color(hex: "#C2410C")// 橘底上的字
    static let accentOrangeBright = Color(hex: "#F97316")
    static let accentOrangeSoft = Color(hex: "#FF9D42")// 中強度

    static let accentGreen = Color(hex: "#16A34A")     // 實際值、已完成
    static let accentGreenBright = Color(hex: "#22C55E")
    static let accentGreenDot = Color(hex: "#2E9E5B")  // 已連接

    static let accentRed = Color(hex: "#EF5B6B")       // 高強度
    static let accentViolet = Color(hex: "#8B7BE8")    // 肌力／交叉訓練

    /// 課表強度分段條的三段漸層（設計 frame-01 的 `linear-gradient(90deg,…)`）。
    static let intensityLowGradient = (from: Color(hex: "#4ADE80"), to: Color(hex: "#16A34A"))
    static let intensityMediumGradient = (from: Color(hex: "#FFB15E"), to: Color(hex: "#F97316"))
    static let intensityHighGradient = (from: Color(hex: "#FF8A99"), to: Color(hex: "#EF4444"))

    /// 成就圓章的銅色（設計 frame-11）。
    static let medalGradient = (from: Color(hex: "#F0A24E"), to: Color(hex: "#A85818"))

    /// 數據來源列的品牌底（設計 frame-21）。
    static let sourceDarkTile = Color(hex: "#0B0D10")
    static let sourceLightTile = Color(hex: "#F0F3F7")
    static let appleHealthRed = Color(hex: "#E5546C")

    /// 軌跡圖三色帶（§3.1a）。
    static let trackBehind = Color(hex: "#F0B48A")
    static let trackOnTrack = Color(hex: "#4FC47E")
    static let trackAhead = Color(hex: "#5AA9F0")

    /// stub 標記色（畫面上明示「這格還沒有後端」）。
    static let stubTint = Color(hex: "#9A7B00")
    static let stubBackground = Color(hex: "#FFF6D9")

    // MARK: - Metrics（值取自設計 markup）

    static let cardCornerRadius: CGFloat = 22   // border-radius:22px
    static let listCardCornerRadius: CGFloat = 20
    static let dayCardCornerRadius: CGFloat = 16
    static let insetCornerRadius: CGFloat = 12
    static let chipCornerRadius: CGFloat = 8
    static let tabBarCornerRadius: CGFloat = 27

    static let cardPadding: CGFloat = 16        // padding:16px
    static let heroPadding: CGFloat = 18        // hero 卡 padding:18px
    static let pagePadding: CGFloat = 18        // scroll area padding:… 18px
    static let sectionSpacing: CGFloat = 16

    /// 懸浮 tab bar 佔用的高度（bottom:20 + height:66）＋ 呼吸空間。
    static let tabBarClearance: CGFloat = 110

    // MARK: - Shadow
    // 設計是雙層陰影：`0 1px 2px rgba(16,24,40,0.04), 0 10px 26px -16px rgba(16,24,40,0.22)`。
    // SwiftUI 一個 modifier 一層，所以拆兩個（`App2Card` 內串接）。

    static let shadowInk = Color(hex: "#101828")

    static let shadowTightColor = shadowInk.opacity(0.04)
    static let shadowTightRadius: CGFloat = 1
    static let shadowTightY: CGFloat = 1

    static let shadowSoftColor = shadowInk.opacity(0.16)
    static let shadowSoftRadius: CGFloat = 13
    static let shadowSoftY: CGFloat = 10

    /// 藍卡的光暈：`0 8px 24px -14px rgba(24,144,255,0.4)`。
    static let shadowAccentColor = Color(hex: "#1890FF").opacity(0.32)
    static let shadowAccentRadius: CGFloat = 12
    static let shadowAccentY: CGFloat = 8

    // 舊呼叫點別名。
    static let shadowColor = shadowSoftColor
    static let shadowRadius = shadowSoftRadius
    static let shadowY = shadowSoftY
}

// MARK: - 課型配色
/// 課表每日卡的左緣色條與課型徽章。
///
/// **不新增第二套課型分類**：分類本體是 repo 既有的 `DayType`
/// （`Havital/Models/WeeklyPlan.swift`，對應後端 run_type taxonomy）。
/// `DayType.labelColor` 給的是 1.x 的系統色（`.green`／`.orange`），這裡只是把
/// 同一個 case 表映到 2.0 的色階；分組方式與 `labelColor` 一致，沒有第二種語意。
extension DayType {
    var app2StripColor: Color {
        switch self {
        case .easyRun, .easy, .recovery_run, .yoga:
            return App2Theme.accentGreenBright
        case .interval, .tempo, .threshold, .combination,
             .strides, .hillRepeats, .cruiseIntervals, .shortInterval,
             .longInterval, .norwegian4x4, .norwegianSingles, .yasso800,
             .fartlek, .steadyIntervals:
            return App2Theme.accentOrangeBright
        case .racePace, .race, .benchmark:
            return App2Theme.accentRed
        case .lsd, .longRun, .progression, .fastFinish, .hiking, .cycling:
            return App2Theme.accentBlue
        case .crossTraining, .strength, .swimming, .elliptical, .rowing:
            return App2Theme.accentViolet
        case .rest:
            return App2Theme.chevron
        }
    }

    /// 徽章的字色／底色（同一顆色的深字＋淺底）。
    var app2ChipForeground: Color {
        switch self {
        case .rest: return App2Theme.inkTertiary
        default:    return app2StripColor.app2Darkened
        }
    }

    var app2ChipBackground: Color {
        app2StripColor.opacity(self == .rest ? 0.14 : 0.13)
    }
}

extension Color {
    /// 徽章字色用的加深版（淺底上要壓得住）。
    /// 訓練詳情 hero 漸層的上緣（設計 frame-02 的 `#ff8a4c → #f4622e → #e8500f`
    /// 三段漸層，起點比課型主色亮一階）。
    var app2Lightened: Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return Color(hue: h, saturation: max(0, s * 0.82), brightness: min(1, b * 1.12), opacity: a)
        }
        #endif
        return self
    }

    var app2Darkened: Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return Color(hue: h, saturation: min(1, s * 1.1), brightness: b * 0.72, opacity: a)
        }
        #endif
        return self
    }
}

// MARK: - 指標配色
/// 指標膠囊／網格的顏色綁「方向」，icon 綁「指標身分」（見 `App2Insight.symbolName`）。
/// 顏色住在 Presentation，不進 Domain。
extension App2Insight {
    var tint: Color {
        switch direction {
        case .up:      return App2Theme.accentGreen
        case .down:    return App2Theme.accentOrangeBright
        case .flat:    return App2Theme.accentBlueDeep
        case .unknown: return App2Theme.inkMuted
        }
    }
}

// MARK: - Typography
//
// 設計用 Noto Sans TC（w400/500/700/900）＋ JetBrains Mono（數字）。
// iOS 對應：系統字（w900 → `.heavy`／`.black`）＋ 數字用 monospacedDigit，
// 不引入自訂字體檔（票面裁決）。

extension Font {
    /// 大數字（`2:34:00`／`1,284`）。設計是 JetBrains Mono w900。
    static func app2Mono(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// 舊呼叫點別名。
    static func app2Numeric(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        app2Mono(size, weight: weight)
    }

    /// 頁面大標（`訓練課表`／`個人成就`）：24px / w900。
    static let app2PageTitle = Font.system(size: 24, weight: .black)

    /// 卡片標題（`訓練狀況`／`個人最佳`）：18px / w900。
    static let app2CardTitle = Font.system(size: 18, weight: .black)

    /// 區塊小標（`目標賽事`／`數據來源`）：13px / w700–800。
    static let app2SectionLabel = Font.system(size: 13, weight: .bold)

    /// 欄位標籤（`目標`／`預估完賽`／`週次`）：13px / w700。
    static let app2FieldLabel = Font.system(size: 13, weight: .bold)

    /// 列標題（設定列、動作名）：15px / w800。
    static let app2RowTitle = Font.system(size: 15, weight: .heavy)

    static let app2Body = Font.system(size: 14, weight: .semibold)
    static let app2Caption = Font.system(size: 13, weight: .semibold)
}
