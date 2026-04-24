---
type: TEST
id: TEST-remove-apiclient-shared
design: TD-remove-apiclient-shared
status: Draft
created: 2026-04-24
updated: 2026-04-24
---

# 測試場景：移除 APIClient.shared

## P0 場景（必須全部通過）

### S1: Legacy APIClient 完全移除
Given: Developer 完成 APIClient removal
When: 執行 `grep -rn "APIClient\b" Havital/ --include="*.swift"`
Then: 無任何 match，且 `Havital/Services/APIClient.swift` 不存在。

### S2: Email auth legacy service 完全移除
Given: Developer 完成 auth 遷移
When: 執行 `grep -rn "EmailAuthService" Havital/ --include="*.swift"` 與 `grep -rn "APINetworkError\|APIErrorResponse" Havital/ --include="*.swift"`
Then: 兩個 grep 都無任何 match。

### S3: Workout upload contract 未退步
Given: AppleHealth workout upload service 仍負責 queue/retry/cache
When: 檢查 `AppleHealthWorkoutUploadService` 與 `WorkoutRemoteDataSource`
Then: 上傳仍走 `/v2/workouts`，summary 仍走 `/workout/summary/{id}`，取消錯誤不被當成 upload failure。

### S4: Demo login 後 Climate Settings 可用
Given: 使用 reviewer demo login
When: 進入主訓練頁，再開啟設定 / 熱適應
Then: 不出現 AuthError 3 / 401，Climate wording 可見。

### S5: Clean build
Given: 所有 migration 已完成
When: 執行 iPhone 17 Pro clean build
Then: build succeeded。

## P1 場景（應通過）

### S6: Firebase logging 仍可送出
Given: app 發出一筆 FirebaseLoggingService cloud log
When: 呼叫 `/internal/cloud-logging`
Then: HTTPClient request 成功，沒有 legacy client dependency。

### S7: Training health daily 讀取不退步
Given: training main page 讀取 health daily
When: TrainingLoadDataManager 載入 initial 與 incremental data
Then: 使用 HealthDailyRepository，UI 不顯示 ErrorView。
