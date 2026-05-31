import Foundation

// MARK: - RevenueCatConfig
/// RevenueCat SDK 設定
/// 單一 API Key 即可：RevenueCat 自動根據 receipt 辨別 Sandbox / Production
struct RevenueCatConfig {
    private static let apiKeyInfoKey = "REVENUECAT_API_KEY"
    private static let entitlementInfoKey = "REVENUECAT_PREMIUM_ENTITLEMENT"
    private static let fallbackPremiumEntitlement = "Paceriz Premium"
    private static let fallbackAPIKey = "appl_goEmxlWDniAtziTzdXeOpmgNkEt"

    static var apiKey: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: apiKeyInfoKey) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.contains("$(") else {
            assertionFailure("Missing \(apiKeyInfoKey) in Info.plist build settings")
            return fallbackAPIKey
        }
        return value
    }

    static var premiumEntitlement: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: entitlementInfoKey) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallbackPremiumEntitlement
        }
        return value
    }
}
