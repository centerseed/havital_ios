---
type: SPEC
id: SPEC-dual-track-cache-and-background-refresh
status: Draft
ontology_entity: dual-track-cache-strategy
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: Dual-Track Cache 與 Background Refresh

## 背景與動機

目前 app 的多個 repository 已共用 `DualTrackCacheHelper`，把「立即顯示快取」與「背景刷新最新資料」收斂成統一策略。這是核心產品行為，不只是實作細節，因為它直接決定使用者看到資料的速度、刷新時是否閃爍，以及網路失敗時畫面是否保持可用。

## 適用範圍

- `TargetRepositoryImpl`
- `WorkoutRepositoryImpl`
- `UserProfileRepositoryImpl`
- `TrainingPlanRepositoryImpl`
- `TrainingPlanV2RepositoryImpl`
- 其他採用 `DualTrackCacheHelper` 或等效雙軌快取語義的 repository

## 需求

### AC-CACHE-01: 有有效快取時，系統必須優先回傳快取

Given repository 本地已有有效快取資料，  
When UI 觸發讀取流程，  
Then 系統必須優先回傳快取，讓畫面先有內容，而不是一律等待 API 完成。

### AC-CACHE-02: 回傳快取後，系統必須在背景啟動 Track B 刷新

Given Track A 已回傳快取資料，  
When 讀取流程結束，  
Then 系統必須在背景發起 Track B API 刷新，嘗試把資料更新到最新狀態。

### AC-CACHE-03: 背景刷新失敗時不得覆蓋當前已顯示內容

Given Track B API 刷新失敗，  
When 背景任務結束，  
Then 系統只能記錄日誌或發出非阻斷訊號，不得把 UI 從已顯示的快取內容打回空白或錯誤主畫面。

### AC-CACHE-04: 無快取時，系統必須直接走 API 並把成功結果寫回快取

Given repository 沒有可用快取，  
When UI 觸發讀取流程，  
Then 系統必須直接從 API 取得資料；成功後必須寫回本地快取，作為下次 Track A 的來源。

### AC-CACHE-05: Force refresh 必須繞過 Track A

Given 使用者手動刷新或流程要求強制最新資料，  
When 呼叫 force refresh，  
Then 系統必須跳過快取直接打 API，並以新結果覆蓋快取。

### AC-CACHE-06: Collection 型資料的空陣列不得被誤當成有效快取

Given repository 讀到的是空集合快取，  
When 執行 collection 型 dual-track 讀取，  
Then 系統不得把該空集合視為有效 cache hit，而必須繼續向 API 取資料。

### AC-CACHE-07: 需要通知 UI 的背景刷新必須有明確事件出口

Given 某 repository 的背景刷新完成後需要 UI 跟著更新，  
When Track B 成功，  
Then 系統必須透過 `CacheEventBus`、通知或等效機制發布明確事件，而不是假設 UI 會自己察覺快取變化。

### AC-CACHE-08: 登出或使用者切換時，快取必須以使用者邊界清理

Given 使用者登出、切帳號或完成會影響資料歸屬的重大流程，  
When 上層發出清理指令，  
Then repository 必須清除該使用者相關快取，避免新 session 看到前一位使用者資料。

## 實作對齊說明

- `DualTrackCacheHelper.execute`：適用單一物件型快取，支援 `isCacheExpired`
- `DualTrackCacheHelper.executeForCollection`：適用集合型資料，空集合視為 cache miss
- `DualTrackCacheHelper.forceRefresh`：明確定義 bypass cache 行為
- `DualTrackCacheHelper.backgroundRefreshWithEvent`：提供 Track B 完成後的 UI 通知出口

