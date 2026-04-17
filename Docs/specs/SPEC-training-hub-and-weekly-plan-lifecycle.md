---
type: SPEC
id: SPEC-training-hub-and-weekly-plan-lifecycle
status: Draft
ontology_entity: training-hub-lifecycle
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: 訓練首頁與週課表生命週期

## 背景與動機

`TrainingPlanV2View` 已是主 app 的核心入口，但目前缺少一份產品規格定義不同課表狀態下應顯示什麼、用戶何時可以切週、何時可以產生本週或下週課表，以及哪些入口應由訓練首頁負責提供。

## 相容性

- 週骨架預覽遵循 `SPEC-weekly-preview-ui.md`
- 編輯課表遵循 `SPEC-training-v2-edit-schedule-screen.md`
- 付費牆與閘門規則遵循 IAP / Subscription 相關 spec

## 需求

### AC-TRAIN-HUB-01: 訓練首頁必須依 plan 狀態顯示對應主內容

Given 使用者進入訓練首頁，  
When `planStatus` 為 `ready`、`noWeeklyPlan`、`needsWeeklySummary`、`noPlan`、`completed`、`loading` 或 `error`，  
Then 系統必須顯示對應的單一主狀態畫面，不得同時混出多種主流程 CTA。

### AC-TRAIN-HUB-02: `ready` 狀態必須呈現本週執行所需的三個核心區塊

Given `planStatus == ready`，  
When 畫面載入完成，  
Then 系統必須顯示訓練進度、週總覽、週時間軸三個區塊，作為本週訓練的主要工作台。

### AC-TRAIN-HUB-03: 缺本週課表或缺上週摘要時必須提供正確 CTA

Given 使用者尚無本週課表或尚未完成產生上週摘要的前置條件，  
When 進入訓練首頁，  
Then 系統必須顯示對應的產生 CTA，且 CTA 只能觸發當前狀態所需的下一步。

### AC-TRAIN-HUB-04: 使用者切換歷史週次後必須可一鍵回到本週

Given 使用者正在查看非本週的週次，  
When 畫面底部顯示回到本週入口，  
Then 點擊後必須切回目前週次，且本週成為重新整理與後續操作的預設上下文。

### AC-TRAIN-HUB-05: 訓練首頁必須支援 refresh 與 retry

Given 使用者下拉刷新或從錯誤畫面點擊 retry，  
When 重新載入流程開始，  
Then 系統必須嘗試刷新最新課表狀態，並以同一套狀態機結果更新頁面。

### AC-TRAIN-HUB-06: 只有在條件滿足時才可產生下週課表

Given 使用者位於本週且 `nextWeekInfo.canGenerate == true` 且 `hasPlan == false`，  
When 訓練首頁評估下週 CTA，  
Then 系統才可顯示產生下週課表按鈕；不符合條件時不得顯示誤導性入口。

### AC-TRAIN-HUB-07: 工具列與選單入口必須反映目前狀態

Given 使用者位於訓練首頁，  
When 打開工具列或右上角選單，  
Then 系統必須提供計畫概覽、個人資料、週摘要、切換週數等入口；編輯週課表僅在 `ready` 狀態可見。

### AC-TRAIN-HUB-08: 訓練完成後必須提供重新設定目標入口

Given 訓練計畫已完成，  
When 使用者進入訓練首頁，  
Then 系統必須顯示完成狀態與重新設定目標的入口，並把該入口導向 re-onboarding。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-TRAIN-HUB-01 | 訓練首頁依 plan 狀態顯示單一主內容 |
| AC-TRAIN-HUB-02 | `ready` 狀態顯示進度 / 週總覽 / 週時間軸 |
| AC-TRAIN-HUB-03 | 缺本週課表或缺摘要時顯示正確 CTA |
| AC-TRAIN-HUB-04 | 切到歷史週後可一鍵回到本週 |
| AC-TRAIN-HUB-05 | 首頁支援 refresh 與 retry |
| AC-TRAIN-HUB-06 | 僅在條件滿足時顯示產生下週課表入口 |
| AC-TRAIN-HUB-07 | 工具列與選單入口反映目前狀態 |
| AC-TRAIN-HUB-08 | 訓練完成後提供 re-onboarding 入口 |
