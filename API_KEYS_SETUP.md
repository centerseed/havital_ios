# API 金鑰設定指南

## 安全性警告 ⚠️

**重要**：API 金鑰是敏感資訊，請勿將真實的金鑰提交到版本控制系統中！

## 設定步驟

### 1. 複製模板檔案

```bash
cp Havital/Resources/APIKeys-template.plist Havital/Resources/APIKeys.plist
```

### 2. 獲取必要的 API 金鑰

#### PromptDash API Key
- 前往 [PromptDash](https://promptdash.ai) 註冊帳號
- 在設定中生成 API 金鑰

#### Garmin Connect API
- 前往 [Garmin Developer Portal](https://developer.garmin.com/)
- 註冊開發者帳號並創建應用程式
- 獲取 Client ID

#### Strava API
- 前往 [Strava API Settings](https://www.strava.com/settings/api)
- 創建新的應用程式
- 獲取 Client ID 和 Client Secret

### 3. 配置金鑰

編輯 `Havital/Resources/APIKeys.plist` 檔案，將占位符替換為真實的金鑰：

```xml
<key>PromptDashAPIKey</key>
<string>你的真實 PromptDash API 金鑰</string>

<key>GarminClientID_Dev</key>
<string>你的 Garmin 開發環境 Client ID</string>

<key>GarminClientID_Prod</key>
<string>你的 Garmin 生產環境 Client ID</string>

<key>StravaClientID_Dev</key>
<string>你的 Strava 開發環境 Client ID</string>

<key>StravaClientSecret_Dev</key>
<string>你的 Strava 開發環境 Client Secret</string>

<key>StravaClientID_Prod</key>
<string>你的 Strava 生產環境 Client ID</string>

<key>StravaClientSecret_Prod</key>
<string>你的 Strava 生產環境 Client Secret</string>
```

### 4. 驗證設定

重新啟動 Xcode 並清理建置快取：

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
xcodebuild clean
```

## 安全注意事項

- ✅ `APIKeys.plist` 已加入 `.gitignore`
- ✅ 使用 `APIKeys-template.plist` 作為模板
- ❌ 不要將真實金鑰提交到 git
- ❌ 不要分享金鑰給未授權的人員

## 疑難排解

如果應用程式無法正常工作，請檢查：

1. 金鑰是否正確配置
2. API 服務是否正常運行
3. 網路連線是否正常
4. Xcode 建置快取是否已清理

## 聯絡支援

如果遇到問題，請聯絡開發團隊，但請勿在公開場合分享你的 API 金鑰。