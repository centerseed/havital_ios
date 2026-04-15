---
type: SPEC
id: SPEC-performance-insights-dashboard
status: Draft
ontology_entity: performance-insights-dashboard
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: 表現資料儀表板

## 背景與動機

`MyAchievementView` 已整合訓練準備度、個人最佳、訓練負荷、週跑量與心率相關圖表，但目前沒有產品規格定義這個頁面的資訊優先順序與刷新行為。這會讓未來新增圖表時容易破壞主頁焦點。

## 需求

### AC-PERF-01: 表現資料頁必須以單一可捲動儀表板呈現核心指標

Given 使用者打開表現資料頁，  
When 畫面載入完成，  
Then 系統必須以單一 scroll view 呈現訓練準備度、個人最佳、訓練負荷、週跑量與心率圖表等核心卡片。

### AC-PERF-02: 訓練準備度卡必須顯示最後更新時間與刷新入口

Given 使用者位於訓練準備度區塊，  
When 系統已有同步時間或正在刷新，  
Then 畫面必須顯示最後更新時間與刷新按鈕，刷新中需給出明確的 loading feedback。

### AC-PERF-03: 個人最佳卡必須以目前快取中的 PB 資料為主入口

Given 使用者已有 personal best 資料，  
When 表現資料頁載入，  
Then 系統必須顯示個人最佳卡，讓使用者可把該頁視為 PB 與近期表現的總覽入口。

### AC-PERF-04: 訓練負荷、週跑量與心率圖表必須作為並列分析區塊存在

Given 使用者進入表現資料頁，  
When 主內容載入完成，  
Then 系統必須提供訓練負荷、週跑量趨勢與心率相關圖表，讓使用者可從同一頁交叉查看恢復與負荷訊號。

### AC-PERF-05: 頁面進入時必須自動載入最新分析資料

Given 使用者第一次打開或重新回到表現資料頁，  
When 畫面 onAppear，  
Then 系統必須觸發必要的資料載入與同步，而不是要求使用者先手動刷新才看得到內容。

### AC-PERF-06: PB 更新事件必須可在頁面上觸發慶祝回饋

Given app 收到 personal best 更新事件，  
When 使用者當前位於表現資料頁，  
Then 系統必須顯示慶祝回饋，讓使用者明確感知自己剛達成新的最佳成績。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-PERF-01 | 表現資料頁以單一可捲動 dashboard 呈現核心指標 |
| AC-PERF-02 | readiness 卡顯示最後更新時間與刷新入口 |
| AC-PERF-03 | 個人最佳卡作為 PB 總覽主入口 |
| AC-PERF-04 | 訓練負荷 / 週跑量 / 心率圖表並列存在 |
| AC-PERF-05 | 頁面進入時自動載入最新分析資料 |
| AC-PERF-06 | PB 更新事件觸發慶祝回饋 |
