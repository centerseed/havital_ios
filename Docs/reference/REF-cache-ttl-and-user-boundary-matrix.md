---
type: REF
id: REF-cache-ttl-and-user-boundary-matrix
status: Draft
ontology_entity: cache-ttl-user-boundary-matrix
created: 2026-04-15
updated: 2026-04-15
---

# Cache TTL 與 User Boundary Matrix

## 結論

目前 app 的 cache 策略已經有一套可描述的現況，但不是所有 cache key 都帶 user namespace。
多數資料安全邊界實際上依賴：

1. `CacheEventBus.shared.publish(.userLogout)`
2. repository / manager 的 `clearCache()` / `clearAll()`
3. onboarding 完成或特定資料事件後的主動 invalidation

換句話說，**多帳號隔離主要靠清 cache，不是靠 key 天生隔離**。

## TTL Matrix

| 區塊 | 檔案 | Cache Key / Scope | TTL / 策略 | 備註 |
|------|------|-------------------|------------|------|
| User Profile | `Havital/Features/UserProfile/Data/DataSources/UserProfileLocalDataSource.swift` | `user_profile_cache_v3` | 1 小時 | profile shell 主資料 |
| Targets（在 UserProfile DS 內） | 同上 | `user_targets_cache_v3` | 1 小時 | 與獨立 TargetLocalDS 並存 |
| Heart Rate Zones | 同上 | `heart_rate_zones_cache_v4` | 24 小時 | 生理設定相對穩定 |
| Target Module | `Havital/Features/Target/Data/DataSources/TargetLocalDataSource.swift` | `target_cache_v3` | 1 小時 | main/supporting targets |
| Subscription Status | `Havital/Features/Subscription/Data/DataSources/SubscriptionLocalDataSource.swift` | `subscription_status_v1` | 5 分鐘 | 狀態短 TTL；repository 有 stale-on-error |
| TrainingPlanV2 Plan Status | `Havital/Features/TrainingPlanV2/Data/DataSources/TrainingPlanV2LocalDataSource.swift` | `training_plan_v2_plan_status_cache` | 1 小時 | 首頁主狀態 |
| TrainingPlanV2 Overview | 同上 | `training_plan_v2_overview_cache` | 1 小時 | 計畫總覽 |
| TrainingPlanV2 Weekly Plan | 同上 | `training_plan_v2_weekly_{week}` | 2 小時 | 各週課表 |
| TrainingPlanV2 Weekly Summary | 同上 | `training_plan_v2_summary_{week}` | 1 小時 | 各週摘要 |
| TrainingPlanV2 Weekly Preview | 同上 | `training_plan_v2_preview_{overviewId}` | 1 小時 | 使用 overview TTL |
| Workout List / Detail（主路徑） | `Havital/Features/Workout/Data/DataSources/WorkoutLocalDataSource.swift` | `BaseCacheManagerTemplate` 管理 | 2 小時 | list / single / detail 共用 2h TTL |
| Workout V2 Legacy Cache | `Havital/Storage/WorkoutV2CacheManager.swift` | list / detail / stats / pagination | list 7 天、detail 24h、stats 6h | 舊快取層仍存在 |
| Workout V2 Retention | 同上 | file cache retention | 最多保留 3 個月 | 舊資料清理邊界 |
| Training Readiness | `Havital/Storage/TrainingReadinessStorage.swift` | `training_readiness_data` | 30 分鐘 refresh threshold | `shouldRefreshData(1800)` |
| VDOT（Legacy Storage） | `Havital/Storage/VDOTStorage.swift` | `vdot_points` 等 | 30 分鐘 refresh threshold | 舊 storage |
| VDOT（Manager） | `Havital/Features/UserProfile/Domain/UseCases/VDOTManager.swift` | `vdot_cache` | 30 分鐘 | 由 `VDOTCacheManager` 持有 |
| Monthly Stats | `Havital/Features/MonthlyStats/Data/Repositories/MonthlyStatsRepositoryImpl.swift` | 月份粒度 | 實質永久 TTL | 只要該月有資料就緩存；零 workout 不緩存 |
| TrainingPlanStorage（Legacy） | `Havital/Storage/TrainingPlanStorage.swift` | `training_plan*` | 不自動過期 | 依賴手動 clear |

## Repository 策略摘要

### Dual-Track 類

- `DualTrackCacheHelper` 定義 Track A / Track B 模式：
  - Track A：先回 cache
  - Track B：背景 refresh API，再寫回 cache
- 適用於需要快顯示、可容忍短暫 stale 的畫面。

### Stale-on-Error 類

- `SubscriptionRepositoryImpl` 在 API 失敗時會回傳過期 cache，而不是直接拋錯。
- 這是「訂閱狀態不能因短暫離線誤判」的特例，不應直接套到所有模組。

### Permanent-Until-Invalidated 類

- `MonthlyStatsRepositoryImpl` 對有資料月份採「一旦同步就保留」策略。
- 真正的刷新來自：
  - user logout clear
  - 手動 refresh month
  - 上層 event 觸發重新讀取

## User Boundary 風險

### 現況

- 多數 cache key 沒有 `userId` 後綴。
- 隔離主要靠：
  - `AuthenticationService.signOut()` / `UserProfileFeatureViewModel.signOut()`
  - `CacheEventBus.shared.publish(.userLogout)`
  - repository / manager 監聽後清 cache

### 風險判斷

- 單一使用者常態流程：可接受。
- 同裝置快速切換多帳號：**有風險**，前提是 logout 清 cache 流程漏掉任何一個模組。

## Invalidation 觸發

| 事件 | 作用 |
|------|------|
| `userLogout` | 清除 TrainingPlan / Workout / MonthlyStats / Auth / UserProfile 等快取 |
| onboarding 完成 | 某些 view model 會 clear cache 後重新讀取 |
| workout 資料變動 | 透過 `CacheEventBus.dataChanged(.workouts)` 刷新相關視圖 |
| `workout_processed` push | `AppDelegate` 會重置 workout cooldown，讓下次存取觸發刷新 |

## 建議

1. 新增高風險 cache 時，優先考慮 `userId` namespace，而不是只依賴 logout clear。
2. 新增 repository 時，必須明確選一種策略：dual-track、stale-on-error、permanent-until-invalidated 或 no-cache。
3. 若某畫面是跨帳號敏感資料，不要只寫「有 cache」，要把 invalidation 路徑寫進 spec 或 ref。
