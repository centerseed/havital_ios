# Garmin 生產環境部署檢查清單

## 📋 部署前準備

### 1. Garmin 開發者審核狀態
- [ ] **Garmin 正式版 App 審核通過**
- [ ] **取得正式環境 Garmin Client ID**
- [ ] **取得正式環境 Garmin Client Secret**

### 2. APIKeys.plist 設定
- [x] `GarminClientID_Dev`: `bde6d189-73a1-4291-a065-0acaf0d56525` (已設定)
- [ ] `GarminClientID_Prod`: `待設定` (審核通過後填入)

### 3. 後端 API 設定
- [ ] **正式環境後端部署完成**
  - `/connect/garmin/*` 端點
  - `/connect/garmin/redirect` 回調處理
  - Garmin webhook 處理
- [ ] **環境變數設定**
  ```bash
  GARMIN_CLIENT_SECRET_PROD=<正式環境 Client Secret>
  GARMIN_REDIRECT_URI_PROD=https://api-service-163961347598.asia-east1.run.app/connect/garmin/redirect
  ```

## 🚀 分階段部署策略

### 階段 1: 基礎設施部署 (Garmin App 審核期間)
```bash
# 當前狀態：可執行
✅ 後端 API 部署
✅ 前端代碼準備 (Feature Flag 關閉)
⚠️ GarminClientID_Prod 留空
```

**部署指令：**
```bash
# 確認 Feature Flag 狀態
# 正式環境中 APIConfig.isGarminEnabled 將返回 false
# 因為 GarminClientID_Prod 為空
```

### 階段 2: 內測階段 (獲得 Client ID 後)
```bash
# 執行條件：Garmin App 審核通過
1. 更新 APIKeys.plist 中的 GarminClientID_Prod
2. 後端設定正式環境 Client Secret
3. 透過後端 API 或管理後台開啟特定用戶的 Garmin 功能
```

**開啟內測的方法：**
```swift
// 方法 1: 透過後端 API 控制
UserDefaults.standard.set(true, forKey: "garmin_feature_enabled")

// 方法 2: 透過 Firebase Remote Config (未來可考慮)
// 方法 3: 透過後端用戶白名單機制
```

### 階段 3: 全面開放
```bash
# 內測驗證無問題後
1. 透過後端 API 或 Remote Config 全面開啟 Garmin 功能
2. 更新 App Store 描述，說明支援 Garmin
```

## 🔧 技術實作檢查清單

### 已完成項目 ✅
- [x] **環境區分機制**
  - `GarminManager.swift:35-39` - 根據 DEBUG/PROD 讀取不同的 Client ID
  - `GarminManager.swift:56-60` - 根據環境設定不同的 redirectURI
- [x] **Feature Flag 機制**
  - `APIConfig.swift:27-37` - 完整的功能開關邏輯
  - `DataSourceSelectionView.swift:53` - UI 層級的功能控制
- [x] **Client ID 有效性檢查**
  - `GarminManager.swift:68-70` - isClientIDValid 方法
  - `GarminManager.swift:118-124` - 連接前的驗證
- [x] **錯誤處理機制**
  - 當 Client ID 無效時顯示友善錯誤訊息
  - 日誌記錄便於問題追蹤

### 待確認項目 ⏳
- [ ] **後端 Webhook 配置** - 需要後端團隊確認
- [ ] **數據同步邏輯** - 需要測試 Garmin 數據拉取
- [ ] **用戶數據遷移** - 已有用戶從 Apple Health 切換到 Garmin 的邏輯

## 🚨 緊急應變機制

### 快速關閉 Garmin 功能
```swift
// 方法 1: 透過 UserDefaults (立即生效)
UserDefaults.standard.set(false, forKey: "garmin_feature_enabled")

// 方法 2: 清空 Client ID (需要 App 更新)
// 將 APIKeys.plist 中的 GarminClientID_Prod 設為空字串

// 方法 3: 後端關閉 API (最快速)
// 後端返回 503 Service Unavailable
```

### 問題排查
1. **檢查日誌關鍵字**
   - `GarminManager: Client ID 無效`
   - `Garmin 功能暫時不可用`
   - `GarminManager: 成功讀取 GarminClientID_Prod`

2. **檢查 Feature Flag 狀態**
   ```swift
   print("Garmin Feature Enabled: \(APIConfig.isGarminEnabled)")
   print("Client ID Valid: \(GarminManager.shared.isClientIDValid)")
   ```

## 📱 用戶體驗考量

### 正式環境 Client ID 未設定時
- ✅ **Onboarding 流程**：只顯示 Apple Health 選項
- ✅ **設定頁面**：不顯示 Garmin 相關設定
- ✅ **錯誤訊息**：友善提示「功能暫時不可用」

### Client ID 設定後
- ✅ **功能完全可用**：所有 Garmin 相關功能正常運作
- ✅ **數據源切換**：完整的 Apple Health ↔ Garmin 切換邏輯

## 🎯 成功指標

### 技術指標
- [ ] 開發環境 Garmin 連接成功率 > 95%
- [ ] 正式環境 OAuth 流程無錯誤
- [ ] 數據同步延遲 < 5 分鐘
- [ ] 無數據丟失或重複

### 用戶指標
- [ ] Garmin 用戶連接成功率 > 90%
- [ ] 數據源切換成功率 > 95%
- [ ] 相關客服問題 < 5%

## 📞 聯絡資訊

- **後端團隊**：確認 API 部署狀態
- **DevOps 團隊**：環境變數設定
- **QA 團隊**：功能測試驗證
- **客服團隊**：用戶問題處理準備

---

**最後更新**：2025-07-23  
**負責人**：開發團隊  
**審核狀態**：待 Garmin 官方審核通過