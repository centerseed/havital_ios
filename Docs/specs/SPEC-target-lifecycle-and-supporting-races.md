---
type: SPEC
id: SPEC-target-lifecycle-and-supporting-races
status: Draft
ontology_entity: target-lifecycle
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: Target Lifecycle 與支援賽事管理

## 背景與動機

目前 app 內的目標管理同時存在 main target、supporting targets、re-onboarding 重設目標與 overview 內的增修刪入口，但沒有一份產品規格定義這些目標如何共存、何時刷新、支援賽事如何排序與編輯。沒有這份 spec，後續功能擴充很容易讓 target 行為與訓練計畫脫鉤。

## 相容性

- 賽事型 onboarding 的建立入口遵循 `SPEC-onboarding-race-selection.md`
- 主訓練完成後重新設定目標入口遵循 `SPEC-training-hub-and-weekly-plan-lifecycle.md`
- Target 資料載入目前由 `TargetFeatureViewModel` + `TargetRepository` 負責

## 明確不包含

- race catalog 本身的搜尋規則
- 訓練計畫重新生成的內部演算法
- 非賽事型目標的完整資料結構改版

## 需求

### AC-TARGET-01: 系統必須區分 main target 與 supporting targets

Given 使用者已有多個 target，  
When app 載入目標資料，  
Then 系統必須將唯一主目標識別為 `mainTarget`，其餘目標視為 `supportingTargets`，兩者在 UI 與後續流程中不得混用。

### AC-TARGET-02: 支援賽事必須按比賽日期由近到遠排序

Given 使用者有多個 supporting targets，  
When race info 頁或相關列表顯示支援賽事，  
Then 系統必須依 `raceDate` 由近到遠排序，讓最近要比的賽事優先顯示。

### AC-TARGET-03: 使用者必須可新增 supporting target

Given 使用者位於 race info 或目標管理入口，  
When 點擊新增支援賽事，  
Then 系統必須提供表單讓使用者輸入賽事名稱、日期、距離與目標完賽時間，儲存成功後新 target 應出現在 supporting targets 列表。

### AC-TARGET-04: 使用者必須可編輯既有 supporting target

Given 使用者已選定一個 supporting target，  
When 打開編輯畫面並修改其名稱、日期、距離或目標時間後儲存，  
Then 系統必須保留該 target 身分並更新顯示內容，而不是建立重複目標。

### AC-TARGET-05: 使用者必須可刪除 supporting target，且需經過確認

Given 使用者位於 supporting target 編輯畫面，  
When 觸發刪除操作，  
Then 系統必須先顯示確認提示；只有在使用者確認後才可刪除該 target。

### AC-TARGET-06: Target 更新後相關畫面必須刷新

Given 使用者完成新增、編輯或刪除 target，  
When 操作成功，  
Then 依賴 target 的畫面必須刷新資料，至少包含 race info 頁、training overview 相關入口與當前可見的 target 卡片。

### AC-TARGET-07: 登出或 onboarding 完成後 target cache 必須進入正確狀態

Given 使用者登出或完成 onboarding，  
When 系統收到對應事件，  
Then target 快取必須清除或強制刷新，以避免上一位使用者的 target 或過期列表殘留到新 session。

### AC-TARGET-08: 使用者從練習流程重設目標時，必須由 re-onboarding 接管

Given 使用者已完成一輪訓練或主動重設訓練目標，  
When 選擇設定新目標，  
Then 系統必須進入 re-onboarding，而不是直接在舊 target 上做隱性覆寫。

## 技術約束（給 Architect 參考）

- `TargetFeatureViewModel` 為 target UI 狀態的主要協調者
- `TargetRepository` 目前已實作 dual-track caching，讀取與寫入後刷新策略需與 repository 行為一致
- 既有 UI 透過 `.targetUpdated` 與 `.supportingTargetUpdated` 通知做相容刷新；若未來移除通知，需保留等效更新機制

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-TARGET-01 | main target 與 supporting targets 必須明確區分 |
| AC-TARGET-02 | supporting targets 依日期由近到遠排序 |
| AC-TARGET-03 | 可新增 supporting target |
| AC-TARGET-04 | 可編輯既有 supporting target 並保留其身份 |
| AC-TARGET-05 | 刪除 supporting target 需確認 |
| AC-TARGET-06 | target 更新後相關畫面必須刷新 |
| AC-TARGET-07 | 登出或 onboarding 完成後 target cache 進入正確狀態 |
| AC-TARGET-08 | 重設目標時由 re-onboarding 接管 |
