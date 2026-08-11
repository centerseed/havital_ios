# iOS 發版 Runbook（Paceriz / Havital）

一鍵出版流程。fastlane 設定在 `fastlane/`。

## 前置（一次性，已備妥）
- fastlane（rbenv）已裝。
- App Store Connect API 團隊金鑰 `~/.appstoreconnect/AuthKey_NG4N2CCQY5.p8`。
- `fastlane/.env.default`（**不進 git**）已含 `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_FILEPATH`。
- 本機 Apple Distribution 憑證。provisioning profile 由 `-allowProvisioningUpdates` 自動處理。

## 每次發版（iOS = 自動直接上傳 + 送審）
0. **只能從 main 發版**：feature branch 上的改動必須先過 `/judge ios <branch>` merge 回 main 才能出貨（root `scripts/hooks/merge_gate.py` 硬擋非 main 的 `fastlane ios release`）。
1. **定版號**：Xcode 改 `MARKETING_VERSION`（目前 pbxproj = 1.4.11）。build 號**免手動**，lane 自動取 App Store/TestFlight 最大 build + 1。
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
- **App Store live = 1.4.11**（`READY_FOR_SALE`；1.4.12 為 `WAITING_FOR_REVIEW`）。
- **1.4.12 已於 2026-08-11 送審**（build **11**，`fastlane ios release` 全程成功：archive → 簽章 → 上傳 → 三語 release notes → 送審）。
  - git main: `fca4bb9b`。
  - 內容：T-0460（紀錄頁下拉刷新截斷已載入清單、分類分頁無法續載）、T-0463（onboarding Garmin 歷史匯入改走後端 `ensure-initial` guard）。
  - release notes：刷新後紀錄變少 / Garmin 首次綁定沒匯入歷史 / 修復錯誤。
- **1.4.11 於 2026-07-22 送審**（build **10**）。git main `7f14b437`（含 T-0280 課表編輯 DayType 補齊等）；
  release notes：Rizo 更快 / 調整 onboarding / 修復錯誤。
- `automatic_release=false` → 過審後仍需在 App Store Connect **手動按 Release**。
