# Firebase Remote Config 依賴添加指南

## 🚀 快速升級步驟

### 1. 在 Xcode 中添加 Firebase Remote Config

#### 方法 A: 透過 Package Manager (推薦)
1. 打開 Xcode 專案 `Havital.xcodeproj`
2. 選擇專案名稱 (最上層的 "Havital")
3. 選擇 "Package Dependencies" 標籤
4. 點擊 "+" 按鈕
5. 輸入 Firebase SDK URL: `https://github.com/firebase/firebase-ios-sdk`
6. 點擊 "Add Package"
7. 在產品列表中勾選 `FirebaseRemoteConfig`
8. 點擊 "Add Package"

#### 方法 B: 如果已有 Firebase 依賴
1. 在現有的 Firebase package 中
2. 確認 `FirebaseRemoteConfig` 已被勾選
3. 如果沒有，點擊 "Add Product" 添加

### 2. 取消程式碼中的註解

#### 在 `HavitalApp.swift` 中：
```swift
// 將這行取消註解
import FirebaseRemoteConfig
```

#### 在 `FeatureFlagManager.swift` 中：
```swift
// 將這行取消註解
import FirebaseRemoteConfig
```

### 3. 替換 FeatureFlagManager 實作

用以下完整的 Firebase Remote Config 實作替換現有的 UserDefaults 實作：

```swift
import Foundation
import FirebaseRemoteConfig
import Combine

/// 集中管理應用程式的 Feature Flags
/// 使用 Firebase Remote Config 實現動態功能開關
class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()
    
    private var remoteConfig: RemoteConfig
    
    // MARK: - Feature Flag Keys
    private enum FeatureKeys: String {
        case garminIntegration = "garmin_integration_enabled"
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
        
        // 設定更新頻率
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0 // 開發環境立即更新
        #else
        settings.minimumFetchInterval = 3600 // 正式環境 1 小時更新一次
        #endif
        
        remoteConfig.configSettings = settings
        
        Logger.firebase("FeatureFlagManager 初始化完成", level: .info, labels: [
            "module": "FeatureFlagManager",
            "action": "setup"
        ])
    }
    
    // MARK: - Fetch Remote Config
    private func fetchRemoteConfig() {
        remoteConfig.fetch { [weak self] status, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.firebase("Remote Config 獲取失敗", level: .error, labels: [
                    "module": "FeatureFlagManager",
                    "error": error.localizedDescription
                ])
                self.updateFeatureFlags()
                return
            }
            
            self.remoteConfig.activate { [weak self] changed, error in
                DispatchQueue.main.async {
                    self?.updateFeatureFlags()
                }
            }
        }
    }
    
    // MARK: - Update Feature Flags
    private func updateFeatureFlags() {
        let newGarminEnabled = remoteConfig.configValue(forKey: FeatureKeys.garminIntegration.rawValue).boolValue
        
        if newGarminEnabled != isGarminEnabled {
            isGarminEnabled = newGarminEnabled
            
            NotificationCenter.default.post(
                name: NSNotification.Name("FeatureFlagDidChange"),
                object: nil,
                userInfo: ["garmin_enabled": isGarminEnabled]
            )
        }
    }
    
    // MARK: - Public Methods
    func refreshConfig() async {
        await withCheckedContinuation { continuation in
            remoteConfig.fetch { [weak self] status, error in
                if error == nil {
                    self?.remoteConfig.activate { [weak self] _, _ in
                        DispatchQueue.main.async {
                            self?.updateFeatureFlags()
                        }
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Convenience Properties
extension FeatureFlagManager {
    var isGarminIntegrationAvailable: Bool {
        guard isGarminEnabled else { return false }
        return GarminManager.shared.isClientIDValid
    }
}
```

### 4. 在 Firebase Console 中設定

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 選擇您的專案
3. 左側選單選擇 **Remote Config**
4. 點擊 **建立設定**
5. 新增參數：
   - **參數名稱**: `garmin_integration_enabled`
   - **資料類型**: Boolean
   - **預設值**: `false`
   - **描述**: 控制 Garmin 整合功能的開關

### 5. 測試升級

#### 開發環境測試
```swift
// 在 Firebase Console 中將 garmin_integration_enabled 設為 true
// 重啟 App 或等待自動更新
// 驗證 Garmin 選項出現在 UI 中
```

#### 日誌驗證
檢查以下日誌確認正常運作：
```
✅ FeatureFlagManager 初始化完成
✅ Remote Config 獲取成功
✅ Feature Flag 更新
```

## 🚨 回滾計劃

如果升級過程中遇到問題：

### 1. 快速回滾到 UserDefaults 版本
```swift
// 註解掉 Firebase Remote Config import
// import FirebaseRemoteConfig

// 使用備份的 UserDefaults 實作
```

### 2. 檢查常見問題
- [ ] Firebase SDK 版本相容性
- [ ] 網路連接問題
- [ ] Firebase 專案設定
- [ ] Remote Config 權限

## 📊 升級後驗證清單

- [ ] App 正常啟動，無崩潰
- [ ] FeatureFlagManager 初始化成功
- [ ] Remote Config 能正常獲取
- [ ] Feature Flag 狀態正確
- [ ] UI 響應 Feature Flag 變化
- [ ] 日誌記錄完整

## 🎯 預期改善

### 升級前 (UserDefaults)
- ❌ 需要發版才能改變 Feature Flag
- ❌ 無法做 A/B 測試
- ❌ 無條件式控制

### 升級後 (Firebase Remote Config)
- ✅ 即時控制，無需發版
- ✅ 支援 A/B 測試
- ✅ 條件式開放（版本、地區、用戶群組）
- ✅ 詳細的使用分析

---

**預估升級時間**: 15-30 分鐘  
**風險等級**: 🟡 中等（有回滾計劃）  
**建議時機**: 非高峰時段進行