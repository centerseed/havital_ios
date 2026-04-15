---
type: SPEC
id: SPEC-monthly-stats-and-calendar-performance-surfaces
status: Draft
ontology_entity: monthly-stats-performance-surface
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: Monthly Stats 與 Performance Calendar Surface

## 背景與動機

目前 app 的表現資料不是只有 `MyAchievementView`，也包含月曆視角的月度統計補資料流程。`TrainingCalendarView` 會把本地 workouts 與 monthly stats API 合併，形成「本地詳細資料優先、月度統計補空白日期」的體驗；但這塊尚未被文件化。

## 相容性

- Performance dashboard 的首頁總覽遵循 `SPEC-performance-insights-dashboard.md`
- Repository 快取與刷新策略遵循 `SPEC-dual-track-cache-and-background-refresh.md`

## 需求

### AC-MONTHLY-01: 月曆頁必須顯示當月訓練資料的整合結果

Given 使用者位於訓練月曆或相關月度統計頁面，  
When 系統載入指定月份資料，  
Then 畫面必須顯示當月的訓練資料整合結果，而不是只依賴單一資料來源。

### AC-MONTHLY-02: 本地 workouts 必須優先於 monthly stats

Given 同一天同時存在本地 workout 與月度統計資料，  
When 系統合併當月資料，  
Then 本地 workout 必須作為該日唯一主要來源，monthly stats 只能補沒有本地資料的日期。

### AC-MONTHLY-03: monthly stats 僅用來補齊本地缺失日期

Given 某月份部分日期沒有本地 workout，  
When monthly stats API 提供對應日期的統計資料，  
Then 系統必須用 synthetic workout 或等效方式補齊這些日期，讓月曆能完整呈現當月訓練分布。

### AC-MONTHLY-04: 月度統計頁必須可切換月份並重新載入

Given 使用者切換到其他月份，  
When 月份改變，  
Then 系統必須重新載入該月份的本地 workout 與 monthly stats，並更新統計結果。

### AC-MONTHLY-05: 月度總里程與平均配速只計算跑步類型

Given 當月存在多種活動紀錄，  
When 顯示月總里程與平均配速等核心統計，  
Then 系統必須只計算 `running` 類型，不得把其他活動誤算進跑步指標。

### AC-MONTHLY-06: 月度統計 API 失敗時系統必須靜默降級到現有本地資料

Given monthly stats API 失敗或沒有額外資料，  
When 畫面載入完成，  
Then 系統必須仍顯示本地已有 workouts，不得因補資料失敗而讓整個月曆變成錯誤畫面。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-MONTHLY-01 | 月曆頁顯示當月訓練資料整合結果 |
| AC-MONTHLY-02 | 本地 workouts 優先於 monthly stats |
| AC-MONTHLY-03 | monthly stats 僅補齊本地缺失日期 |
| AC-MONTHLY-04 | 切換月份後重新載入整合結果 |
| AC-MONTHLY-05 | 月總里程與平均配速只計算 running |
| AC-MONTHLY-06 | monthly stats API 失敗時靜默降級到本地資料 |
