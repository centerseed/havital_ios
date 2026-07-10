# iOS 發版 Runbook（Paceriz / Havital）

一鍵出版流程。fastlane 設定在 `fastlane/`。

## 前置（一次性，已備妥）
- fastlane（rbenv）已裝。
- App Store Connect API 團隊金鑰 `~/.appstoreconnect/AuthKey_NG4N2CCQY5.p8`。
- `fastlane/.env.default`（**不進 git**）已含 `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_FILEPATH`。
- 本機 Apple Distribution 憑證。provisioning profile 由 `-allowProvisioningUpdates` 自動處理。

## 每次發版
1. **定版號**：Xcode 改 `MARKETING_VERSION`（目前 pbxproj = 1.4.9）。build 號**免手動**，lane 自動取 App Store/TestFlight 最大 build + 1。
2. **確認 release notes**（唯一要人工過的關）：三語文案（zh-Hant / ja / en）先確認，上傳時填進 App Store Connect。
3. **出版**：
   ```bash
   cd apps/ios/Havital && fastlane ios build
   ```
   → archive + 匯出 app-store IPA 到 `build/ipa/Havital.ipa` → 自動開 Finder → 用 **Transporter** 上傳。
4. App Store Connect 選這顆 build、填 release notes、送審。過審後手動 Release。

## 選配 lane（想更自動時）
- `fastlane ios beta` — build 後直接上 TestFlight。
- `fastlane ios release` — build 後上傳 App Store + 送審（`automatic_release=false`，過審後手動 release）。
- `fastlane ios info` — 唯讀列 App Store 現行版本。

## 現況 / 首次真 archive 要盯的風險
- **App Store live = 1.4.7**；本地 = 1.4.9 → iOS 落後 Android 兩版，第一發等於送出 1.4.8+1.4.9 的累積。
- 主 app 有 **HavitalWatch + complication** 三個 bundle 要簽；本機無 profile → 首次 archive 由 API key 自動產生，**第一次要盯它有沒有簽過**。
- 注意 pbxproj 有 `MARKETING_VERSION = 1.0`（watch/extension target）與 1.4.9 並存；上傳前確認 watch 版號不會被 App Store 擋。
- 本 pipeline 的 lane 語法已驗；**真 archive 尚未跑過**（等新功能完成後首發時驗證）。
