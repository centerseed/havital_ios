import SwiftUI

/// 多語言字型管理系統
/// 自動根據當前語言選擇合適的字型
struct AppFont {

    // MARK: - Large Titles (大標題)
    /// 用於主頁面標題 (54pt)
    static func largeTitle() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 54, relativeTo: .largeTitle)
        case .japanese, .traditionalChinese:
            return .system(size: 52, weight: .semibold, design: .default)
        }
    }

    // MARK: - Title 1 (主標題)
    /// 用於頁面主標題 (28pt)
    static func title1() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 28, relativeTo: .title)
        case .japanese, .traditionalChinese:
            return .system(size: 28, weight: .bold, design: .default)
        }
    }

    // MARK: - Title 2 (次標題)
    /// 用於分區標題或卡片標題 (24pt)
    static func title2() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 24, relativeTo: .headline)
        case .japanese, .traditionalChinese:
            return .system(size: 24, weight: .bold, design: .default)
        }
    }

    // MARK: - Title 3 (小標題)
    /// 用於子標題 (20pt)
    static func title3() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 20, relativeTo: .headline)
        case .japanese, .traditionalChinese:
            return .system(size: 20, weight: .semibold, design: .default)
        }
    }

    // MARK: - Headline
    /// 用於強調文本或次要標題 (18pt)
    static func headline() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 18, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 18, weight: .semibold, design: .default)
        }
    }

    // MARK: - Headline Medium
    /// 用於中等強調 (16pt, semibold)
    static func headlineMedium() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .semibold, design: .default)
        }
    }

    // MARK: - Body
    /// 用於主要內文 (16pt)
    static func body() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .regular, design: .default)
        }
    }

    // MARK: - Body Medium
    /// 用於強調內文 (16pt, semibold)
    static func bodyMedium() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 16, relativeTo: .body)
        case .japanese, .traditionalChinese:
            return .system(size: 16, weight: .semibold, design: .default)
        }
    }

    // MARK: - Body Small
    /// 用於次要內文 (14pt)
    static func bodySmall() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 14, relativeTo: .subheadline)
        case .japanese, .traditionalChinese:
            return .system(size: 14, weight: .regular, design: .default)
        }
    }

    // MARK: - Caption
    /// 用於輔助文本或標籤 (12pt)
    static func caption() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 12, relativeTo: .caption)
        case .japanese, .traditionalChinese:
            return .system(size: 12, weight: .regular, design: .default)
        }
    }

    // MARK: - Caption Medium
    /// 用於中等輔助文本 (12pt, semibold)
    static func captionMedium() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 12, relativeTo: .caption)
        case .japanese, .traditionalChinese:
            return .system(size: 12, weight: .semibold, design: .default)
        }
    }

    // MARK: - Caption Small
    /// 用於最小輔助文本 (10pt)
    static func captionSmall() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 10, relativeTo: .caption2)
        case .japanese, .traditionalChinese:
            return .system(size: 10, weight: .regular, design: .default)
        }
    }

    // MARK: - Data Display (數據展示)
    /// 用於大型數據顯示 (54pt, 適用於訓練卡片)
    static func dataLarge() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 54, relativeTo: .largeTitle)
        case .japanese, .traditionalChinese:
            return .system(size: 52, weight: .semibold, design: .default)
        }
    }

    /// 用於中型數據顯示 (40pt)
    static func dataMedium() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 40, relativeTo: .largeTitle)
        case .japanese, .traditionalChinese:
            return .system(size: 38, weight: .semibold, design: .default)
        }
    }

    /// 用於小型數據顯示 (28pt)
    static func dataSmall() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 28, relativeTo: .title)
        case .japanese, .traditionalChinese:
            return .system(size: 26, weight: .semibold, design: .default)
        }
    }

    // MARK: - Button
    /// 用於按鈕文本 (16pt, semibold)
    static func button() -> Font {
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            return .custom("Inter", size: 16, relativeTo: .body)
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
        let language = LanguageManager.shared.currentLanguage
        switch language {
        case .english:
            // 英文使用 Inter 自訂字型
            let weightName = weightName(for: weight)
            return .custom("Inter", size: size, relativeTo: .body)
        case .japanese, .traditionalChinese:
            // 日文和中文使用系統字型
            return .system(size: size, weight: weight, design: .default)
        }
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
