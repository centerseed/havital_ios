---
type: SPEC
id: SPEC-workout-upload-error-noise-filtering
status: Draft
layer: product
ontology_entity: workout-upload-error-noise-filtering
owns: Apple Health workout 上傳失敗的分類、對使用者呈現的失敗原因，以及失敗後的重試／放棄處置
created: 2026-04-17
updated: 2026-08-27
tasks: T-0322
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
- Apple Health workout 上傳失敗的分類（暫時性 vs 資料驗證失敗）、對使用者呈現的原因，
  以及 `WorkoutUploadTracker` 的重試／放棄處置（2026-08-27 由 T-0322 併入）

## 明確不包含

- 資料驗證的判準本身（哪些 workout 算有效）——這次不動
- 批次上傳的 60 秒單筆逾時上限的取值
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

### AC-WORKOUT-LOG-06: 只有資料驗證失敗才是永久失敗

Given workout 上傳失敗，
When 系統為這次失敗分類，
Then 只有「重試不會改變結果」的資料驗證失敗（本機 `duration <= 0`、backend 回 400 bad request
或 validation failed）才分類為 `permanent`；其餘一切失敗——含逾時、任務中斷、取消、5xx、429、
無網路，以及任何未列舉的未知錯誤——一律分類為 `transient`。未知錯誤預設 `transient`，
不得反過來預設 `permanent`。

### AC-WORKOUT-LOG-07: 暫時性失敗不得被永久放棄

Given 一筆 Apple Health workout 因暫時性原因上傳失敗，
When 失敗次數累積，
Then 系統不得對它設重試次數上限；每次失敗只以冷卻時間節流，冷卻時間從 30 分鐘起、
每次失敗加倍、上限 6 小時。資料驗證失敗（`permanent`）維持最多 3 次、固定 30 分鐘冷卻，
用完即停止自動上傳。取值理由見 `ADR-005-apple-health-upload-failure-retry-policy.md`。

### AC-WORKOUT-LOG-08: 舊版失敗記錄不得繼承永久放棄

Given 裝置上存在修復前寫下、沒有分類欄位的失敗記錄，
When 系統讀取該記錄決定要不要重試，
Then 必須視為 `transient`，讓先前被永久跳過的 workout 重新獲得上傳機會。

### AC-WORKOUT-LOG-09: 失敗原因對使用者必須可辨識

Given 上傳流程在不同環節失敗或跳過，
When 錯誤訊息呈現給使用者（同步頁、重新上傳結果）或寫入失敗帳本，
Then 每一種情境必須有各自可辨識的三語訊息，「無效的運動數據」只保留給資料驗證失敗；
且「資料來源不是 Apple Health」與「本輪已達重試上限、未實際嘗試」不得寫入失敗帳本、
不得上報為 prod error——它們是跳過，不是失敗。

## AC ID Index

| AC ID | 對應需求 |
|------|----------|
| AC-WORKOUT-LOG-01 | 鎖屏導致的 protected data 不上報為 ERROR |
| AC-WORKOUT-LOG-02 | 真正 HealthKit 錯誤保留可觀測性 |
| AC-WORKOUT-LOG-03 | `-999` 不分類為 invalid workout data / ERROR |
| AC-WORKOUT-LOG-04 | 非取消類網路與 API 錯誤維持上報 |
| AC-WORKOUT-LOG-05 | 可恢復事件不重複上報 |
| AC-WORKOUT-LOG-06 | 只有資料驗證失敗才是永久失敗 |
| AC-WORKOUT-LOG-07 | 暫時性失敗不設次數上限，只用退避冷卻節流 |
| AC-WORKOUT-LOG-08 | 舊版無分類記錄視為暫時性 |
| AC-WORKOUT-LOG-09 | 失敗原因三語可辨識；跳過不進失敗帳本 |
