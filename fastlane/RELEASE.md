# iOS 發版 Runbook（Paceriz / Havital）

一鍵出版流程。fastlane 設定在 `fastlane/`。

## 前置（一次性，已備妥）
- fastlane（rbenv）已裝。
- App Store Connect API 團隊金鑰 `~/.appstoreconnect/AuthKey_NG4N2CCQY5.p8`。
- `fastlane/.env.default`（**不進 git**）已含 `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_FILEPATH`。
- 本機 Apple Distribution 憑證。provisioning profile 由 `-allowProvisioningUpdates` 自動處理。

## 每次發版（iOS = 自動直接上傳 + 送審）
1. **定版號**：Xcode 改 `MARKETING_VERSION`（目前 pbxproj = 1.4.9）。build 號**免手動**，lane 自動取 App Store/TestFlight 最大 build + 1。
2. **確認 release notes**（唯一要人工過的關）：填 `fastlane/metadata/{zh-Hant,ja,en-US}/release_notes.txt` 三語文案並確認。
3. **出版**：
   ```bash
   cd apps/ios/Havital && fastlane ios release
   ```
   → archive → 簽章 → 上傳 App Store → 推 release notes → **送審**（`automatic_release=false`）。過審後在 App Store Connect 手動 Release。

## 其他 lane
- `fastlane ios build` — 只 build + 匯出 IPA 到 `build/ipa/`，開 Finder（想手動 Transporter 上傳時用）。
- `fastlane ios beta` — build 後直接上 TestFlight。
- `fastlane ios info` — 唯讀列 App Store 現行版本。

## 現況
- **App Store live = 1.4.9**；**1.4.10 已於 2026-07-14 送審**（build 8，`WAITING_FOR_REVIEW`）。
- **真 archive 已跑過**（2026-07-14 首發 1.4.10）：`fastlane ios release` 全程成功 —— archive → 簽章
  （HavitalWatch + complication 共 10 個 bundle 由 API key 自動 provisioning，無需本機 profile）
  → 上傳 → 推三語 release notes → 送審。原本標記的「首次 archive 簽章可能卡住」風險**未發生**。
- `automatic_release=false` → 過審後仍需在 App Store Connect **手動按 Release**。
