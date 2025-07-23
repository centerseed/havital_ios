# Feature Flag Debug 指令

## 🔍 排查 Feature Flag 問題

### 在 App 中執行以下指令

#### 1. 檢查當前狀態
```swift
// 在任何 ViewController 或適當位置執行
#if DEBUG
FeatureFlagManager.shared.debugPrintAllFlags()
#endif
```

#### 2. 手動啟用 Garmin 功能
```swift
#if DEBUG
FeatureFlagManager.shared.enableGarminForTesting()
print("✅ Garmin 功能已啟用")
FeatureFlagManager.shared.debugPrintAllFlags()
#endif
```

#### 3. 檢查各個組件狀態
```swift
#if DEBUG
print("=== Feature Flag 詳細檢查 ===")
print("FeatureFlagManager.shared.isGarminEnabled: \(FeatureFlagManager.shared.isGarminEnabled)")
print("GarminManager.shared.isClientIDValid: \(GarminManager.shared.isClientIDValid)")
print("FeatureFlagManager.shared.isGarminIntegrationAvailable: \(FeatureFlagManager.shared.isGarminIntegrationAvailable)")
print("APIConfig.isGarminEnabled: \(APIConfig.isGarminEnabled)")
print("UserPreferenceManager.shared.dataSourcePreference: \(UserPreferenceManager.shared.dataSourcePreference)")
#endif
```

#### 4. 重置並重新設定
```swift
#if DEBUG
FeatureFlagManager.shared.resetAllFlags()
FeatureFlagManager.shared.enableGarminForTesting()
#endif
```

## 🚨 常見問題排查

### 問題 1: Feature Flag 設為 true 但 UI 沒有顯示

**可能原因:**
1. `GarminManager.shared.isClientIDValid` 返回 false
2. UI 沒有監聽 Feature Flag 變化
3. 值沒有正確更新到 `@Published` 屬性

**排查步驟:**
```swift
// 步驟 1: 檢查 Client ID
print("Client ID: \(GarminManager.shared.clientID)")
print("Client ID Valid: \(GarminManager.shared.isClientIDValid)")

// 步驟 2: 檢查 Feature Flag 值
print("UserDefaults value: \(UserDefaults.standard.bool(forKey: "garmin_integration_enabled"))")
print("Published value: \(FeatureFlagManager.shared.isGarminEnabled)")

// 步驟 3: 檢查最終結果
print("Integration Available: \(FeatureFlagManager.shared.isGarminIntegrationAvailable)")
```

### 問題 2: 正式環境中 Client ID 無效

**解決方案:**
```swift
// 在開發環境中臨時使用 Dev Client ID 測試
#if DEBUG
// 確認當前使用的是哪個 Client ID
print("Current Client ID: \(GarminManager.shared.clientID)")
print("Is Dev Build: \(true)")
#else
print("Current Client ID: \(GarminManager.shared.clientID)")  
print("Is Prod Build: \(true)")
#endif
```

## 📱 在 App 中快速測試

### 方法 1: 在 AppDelegate 或 SceneDelegate 中添加
```swift
#if DEBUG
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    FeatureFlagManager.shared.debugPrintAllFlags()
    FeatureFlagManager.shared.enableGarminForTesting()
    print("🔥 Feature Flag 已強制啟用")
}
#endif
```

### 方法 2: 在 ContentView 的 onAppear 中添加
```swift
.onAppear {
    #if DEBUG
    print("=== DEBUG: 檢查 Feature Flag ===")
    FeatureFlagManager.shared.debugPrintAllFlags()
    #endif
}
```

### 方法 3: 添加手勢觸發 Debug
```swift
// 在某個 View 中添加
.onTapGesture(count: 5) {
    #if DEBUG
    print("🚧 DEBUG: 5 次點擊觸發")
    FeatureFlagManager.shared.enableGarminForTesting()
    #endif
}
```

## 📊 預期的正常日誌輸出

當 Feature Flag 正常工作時，你應該看到：

```
✅ FeatureFlagManager 初始化完成 (UserDefaults 模式)
✅ Feature Flag 讀取 
✅ 準備設定 Feature Flag
✅ UserDefaults 已更新
✅ Feature Flag 值已變更
✅ 檢查 Garmin 整合可用性
✅ 手動設定 Feature Flag 完成
```

## 🔧 緊急修復方案

如果 Feature Flag 完全不工作：

```swift
// 暫時繞過 Feature Flag，直接返回 true
extension FeatureFlagManager {
    var isGarminIntegrationAvailable: Bool {
        #if DEBUG
        return true  // 開發環境強制啟用
        #else
        return isGarminEnabled && GarminManager.shared.isClientIDValid
        #endif
    }
}
```

---

**使用建議**: 先執行 `debugPrintAllFlags()` 查看完整狀態，再根據輸出判斷問題所在。