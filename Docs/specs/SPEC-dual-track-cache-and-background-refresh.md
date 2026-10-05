---
type: SPEC
id: SPEC-dual-track-cache-and-background-refresh
status: Implemented
layer: architecture
owns: repository 層「先回快取、背景刷新」的雙軌讀取語意，含顯式刷新與失效事件的行為承諾
ontology_entity: dual-track-cache-strategy
created: 2026-04-15
updated: 2026-09-09
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

### AC-CACHE-09: 使用者顯式刷新不得被卡死的 in-flight 輪永久吞掉

Given 某常駐 ViewModel 的重驗互斥鎖因一輪請求掛住而未釋放，
When 使用者再次觸發顯式刷新（下拉），且前一輪開始已超過 30 秒（`App2RevalidatePolicy.stuckThreshold`），
Then 新一輪必須接管執行並真正發出網路請求；30 秒內的重入仍由互斥鎖擋下（SWR 防抖）。

（T-0355：舊行為 `guard !isRevalidating` 無限期吞掉下拉刷新，重開 app 才復原。）

### AC-CACHE-10: workout 處理完成推播必須觸發 workouts 快取失效

Given 使用者收到 `data.type == "workout_processed"` 推播（前景顯示或點擊進入皆算），
When 推播抵達 app，
Then 系統必須發布 `.dataChanged(.workouts)`，讓首頁完成列、紀錄頁等訂閱者立即失效重抓；使用者不需重開 app 或等待 SWR 視窗。

（T-0355：佈線為 `WorkoutBackgroundManager.workoutPushReceived`（被動 publisher）→ `CacheRegistrationCoordinator` 訂閱後轉發至 bus。）

### AC-CACHE-11: App2 指標讀取失敗保留結果，並可重試

承接 backend `SPEC-athlete-state` §1.2.1 的已核定顯示規則。指標頁首次讀取失敗時，顯示「暫時讀取失敗」與重試操作，不冒充零資料。已有結果時保留原結果與圖表中的原日期，附非阻斷的失敗提示；失敗不推進成功載入時間。使用者可下拉刷新；讀取失敗時也可按提示內的重試。兩者都沿用同一條 force refresh，成功後清除提示，改顯示新結果。離開頁面或已被新一輪接管的請求不發布錯誤，也不改結果或成功時間；下拉手勢結束或畫面重繪不能中止仍在進行的刷新及重試。

訓練量頁的來源可部分成功：例如週量讀取成功、健康資料或負荷比曲線失敗，成功來源照常顯示，失敗來源保留同範圍原有結果與原日期，提示部分資料未刷新。不把失敗轉成空值覆蓋原結果，也不把混合的新舊內容標成整頁剛成功刷新。原本無資料的來源仍為無資料，不補 0 或延長曲線。

### AC-CACHE-12: App2 課表讀取失敗顯示失敗，不顯示範例資料

When 課表頁讀取週課表的 API 失敗，且目前沒有可保留的舊課表，
Then 課表頁必須顯示讀取失敗與重試，不顯示範例週次、日期、公里數或每日課表；已有舊課表時保留舊課表，沿用 SWR。

驗法：`App2PlanWorkoutRefreshTests.test_weeklyPlanFailureWithoutExistingWeekLeavesNilAndMarksFailure` 驗證 API 丟錯時 `week == nil` 且狀態為失敗；同檔的既有 refresh 失敗測試驗證有舊資料時保留原課表。

## 實作對齊說明

- AC-01/02/03/04：`DualTrackCacheHelper.execute`（`Havital/Core/Data/DualTrackCacheHelper.swift:47`），支援 `isCacheExpired`
- AC-06：`DualTrackCacheHelper.executeForCollection`（同檔 :87），空集合視為 cache miss
- AC-05：`DualTrackCacheHelper.forceRefresh`（同檔 :128）
- AC-07：`CacheEventBus`（`Havital/Utils/CacheEventBus.swift:69` `publish`）
- AC-08：`CacheEventBus` 的 `.userLogout`／`.dataChanged(.user)` 失效路徑
- AC-09：`App2RevalidatePolicy.shouldBlock`（`Havital/Features/App2/Presentation/App2RootView.swift:12`），四個常駐 VM 的 `revalidate()` 開頭引用
- AC-10：`WorkoutBackgroundManager.emitWorkoutPushIfNeeded`（`Havital/Features/Workout/Domain/UseCases/WorkoutBackgroundManager.swift:958`）→ `CacheRegistrationCoordinator`（`Havital/Core/DI/CacheRegistrationCoordinator.swift:109`）→ 首頁／紀錄 VM 訂閱端
