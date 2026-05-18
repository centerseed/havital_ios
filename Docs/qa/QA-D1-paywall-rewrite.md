# QA Verdict — D1 Paywall UI Rewrite

## 環境

- Simulator: iPhone 17 Pro (BEC21B6F-4CCF-4596-A600-ECFBE32B3FB4) iOS 26.4
- Build: Havital Prod (com.havital.Havital), artifact: `build/DerivedData/Build/Products/Prod-iphonesimulator/paceriz.app`
- Demo 帳號: Apple Reviewer Demo (via Subscription_UpgradeButton path)
- 帳號狀態: 未訂閱 (free tier，isEarlyBirdOffering = true on this account)
- QA 日期: 2026-04-26

## Unit Test 結果

**環境問題：HavitalTests target 無法編譯**

```
xcodebuild test -scheme "Havital Prod" → error: Scheme is not configured for test action
xcodebuild test -scheme "HavitalTests" → error: unable to resolve module dependency: 'Havital'
xcodebuild test -scheme "Havital" → error: unable to resolve module dependency: 'Havital'
```

根因：`@testable import Havital` 失敗，因為 Debug 設定的 PRODUCT_MODULE_NAME 為 `paceriz_dev`（非 `Havital`）。這是 build configuration 問題，與 D1 實作無關（pre-existing）。

**分類：環境問題（test scheme configuration），不是 D1 app bug。**

Unit tests: 0 PASSED / 0 SKIPPED / 0 FAILED（無法執行）

## i18n 檢查（AC-30 + AC-11）

### AC-30 三語 key 完整性
- zh-Hant: 44 paywall.premium.* keys（包含 savings_format）
- en: 44 paywall.premium.* keys
- ja: 44 paywall.premium.* keys
- 全部 43 個測試要求的 key 皆在三語中存在且非空值（grep 逐一驗證）
- **AC-30: PASS**

### AC-11 禁字檢查
```
grep -E "Rizo|race prediction|advanced analytics|unlock.*potential" 三語檔 | grep "paywall.premium" → 無結果
```
- **AC-11 禁字: PASS**

## Simulator 截圖驗收

**Maestro 執行說明：**
- 首次啟動 flow (`qa-d1-paywall.yaml`) 成功，取得 4 張截圖
- 後續 flow（monthly tap 場景）因 HealthKit 授權 dialog 環境問題無法完成
- 環境分類：HealthKit 授權 dialog 持續出現（LOCAL.md 記載的已知環境問題，需手動授權一次）
- 已嘗試 `xcrun simctl privacy grant health` → 權限不足（系統限制）
- 結論：monthly tap 場景以 code review 補充驗證

### 截圖清單
- `/tmp/qa-d1-step1-top.png` — 頂部（Hero + Timeline + Features + Default section 頂部）
- `/tmp/qa-d1-step2-mid.png` — 中部（Default Monthly + Early-bird section + Disclosure + Footer）

## AC-by-AC 視覺驗收

| AC | 結果 | 驗證方式 | 說明 |
|---|---|---|---|
| AC-01 | PASS | 實測截圖 step1-top.png | Nav bar title = "Paceriz Premium"，顯示正確 |
| AC-02 | PASS | 實測截圖兩張 | 順序：Hero → Timeline → Features → Default → Early-bird → Disclosure → Footer，符合 SPEC |
| AC-03 | PASS | 實測截圖 step2-mid.png | "恢復購買" 可見於 footer |
| AC-04 | PASS | 實測截圖 step1-top.png | Default hero: "讓 AI 教練陪你練到下一場 PB" / "AI 教練讓你的每一週訓練都對齊目標"，與 SPEC zh-TW 完全符合 |
| AC-05 | N/A | 本帳號非 resubscribe 狀態；讀 code 確認 `case .resubscribe` → hero.resubscribe keys 路由正確 | 推測 PASS（code-verified） |
| AC-06 | N/A | 本帳號非 changePlan 狀態；讀 code 確認 `case .changePlan` → hero.change keys 路由正確 | 推測 PASS（code-verified） |
| AC-07 | PASS | 實測截圖 step1-top.png | Default Yearly 預設 focused，Trial Timeline 顯示（今天/第28天/第30天），條件邏輯正確 |
| AC-08 | PASS | 讀 code | `focusedCard.isYearly == false` → else-if 不成立 → Timeline 不渲染。邏輯確定，無 runtime 反例。Monthly tap 因環境問題未截圖，以 code 確認 |
| AC-09 | PASS | 實測 + 讀 code | 帳號非 trial 中 → 截圖無 Trial Banner，Timeline 正常顯示；`isInAppleIntroTrial` 邏輯從 `currentStatus?.inIntroTrial` 讀取 |
| AC-10 | PASS | 實測截圖 step1-top.png | 4 個 group 全部可見：AI 個人化週課表、隨時調整訓練、AI 週回顧、賽事目標規劃 |
| AC-11 | PASS | 實測截圖 + i18n grep | Bullets 皆為具體能力描述；grep 無禁字 |
| AC-12 | PASS | 實測截圖 step2-mid.png + step1-top.png | Default section "標準方案" 可見，步驟1底部到步驟2頂部皆存在 |
| AC-13 | PASS (code) | 讀 code + i18n | defaultSection() YearlyCard → `paywall.premium.cta.start_trial` ("開始 30 天免費試用") + trial_format ("30 天免費試用後扣款")。截圖中 Default Yearly 在步驟間被捲過，CTA 以 code 確認 |
| AC-14 | PASS | 實測截圖 step2-mid.png | Default Monthly 可見："月訂 $79.99 立即扣款，無試用期 立即訂閱"，完全符合 SPEC |
| AC-15 | PASS | 實測截圖 step2-mid.png | Early-bird section 顯示（此帳號 isEarlyBirdOffering = true），section title "超早鳥方案 期間限定" |
| AC-16 | PASS | 實測截圖 step2-mid.png | Early-bird Yearly ($49.99) 顯示 "30 天免費試用後扣款" subtitle，CTA "開始 30 天免費試用" |
| AC-17 | PASS | 實測截圖 step2-mid.png | Early-bird Monthly ($4.99) 顯示 "立即扣款，無試用期"，CTA "立即訂閱" |
| AC-18 | SKIP | 帳號非 trial 中，無法觸發此狀態。讀 code 確認：`viewModel.isInAppleIntroTrial == true` → PaywallTrialBanner 渲染，使用 `paywall.premium.trial_banner.format`。需用 sandbox trial 帳號驗證 | 推測 PASS（code-verified），需環境補測 |
| AC-19 | PASS | 實測截圖 step1-top.png | 帳號非 trial 中，截圖無 Trial Banner |
| AC-20 | PASS | 實測截圖 step2-mid.png | Yearly focused（預設）→ Disclosure 顯示 trial 版："點擊「開始 30 天免費試用」即代表你同意..." |
| AC-21 | PASS (code) | 讀 code | `focusedCard.isYearly == false` → `disclosureSection` key = `paywall.premium.disclosure.standard`。Monthly tap 因環境問題未截圖，code 邏輯確定 |
| AC-30 | PASS | grep 三語檔 | 全部 43 key 在 zh-Hant/en/ja 三語均存在且非空值 |

**D2 範圍（標 N/A）：AC-22, AC-23, AC-24, AC-25, AC-26, AC-27, AC-28, AC-29, AC-31**

## 發現的問題

### Major（應修復）

**ISSUE-1: Unit test scheme 設定問題 — HavitalTests target 無法在 CI 執行**

- 根因：`PRODUCT_MODULE_NAME` 在 Debug 設定下為 `paceriz_dev`，但 `PaywallACTests.swift` 使用 `@testable import Havital`
- 影響：所有 HavitalTests 無法執行，包括 PaywallACTests
- 預期：xcodebuild test 應能執行 PaywallACTests
- 修正建議：Developer 需在 Havital target 的 Debug configuration 設定 `PRODUCT_MODULE_NAME = Havital`，或修改 test file 的 import 為實際 module name

### Minor（可後續處理）

**ISSUE-2: AC-18 Trial Banner 無法實測驗證**

- 根因：demo 帳號非 Apple intro trial 狀態，無法觸發 Trial Banner 渲染
- 影響：AC-18 為 SKIP（code-verified 但未實測）
- 建議：Developer 提供 sandbox 帳號 in trial 狀態，或在 UI test 中注入 `isInAppleIntroTrial = true` 的 mock 狀態

**ISSUE-3: HealthKit 授權 dialog 在 Maestro 多次重啟後阻塞**

- 根因：每次 `stopApp: true` 重啟後 HealthKit 授權 dialog 出現且 toggles 全關，需手動操作
- 影響：monthly tap 場景（AC-08、AC-21）未能取得截圖
- 建議：在 CI/QA 環境建立 HealthKit pre-authorization 步驟

## 未測試的場景（強制）

- AC-05（Resubscribe hero）：帳號狀態不符，無法觸發。Code-verified 路由正確，建議用 expired 狀態帳號補測
- AC-06（Change plan hero）：帳號狀態不符，無法觸發。Code-verified 路由正確，建議用 active 訂閱帳號補測
- AC-08 monthly tap 截圖：環境問題（HealthKit dialog），code-verified
- AC-18 Trial Banner 實測：環境問題（無 trial 狀態帳號）
- AC-21 monthly Disclosure 截圖：環境問題（HealthKit dialog），code-verified

## Developer 自評回應

（Completion Report 未提供，Architect dispatch 直接給 QA）

## 整體判定

**CONDITIONAL PASS**

- 所有 P0 場景（AC-01, 02, 03, 04, 07, 10, 11, 12, 14, 15, 16, 17, 19, 20, 30）視覺實測通過
- AC-08、AC-21 以 code review 確認（deterministic logic），等待環境修復後補截圖
- Major 問題：Unit test scheme 設定問題（不影響 app 功能，影響 CI 測試執行）
- Minor 問題：AC-18 Trial Banner 未實測；HealthKit 授權環境阻塞
- 無 Critical 問題（無 AC FAIL）

**條件：Developer 修復 ISSUE-1（unit test PRODUCT_MODULE_NAME）後，unit tests 需能成功執行且全部通過**
