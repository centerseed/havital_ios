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
        let normalizedType = normalizedType(rawType)
        let key = "training.type.\(normalizedType)"
        let localized = NSLocalizedString(key, comment: "")
        // NSLocalizedString returns the key itself when no translation is found
        if localized != key {
            return localized
        }
        // Fallback: any unmapped "*_interval(s)" type is generically a 間歇 workout.
        // Avoids leaking raw IDs / methodology branding (e.g. "paceriz_interval").
        if normalizedType.lowercased().contains("interval") {
            let intervalKey = "training.type._generic_interval"
            let intervalName = NSLocalizedString(intervalKey, comment: "")
            return intervalName == intervalKey ? normalizedType : intervalName
        }
        // Fallback: any unmapped "*combo/*combination" segment-quality template
        // (e.g. "easy_surge_combo", "tempo_race_combo") is generically a 組合訓練.
        // Backend maps these to the "combination" RunType; mirror that so the
        // raw template ID never leaks in the plan overview.
        let lowered = normalizedType.lowercased()
        if lowered.contains("combo") || lowered.contains("combination") {
            let comboKey = "training.type.combination"
            let comboName = NSLocalizedString(comboKey, comment: "")
            return comboName == comboKey ? normalizedType : comboName
        }
        return normalizedType
    }

    private static func normalizedType(_ rawType: String) -> String {
        switch rawType.lowercased() {
        case "easy_long":
            return "long_run"
        default:
            return rawType
        }
    }
}
