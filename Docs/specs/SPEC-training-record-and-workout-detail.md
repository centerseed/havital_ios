---
type: SPEC
id: SPEC-training-record-and-workout-detail
status: Draft
ontology_entity: training-record-detail
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: 訓練紀錄與單次訓練詳情

## 背景與動機

`TrainingRecordView` 是使用者回顧歷史訓練的主要入口，但目前缺少產品規格說明列表、分頁、空狀態、錯誤與詳情打開方式。沒有規格時，後續調整資料源或 UI 很容易破壞基本使用路徑。

## 需求

### AC-RECORD-01: 訓練紀錄頁必須在首次載入時處理 loading 與內容兩種主狀態

Given 使用者進入訓練紀錄頁，  
When 系統尚未取得任何資料，  
Then 畫面必須先顯示 loading；一旦取得資料或確認無資料，必須切換為列表或空狀態。

### AC-RECORD-02: 使用者必須可下拉刷新最新訓練紀錄

Given 使用者位於訓練紀錄頁，  
When 觸發 pull-to-refresh，  
Then 系統必須重新請求最新資料並更新目前列表。

### AC-RECORD-03: 列表中的每筆訓練紀錄都必須可打開詳情

Given 訓練紀錄列表已有資料，  
When 使用者點擊任一訓練項目，  
Then 系統必須打開該筆 `WorkoutDetailViewV2`，讓使用者查看單次訓練詳情。

### AC-RECORD-04: 長列表必須支援分頁載入

Given 訓練紀錄列表尚有更多資料，  
When 使用者捲動到目前列表底部，  
Then 系統必須觸發下一頁載入，並顯示明確的 loading-more 指示，不得重複或無限觸發同一次請求。

### AC-RECORD-05: 無資料時必須顯示可理解的 empty state

Given 使用者目前沒有任何可顯示的訓練紀錄，  
When loading 結束，  
Then 系統必須顯示空狀態說明，告知紀錄會在開始訓練後出現在此頁。

### AC-RECORD-06: 載入失敗時必須以非離頁方式提示

Given 訓練紀錄載入或刷新失敗，  
When 錯誤被回報到畫面，  
Then 系統必須以 alert 或等效方式提示錯誤，且使用者仍可留在目前頁面重新操作。

### AC-RECORD-07: 記錄頁必須提供裝置資訊輔助入口

Given 使用者位於訓練紀錄頁，  
When 點擊右上角資訊按鈕，  
Then 系統必須打開裝置資訊 sheet，作為資料來源與診斷的補充資訊入口。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-RECORD-01 | 首次載入處理 loading / content 主狀態 |
| AC-RECORD-02 | 記錄頁支援下拉刷新 |
| AC-RECORD-03 | 每筆記錄都可打開詳情 |
| AC-RECORD-04 | 長列表支援分頁載入 |
| AC-RECORD-05 | 無資料時顯示可理解 empty state |
| AC-RECORD-06 | 載入失敗以非離頁方式提示 |
| AC-RECORD-07 | 提供裝置資訊輔助入口 |
