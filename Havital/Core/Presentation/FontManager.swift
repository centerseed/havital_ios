import SwiftUI

/// 多語言字型管理系統
/// 自動根據當前語言選擇合適的字型
struct AppFont {

    // MARK: - Thread-Safe Language Cache

    /// 線程安全的語言緩存（避免使用 MainActor.assumeIsolated）
    private static var cachedLanguage: SupportedLanguage = .english

    /// 更新緩存的語言（應該在 LanguageManager 語言改變時調用）
    @MainActor
    static func updateLanguage(_ language: SupportedLanguage) {
        cachedLanguage = language
    }

    /// 獲取當前語言（線程安全）
    private static func currentLanguage() -> SupportedLanguage {
        return cachedLanguage
    }

    /// 小字級在 CJK 可讀性明顯較差，因此只對小尺寸做輕量放大。
    private static func adjustedSystemSize(_ size: CGFloat) -> CGFloat {
        switch currentLanguage() {
        case .english:
            return size
        case .japanese, .traditionalChinese:
            switch size {
            case ...10:
                return size + 3
            case ...12:
                return size + 3
            case ...14:
                return size + 2
            case ...16:
                return size + 1
            default:
                return size
            }
        }
    }

    // MARK: - Large Titles (大標題)
    /// 用於主頁面標題 (54pt)
    static func largeTitle() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 54, relativeTo: .largeTitle)
        case .japanese, .traditionalChinese:
            return .system(size: 52, weight: .semibold, design: .default)
        }
    }

    // MARK: - Title 1 (主標題)
    /// 用於頁面主標題 (28pt)
    static func title1() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 28, relativeTo: .title)
        case .japanese, .traditionalChinese:
            return .system(size: 28, weight: .bold, design: .default)
        }
    }

    // MARK: - Title 2 (次標題)
    /// 用於分區標題或卡片標題 (24pt)
    static func title2() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 24, relativeTo: .headline)
        case .japanese, .traditionalChinese:
            return .system(size: 24, weight: .bold, design: .default)
        }
    }

    // MARK: - Title 3 (小標題)
    /// 用於子標題 (20pt)
    static func title3() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 20, relativeTo: .headline)
        case .japanese, .traditionalChinese:
            return .system(size: 20, weight: .semibold, design: .default)
        }
    }

    // MARK: - Headline
    /// 用於強調文本或次要標題 (18pt)
    static func headline() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 18, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 18, weight: .semibold, design: .default)
        }
    }

    // MARK: - Headline Medium
    /// 用於中等強調 (16pt, semibold)
    static func headlineMedium() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .semibold, design: .default)
        }
    }

    // MARK: - Subheadline
    /// 用於次級標題與說明 (15pt)
    static func subheadline() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 16, relativeTo: .subheadline)
        case .japanese, .traditionalChinese:
            return .system(size: 17, weight: .regular, design: .default)
        }
    }

    // MARK: - Body
    /// 用於主要內文 (16pt)
    static func body() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 17, weight: .regular, design: .default)
        }
    }

    // MARK: - Body Medium
    /// 用於強調內文 (16pt, semibold)
    static func bodyMedium() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 17, weight: .semibold, design: .default)
        }
    }

    // MARK: - Body Small
    /// 用於次要內文 (14pt)
    static func bodySmall() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 14, relativeTo: .subheadline)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .regular, design: .default)
        }
    }

    // MARK: - Caption
    /// 用於輔助文本或標籤 (12pt)
    static func caption() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 13, relativeTo: .footnote)
        case .japanese, .traditionalChinese:
            return .system(size: 15, weight: .regular, design: .default)
        }
    }

    // MARK: - Caption Medium
    /// 用於中等輔助文本 (12pt, semibold)
    static func captionMedium() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 13, relativeTo: .footnote)
        case .japanese, .traditionalChinese:
            return .system(size: 15, weight: .semibold, design: .default)
        }
    }

    // MARK: - Caption Small
    /// 用於最小輔助文本 (10pt)
    static func captionSmall() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 12, relativeTo: .caption)
        case .japanese, .traditionalChinese:
            return .system(size: 14, weight: .regular, design: .default)
        }
    }

    // MARK: - Footnote
    /// 用於註解與次級說明 (13pt)
    static func footnote() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 14, relativeTo: .footnote)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .regular, design: .default)
        }
    }

    // MARK: - Caption 2
    /// 用於極短輔助標籤，避免小於 captionSmall 的可讀性問題。
    static func caption2() -> Font {
        captionSmall()
    }

    // MARK: - Callout
    /// 用於提醒與短段落說明 (16pt)
    static func callout() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 16, relativeTo: .callout)
        case .japanese, .traditionalChinese:
            return .system(size: 17, weight: .regular, design: .default)
        }
    }

    // MARK: - Data Display (數據展示)
    /// 用於大型數據顯示 (54pt, 適用於訓練卡片)
    static func dataLarge() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 54, relativeTo: .largeTitle)
        case .japanese, .traditionalChinese:
            return .system(size: 52, weight: .semibold, design: .default)
        }
    }

    /// 用於中型數據顯示 (40pt)
    static func dataMedium() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 40, relativeTo: .largeTitle)
        case .japanese, .traditionalChinese:
            return .system(size: 38, weight: .semibold, design: .default)
        }
    }

    /// 用於小型數據顯示 (28pt)
    static func dataSmall() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 28, relativeTo: .title)
        case .japanese, .traditionalChinese:
            return .system(size: 26, weight: .semibold, design: .default)
        }
    }

    // MARK: - Button
    /// 用於按鈕文本 (16pt, semibold)
    static func button() -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            return .custom("Onest", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .semibold, design: .default)
        }
    }

    // MARK: - Custom Size
    /// 自訂大小的字型
    /// - Parameters:
    ///   - size: 字號大小
    ///   - weight: 字重 (.regular, .medium, .semibold, .bold)
    static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let language = currentLanguage()
        switch language {
        case .english:
            // 英文使用 Inter 自訂字型
            let weightName = weightName(for: weight)
            return .custom("Onest", size: size, relativeTo: .body)
        case .japanese, .traditionalChinese:
            // 日文和中文使用系統字型
            return .system(size: adjustedSystemSize(size), weight: weight, design: .default)
        }
    }

    /// 將原本散落在 view 的 `.system(size:)` 收斂到同一入口，
    /// 並讓 CJK 小字可以共用一致的補償邏輯。
    static func systemScaled(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        .system(size: adjustedSystemSize(size), weight: weight, design: design)
    }

    static func monospacedBody() -> Font {
        .system(.body, design: .monospaced)
    }

    // MARK: - Helper
    /// 取得字重名稱（用於自訂字型名稱）
    private static func weightName(for weight: Font.Weight) -> String {
        switch weight {
        case .thin:
            return "Thin"
        case .ultraLight:
            return "ExtraLight"
        case .light:
            return "Light"
        case .regular:
            return "Regular"
        case .medium:
            return "Medium"
        case .semibold:
            return "SemiBold"
        case .bold:
            return "Bold"
        case .heavy:
            return "ExtraBold"
        case .black:
            return "Black"
        default:
            return "Regular"
        }
    }

    // MARK: - Dynamic Font Loading
    /// 動態載入 Onest 字體檔案（如果未被 Info.plist 載入）
    static func loadOnestFontsIfNeeded() {
        let fontNames = ["Onest-Regular", "Onest-Medium", "Onest-SemiBold", "Onest-Bold"]

        for fontName in fontNames {
            let fonts = UIFont.fontNames(forFamilyName: "Onest")
            if !fonts.isEmpty {
                return  // 字體已經載入，無需重複載入
            }

            // 嘗試從 app bundle 根目錄載入
            if let path = Bundle.main.path(forResource: fontName, ofType: "ttf"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let provider = CGDataProvider(data: data as CFData),
               let font = CGFont(provider) {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterGraphicsFont(font, &error) {
                    Logger.debug("✅ 動態載入字體成功: \(fontName)")
                } else if let error = error?.takeRetainedValue() {
                    Logger.error("❌ 動態載入字體失敗 (\(fontName)): \(error.localizedDescription)")
                }
            } else {
                Logger.error("❌ 找不到字體檔案: \(fontName).ttf 或無法讀取")
            }
        }
    }

    // MARK: - Debug: Verify Font Loading
    /// Debug 函數：驗證 Onest 字體是否被正確載入
    static func debugCheckFonts() {
        #if DEBUG
        Logger.debug("=== Font Loading Debug Info ===")

        // 檢查 Onest 字體是否可用
        let onestFamilyName = "Onest"
        let fonts = UIFont.fontNames(forFamilyName: onestFamilyName)
        if !fonts.isEmpty {
            Logger.debug("✅ Onest 字體已載入，可用的字重：")
            for fontName in fonts {
                Logger.debug("   - \(fontName)")
            }
        } else {
            Logger.error("❌ Onest 字體未找到！")
        }

        // 列出所有已載入的字體家族
        let allFamilies = UIFont.familyNames.sorted()
        Logger.debug("已載入的字體家族總數：\(allFamilies.count)")

        // 搜尋包含 "Onest" 的字體
        let onestFamilies = allFamilies.filter { $0.lowercased().contains("onest") }
        if onestFamilies.isEmpty {
            Logger.error("❌ 未找到任何包含 'Onest' 的字體家族")
        } else {
            Logger.debug("找到 Onest 字體家族：\(onestFamilies)")
        }
        #endif
    }
}

// MARK: - SwiftUI View Extensions
extension View {
    /// 應用大標題字型
    func largeTitle() -> some View {
        self.font(AppFont.largeTitle())
    }

    /// 應用 Title1 字型
    func title1() -> some View {
        self.font(AppFont.title1())
    }

    /// 應用 Title2 字型
    func title2() -> some View {
        self.font(AppFont.title2())
    }

    /// 應用 Title3 字型
    func title3() -> some View {
        self.font(AppFont.title3())
    }

    /// 應用 Headline 字型
    func headline() -> some View {
        self.font(AppFont.headline())
    }

    /// 應用 Body 字型
    func body() -> some View {
        self.font(AppFont.body())
    }

    /// 應用 Body Small 字型
    func bodySmall() -> some View {
        self.font(AppFont.bodySmall())
    }

    /// 應用 Caption 字型
    func caption() -> some View {
        self.font(AppFont.caption())
    }

    /// 應用 Data Large 字型
    func dataLarge() -> some View {
        self.font(AppFont.dataLarge())
    }
}
