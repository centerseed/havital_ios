---
type: SPEC
id: SPEC-workout-upload-error-noise-filtering
status: Draft
ontology_entity: workout-upload-error-noise-filtering
created: 2026-04-17
updated: 2026-04-17
---

# Feature Spec: Workout Upload Error Noise Filtering

## 背景與動機

目前 iOS App 會把兩類「可自動恢復且不影響功能」的事件上報成 prod `ERROR`：

1. 裝置鎖屏時，HealthKit 回傳 `Protected health data is inaccessible`
2. URLSession / Task 被取消時回傳 `NSURLErrorCancelled (-999)`

這兩類事件每天大量污染 `paceriz-prod` 監控，直接遮蔽真正需要處理的 P0 / P1 問題。這次修復只限 iOS App 端 logging level、錯誤分類與重複報錯控制，不涉及 backend 行為變更。

## 範圍

- `WorkoutBackgroundManager` 的待上傳 workout 檢查錯誤分類
- `AppleHealthWorkoutUploadService` 的 upload cancellation 分類與 log 去重
- 針對真正錯誤保留原有上報能力

## 明確不包含

- backend `WorkoutV2Service` validation 邏輯修改
- HealthKit 背景任務排程策略重寫
- 通用 logging framework 重構

## 需求

### AC-WORKOUT-LOG-01: 裝置鎖屏導致的 HealthKit protected data 不得上報為 ERROR

Given `WorkoutBackgroundManager` 在背景檢查待上傳 workout，  
When HealthKit 因裝置鎖屏回傳 `Protected health data is inaccessible` 或等效的受保護資料不可存取錯誤，  
Then 系統必須把這次檢查視為 skip / defer，而不是 prod error；可記錄為 `info` 或更低等級，訊息需明確表示是裝置鎖定導致稍後重試。

### AC-WORKOUT-LOG-02: 真正的 HealthKit 授權或查詢失敗仍必須保留可觀測性

Given `WorkoutBackgroundManager` 遇到非鎖屏造成的 HealthKit 查詢或授權錯誤，  
When 背景檢查失敗，  
Then 系統仍必須保留原本的 warning / error 可觀測性，不得把所有 HealthKit 相關失敗一刀切靜默。

### AC-WORKOUT-LOG-03: `NSURLErrorCancelled (-999)` 不得被分類成 invalid workout data 或 prod ERROR

Given workout 上傳流程遇到 `CancellationError`、`NSURLErrorCancelled` 或 `URLError.cancelled`，  
When `AppleHealthWorkoutUploadService` 的單筆、批次或詳細錯誤分析路徑處理該錯誤，  
Then 系統必須把它視為可重試取消事件，最多記錄一筆非 error 診斷訊息，且不得上報為 `invalid_workout_data` 或 prod `ERROR`。

### AC-WORKOUT-LOG-04: 非取消類網路與 API 錯誤必須維持原有上報能力

Given workout 上傳失敗原因是非取消類錯誤，例如無網路、timeout、HTTP 4xx / 5xx 或資料編碼問題，  
When 系統進行錯誤分類與上報，  
Then 既有的 warning / error 行為必須保持可用，不得因這次 noise filtering 而漏掉真正問題。

### AC-WORKOUT-LOG-05: 同一筆可恢復事件不得在多層路徑重複上報

Given 同一筆 workout 或同一輪 background check 觸發的是鎖屏 skip 或 upload cancellation，  
When 錯誤穿過多層 manager / service，  
Then 系統最多只能留下單一非 error 診斷訊息，不得出現多筆內容近似、只差層級的重複 Cloud Logging。

## AC ID Index

| AC ID | 對應需求 |
|------|----------|
| AC-WORKOUT-LOG-01 | 鎖屏導致的 protected data 不上報為 ERROR |
| AC-WORKOUT-LOG-02 | 真正 HealthKit 錯誤保留可觀測性 |
| AC-WORKOUT-LOG-03 | `-999` 不分類為 invalid workout data / ERROR |
| AC-WORKOUT-LOG-04 | 非取消類網路與 API 錯誤維持上報 |
| AC-WORKOUT-LOG-05 | 可恢復事件不重複上報 |
