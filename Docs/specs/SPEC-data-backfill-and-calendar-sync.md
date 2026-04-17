---
type: SPEC
id: SPEC-data-backfill-and-calendar-sync
status: Draft
ontology_entity: data-backfill-calendar-sync
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: Data Backfill 與 Calendar Sync

## 背景與動機

app 目前已提供兩類同步能力：一是從 Apple Health / Garmin / Strava 取得歷史運動資料並導回 app；二是把訓練日同步到系統日曆。這些流程對使用者來說都是「把外部資料接進來或送出去」，但缺少統一規格定義流程狀態、取消行為、錯誤顯示與日曆同步偏好。

## 範圍

- `DataSyncView` 的歷史資料同步流程
- Apple Health / Garmin / Strava 的同步狀態與錯誤行為
- `CalendarSyncSetupView` 與 `CalendarManager` 的訓練日曆同步偏好

## 明確不包含

- 各第三方平台 OAuth 技術細節
- HealthKit 資料解析演算法
- 日曆事件內容的品牌文案最佳化

## 需求

### AC-SYNC-01: 歷史資料同步頁必須有清楚的 processing / completed / error 狀態

Given 使用者進入資料同步頁，  
When 同步尚在進行、已完成或失敗，  
Then 系統必須分別顯示對應的主狀態，不得讓使用者無法判斷目前同步進度。

### AC-SYNC-02: Apple Health 同步必須先檢查授權，再同步近 30 天資料

Given 使用者選擇 Apple Health 同步，  
When 同步流程開始，  
Then 系統必須先要求或檢查 HealthKit 授權，授權成功後同步近 30 天運動資料；若完全沒有記錄，需回報可理解的錯誤。

### AC-SYNC-03: Garmin 同步必須支援長時間處理與輪詢進度

Given 使用者選擇 Garmin 歷史資料同步，  
When 後端處理需要時間，  
Then 系統必須顯示輪詢進度、已處理數量與當前項目；若已有處理中的 job，需接續既有 job，而不是再發一個重複任務。

### AC-SYNC-04: 同步中必須提供受控的取消或跳過路徑

Given 資料同步仍在進行中，  
When 使用者選擇取消或跳過，  
Then 系統必須依當前模式（settings / onboarding）給出對應離開路徑，但不得讓畫面停在半完成且不可返回的狀態。

### AC-SYNC-05: 同步失敗時必須提供 retry 與 skip

Given 資料同步失敗，  
When 顯示錯誤狀態，  
Then 系統必須提供重試與跳過兩個入口，讓使用者可以選擇重新同步或繼續流程。

### AC-SYNC-06: Calendar sync 必須要求使用者先決定同步模式

Given 使用者首次設定訓練日曆同步，  
When 打開 calendar sync 設定畫面，  
Then 系統必須要求使用者在全天事件與指定時間事件之間擇一，作為後續訓練日建立方式。

### AC-SYNC-07: 指定時間模式必須保存開始與結束時段

Given 使用者選擇指定時間同步模式，  
When 調整開始與結束時間後開始同步，  
Then 系統必須保存該時間偏好，供之後建立訓練日曆事件時重用。

### AC-SYNC-08: Calendar sync 必須先移除舊的 Paceriz 訓練事件，再寫入新訓練日

Given 系統準備同步新的訓練日曆資料，  
When 呼叫 calendar sync，  
Then 系統必須先清除同步範圍內既有的 `Paceriz 訓練日` 事件，再根據最新訓練日列表重建事件，避免重複。

### AC-SYNC-09: Calendar sync 權限被拒時必須明確失敗

Given 使用者未授權日曆存取，  
When 開始 calendar sync，  
Then 系統必須明確提示權限不足，而不是表面成功但實際沒有寫入事件。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-SYNC-01 | DataSyncView 顯示 processing / completed / error 主狀態 |
| AC-SYNC-02 | Apple Health 先授權再同步近 30 天資料 |
| AC-SYNC-03 | Garmin 支援長時間處理與輪詢進度 |
| AC-SYNC-04 | 同步中提供受控取消 / 跳過路徑 |
| AC-SYNC-05 | 同步失敗時提供 retry 與 skip |
| AC-SYNC-06 | Calendar sync 先選擇同步模式 |
| AC-SYNC-07 | 指定時間模式保存開始 / 結束時段 |
| AC-SYNC-08 | Calendar sync 先刪舊事件再重建 |
| AC-SYNC-09 | 日曆權限被拒時明確失敗 |
