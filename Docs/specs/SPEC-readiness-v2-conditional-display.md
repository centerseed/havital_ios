---
type: SPEC
id: SPEC-readiness-v2-conditional-display
status: Draft
ontology_entity: readiness-v2-conditional-display
created: 2026-04-28
updated: 2026-04-28
---

# Feature Spec: Readiness V2 — 依 plan_type 條件顯示

## 背景與動機

Readiness 五個維度中，race_fitness / endurance / recovery 本質是賽事適能指標——對 beginner（新手養成）和 maintenance（維持訓練）的用戶沒有賽事目標，這三個維度顯示 0 或「資料不足」，誤導體驗。

Backend V2 已在 readiness doc 寫入 `plan_type` 欄位，並對 beginner/maintenance plan 不計算 race_fitness / endurance / recovery。iOS 端對應改為：依 plan_type 條件顯示 UI 元件。

## 相容性

- 表現頁整體布局遵循 `SPEC-heart-rate-and-training-readiness-surfaces.md`
- Backend contract: `/v1/training-readiness?date=today` 回應含 `plan_type: "race_run" | "beginner" | "maintenance" | null`

## 顯示規則

| plan_type | speed | training_load | endurance | race_fitness | recovery | 雷達圖 | 總分 | 完賽時間 | status_text |
|-----------|-------|---------------|-----------|--------------|----------|--------|------|----------|-------------|
| `race_run` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `beginner` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `maintenance` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

## 需求

### AC-RDNS-01: race_run plan 顯示 5 維齊全

Given 用戶的 plan_type 為 `race_run`，  
When 表現頁 readiness 卡片載入完成，  
Then 顯示速度、耐力、比賽適能、訓練負荷、恢復 5 張卡片，同時顯示雷達圖、總分數字、完賽時間（若有）、status_text。

### AC-RDNS-02: beginner plan 只顯示速度 + 訓練負荷

Given 用戶的 plan_type 為 `beginner`，  
When 表現頁 readiness 卡片載入完成，  
Then 只顯示速度與訓練負荷 2 張卡片；耐力、比賽適能、恢復卡片不可見，雷達圖、總分數字、完賽時間、status_text 一律不顯示。

### AC-RDNS-03: maintenance plan 同 beginner 顯示規則

Given 用戶的 plan_type 為 `maintenance`，  
When 表現頁 readiness 卡片載入完成，  
Then 行為與 AC-RDNS-02 完全相同（2 張卡，其餘全 hide）。

### AC-RDNS-04: 過渡期 fallback — readiness doc 無 plan_type 時讀 PlanOverviewV2

Given 用戶的 readiness doc 不含 `plan_type` 欄位（V1 舊 doc），  
When iOS 解碼後 `planType == nil`，  
Then iOS 必須 fallback 讀 `PlanOverviewV2.targetType`，依其值套用對應顯示規則（AC-RDNS-01 / AC-RDNS-02 / AC-RDNS-03）；若 PlanOverviewV2 也尚未載入，預設顯示 race_run 全套（保守不隱藏）。

### AC-RDNS-05: plan type 切換後 readiness 自動刷新

Given 用戶在 app 內切換訓練目標（race_run ↔ beginner ↔ maintenance），  
When plan creation 完成並觸發 `overviewDidUpdate`，  
Then iOS readiness manager 必須強制 invalidate cache 並重新 fetch readiness doc；  
readiness 卡片顯示必須在新 doc 回來後自動更新為對應 plan_type 的顯示規則。

## 明確不包含

- Backend readiness 計算邏輯（由 barry 主線負責）
- i18n 文案新增（beginner/maintenance 不需要額外文案，只是少幾張卡）
- 卡片空狀態/loading 動畫調整（保持現狀）
