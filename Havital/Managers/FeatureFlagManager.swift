import Foundation
// TODO: 需要在 Xcode 專案中加入 FirebaseRemoteConfig 依賴
// import FirebaseRemoteConfig
import Combine

/// 集中管理應用程式的 Feature Flags
/// 臨時實作：使用 UserDefaults，待加入 FirebaseRemoteConfig 依賴後升級
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()
    
    // 臨時解決方案：使用 UserDefaults 替代 Remote Config
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Feature Flag Keys
    private enum FeatureKeys: String {
        case garminIntegration = "garmin_integration_enabled"
        // 未來可以加入更多 feature flags
        // case newTrainingPlan = "new_training_plan_enabled"
        // case betaFeatures = "beta_features_enabled"
    }
    
    // MARK: - Published Properties
    @Published var isGarminEnabled: Bool = false
    
    private init() {
        // 初始化預設值
        setupDefaultValues()
        updateFeatureFlags()
    }
    
    // MARK: - Setup
    private func setupDefaultValues() {
        // 設定預設值（只有在沒有設定過的情況下）
        if userDefaults.object(forKey: FeatureKeys.garminIntegration.rawValue) == nil {
            userDefaults.set(false, forKey: FeatureKeys.garminIntegration.rawValue)
        }
        
        Logger.firebase("FeatureFlagManager 初始化完成 (UserDefaults 模式)", level: .info, labels: [
            "module": "FeatureFlagManager",
            "action": "setup",
            "mode": "userdefaults"
        ])
    }
    
    // MARK: - Update Feature Flags
    private func updateFeatureFlags() {
        let newGarminEnabled = userDefaults.bool(forKey: FeatureKeys.garminIntegration.rawValue)
        
        // 只有在值改變時才更新，避免不必要的 UI 刷新
        if newGarminEnabled != isGarminEnabled {
            isGarminEnabled = newGarminEnabled
            
            Logger.firebase("Feature Flag 更新", level: .info, labels: [
                "module": "FeatureFlagManager",
                "garmin_enabled": "\(isGarminEnabled)"
            ])
            
            // 發送通知讓其他組件知道 feature flag 改變了
            NotificationCenter.default.post(
                name: NSNotification.Name("FeatureFlagDidChange"),
                object: nil,
                userInfo: ["garmin_enabled": isGarminEnabled]
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// 手動重新載入設定（臨時實作，用於測試）
    func refreshConfig() async {
        updateFeatureFlags()
    }
    
    /// 檢查特定 feature flag 是否啟用
    func isFeatureEnabled(_ feature: String) -> Bool {
        return userDefaults.bool(forKey: feature)
    }
    
    /// 獲取設定的字串值
    func stringValue(forKey key: String) -> String {
        return userDefaults.string(forKey: key) ?? ""
    }
    
    /// 獲取設定的數值
    func numberValue(forKey key: String) -> NSNumber {
        return NSNumber(value: userDefaults.double(forKey: key))
    }
    
    /// 手動設定 feature flag 值（臨時實作，正式版應透過 Firebase Console）
    func setFeatureFlag(_ key: String, value: Bool) {
        userDefaults.set(value, forKey: key)
        updateFeatureFlags()
        
        Logger.firebase("手動設定 Feature Flag", level: .info, labels: [
            "module": "FeatureFlagManager",
            "key": key,
            "value": "\(value)"
        ])
    }
}

// MARK: - Convenience Properties
extension FeatureFlagManager {
    /// Garmin 整合功能是否啟用
    /// 考慮 Remote Config + Client ID 有效性
    var isGarminIntegrationAvailable: Bool {
        // Remote Config 控制功能開關
        guard isGarminEnabled else { return false }
        
        // 還需要檢查 Client ID 是否有效
        return GarminManager.shared.isClientIDValid
    }
}

// MARK: - Debug Helpers
#if DEBUG
extension FeatureFlagManager {
    /// 開發環境專用：強制設定 feature flag（僅用於測試）
    func setDebugFlag(_ key: String, value: Bool) {
        setFeatureFlag(key, value: value)
        print("🚧 DEBUG: 強制設定 \(key) = \(value)")
    }
    
    /// 開發環境專用：列出所有 feature flags
    func debugPrintAllFlags() {
        print("🚧 DEBUG: Feature Flags 狀態 (UserDefaults 模式)")
        print("  - garmin_integration_enabled: \(isGarminEnabled)")
        print("  - client_id_valid: \(GarminManager.shared.isClientIDValid)")
        print("  - final_garmin_available: \(isGarminIntegrationAvailable)")
    }
    
    /// 開發環境專用：快速啟用 Garmin 功能
    func enableGarminForTesting() {
        setFeatureFlag(FeatureKeys.garminIntegration.rawValue, value: true)
        print("🚧 DEBUG: Garmin 功能已啟用（測試模式）")
    }
    
    /// 開發環境專用：重置所有 feature flags
    func resetAllFlags() {
        userDefaults.removeObject(forKey: FeatureKeys.garminIntegration.rawValue)
        setupDefaultValues()
        updateFeatureFlags()
        print("🚧 DEBUG: 所有 Feature Flags 已重置")
    }
}
#endif