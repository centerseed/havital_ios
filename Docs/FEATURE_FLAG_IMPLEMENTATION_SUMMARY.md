# Feature Flag 實作完成摘要

## 🎯 實作目標達成

1. ✅ **以 Garmin branch 為主**，使用 feature flag 控制功能顯示
2. ✅ **Feature flag 關閉時**，onboarding 和 user profile 中不顯示 Garmin 選項
3. ✅ **預設 Apple HealthKit**，當 Garmin 功能未啟用時自動選擇
4. ✅ **拿到正式 Client ID 後**，可透過 feature flag 開啟功能
5. ✅ **穩定後可移除** feature flag 的架構設計

## 🔧 技術實作詳情

### 核心架構

```
FeatureFlagManager (UserDefaults 模式)
├── 目前實作：基於 UserDefaults 的臨時方案
├── 未來升級：Firebase Remote Config 整合
└── 功能：動態控制 Garmin 功能顯示

UserPreferenceManager
├── 自動監聽 Feature Flag 變化
├── Garmin 關閉 → 自動切換到 Apple Health
└── 確保數據源一致性

UI 層級控制
├── DataSourceSelectionView：動態顯示選項
├── UserProfileView：條件式 Garmin 設定
└── 所有相關 UI 響應 Feature Flag
```

### 已修改的檔案

| 檔案 | 修改內容 |
|------|----------|
| `FeatureFlagManager.swift` | **新建** - 中央化 Feature Flag 管理 |
| `APIConfig.swift` | 使用 FeatureFlagManager 替代硬編碼邏輯 |
| `APIKeys.plist` | 區分 Dev/Prod Garmin Client ID |
| `GarminManager.swift` | 環境區分 + Client ID 有效性檢查 |
| `HavitalApp.swift` | 注入 FeatureFlagManager 環境物件 |
| `DataSourceSelectionView.swift` | Feature Flag 控制 + 自動選擇邏輯 |
| `UserProfileView.swift` | 條件式顯示 Garmin 選項 |
| `UserPreferenceManager.swift` | 監聽 Feature Flag + 自動調整數據源 |

## 🚦 當前狀態

### 開發環境
```bash
✅ Feature Flag 預設關閉 (false)
✅ 有 Dev Client ID，功能可測試
✅ UI 自動隱藏 Garmin 選項
✅ 預設使用 Apple Health
```

### 正式環境
```bash
✅ Feature Flag 預設關閉 (false)
❌ Prod Client ID 為空 (符合預期)
✅ UI 完全隱藏 Garmin 功能
✅ 100% Apple Health 用戶體驗
```

## 🔄 升級到 Firebase Remote Config 步驟

### 步驟 1: 在 Xcode 中添加依賴
1. 打開 Xcode 專案 `Havital.xcodeproj`
2. 選擇專案根目錄 → Package Dependencies
3. 點擊 "+" → 輸入 Firebase SDK URL: `https://github.com/firebase/firebase-ios-sdk`
4. 選擇 `FirebaseRemoteConfig` 模組
5. 加入到 Target

### 步驟 2: 啟用程式碼
```swift
// 在 HavitalApp.swift 中取消註解
import FirebaseRemoteConfig

// 在 FeatureFlagManager.swift 中取消註解
import FirebaseRemoteConfig
```

### 步驟 3: 替換實作
將 `FeatureFlagManager.swift` 中的 UserDefaults 實作替換為完整的 Firebase Remote Config 實作。

### 步驟 4: Firebase Console 設定
1. 在 Firebase Console 中啟用 Remote Config
2. 設定 `garmin_integration_enabled` 參數
3. 預設值設為 `false`

## 📱 使用指南

### 開發環境測試
```swift
// 啟用 Garmin 功能（開發專用）
#if DEBUG
FeatureFlagManager.shared.enableGarminForTesting()
#endif

// 查看當前狀態
FeatureFlagManager.shared.debugPrintAllFlags()

// 重置所有設定
FeatureFlagManager.shared.resetAllFlags()
```

### 正式環境控制
```swift
// 手動啟用（透過後端 API 或管理介面）
FeatureFlagManager.shared.setFeatureFlag("garmin_integration_enabled", value: true)

// 檢查狀態
print("Garmin 可用: \(FeatureFlagManager.shared.isGarminIntegrationAvailable)")
```

## 🎚️ 部署策略

### 當前階段：安全部署 ✅
- **現狀**: Feature Flag 關閉，Prod Client ID 空白
- **結果**: 用戶完全看不到 Garmin 功能
- **風險**: 零風險，可立即部署

### 階段 1：獲得正式 Client ID
```bash
1. 更新 APIKeys.plist 中的 GarminClientID_Prod
2. 後端設定正式環境 Client Secret
3. 準備就緒，但 Feature Flag 仍關閉
```

### 階段 2：內測開放
```bash
# 透過程式碼或後端 API 開啟特定用戶
UserDefaults.standard.set(true, forKey: "garmin_integration_enabled")

# 或透過 Firebase Remote Config 條件設定
條件: App version >= "x.x.x"
或: 用戶群組 = "Beta Testers"
值: true
```

### 階段 3：全面開放
```bash
# Firebase Remote Config 全域設定
garmin_integration_enabled = true

# 或移除 Feature Flag（穩定後）
直接啟用功能，移除相關判斷邏輯
```

## 🛠 Debug 工具

### 即時檢查狀態
```swift
print("=== Feature Flag 狀態 ===")
print("Garmin Enabled: \(FeatureFlagManager.shared.isGarminEnabled)")
print("Client ID Valid: \(GarminManager.shared.isClientIDValid)")
print("Integration Available: \(FeatureFlagManager.shared.isGarminIntegrationAvailable)")
print("Current Data Source: \(UserPreferenceManager.shared.dataSourcePreference)")
```

### 日誌關鍵字
監控以下日誌來確認功能正常：
- `FeatureFlagManager 初始化完成`
- `Feature Flag 更新`
- `Garmin 功能關閉，自動選擇 Apple Health`
- `自動切換數據源到 Apple Health`

## 🏆 成功指標

### 技術指標
- [x] 編譯成功，無錯誤
- [x] Feature Flag 動態響應
- [x] UI 狀態正確切換
- [x] 數據源自動調整
- [x] 日誌完整記錄

### 用戶體驗指標
- [x] Feature Flag 關閉時完全隱藏 Garmin
- [x] 預設選擇 Apple Health
- [x] 切換過程無感知
- [x] 錯誤處理友善

## 📞 後續支援

### 即時啟用 Garmin 功能
```swift
// 當拿到正式 Client ID 後，立即啟用
FeatureFlagManager.shared.setFeatureFlag("garmin_integration_enabled", value: true)
```

### 緊急關閉功能
```swift
// 如有問題，立即關閉
FeatureFlagManager.shared.setFeatureFlag("garmin_integration_enabled", value: false)
```

---

**實作狀態**: ✅ 完成並可部署  
**編譯狀態**: ✅ BUILD SUCCEEDED  
**風險評估**: 🟢 零風險，完全向後相容  
**準備程度**: 🚀 隨時可部署到 Production