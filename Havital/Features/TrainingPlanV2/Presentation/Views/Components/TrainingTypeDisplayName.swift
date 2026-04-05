import Foundation

// MARK: - Training Type Display Names
/// 訓練類型多語系化對照
/// 將 API 回傳的英文 training type 轉換為本地化顯示名稱
enum TrainingTypeDisplayName {

    /// 長跑類型本地化
    static func longRunName(_ rawType: String) -> String {
        return localizedName(rawType)
    }

    /// 品質課類型本地化
    static func qualityOptionName(_ rawType: String) -> String {
        return localizedName(rawType)
    }

    /// 將品質課列表轉為本地化顯示字串
    static func qualityOptionsDisplay(_ options: [String]) -> String {
        guard !options.isEmpty else { return "—" }
        return options.map { qualityOptionName($0) }.joined(separator: "、")
    }

    /// 長跑類型顯示字串
    static func longRunDisplay(_ longRun: String?) -> String {
        guard let longRun = longRun else { return "—" }
        return longRunName(longRun)
    }

    // MARK: - Private

    private static func localizedName(_ rawType: String) -> String {
        let key = "training.type.\(rawType)"
        let localized = NSLocalizedString(key, comment: "")
        // NSLocalizedString returns the key itself when no translation is found
        return localized == key ? rawType : localized
    }
}
