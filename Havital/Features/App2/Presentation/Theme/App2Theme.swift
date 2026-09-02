import SwiftUI
import UIKit

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

    /// SPEC-app-appearance R3：dark 表面／文字對 1.x `color.dark`。
    /// `UIColor` dynamic provider 讓既有呼叫點在系統外觀切換時自己換色。
    private static func adaptive(light: String, dark: String, alpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(Color(hex: hex)).withAlphaComponent(alpha)
        })
    }

    /// 兩個模式的 alpha 不同時用這一支（陰影：深色下要壓得比淺色重得多）。
    private static func adaptive(
        light: String, lightAlpha: CGFloat,
        dark: String, darkAlpha: CGFloat
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(Color(hex: isDark ? dark : light))
                .withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        })
    }

    // MARK: - Surface

    /// 頁面底：light 設計包漸層；dark 兩端都是 1.x `#121212`。
    static let pageTop = adaptive(light: "#F3F6FA", dark: "#0B0B0D")
    static let pageBottom = adaptive(light: "#EEF2F7", dark: "#0B0B0D")

    static var pageGradient: LinearGradient {
        LinearGradient(colors: [pageTop, pageBottom], startPoint: .top, endPoint: .bottom)
    }

    /// 舊呼叫點的單色別名（載入態／空狀態底色）。
    static let pageBackground = pageTop

    static let cardBackground = adaptive(light: "#FFFFFF", dark: "#232329")
    /// `1px solid rgba(15,23,42,0.07)`；dark 同 alpha 的白。
    static let cardBorder = adaptive(light: "#0F172A", lightAlpha: 0.07, dark: "#FFFFFF", darkAlpha: 0.14)

    /// 卡中卡：light 設計包；dark 1.x tertiary `#2C2C2E`。
    static let insetBackground = adaptive(light: "#F5F7FA", dark: "#2E2E35")
    static let insetBackgroundCool = adaptive(light: "#F7F9FC", dark: "#2E2E35")
    static let insetBorder = adaptive(light: "#0F172A", dark: "#FFFFFF", alpha: 0.06)

    /// 強調卡（目標賽事／本週跑量／紀錄 hero／成就 hero）：
    /// `linear-gradient(150deg, rgba(24,144,255,0.12), rgba(24,144,255,0.02) 60%, #ffffff)`。
    /// SwiftUI 沒有 CSS 的 150deg 語意，用等效的左上→右下對角。
    static func accentCardGradient(strength: Double = 0.12) -> LinearGradient {
        // 深色下同一個 alpha 幾乎看不出來：藍疊在近黑上，整張卡與一般卡沒差別
        // （2026-09-02 使用者回報「hero 藍色漸層很不明顯」）。深色把疊色加重約一倍，
        // 中段也不收到 0.02，讓漸層在整張卡上都還讀得出來。
        LinearGradient(
            stops: [
                .init(
                    color: adaptive(
                        light: "#1890FF", lightAlpha: strength,
                        dark: "#1890FF", darkAlpha: min(strength * 2.4, 0.42)
                    ),
                    location: 0
                ),
                .init(
                    color: adaptive(
                        light: "#1890FF", lightAlpha: 0.02,
                        dark: "#1890FF", darkAlpha: 0.12
                    ),
                    location: 0.6
                ),
                .init(color: cardBackground, location: 1)
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

    /// 深綠 hero —— **maintenance 計畫的結束態**（設計 frame-00g（b）右卡）。
    ///
    /// 與 `heroDarkGradient` 是同一種構造只換色：兩張卡的差別是**語意**
    /// （備賽完成 vs 訓練期完成），不是版式。2026-08-27 裁決：顏色跟語意變體走，
    /// 首頁 hero、整期總結 hero、課表 tab 結束態卡三處一致，且與 Android 對齊。
    static var heroGreenGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#1E7A47"), location: 0),
                .init(color: Color(hex: "#14532D"), location: 0.58),
                .init(color: Color(hex: "#0B1F13"), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let shadowHeroGreenColor = Color(hex: "#1E7A47").opacity(0.55)

    /// 舊呼叫點別名。
    static let goalCardBackground = adaptive(light: "#EAF2FE", dark: "#2C2C2E")

    // MARK: - Ink

    static let inkPrimary = adaptive(light: "#10151C", dark: "#FFFFFF")
    static let inkSecondary = adaptive(light: "#4A5561", dark: "#C8CDD3")
    static let inkTertiary = adaptive(light: "#8A929C", dark: "#9AA1A9")
    static let inkMuted = adaptive(light: "#94A0AD", dark: "#8A9199")
    static let inkFaint = adaptive(light: "#A2ABB6", dark: "#7C838B")
    static let inkSubtle = adaptive(light: "#6B7581", dark: "#B0B6BD")
    static let chevron = adaptive(light: "#C2CAD3", dark: "#B3B3B3")

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
    /// 深色下壓暗一階：`#22C55E` 在近黑底上大面積鋪（詳情頁輕鬆跑 hero）會刺眼
    /// （2026-09-02 使用者回報）。淺色維持設計包的值。
    static let accentGreenBright = adaptive(light: "#22C55E", dark: "#1E9E52")
    static let accentGreenDot = Color(hex: "#2E9E5B")  // 已連接

    static let accentRed = Color(hex: "#EF5B6B")       // 高強度
    static let accentViolet = Color(hex: "#8B7BE8")    // 肌力／交叉訓練

    /// 強度區間六色（Z1…Z6，由低到高）。編號就是心率區間設定頁那張表上的編號，
    /// 語意與 Android `workoutZoneColor` 同一組：綠 → 藍 → 黃 → 橘 → 紫 → 紅。
    static let zoneRecovery = Color(hex: "#4FC47E")
    static let zoneAerobic = accentBlue
    static let zoneMarathon = Color(hex: "#F0A93B")
    static let zoneThreshold = accentOrangeBright
    static let zoneAnaerobic = accentViolet
    static let zoneInterval = accentRed

    /// 課表強度分段條的三段漸層（設計 frame-01 的 `linear-gradient(90deg,…)`）。
    static let intensityLowGradient = (from: Color(hex: "#4ADE80"), to: Color(hex: "#16A34A"))
    static let intensityMediumGradient = (from: Color(hex: "#FFB15E"), to: Color(hex: "#F97316"))
    static let intensityHighGradient = (from: Color(hex: "#FF8A99"), to: Color(hex: "#EF4444"))

    /// 成就圓章的銅色（設計 frame-11）。
    static let medalGradient = (from: Color(hex: "#F0A24E"), to: Color(hex: "#A85818"))

    /// 數據來源列的品牌底（設計 frame-21）。
    static let sourceDarkTile = Color(hex: "#0B0D10")
    static let sourceLightTile = adaptive(light: "#F0F3F7", dark: "#2C2C2E")
    static let appleHealthRed = Color(hex: "#E5546C")

    /// 軌跡圖三色帶（§3.1a）。
    static let trackBehind = Color(hex: "#F0B48A")
    static let trackOnTrack = Color(hex: "#4FC47E")
    static let trackAhead = Color(hex: "#5AA9F0")

    /// stub 標記色（畫面上明示「這格還沒有後端」）。
    static let stubTint = Color(hex: "#9A7B00")
    static let stubBackground = adaptive(light: "#FFF6D9", dark: "#2C2C2E")

    // MARK: - 邊線與中性填色（view 內不落 hex；2026-08-29 外審 C10）

    /// 比 `cardBorder`（0.07）再重一階的外框，選擇卡的常態邊線。
    static let strokeStrong = adaptive(light: "#0F172A", dark: "#FFFFFF", alpha: 0.08)
    /// 比 `insetBorder`（0.06）再淡一階，禁用態的框線。
    static let strokeFaint = adaptive(light: "#0F172A", dark: "#FFFFFF", alpha: 0.05)
    /// 分隔線／未選中膠囊底。
    static let hairline = adaptive(light: "#D9E0E8", dark: "#FFFFFF", alpha: 0.12)
    /// 未選中 chip 的中性填色。dark 用卡片底 `#1E1E1E`（R3），不是頁面底。
    static let neutralFill = adaptive(light: "#EEF2F7", dark: "#232329")
    /// radio 圈的未選中環。
    static let radioRing = adaptive(light: "#D0D7E0", dark: "#FFFFFF", alpha: 0.16)
    /// 禁用態填色（呼叫端自帶 opacity）。
    static let disabledFill = adaptive(light: "#E6EBF1", dark: "#2C2C2E")

    // MARK: - Onboarding（frame-30~39 專屬色）

    /// 進度點的未到達態。
    static let onbStepDim = adaptive(light: "#B4BCC6", dark: "#B3B3B3")
    /// 深色 hero 上的提示字。
    static let onbHintOnDark = Color(hex: "#B4C2D2")
    /// 深綠成功文字（頂部 hero 淺底上）。
    static let successTextDeep = Color(hex: "#2E8A53")
    /// onboarding 天空漸層（frame-30 backdrop／frame-39 完成頁共用的深→淺四階）。
    static let skyDeep = Color(hex: "#0A4F96")
    static let skyMid = Color(hex: "#1774CF")
    static let skyLight = Color(hex: "#3F8FDB")
    static let skyPale = Color(hex: "#CFE0F0")
    static let skyLightCompact = Color(hex: "#4F9AE0")
    static let skyPaleCompact = Color(hex: "#B9D3EC")
    /// frame-33 五條強度色帶（藍／綠與軌跡圖同色，不開第二個來源）。
    /// 心率區間與配速區間設定頁的五色也是同一組。
    static let bandAmber = Color(hex: "#E0B23A")
    static let bandOrange = Color(hex: "#EC8A4C")
    static let bandRed = Color(hex: "#E5546C")

    // MARK: - 深藍 hero 上的輔助色（訓練計畫頁）

    static let heroSkyLight = Color(hex: "#9FCCFF")
    static let heroTickDim = Color(hex: "#C2CCD8")
    static let dotInactive = adaptive(light: "#C8D3DF", dark: "#B3B3B3")

    // MARK: - 編輯面（day edit／plan edit／edit components）

    /// 警示黃（恢復段標點、提示框；深字用 `editAmberText`）。
    static let editAmber = Color(hex: "#EAB308")
    static let editAmberText = Color(hex: "#A16207")
    /// 控件的關閉態灰。
    static let controlDim = adaptive(light: "#8A97A6", dark: "#B3B3B3")
    /// 柔性危險紅（移除課表這類次要破壞動作）。
    static let dangerSoft = Color(hex: "#DC7676")
    static let accentVioletLight = Color(hex: "#C084FC")
    static let chevronViolet = Color(hex: "#C9A6EC")
    static let editBase = adaptive(light: "#EEF3F8", dark: "#2C2C2E")
    static let editStripe = adaptive(light: "#EAEFF5", dark: "#2C2C2E")
    static let editFilledChip = adaptive(light: "#EEF1F6", dark: "#2C2C2E")
    static let editDotDim = adaptive(light: "#CBD3DD", dark: "#B3B3B3")
    static let editFieldFill = adaptive(light: "#F4F6FA", dark: "#2C2C2E")

    // MARK: - 圖表（App2Charts 專屬漸層端點）

    static let chartSupport = adaptive(light: "#CFD6DF", dark: "#B3B3B3")
    static let chartGreenLight = Color(hex: "#5BE08A")
    static let chartOrangeLight = Color(hex: "#FB7A3C")
    static let chartOrangeDeep = Color(hex: "#E8500F")
    static let chartGreenSoftFrom = Color(hex: "#7BD79C")
    static let chartGreenSoftTo = Color(hex: "#63C98A")

    // MARK: - Metrics（值取自設計 markup）

    static let cardCornerRadius: CGFloat = 22   // border-radius:22px
    static let listCardCornerRadius: CGFloat = 20
    static let dayCardCornerRadius: CGFloat = 16
    static let insetCornerRadius: CGFloat = 12
    static let chipCornerRadius: CGFloat = 8

    static let cardPadding: CGFloat = 16        // padding:16px
    static let heroPadding: CGFloat = 18        // hero 卡 padding:18px
    static let pagePadding: CGFloat = 18        // scroll area padding:… 18px
    static let sectionSpacing: CGFloat = 16

    /// 頁面內容底部的呼吸空間。
    ///
    /// 2026-08-26 起底部導航是系統原生 `TabView`：tab bar 的高度與 safe area 由系統
    /// inset 進 scroll view，頁面**不再**需要自己空出一條 bar 的高度（原本是 110，
    /// 那是自繪懸浮膠囊的 bottom:20 + height:66）。留 16 只是最後一張卡與 tab bar
    /// 之間的間距。
    static let tabBarClearance: CGFloat = 16

    // MARK: - Shadow
    // 設計是雙層陰影：`0 1px 2px rgba(16,24,40,0.04), 0 10px 26px -16px rgba(16,24,40,0.22)`。
    // SwiftUI 一個 modifier 一層，所以拆兩個（`App2Card` 內串接）。

    static let shadowInk = Color(hex: "#101828")

    static let shadowTightColor = adaptive(light: "#101828", lightAlpha: 0.04, dark: "#000000", darkAlpha: 0.35)
    static let shadowTightRadius: CGFloat = 1
    static let shadowTightY: CGFloat = 1

    static let shadowSoftColor = adaptive(light: "#101828", lightAlpha: 0.16, dark: "#000000", darkAlpha: 0.5)
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

    /// 課型的 icon 圓章符號（設計 frame-02d 單段課首卡、frame-02f workout hero）。
    /// 是 `DayType` 的型別對照，不是對顯示字比對。
    var app2SymbolName: String {
        switch self {
        case .strength:
            return "dumbbell.fill"
        case .yoga:
            return "figure.mind.and.body"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        case .rowing:
            return "figure.rower"
        case .elliptical:
            return "figure.elliptical"
        case .crossTraining:
            return "figure.cross.training"
        case .hiking:
            return "figure.hiking"
        case .rest:
            return "moon.zzz.fill"
        default:
            return "figure.run"
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

// MARK: - 計畫結束態配色
/// 顏色跟**語意變體**走（2026-08-27 裁決，與 Android 一致）：race 深藍、
/// maintenance 深綠。
///
/// 首頁 hero、整期總結 hero、課表 tab 結束態卡是同一個語意的三個版位 ——
/// 分岔只能有一份，不在各畫面各寫一次三元式。
extension App2PlanEndKind {
    var heroGradient: LinearGradient {
        self == .race ? App2Theme.heroDarkGradient : App2Theme.heroGreenGradient
    }

    var heroShadow: Color {
        self == .race ? App2Theme.shadowHeroColor : App2Theme.shadowHeroGreenColor
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

    /// 弱化的卡片標題：16px / w600。**只有首頁「訓練狀況」用**
    /// （2026-08-27 晚實機走查裁決（a）：那張卡的主角是 headline 與指標，
    /// 標題本身壓下去）。其餘卡標題維持 `app2CardTitle` —— 這是變體，
    /// 不是把共用值改掉。
    static let app2CardTitleMuted = Font.system(size: 16, weight: .semibold)

    /// 區塊小標（`目標賽事`／`數據來源`）：13px / w700–800。
    static let app2SectionLabel = Font.system(size: 13, weight: .bold)

    /// 欄位標籤（`目標`／`預估完賽`／`週次`）：13px / w700。
    static let app2FieldLabel = Font.system(size: 13, weight: .bold)

    /// 列標題（設定列、動作名）：15px / w800。
    static let app2RowTitle = Font.system(size: 15, weight: .heavy)

    static let app2Body = Font.system(size: 14, weight: .semibold)
    static let app2Caption = Font.system(size: 13, weight: .semibold)
}
