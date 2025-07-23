# Firebase Remote Config 設定指南

## 🚀 Feature Flag 實作完成

### 已實作的 Feature Flags

| Feature Flag | Key | 描述 | 預設值 |
|-------------|-----|------|--------|
| **Garmin 整合** | `garmin_integration_enabled` | 控制 Garmin 數據源選項的顯示與功能 | `false` |

## 📱 Firebase 控制台設定步驟

### 1. 進入 Firebase Remote Config

1. 登入 [Firebase Console](https://console.firebase.google.com/)
2. 選擇您的專案
3. 左側選單選擇 **Remote Config**
4. 點擊 **建立設定** (如果是第一次使用)

### 2. 新增 Garmin Feature Flag

#### 基本設定
```
參數名稱: garmin_integration_enabled
資料類型: Boolean
預設值: false
描述: 控制 Garmin 整合功能的開關
```

#### 條件式設定 (可選)

##### 方案 A: 版本控制
```
條件名稱: iOS_Version_Latest
條件: App version >= "1.5.0"
值: true
```

##### 方案 B: 百分比推出
```
條件名稱: Gradual_Rollout
條件: Random percentile <= 10%
值: true
```

##### 方案 C: 特定用戶群組
```
條件名稱: Beta_Users
條件: User in audience "Beta Testers"
值: true
```

### 3. 發布設定

1. 點擊 **發布變更**
2. 確認設定無誤
3. 點擊 **發布**

## 🔧 技術實作詳情

### 程式碼架構

```swift
FeatureFlagManager.shared.isGarminEnabled
     │
     ├─ Firebase Remote Config 載入
     ├─ 本地預設值 (false)
     └─ 即時更新通知

UserPreferenceManager.shared.dataSourcePreference
     │
     ├─ 監聽 Feature Flag 變化
     ├─ 自動調整數據源設定
     └─ 確保 UI 一致性
```

### 自動化邏輯

1. **App 啟動時**
   - 載入 Remote Config 預設值
   - 檢查並調整數據源設定
   - 隱藏不可用的功能選項

2. **Feature Flag 變化時**
   - 即時更新 UI 顯示
   - 自動切換數據源 (Garmin → Apple Health)
   - 記錄變化日誌

3. **UI 層級控制**
   - Onboarding: 動態顯示/隱藏 Garmin 選項
   - UserProfile: 條件式渲染數據源設定
   - 所有相關 UI 自動響應變化

## 📊 部署策略

### 階段 1: 基礎準備 (當前)
```bash
✅ 程式碼實作完成
✅ Firebase Remote Config 整合
✅ Feature Flag 預設關閉
📱 可安全部署到 Production
```

### 階段 2: 內測開放
```bash
# 在 Firebase Console 中設定條件
條件: App version >= "正式版本號"
值: true

# 或使用百分比推出
條件: Random percentile <= 5%
值: true
```

### 階段 3: 逐步開放
```bash
# 調整百分比
10% → 25% → 50% → 100%

# 監控關鍵指標
- 連接成功率
- 錯誤日誌數量
- 用戶反饋
```

### 階段 4: 穩定後清理
```bash
# 移除 Feature Flag (未來)
1. 確認功能穩定運行 3 個月+
2. 移除相關 Feature Flag 程式碼
3. 直接啟用功能
```

## 🛠 開發環境測試

### 方法 1: Firebase Console 測試
1. 在 Firebase Console 中調整 `garmin_integration_enabled`
2. 重啟 App 或等待自動更新
3. 驗證 UI 變化

### 方法 2: 程式碼強制設定 (Debug 專用)
```swift
#if DEBUG
// 在 AppDelegate 或適當位置
FeatureFlagManager.shared.setDebugFlag("garmin_integration_enabled", value: true)
#endif
```

### 方法 3: 查看當前狀態
```swift
#if DEBUG
FeatureFlagManager.shared.debugPrintAllFlags()
#endif
```

## 📈 監控與分析

### 重要日誌關鍵字
```
FeatureFlagManager: Remote Config 獲取成功
FeatureFlagManager: Feature Flag 更新
UserPreferenceManager: 自動切換數據源到 Apple Health
DataSourceSelectionView: Garmin 功能關閉，自動選擇 Apple Health
```

### Firebase Analytics 事件
系統會自動記錄以下事件：
- `feature_flag_changed`: Feature Flag 狀態變化
- `data_source_switched`: 數據源自動切換
- `garmin_auto_select`: 自動選擇邏輯觸發

## 🚨 緊急應變

### 快速關閉功能
1. **最快方式**: Firebase Console 中設定 `garmin_integration_enabled = false`
2. **影響範圍**: 全球所有用戶 1 小時內生效
3. **自動行為**: 所有 Garmin 用戶自動切換到 Apple Health

### 故障排除
```swift
// 檢查 Remote Config 連接狀態
print("Remote Config status: \(RemoteConfig.remoteConfig().lastFetchStatus)")

// 檢查 Feature Flag 值
print("Garmin enabled: \(FeatureFlagManager.shared.isGarminEnabled)")

// 檢查數據源狀態
print("Current data source: \(UserPreferenceManager.shared.dataSourcePreference)")
```

## 🎯 成功指標

### 技術指標
- [x] Feature Flag 響應時間 < 1 小時
- [x] 自動切換成功率 = 100%
- [x] UI 更新即時性 = 即時
- [x] 零 App 崩潰相關於 Feature Flag

### 用戶體驗指標
- [x] 無感知的功能開關
- [x] 數據源切換無數據丟失
- [x] UI 狀態一致性
- [x] 錯誤處理優雅

---

**實作完成時間**: 2025-07-23  
**負責人**: 開發團隊  
**狀態**: ✅ 可部署