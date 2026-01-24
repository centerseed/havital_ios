import Foundation
import FirebaseRemoteConfig
import Combine

/// 集中管理應用程式的 Feature Flags
/// 使用 Firebase Remote Config 實現動態功能開關
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()
    
    private var remoteConfig: RemoteConfig
    private let userDefaults = UserDefaults.standard // 保留作為 fallback
    
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
        remoteConfig = RemoteConfig.remoteConfig()
        setupRemoteConfig()
        fetchRemoteConfig()
    }
    
    // MARK: - Setup
    private func setupRemoteConfig() {
        // 設定 Remote Config 預設值
        let defaults: [String: NSObject] = [
            FeatureKeys.garminIntegration.rawValue: false as NSObject
        ]
        
        remoteConfig.setDefaults(defaults)
        
        // 設定開發環境的更新頻率（正式環境建議 12 小時以上）
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // 開發環境立即更新
        #else
        settings.minimumFetchInterval = 0 // 正式環境 1 小時更新一次
        #endif
        
        remoteConfig.configSettings = settings
        
        Logger.firebase("FeatureFlagManager 初始化完成 (Firebase Remote Config)", level: .info, labels: [
            "module": "FeatureFlagManager",
            "action": "setup",
            "mode": "firebase_remote_config"
        ])
    }
    
    // MARK: - Fetch Remote Config
    private func fetchRemoteConfig() {
        print("🔄 開始獲取並啟用 Remote Config...")
        
        // 使用 fetchAndActivate 一次完成獲取和啟用
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self = self else { return }
            
            print("📡 Remote Config fetchAndActivate 完成 - status: \(status.rawValue)")
            
            if let error = error {
                print("❌ Remote Config fetchAndActivate 失敗: \(error.localizedDescription)")
                Logger.firebase("Remote Config fetchAndActivate 失敗", level: .error, labels: [
                    "module": "FeatureFlagManager",
                    "error": error.localizedDescription
                ])
                // 使用預設值
                DispatchQueue.main.async {
                    self.updateFeatureFlags()
                }
                return
            }
            
            print("✅ Remote Config fetchAndActivate 成功 - status: \(status.rawValue)")
            Logger.firebase("Remote Config fetchAndActivate 成功", level: .info, labels: [
                "module": "FeatureFlagManager",
                "status": "\(status.rawValue)"
            ])
            
            // 在主線程更新 feature flags
            DispatchQueue.main.async {
                self.updateFeatureFlags()
            }
        }
    }
    
    // MARK: - Update Feature Flags
    private func updateFeatureFlags() {
        let newGarminEnabled = remoteConfig.configValue(forKey: FeatureKeys.garminIntegration.rawValue).boolValue
        
        Logger.firebase("Feature Flag 讀取", level: .info, labels: [
            "module": "FeatureFlagManager",
            "key": FeatureKeys.garminIntegration.rawValue,
            "value_from_remote_config": "\(newGarminEnabled)",
            "current_published_value": "\(isGarminEnabled)",
            "remote_config_source": "\(remoteConfig.configValue(forKey: FeatureKeys.garminIntegration.rawValue).source.rawValue)"
        ])
        
        // 更新值（初始化時也要更新）
        let valueChanged = newGarminEnabled != isGarminEnabled
        isGarminEnabled = newGarminEnabled
        
        if valueChanged {
            Logger.firebase("Feature Flag 值已變更", level: .info, labels: [
                "module": "FeatureFlagManager",
                "garmin_enabled": "\(isGarminEnabled)",
                "change_trigger": "remote_config_update"
            ])

            // 發送通知讓其他組件知道 feature flag 改變了
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: NSNotification.Name("FeatureFlagDidChange"),
                    object: nil,
                    userInfo: ["garmin_enabled": self.isGarminEnabled]
                )
            }
        } else {
            Logger.firebase("Feature Flag 值未變更", level: .info, labels: [
                "module": "FeatureFlagManager",
                "garmin_enabled": "\(isGarminEnabled)"
            ])
        }
    }
    
    // MARK: - Public Methods
    
    /// 手動重新獲取 Remote Config（用於測試或特殊情況）
    func refreshConfig() async {
        await withCheckedContinuation { continuation in
            remoteConfig.fetchAndActivate { [weak self] status, error in
                if error == nil {
                    DispatchQueue.main.async {
                        self?.updateFeatureFlags()
                    }
                }
                continuation.resume()
            }
        }
    }
    
    /// 檢查特定 feature flag 是否啟用
    func isFeatureEnabled(_ feature: String) -> Bool {
        return remoteConfig.configValue(forKey: feature).boolValue
    }
    
    /// 獲取 Remote Config 的字串值
    func stringValue(forKey key: String) -> String {
        return remoteConfig.configValue(forKey: key).stringValue ?? ""
    }
    
    /// 獲取 Remote Config 的數值
    func numberValue(forKey key: String) -> NSNumber {
        return remoteConfig.configValue(forKey: key).numberValue
    }
    
    /// 手動設定 feature flag 值（開發環境專用，正式版應透過 Firebase Console）
    func setFeatureFlag(_ key: String, value: Bool) {
        #if DEBUG
        Logger.firebase("開發環境：手動覆蓋 Feature Flag", level: .info, labels: [
            "module": "FeatureFlagManager",
            "key": key,
            "override_value": "\(value)",
            "warning": "此設定僅在開發環境有效"
        ])
        
        // 在開發環境中，臨時覆蓋 Remote Config 預設值
        let overrideDefaults: [String: NSObject] = [key: value as NSObject]
        remoteConfig.setDefaults(overrideDefaults)
        
        updateFeatureFlags()
        
        Logger.firebase("開發環境 Feature Flag 覆蓋完成", level: .info, labels: [
            "module": "FeatureFlagManager",
            "key": key,
            "final_published_value": "\(isGarminEnabled)"
        ])
        #else
        Logger.firebase("正式環境：無法手動設定 Feature Flag", level: .warn, labels: [
            "module": "FeatureFlagManager",
            "key": key,
            "message": "請使用 Firebase Console 設定"
        ])
        #endif
    }
}

// MARK: - Convenience Properties
extension FeatureFlagManager {
    /// Garmin 整合功能是否啟用
    /// 考慮 Remote Config + Client ID 有效性
    var isGarminIntegrationAvailable: Bool {
        let featureFlagEnabled = isGarminEnabled
        let clientIDValid = MainActor.assumeIsolated { GarminManager.shared.isClientIDValid }
        let result = featureFlagEnabled && clientIDValid
        
        Logger.firebase("檢查 Garmin 整合可用性", level: .info, labels: [
            "module": "FeatureFlagManager",
            "feature_flag_enabled": "\(featureFlagEnabled)",
            "client_id_valid": "\(clientIDValid)",
            "final_result": "\(result)"
        ])
        
        return result
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
        let key = FeatureKeys.garminIntegration.rawValue
        let remoteConfigValue = remoteConfig.configValue(forKey: key)
        let publishedValue = isGarminEnabled
        let clientIDValid = MainActor.assumeIsolated { GarminManager.shared.isClientIDValid }
        let finalAvailable = isGarminIntegrationAvailable
        
        print("🚧 DEBUG: Feature Flags 完整狀態 (Firebase Remote Config 模式)")
        print("  - Key: \(key)")
        print("  - Remote Config Value: \(remoteConfigValue.boolValue)")
        print("  - Remote Config Source: \(remoteConfigValue.source.rawValue)")
        print("  - Published Value: \(publishedValue)")
        print("  - Client ID Valid: \(clientIDValid)")
        print("  - Final Available: \(finalAvailable)")
        print("  - APIConfig.isGarminEnabled: \(APIConfig.isGarminEnabled)")
        
        // 也記錄到 Firebase 日誌
        Logger.firebase("DEBUG: 完整 Feature Flag 狀態", level: .info, labels: [
            "module": "FeatureFlagManager",
            "remote_config_value": "\(remoteConfigValue.boolValue)",
            "remote_config_source": "\(remoteConfigValue.source.rawValue)",
            "published_value": "\(publishedValue)",
            "client_id_valid": "\(clientIDValid)",
            "final_available": "\(finalAvailable)",
            "apiconfig_enabled": "\(APIConfig.isGarminEnabled)"
        ])
    }
    
    /// 開發環境專用：快速啟用 Garmin 功能
    func enableGarminForTesting() {
        setFeatureFlag(FeatureKeys.garminIntegration.rawValue, value: true)
        print("🚧 DEBUG: Garmin 功能已啟用（測試模式）")
    }
    
    /// 開發環境專用：重置所有 feature flags
    func resetAllFlags() {
        // 重新設定預設值
        let defaults: [String: NSObject] = [
            FeatureKeys.garminIntegration.rawValue: false as NSObject
        ]
        remoteConfig.setDefaults(defaults)
        updateFeatureFlags()
        print("🚧 DEBUG: 所有 Feature Flags 已重置到預設值")
    }
    
    /// 開發環境專用：強制重新獲取 Remote Config
    func forceRefreshRemoteConfig() {
        print("🚧 DEBUG: 強制重新獲取 Remote Config")
        Task {
            await refreshConfig()
            debugPrintAllFlags()
        }
    }
}
#endif
