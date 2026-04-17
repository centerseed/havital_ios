---
type: REF
id: INCIDENT-2026-04-17-01
status: Draft
l2_entity: paceriz-ios
created: 2026-04-17
updated: 2026-04-17
---

# Incident 2026-04-17-01: Initial Block Inventory

## Meta

| 欄位 | 內容 |
|------|------|
| Incident ID | `2026-04-17-01` |
| 發現時間 | `2026-04-17T15:00:00+08:00` |
| 發現來源 | Architect 主動從 gcloud logging 撈取 7 天資料 |
| 查詢 Project | `paceriz-prod`（GCP） |
| 查詢區間 | `2026-04-10T00:00:00Z` → `2026-04-17T07:00:00Z`（約 7 天） |
| 資料筆數 | 500 筆 ERROR 等級 log（gcloud logging read limit） |
| Status | `investigating`（inventory 盤點階段） |

## 查詢指令（可重現）

```bash
gcloud logging read 'severity>=ERROR timestamp>="2026-04-10T00:00:00Z"' \
  --project=paceriz-prod --limit=500 --format=json
```

Client 端錯誤透過 `app_error_report` log_type 寫入同一 stream（`jsonPayload.message` 是一層 JSON 字串，內含 `source=app_client`）。

## Top 15 Block-Class Errors（7 天，依受影響用戶 + 次數排序）

### 1. HealthKit Protected Data Inaccessible（WorkoutBackgroundManager）⚠️ P0

| 項 | 內容 |
|---|------|
| 次數 | **230** |
| 受影響用戶 | **55** unique users |
| App 版本 | 1.1.9 / 1.2.0 / 1.2.1 / 1.2.2（橫跨 4 版） |
| OS 版本 | iOS 26.0–26.5 + iPadOS 26.2 |
| 錯誤位置 | `WorkoutBackgroundManager.swift:490 checkAndUploadPendingWorkouts()` |
| 原始錯誤 | `{"error":"Protected health data is inaccessible"}` |
| 初步歸類 | **非真正 bug**。iOS 鎖屏時 HealthKit 受保護屬預期行為。但目前當作 ERROR 上報 = 噪音淹沒真 bug。 |
| iOS 觸發路徑 | 背景 BGTaskScheduler 喚醒 → 嘗試讀 HealthKit → 鎖屏狀態下失敗 |

**行動**：降級為 INFO/WARNING 層級，在 log 層加 `isProtectedDataAvailable` 前置檢查。這 230 筆噪音讓其他真正 block 的錯誤被淹沒。

---

### 2. API Response Decode Failed - `TrainingPlanOverview.id` missing ⚠️ P0（真 block）

| 項 | 內容 |
|---|------|
| 次數 | **38** |
| 受影響用戶 | **6** unique users |
| App 版本 | 1.2.2 / 1.2.3 |
| OS 版本 | iOS 26.3 / 26.3.1 / 26.4.1 |
| 錯誤位置 | `APIParser.swift:68 parse(_:from:)` |
| 原始錯誤 | `{"coding_path":"","error_detail_type":"missingKey","expected_type":"TrainingPlanOverview","missing_field":"id","response_preview":"{\"success\":true,...}"}` |
| 初步歸類 | **Backend/Client contract drift**。Backend 回傳的 `TrainingPlanOverview` 少了 `id` 欄位，client DTO 是必填 → decode 失敗 → 用戶看不到訓練計畫總覽。 |
| iOS 觸發路徑 | 進入 PlanOverview 畫面 → API 回應 decode 失敗 → ErrorView 或 blank |

**行動**：立即查 backend `/plans/overview` endpoint 是否 schema 變更；同時 client DTO `id` 改 optional 並補上解析失敗的 fallback UI。有 QA 沒抓到 = 測試環境沒覆蓋真實 backend 回應 schema drift。

---

### 3. BGTaskScheduler 註冊失敗（Error Domain 3）

| 項 | 內容 |
|---|------|
| 次數 | 39 |
| 受影響用戶 | 2（兩個用戶反覆觸發） |
| App 版本 | **1.1.3 / 1.1.5（舊版）** |
| OS 版本 | iOS 26.3.1 / 26.4 |
| 錯誤位置 | `HealthDataUploadManagerV2.swift:841 enableBackgroundSync()` |
| 原始錯誤 | `BGTaskSchedulerErrorDomain error 3` |
| 初步歸類 | 僅發生在舊版（1.1.3/1.1.5），新版可能已修。確認後可能只需強制升級 gate。 |

**行動**：驗證 1.2.x 是否已無此錯。若是，加 version gate 強制升級。

---

### 4. HealthKit Protected Data（HealthDataUploadManagerV2 多處）

| 項 | 內容 |
|---|------|
| 次數（合計） | 32 + 11 + 2 = **45** |
| 受影響用戶 | 16 + 2 + 1 = 19 unique |
| 錯誤位置 | `HealthDataUploadManagerV2.swift:1002 getLocalHealthData(days:)`、`:816 collectHealthDataForUpload(days:)`、`:866 collectHealthDataForUpload(days:)`（Authorization not determined） |

**行動**：同 #1，合併處理。`Authorization not determined`（2 筆）是**真異常**——代表 HealthKit 授權流程有 edge case 沒走完，需單獨追。

---

### 5. UnifiedWorkoutManager Apple Health 上傳 V2 失敗（workout_type=37）

| 項 | 內容 |
|---|------|
| 次數 | 6 |
| 受影響用戶 | 1 unique |
| App 版本 | 1.1.3 |
| OS 版本 | iOS 26.4 |
| 錯誤位置 | `UnifiedWorkoutManager.swift:756 reportWorkoutUploadError(workout:error:)` |
| 原始錯誤 | workout_type=37（其他/unknown），含 HKMaximumSpeed metadata |

**行動**：workout_type=37 可能是 backend 尚未支援的運動類型。需對應新增白名單或 graceful skip。

---

### 6. Upload Timeout（HealthDataUploadManagerV2）

| 項 | 內容 |
|---|------|
| 次數 | 6 + 1 = 7 |
| 受影響用戶 | 4 + 1 = 5 |
| App 版本 | 1.1.9 / 1.2.2 / iPadOS 1.2.2 |
| 錯誤位置 | `HealthDataUploadManagerV2.swift:698 performUploadRecentData()` |
| 原始錯誤 | `要求逾時。`（NSURLError timeout） |

**行動**：檢查 backend `/health/upload/recent` 回應時間；client side 是否需要加重試 + 分批。

---

### 7. Remote Config fetchAndActivate 失敗

| 項 | 內容 |
|---|------|
| 次數 | 5 |
| 受影響用戶 | 5 unique |
| App 版本 | 1.2.2（全部新版） |
| 錯誤位置 | `FeatureFlagManager.swift:78 fetchRemoteConfig()` |

**行動**：Remote Config 失敗會影響 Version Gate（最近 commit 5273d1d 相關）。必須確認失敗時 fallback 行為正確（不應 block 用戶進入 app）。

---

### 8. AppleHealthUpload Workout 無效數據

| 項 | 內容 |
|---|------|
| 次數 | 5 |
| 受影響用戶 | 3 |
| App 版本 | 1.2.0 / 1.2.2 |
| 錯誤位置 | `AppleHealthWorkoutUploadService.swift:410 performBatchUpload(_:force:retryHeartRate:)` |
| 原始錯誤 | `{"error":"無效的運動數據","workoutId":"run_1776327128_4021"}` |

**行動**：backend validation 拒絕；需取 workout 完整 payload 對照 validator，找出 validation rule 與 client 產生資料的 gap。

---

### 9. AppStateManager 用戶資料載入失敗（降級本地）

| 項 | 內容 |
|---|------|
| 次數 | 4 |
| 受影響用戶 | 4 |
| 錯誤位置 | `AppStateManager.swift:255 loadUserData()` |
| 原始錯誤 | `{"error":"要求逾時。","fallback_data_source":"unbound"}` |

**行動**：初始化流程 timeout = 用戶看到過時/空的狀態。確認 fallback UX 是否誤導（不應顯示成功狀態）。

---

### 10. AuthenticationService fetchUserProfile timeout ⚠️

| 項 | 內容 |
|---|------|
| 次數 | 3 |
| 受影響用戶 | 3 |
| App 版本 | 1.2.2 |
| 錯誤位置 | `AuthenticationService.swift:673 fetchUserProfile()` |
| 原始錯誤 | `{"error_type":"NSURLError","error":"要求逾時。"}` |

**行動**：Auth 階段 timeout 屬啟動 block；對照 backend `/auth/*` endpoint 延遲。

---

### 11. HTTPClient 401 重試失敗

| 項 | 內容 |
|---|------|
| 次數 | 1 |
| 受影響用戶 | 1 |
| 錯誤位置 | `HTTPClient.swift:147 request(path:method:body:customHeaders:)` |
| 原始錯誤 | `Token expired, 1776177637 < 1776346854` on `/auth/sync` |

**行動**：id_token expired 後重試仍用同一 token = token refresh 邏輯缺陷。單一案例但是 auth 核心 path。

---

### 12. PlanOverview / WeeklyPlan / WeeklyPreview fetch 失敗（zero redundancy）

| 模組 | 次數 | 錯誤 |
|------|------|------|
| PlanOverview | 1 | 要求逾時 |
| WeeklyPlan | 1 | `Weekly plan not found`（404） |
| WeeklyPlan | 1 | 網路連線中斷 |
| WeeklyPreview | 1 | 要求逾時 |

**行動**：低頻但都是主流程畫面。`Weekly plan not found` 特別要追 — 進入週課表後 404 = 計畫產生流程缺陷或 Firestore 狀態不一致（回呼歷史 incident `feedback_weekly_plan_flow_logic.md`）。

---

### 13. Backend-only：FCM Requested entity was not found

| 項 | 內容 |
|---|------|
| 次數 | **101**（分散在 26+ 用戶） |
| 分類 | Backend 層，與 client 無直接 block 關係 |
| 原始錯誤 | `Failed to send FCM message to user <ID>: Requested entity was not found.` |

**行動**：用戶已刪除 / FCM token invalid 但 backend 還在送。非 block client，但長期噪音需清理。

---

### 14. Backend-only：Japan race YAML not found

| 項 | 內容 |
|---|------|
| 次數 | 2 |
| 錯誤 | `/app/domains/race/data/races_jp.yaml` 不存在 |

**行動**：backend deploy 缺檔。日本用戶搜賽事會失敗 → 間接 block onboarding race flow。

---

### 15. Backend-only：Workout template not found

| 項 | 內容 |
|---|------|
| 次數 | 1 |
| 錯誤 | `Workout template not found: hill_repeats` |

**行動**：backend config 缺 template。若命中會讓課表產生失敗。

---

## 優先級分類

| 優先級 | Incidents | 行動窗 |
|--------|-----------|-------|
| **P0（真 block，立刻處理）** | #2（Decode fail）、#10（Auth timeout）、#11（Token refresh bug）、#12 的 `Weekly plan not found` | 本週內 |
| **P1（降噪 + 修 edge case）** | #1、#4（HealthKit protected data → 日誌降級 + authorization not determined 追根） | 本週內 |
| **P2（舊版 / 低頻）** | #3、#5、#6、#7、#8、#9、#13、#14、#15 | 下兩週 |

## 測試盲區觀察（最關鍵）

P0 #2（TrainingPlanOverview decode failed）**完全沒被測試抓到**——這代表：

1. **沒有 contract test**：client DTO 與 backend 實際回應沒有 schema 比對。
2. **QA 環境可能用 stub/mock**：沒打到真實 prod-like backend。
3. **Maestro flow 可能走 demo login 跳過真 API**：demo 帳號回的是固定資料，不代表真用戶。

⭐ **這是「看不到」的核心證據**。P0-1（Crashlytics）只能抓 crash，這類 silent decode failure 仍需要 app_error_report log + CI 增加 contract test 才能補上。

## 下一步 Follow-up

1. **P0-1（Crashlytics）完成後**：為上述 P0 錯誤建立 Crashlytics non-fatal log，而不是只靠 app_error_report。
2. **Contract test spec（待撰寫）**：針對 top 10 API endpoint，建立 client DTO ↔ backend response 的自動比對測試。
3. **Log severity review（待執行）**：把 `Protected health data is inaccessible` 從 ERROR 降為 WARNING，否則 ERROR 噪音比 1:1 高（真 block 錯誤只佔約 10%）。
4. **request_id 關聯規範（待撰寫）**：讓 client log 與 backend log 能用同一 UUID 對照。

## 關聯

- 相關 ADR：(待建) ADR-XXX-crashlytics-integration
- 相關 task：(待建) 建立 contract test 機制、降 HealthKit 保護資料 log 等級
- 相關文件：`docs/05-sprints/production-incidents/README.md`（流程）、`_TEMPLATE.md`（後續 incident 模板）
