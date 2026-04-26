---
doc_id: SPEC-iap-paywall-pricing-and-trial-protection
title: 功能規格：IAP 畫面定價、促銷策略、狀態同步與到期閘門
type: SPEC
ontology_entity: iap-subscription
status: Active
version: "0.3"
date: 2026-04-25
supersedes: "0.2"
---

# Feature Spec: IAP 畫面定價、促銷策略、狀態同步與到期閘門

## 背景與動機

目前 iOS 端已具備 IAP 相關架構與測試決策（Subscription Repository、RevenueCat 整合、Paywall 觸發），但缺少一份明確產品規格定義「畫面要顯示什麼」與「試用期轉訂閱的權益邏輯」。

v0.3 更新：補充三類促銷定價策略，包括終身鎖定早鳥、一般優惠、限時終身促銷，並定義不同優惠之間的切換邊界。

本規格目標是補齊用戶最敏感的五件事：
- 付費頁資訊透明：月訂／年訂方案要清楚，且能看見原價與特價
- 促銷策略：支援終身價與期間優惠兩種本質不同的價格模型，並可透過 RevenueCat Offering 無縫切換不需發版
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
- `SPEC-subscription-management-and-status-ui`（訂閱管理與狀態 UI 矩陣，互補關係）

已比對相關 ADR：
- `ADR-001-subscription-service-architecture`
- `ADR-002-revenuecat-sdk-integration`
- `ADR-003-paywall-trigger-and-error-handling`
- `ADR-004-iap-ui-state-test-harness`

衝突結論：
- 與既有 SPEC 無直接衝突（現有 SPEC 未定義 IAP 產品行為）
- 與既有 ADR 一致（定價來源、狀態真相、paywall 觸發邏輯不變）
- `SPEC-subscription-management-and-status-ui` 定義狀態矩陣（cancelled、grace_period 等），本規格定義促銷定價，兩者互補無重疊
- `TD-iap-apple-offers-rollout.md`（位於 `cloud/api_service/docs/02-designs/`）：已比對並同步更新，AC-IAP-OFFER-01~04 已對齊本規格的獨立產品模型
- `SPEC-iap-subscription.md`（位於 `cloud/api_service/docs/01-specs/`）：已同步更新，AC-IAP-OFFER-03 由「續訂回標準價」改為「永久鎖定早鳥價」，截止時間 Firestore 節點需求已移除
- 本版補齊 ADR 已定義但 SPEC 尚未具體化的驗收面：購買後同步、重進一致性、expired 提醒與 AI gate
- **產品決策確認（2026-04-25）**：任何「訂閱後可終身用該價格續訂」的優惠，必須採獨立低價訂閱產品；Apple Introductory Offer / Promotional Offer / Offer Code 只作為期間優惠或首期優惠，不可承諾終身續訂價。三份文件（iOS SPEC、backend SPEC、backend TD）已同步對齊

## 需求

### P0（必須有）

#### 0) 促銷定價架構：終身價、一般優惠、限時促銷

- **描述**：Paceriz 採用三類促銷策略。所有 paywall 展示切換透過 RevenueCat Offering 控制，不需要 App 發版；但不同優惠類型的續訂價格語意必須嚴格區分。

**三類優惠模型：**

| 類型 | 用途 | 機制 | 續訂價格規則 | 產品處理 |
|------|------|------|--------------|----------|
| 超早鳥終身價 | 上線早期取得永久低價 | 獨立低價產品（如 `paceriz_yearly_early_bird_s1`） | 訂閱後永久以該產品價格續訂，直到自行取消或 Apple 規則終止 | 促銷結束後設為「停止販售」，不刪除 |
| 一般優惠 | 首期折扣、試用、指定名單優惠、客服補發 | Apple Introductory Offer / Promotional Offer / Offer Code | 優惠期間結束後回到該產品的標準續訂價 | 使用正價產品或對應 offer，不承諾終身低價 |
| 限時終身促銷 | 活動期間訂閱即可永久取得活動價 | 獨立低價產品（如 `paceriz_yearly_promo_2026_spring`） | 訂閱後永久以該促銷產品價格續訂，直到自行取消或 Apple 規則終止 | 活動結束後設為「停止販售」，不刪除 |

**核心規則：**
- 任何「終身此價格續訂」都必須是獨立低價訂閱產品，不得用 Introductory Offer / Promotional Offer / Offer Code 假裝成終身價。
- 任何「一般優惠」都必須揭露優惠結束後的續訂價格；該續訂價格必須是目標產品的標準價。
- 超早鳥終身價與限時終身促銷是同一類技術模型：差異只在活動名稱、產品 ID、活動期間與展示文案。
- 優惠不得疊加成一個新的隱含價格；若用戶從一般優惠切到限時終身促銷，必須視為 subscription product switch / crossgrade。

**RevenueCat Offering 設計：**

```
default           → 正價方案（paceriz_yearly / paceriz_monthly）
phase1_early_bird → 超早鳥終身方案（early_bird 產品 + ref_yearly 正價產品用於顯示原價）
promo_lifetime_*  → 限時終身促銷（活動專屬低價產品 + ref_yearly 正價產品用於顯示原價）
promo_standard_*  → 一般優惠（正價產品 + Introductory / Promotional Offer / Offer Code）
```

**促銷結束操作 SOP（順序不可反）：**

```
Step 1：RevenueCat Dashboard → 切換 current_offering 回 default   ← 必須先做
Step 2：App Store Connect → 早鳥產品設為「停止販售」              ← 必須後做
         （不可刪除產品，否則現有早鳥訂閱者續訂中斷）
```

**App Store 審查邊界：**

| 動作 | 需要審查 |
|------|---------|
| 建立新訂閱產品（早鳥 / 特價）| 是 |
| 對已過審產品新增 / 修改 / 移除 Introductory Offer | 否，直接生效 |
| 對已過審產品產生 Offer Code | 否，直接生效 |
| 把已過審產品設為「停止販售」| 否 |

- **Acceptance Criteria**：
  - Given 當前 RevenueCat current_offering 為終身早鳥 Offering，When 用戶開啟 IAP 畫面，Then 顯示早鳥售價，同時以劃線呈現正價作為參考原價。
  - Given 當前 Offering 為正價，When 用戶開啟 IAP 畫面，Then 只顯示正價，不得顯示任何非當前有效的折扣或早鳥標記。
  - Given 終身早鳥促銷期間結束，When RevenueCat 已切回 default 且早鳥產品已設為停止販售，Then 新用戶只看到正價方案；現有早鳥訂閱者續訂不受影響。
  - Given 當前 RevenueCat current_offering 為限時終身促銷 Offering，When 用戶開啟 IAP 畫面，Then 顯示限時促銷售價，同時揭露「訂閱後可用此價格續訂」的等值語意與正價劃線參考。
  - Given 用戶購買的是一般優惠，When 優惠期間結束，Then 後續續訂價格回到該產品標準價，不得顯示或暗示終身鎖定優惠價。
  - Given 用戶正在使用一般優惠且限時終身促銷仍有效，When 用戶選擇訂閱限時終身促銷，Then App 必須把它視為切換到活動專屬低價產品，不得把一般優惠與限時終身促銷疊加。
  - Given 用戶從一般優惠切換到限時終身促銷，When 顯示確認與 disclosure 文案，Then 必須明確說明後續續訂價格改以限時促銷產品為準，既有優惠剩餘期間與生效時間依 App Store 同訂閱群組切換規則處理。
  - Given App 顯示終身早鳥方案，When 用戶看到折扣資訊，Then 折扣幅度計算來自「早鳥售價 vs 正價」兩個 StoreKit 價格，不得硬編碼任何地區的原價數字。
  - Given 終身早鳥 Offering 包含早鳥 package 與正價 reference package，When App 解析 Offering，Then 正價 reference package 不得出現購買按鈕，只作為原價顯示來源。
  - Given App 嘗試載入當前 Offering 但任一 **purchasable** package 因產品已停售而載入失敗，When Offering 解析過程發生錯誤，Then App 必須自動 fallback 至 default Offering 並正常顯示正價方案，不得呈現錯誤畫面或空白狀態。
  - Given App 成功 fallback 至 default Offering，When 用戶看到 IAP 畫面，Then 不得出現任何早鳥或促銷標記（AC-IAP-00b）。

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

### P1（應該有）

#### 6) 優惠碼（Offer Code）搭配終身價產品

- **描述**：App Store Offer Code 可針對特定產品（包含早鳥或限時終身促銷產品）發放，允許先給首期優惠（例如首 3 個月免費），之後繼續以該低價產品的價格永久續訂。這是「Offer Code 搭配目標產品」，不是把兩個 paywall 優惠任意疊加成新價格。
- **邊界定義**：
  - 優惠碼必須針對「正確的目標產品」建立。若要讓優惠碼搭配早鳥產品，必須在 App Store Connect 對早鳥產品建立對應 Offer Code，不可將正價產品的優惠碼套用到早鳥訂閱。
  - 優惠碼搭配終身價產品的效果：首期（優惠碼期間）→ 之後永久以該目標產品價格續訂。
  - 正價 + 優惠碼的效果：首期優惠 → 之後正價。
  - 這兩種組合在 Paywall 文案上的「優惠結束後續訂價格」揭露需對應正確的續訂產品。
- **Acceptance Criteria**：
  - Given 用戶透過優惠碼兌換並訂閱早鳥產品，When 優惠碼期間結束，Then 系統以早鳥價（非正價）續訂。
  - Given IAP 畫面有「兌換優惠碼」入口，When 用戶點擊後完成兌換，Then 成功訂閱後狀態同步行為與一般購買相同（AC-IAP-03a 至 AC-IAP-03d）。
  - Given 用戶以優惠碼完成訂閱，When 查看 disclosure 文案，Then 揭露的「優惠結束後續訂價格」必須與該用戶實際會被扣款的產品價格一致。

### P2（可以有）

#### 7) 價格可讀性優化

- **描述**：支援更直觀的折扣強調（例如節省比例或節省金額），提高比較效率。
- **Acceptance Criteria**：
  - Given 方案有折扣，When 顯示方案卡片，Then 可額外顯示節省資訊（百分比或金額）且與原價/特價一致。

## AC ID Index

本 spec 原始結構以需求章節編排；以下 AC ID 為正式引用索引，供派工、review 與 QA 使用。

| AC ID | 對應需求 |
|------|----------|
| AC-IAP-00a | 終身早鳥 Offering 啟用時，IAP 畫面顯示早鳥價 + 正價劃線 |
| AC-IAP-00b | 正價 Offering 啟用時，不得顯示早鳥或無效折扣標記 |
| AC-IAP-00c | 早鳥促銷結束後現有訂閱者續訂不受影響 |
| AC-IAP-00d | 限時終身促銷 Offering 啟用時，顯示活動價 + 正價劃線 + 終身續訂語意 |
| AC-IAP-00e | 一般優惠結束後回到目標產品標準續訂價，不得暗示終身價 |
| AC-IAP-00f | 一般優惠用戶改訂限時終身促銷時，視為產品切換，不疊加優惠 |
| AC-IAP-00g | 產品切換 disclosure 必須說明續訂價與 App Store 生效規則 |
| AC-IAP-00h | 折扣幅度計算來自兩個 StoreKit 價格，不硬編碼 |
| AC-IAP-00i | 正價 reference package 不得出現購買按鈕 |
| AC-IAP-00j | Offering 任一 **purchasable** package 載入失敗時，自動 fallback 至 default Offering |
| AC-IAP-00k | Fallback 後不得出現早鳥或促銷標記 |
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
| AC-IAP-06a | 優惠碼兌換終身價產品後，優惠期滿以該目標產品價格續訂 |
| AC-IAP-06b | 優惠碼兌換後購買狀態同步行為與一般購買一致 |
| AC-IAP-06c | 優惠碼兌換後 disclosure 文案揭露正確的續訂價格 |
| AC-IAP-07 | 有折扣時可顯示節省資訊 |

## 明確不包含

- 不定義 RevenueCat / StoreKit / 後端計費實作細節
- 不定義地區差異定價（各地區售價由 App Store Connect 設定，App 端透過 StoreKit 取得，不硬編碼）
- 不定義優惠碼的發放流程、數量上限、行銷活動設計（僅定義兌換後的 App 行為邊界）
- 不定義 Android 端畫面與流程（本規格僅 iOS App）

## 技術約束（給 Architect 參考）

- 訂閱狀態與閘門判斷以後端狀態為準（對齊 ADR-002、ADR-003）
- 方案價格來源必須為可配置來源，不可在 App 端硬編碼（對齊 ADR-002）
- 試用轉付費的起訖日需要有可追蹤、可顯示的資料來源，避免前端自行推估造成權益誤差
- 進前景與購買後都必須觸發狀態刷新，確保跨頁面與重進 App 的狀態一致
- AI 功能 gate 必須用同一份訂閱狀態判斷，不得各功能自行定義不同閘門條件

### RevenueCat Offering 串接規格

#### Offering 觸發時機
App 在以下時機必須重新 fetch current offering（不得使用上次快取結果）：
- App 冷啟動
- App 從背景回到前景
- 用戶進入 IAP 畫面（`.task { await viewModel.loadOfferings() }`）

#### Package 識別規則
App 透過 RevenueCat package identifier 前綴區分用途：

| Identifier 前綴 | 用途 | 行為 |
|----------------|------|------|
| `$rc_annual`、`$rc_monthly`（或自訂非 `ref_`）| 可購買方案 | 顯示購買按鈕，參與購買流程 |
| `ref_` 開頭（如 `ref_yearly`、`ref_monthly`）| 參考正價 | 只取 `localizedPrice` 顯示原價，不得出現購買按鈕 |

#### Offering 結構對應

**終身價 Offering（phase1_early_bird / promo_lifetime_*）：**
```
Offering
  ├── $rc_annual（或 eb_yearly）: paceriz_yearly_early_bird_s1 / paceriz_yearly_promo_* → 終身價年訂，用於購買
  ├── $rc_monthly（或 eb_monthly）: paceriz_monthly_early_bird_s1 / paceriz_monthly_promo_* → 終身價月訂，用於購買
  ├── ref_yearly: paceriz_yearly                    → 正價年訂，只取 localizedPrice
  └── ref_monthly: paceriz_monthly                  → 正價月訂，只取 localizedPrice
```

**一般優惠 Offering（promo_standard_*）：**
```
Offering
  ├── $rc_annual: paceriz_yearly（含 Introductory Offer）→ 購買 + officialOffer 提供折扣資訊
  └── $rc_monthly: paceriz_monthly（含 Introductory Offer）→ 同上
（無需 ref_ package：原價 = package.localizedPrice，特價 = officialOffer.localizedPrice）
```

**正價 Offering（default）：**
```
Offering
  ├── $rc_annual: paceriz_yearly  → 無折扣，顯示單一正價
  └── $rc_monthly: paceriz_monthly → 無折扣，顯示單一正價
```

### 折扣顯示計算規格

App 根據 Offering 內容自動判斷顯示模式，**不接受任何地區原價硬編碼**。

#### 模式 A：終身價獨立產品（ref_ package 存在）
```
原價 = ref_yearly.localizedPrice（劃線顯示）
售價 = $rc_annual.localizedPrice（大字顯示）
折扣 % = round((ref.price - eb.price) / ref.price × 100)
```
兩個價格皆來自 StoreKit，自動對應用戶所在地區幣別。

#### 模式 B：Introductory Offer（package.officialOffer 存在）
```
原價 = package.localizedPrice（劃線顯示）
售價 = package.officialOffer.localizedPrice（大字顯示）
折扣 % = 現有 officialDiscountPercent(for:) 邏輯（依 payAsYouGo / payUpFront / freeTrial 分支）
```

#### 模式 C：正價無折扣
```
只顯示 package.localizedPrice，不顯示原價或折扣 %
```

三種模式的折扣 badge 樣式一致（`paywall.offer.discount_percent` 格式），由 PaywallViewModel 在 Offering 解析階段決定模式，下傳至 View 層，View 不做模式判斷。

### Offering Fallback 規格

```
loadOfferings() 流程：

1. fetch RevenueCat current offering
2. 逐一解析 purchasable packages 的 StoreKit 產品
3. 任一 purchasable package 的 productID 無法載入（productNotFound / unavailable）
   → 捨棄當前 offering，重新 fetch "default" offering
4. default offering 也失敗 → 呈現 offerings_unavailable 畫面（現有 .error 狀態）
5. default offering 成功 → 以正價模式（模式 C）呈現，不顯示任何促銷標記
```

ref_ package 載入失敗**不觸發** fallback，也不影響用戶訂閱或購買流程。ref_ 只用於 UI 顯示，退化規則如下：
- 劃線原價：隱藏
- 折扣 badge：隱藏（不顯示 0%，不報錯）
- 早鳥售價與購買按鈕：正常顯示，用戶仍可完成購買

## 開放問題

- Domain entity 是否需要新增 `referencePrice: Decimal?` 欄位，或維持現有「ViewModel 在 Offering 解析階段從 ref_ package 抽取」的模式，需 Architect 確認
- 「一個月／一年」的到期計算在月末、時區、閏年情境的統一規則需另補測試規格
- 試用期內購買後，是否要在所有入口（Paywall、Profile、設定頁）統一顯示相同權益文案
- 到期提醒的頻率與抑制規則（每次前景都提醒，或每日一次）需產品決策
- 「購買成功但尚在同步中」是否需要獨立狀態欄位（例如 processing / pending_activation）需與後端契約對齊
- 優惠碼是否需支援「跨方案兌換」（例如：優惠碼建立在年訂，但用戶目前在月訂頁），產品邊界需確認
