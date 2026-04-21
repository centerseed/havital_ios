---
doc_id: SPEC-iap-paywall-pricing-and-trial-protection
title: 功能規格：IAP 畫面定價、狀態同步與到期閘門
type: SPEC
ontology_entity: iap-subscription
status: draft
version: "0.2"
date: 2026-04-13
supersedes: null
---

# Feature Spec: IAP 畫面定價、狀態同步與到期閘門

## 背景與動機

目前 iOS 端已具備 IAP 相關架構與測試決策（Subscription Repository、RevenueCat 整合、Paywall 觸發），但缺少一份明確產品規格定義「畫面要顯示什麼」與「試用期轉訂閱的權益邏輯」。

本規格目標是補齊用戶最敏感的四件事：
- 付費頁資訊透明：月訂／年訂方案要清楚，且能看見原價與特價
- 權益公平：試用期中提前訂閱，不得吃掉用戶剩餘試用天數
- 購買後一致性：訂閱成功後，狀態更新需可預期且重進 App 不回退到錯誤狀態
- 到期保護：到期需有明確提醒，且 AI 受限功能不得繼續執行

## 目標用戶

- 試用中、正在評估是否付費的使用者
- 已進入付費牆頁面、需比較月訂與年訂方案的使用者
- 已完成購買但正在等待狀態同步的使用者
- 到期後仍嘗試使用 AI 功能的使用者
- 產品與客服團隊（需能用一致規則說明訂閱起算與到期）

## Spec 相容性

已比對既有 SPEC：
- `SPEC-maestro-ui-final-guardrail`（測試防線規格，非 IAP 產品行為規格）
- `SPEC-weekly-preview-ui`
- `SPEC-training-v2-edit-schedule-screen`

已比對相關 ADR：
- `ADR-001-subscription-service-architecture`
- `ADR-002-revenuecat-sdk-integration`
- `ADR-003-paywall-trigger-and-error-handling`
- `ADR-004-iap-ui-state-test-harness`

衝突結論：
- 與既有 SPEC 無直接衝突（現有 SPEC 未定義 IAP 產品行為）
- 與既有 ADR 一致（定價來源、狀態真相、paywall 觸發邏輯不變）
- 本版補齊 ADR 已定義但 SPEC 尚未具體化的驗收面：購買後同步、重進一致性、expired 提醒與 AI gate

## 需求

### P0（必須有）

#### 1) IAP 方案資訊顯示：月訂、年訂、原價、特價

- **描述**：IAP 畫面需同時展示月訂與年訂方案，並清楚呈現當前售價、原價與折扣資訊，讓用戶可以直接比較。
- **Acceptance Criteria**：
  - Given 用戶進入 IAP 畫面，When 可購買方案成功載入，Then 畫面至少顯示「月訂」與「年訂」兩個方案卡片。
  - Given 某方案有折扣資訊，When 方案卡片顯示，Then 必須同時顯示「原價」與「特價」且語意清楚可辨識。
  - Given 某方案無折扣資訊，When 方案卡片顯示，Then 只顯示單一價格，不得顯示虛假的原價/特價。
  - Given 畫面顯示價格，When 用戶查看方案，Then 價格幣別與週期單位（月／年）必須完整且不歧義。
  - Given 用戶在同一畫面比較月訂與年訂，When 查看兩方案，Then 兩者價格欄位資訊結構一致（皆可辨識原價/特價或無折扣狀態）。
  - Given 用戶停留在 Paywall，When 看到任一可購買方案 CTA，Then CTA 附近必須同時揭露「試用／優惠期間」與「優惠結束後的續訂價格 / 週期」。
  - Given 用戶停留在 Paywall，When 查看方案揭露文案，Then 必須明確寫出「自動續訂，除非於當前週期結束前取消」等值語意，不得只靠價格卡片暗示。

#### 2) 試用期權益保護：可隨時訂閱且不吃掉剩餘試用天數

- **描述**：試用期使用者可在任何時間點訂閱；若在試用期內完成訂閱，付費方案到期日必須從「試用期結束日」往後計算，而非從「購買當下」起算。
- **Acceptance Criteria**：
  - Given 用戶處於 trial_active，When 用戶於試用期間任一天完成訂閱，Then 訂閱生效時間為試用期結束後銜接開始。
  - Given 用戶在 trial_active 時購買月訂，When 系統計算到期日，Then 月訂到期日 = 試用期結束日 + 1 個月（依方案週期）。
  - Given 用戶在 trial_active 時購買年訂，When 系統計算到期日，Then 年訂到期日 = 試用期結束日 + 1 年（依方案週期）。
  - Given 用戶在 trial_active 完成訂閱，When 使用者回到訂閱資訊畫面，Then 必須能看到「試用結束日」與「付費期間起訖」不重疊的結果。
  - Given 用戶已離開 trial（例如 expired），When 之後才完成訂閱，Then 訂閱期間依正常購買時間起算。

#### 3) 購買成功後狀態同步與重進一致性

- **描述**：完成購買後，App 必須在可預期時間內同步為正確訂閱狀態，且使用者重新進入 App 後不得回到錯誤狀態（例如已購買卻顯示 free）。
- **Acceptance Criteria**：
  - Given 用戶不在 trial（例如 expired 或 none）且完成購買，When App 進行購買後狀態同步，Then 狀態最終必須收斂為 active。
  - Given 購買完成但後端尚未即時回傳 active，When 同步尚在進行，Then App 必須顯示「處理中」語意，不得誤判為購買失敗或未訂閱。
  - Given 用戶在購買完成後立即關閉並重開 App，When App 啟動與進前景刷新狀態，Then 顯示狀態必須與最新訂閱真相一致，不得卡在舊狀態。
  - Given 用戶在 trial_active 期間完成購買，When 重新進入 App，Then 仍可顯示 trial_active（屬預期），但必須同時有「已購買，將於試用結束後生效」的權益提示，不得讓使用者誤以為購買失敗。

#### 4) 到期提醒與 AI 受限功能閘門

- **描述**：訂閱到期後，App 需在進入時主動提醒，且 AI 受限功能需被明確阻擋並導向升級。
- **Acceptance Criteria**：
  - Given 用戶訂閱狀態為 expired，When 用戶開啟 App 或 App 回到前景，Then 必須顯示可感知的到期提醒（banner、sheet 或等效提醒元件）與升級入口。
  - Given 用戶訂閱狀態為 expired，When 用戶觸發 AI 受限功能（如 Rizo / AI coach / 需訂閱的生成動作），Then 功能不得繼續執行，且需顯示 paywall 或等效升級導引。
  - Given 用戶狀態為 active 或 trial_active，When 觸發同一批 AI 受限功能，Then 不得被 paywall 誤擋。
  - Given 用戶有 billing_issue 但訂閱仍有效，When 使用 AI 受限功能，Then 允許使用並以非阻斷方式提示帳務風險。

### P1（應該有）

#### 5) 權益說明文案清晰

- **描述**：在試用中購買時，畫面需明確說明「現在購買不影響剩餘試用天數」。
- **Acceptance Criteria**：
  - Given 用戶處於 trial_active 且停留在 IAP 畫面，When 查看方案區域，Then 可見清楚文案說明提早訂閱不會損失試用天數。
  - Given 用戶購買成功且仍在 trial_active，When 查看訂閱摘要，Then 可見「試用先跑完、付費再開始」的權益說明。

### P2（可以有）

#### 6) 價格可讀性優化

- **描述**：支援更直觀的折扣強調（例如節省比例或節省金額），提高比較效率。
- **Acceptance Criteria**：
  - Given 方案有折扣，When 顯示方案卡片，Then 可額外顯示節省資訊（百分比或金額）且與原價/特價一致。

## AC ID Index

本 spec 原始結構以需求章節編排；以下 AC ID 為正式引用索引，供派工、review 與 QA 使用。

| AC ID | 對應需求 |
|------|----------|
| AC-IAP-01a | IAP 畫面至少顯示月訂與年訂兩個方案 |
| AC-IAP-01b | 有折扣時同時顯示原價與特價 |
| AC-IAP-01c | 無折扣時只顯示單一價格 |
| AC-IAP-01d | 價格幣別與週期單位完整可辨識 |
| AC-IAP-01e | 月訂 / 年訂價格資訊結構一致 |
| AC-IAP-01f | CTA 附近揭露試用／優惠期間與續訂價格 |
| AC-IAP-01g | CTA 附近揭露自動續訂條款 |
| AC-IAP-02a | trial 期間購買時付費生效銜接試用結束 |
| AC-IAP-02b | trial 期間買月訂，到期日 = 試用結束 + 月週期 |
| AC-IAP-02c | trial 期間買年訂，到期日 = 試用結束 + 年週期 |
| AC-IAP-02d | trial 期間購買後可見不重疊的試用 / 付費期間 |
| AC-IAP-02e | 非 trial 狀態購買時依購買當下起算 |
| AC-IAP-03a | 非 trial 完成購買後最終收斂為 active |
| AC-IAP-03b | 同步中顯示處理中語意，不誤判失敗 |
| AC-IAP-03c | 重進 App 後狀態與最新訂閱真相一致 |
| AC-IAP-03d | trial 期間購買後重進 App 仍可顯示 trial_active，但要有已購買提示 |
| AC-IAP-04a | expired 開 app 或回前景顯示到期提醒 |
| AC-IAP-04b | expired 觸發 AI 受限功能時導向升級 |
| AC-IAP-04c | active / trial_active 不得被 AI gate 誤擋 |
| AC-IAP-04d | billing_issue 仍允許使用並非阻斷提示 |
| AC-IAP-05a | trial_active 在 IAP 畫面可見不吃試用天數文案 |
| AC-IAP-05b | trial 期間購買成功後可見權益說明 |
| AC-IAP-06 | 有折扣時可顯示節省資訊 |

## 明確不包含

- 不定義 RevenueCat / StoreKit / 後端計費實作細節
- 不定義優惠碼、限時券、地區活動價等進階促銷機制
- 不定義 Android 端畫面與流程（本規格僅 iOS App）

## 技術約束（給 Architect 參考）

- 訂閱狀態與閘門判斷以後端狀態為準（對齊 ADR-002、ADR-003）
- 方案價格來源必須為可配置來源，不可在 App 端硬編碼（對齊 ADR-002）
- 試用轉付費的起訖日需要有可追蹤、可顯示的資料來源，避免前端自行推估造成權益誤差
- 進前景與購買後都必須觸發狀態刷新，確保跨頁面與重進 App 的狀態一致
- AI 功能 gate 必須用同一份訂閱狀態判斷，不得各功能自行定義不同閘門條件

## 開放問題

- 原價與特價的權威來源欄位定義為何（目前規格只定義顯示需求，未定義資料欄位契約）
- 「一個月／一年」的到期計算在月末、時區、閏年情境的統一規則需另補測試規格
- 試用期內購買後，是否要在所有入口（Paywall、Profile、設定頁）統一顯示相同權益文案
- 到期提醒的頻率與抑制規則（每次前景都提醒，或每日一次）需產品決策
- 「購買成功但尚在同步中」是否需要獨立狀態欄位（例如 processing / pending_activation）需與後端契約對齊
