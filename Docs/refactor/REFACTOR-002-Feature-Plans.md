# REFACTOR-002: Feature 重構計劃

**版本**: 1.1
**最後更新**: 2026-01-03
**狀態**: 🔄 進行中

---

## 概述

本文檔詳細規劃各個 Feature 的 Clean Architecture 重構計劃，每個 Feature 包含:
- 當前架構分析
- 目標架構設計
- 重構步驟清單
- 測試策略
- 驗收標準

所有 Features 遵循 **TrainingPlan Feature** 的參考實現（[ARCH-005](../01-architecture/ARCH-005-TrainingPlan-Reference-Implementation.md)）。

---

## 📊 整體重構進度

| Feature | 架構層 | Views 遷移 | 測試 | 整體進度 |
|---------|-------|-----------|------|---------|
| **TrainingPlan** | ✅ 100% | ⚠️ 85% (3 Views 待遷移) | 📋 待完成 | **85%** |
| **UserProfile** | ✅ 100% | ✅ 62% (8/13 核心已遷移) | 📋 待完成 | **85%** |
| **Workout** | 📋 規劃中 | 📋 未開始 | 📋 未開始 | **0%** |
| **VDOT** | 📋 規劃中 | 📋 未開始 | 📋 未開始 | **0%** |
| **TrainingReadiness** | 📋 規劃中 | 📋 未開始 | 📋 未開始 | **0%** |
| **Authentication** | 📋 規劃中 | 📋 未開始 | 📋 未開始 | **0%** |
| **Garmin/Strava** | 📋 規劃中 | 📋 未開始 | 📋 未開始 | **0%** |

### 已完成的架構檔案

```
Features/
├── TrainingPlan/              ✅ 完整 Clean Architecture
│   ├── Domain/
│   │   ├── Repositories/ (2 protocols)
│   │   └── UseCases/ (2 use cases)
│   ├── Data/
│   │   ├── DataSources/ (2 sources)
│   │   └── Repositories/ (2 implementations)
│   └── Presentation/
│       └── ViewModels/ (4 viewmodels)
│
└── UserProfile/               ✅ 完整 Clean Architecture
    ├── Domain/
    │   ├── Errors/ (1 error type)
    │   ├── Repositories/ (2 protocols)
    │   └── UseCases/ (8 use cases)
    ├── Data/
    │   ├── DataSources/ (4 sources)
    │   └── Repositories/ (2 implementations)
    └── Presentation/
        └── ViewModels/ (1 viewmodel)
```

### 待遷移 Views 總覽

| Feature | 待遷移 Views | 優先級 |
|---------|-------------|--------|
| TrainingPlan | 3 Views | 🔥 高 |
| UserProfile | 5 Views (待 Training Feature) | ⚠️ 中 |
| **總計** | **8 Views** | - |

---

## Feature 1: Workout Feature 🔥

**優先級**: 🔥 最高
**預計時間**: 5 個工作日
**複雜度**: ⭐⭐⭐⭐ (高)
**狀態**: 📋 規劃中

---

### 1.1 當前架構分析

#### 現有組件
- **Manager**: `UnifiedWorkoutManager.swift` (Singleton)
- **Service**: `WorkoutV2Service.swift` (API 調用)
- **ViewModel**: `WorkoutDetailViewModel.swift`, `WorkoutDetailViewModelV2.swift`
- **Storage**: 使用 `UnifiedCacheManager`

#### 主要問題
- ❌ ViewModel 直接依賴 `UnifiedWorkoutManager.shared` (Singleton)
- ❌ 業務邏輯散落在 Manager 和 ViewModel 中
- ❌ 數據同步邏輯複雜（HealthKit, Garmin, Strava）未封裝
- ❌ 沒有明確的 Repository 層

#### 符合度評估
- Domain Layer: 0% (無 Repository Protocol, 無 Use Cases)
- Data Layer: 40% (有 Service 和 Cache，但未封裝為 Repository)
- Presentation Layer: 30% (ViewModel 職責過多)

---

### 1.2 目標架構設計

#### 目錄結構
```
Features/Workout/
├── Domain/
│   ├── Repositories/
│   │   └── WorkoutRepository.swift       # Repository 協議
│   ├── UseCases/
│   │   ├── GetWorkoutsInRangeUseCase.swift
│   │   ├── SyncWorkoutFromHealthKitUseCase.swift
│   │   ├── SyncWorkoutFromGarminUseCase.swift
│   │   ├── CalculateWorkoutStatsUseCase.swift
│   │   └── GroupWorkoutsByActivityUseCase.swift
│   └── Errors/
│       └── WorkoutError.swift            # 領域錯誤
│
├── Data/
│   ├── Repositories/
│   │   └── WorkoutRepositoryImpl.swift   # Repository 實現
│   └── DataSources/
│       ├── WorkoutRemoteDataSource.swift # API 調用
│       └── WorkoutLocalDataSource.swift  # 本地緩存
│
└── Presentation/
    └── ViewModels/
        └── WorkoutDetailViewModel.swift  # 重構後的 ViewModel
```

#### Repository Protocol 定義
```
WorkoutRepository 職責:
- 獲取訓練記錄（按日期範圍、類型篩選）
- 同步訓練記錄（HealthKit, Garmin, Strava）
- 創建/更新/刪除訓練記錄
- 緩存管理
```

#### Use Cases 定義

| Use Case | 職責 | 輸入 | 輸出 |
|---------|------|------|------|
| `GetWorkoutsInRangeUseCase` | 獲取指定日期範圍的訓練記錄 | `DateRange`, `activityTypes` | `[WorkoutV2]` |
| `SyncWorkoutFromHealthKitUseCase` | 從 HealthKit 同步訓練記錄 | `syncOptions` | `Result<Int, Error>` |
| `SyncWorkoutFromGarminUseCase` | 從 Garmin 同步訓練記錄 | `userId` | `Result<Int, Error>` |
| `CalculateWorkoutStatsUseCase` | 計算訓練統計（距離、配速、心率） | `[WorkoutV2]` | `WorkoutStats` |
| `GroupWorkoutsByActivityUseCase` | 按活動類型分組訓練記錄 | `[WorkoutV2]` | `[ActivityType: [WorkoutV2]]` |

---

### 1.3 重構步驟清單

#### Phase 1: Domain Layer (Day 1)
- [ ] **創建 Domain 目錄結構**
  - `Features/Workout/Domain/Repositories/`
  - `Features/Workout/Domain/UseCases/`
  - `Features/Workout/Domain/Errors/`

- [ ] **定義 WorkoutRepository 協議**
  ```
  協議方法:
  - getWorkouts(startDate: Date, endDate: Date, activityTypes: [String]?) -> [WorkoutV2]
  - getAllWorkouts() -> [WorkoutV2]
  - syncFromHealthKit() async throws -> Int
  - syncFromGarmin(userId: String) async throws -> Int
  - saveWorkout(_ workout: WorkoutV2) async throws
  - deleteWorkout(id: String) async throws
  - clearCache() async
  ```

- [ ] **定義 WorkoutError 錯誤類型**
  ```
  錯誤類型:
  - workoutNotFound(id: String)
  - syncFailed(source: String, reason: String)
  - invalidDateRange
  - healthKitNotAuthorized
  - networkError(String)
  ```

- [ ] **創建基礎 Use Cases**
  - `GetWorkoutsInRangeUseCase.swift`
  - `SyncWorkoutFromHealthKitUseCase.swift`

#### Phase 2: Data Layer (Day 2)
- [ ] **創建 Data 目錄結構**
  - `Features/Workout/Data/Repositories/`
  - `Features/Workout/Data/DataSources/`

- [ ] **實現 WorkoutRepositoryImpl**
  ```
  依賴:
  - remoteDataSource: WorkoutRemoteDataSource
  - localDataSource: WorkoutLocalDataSource
  - healthKitManager: HealthKitManager (可選)

  實現雙軌緩存策略:
  - Track A: 立即返回本地緩存
  - Track B: 背景刷新遠端數據
  ```

- [ ] **創建 WorkoutRemoteDataSource**
  ```
  職責:
  - 封裝 WorkoutV2Service API 調用
  - 處理網路錯誤
  - 數據轉換（DTO → Domain Entity）

  方法:
  - fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutV2]
  - uploadWorkout(_ workout: WorkoutV2) async throws
  - deleteWorkout(id: String) async throws
  ```

- [ ] **創建 WorkoutLocalDataSource**
  ```
  職責:
  - 整合 UnifiedCacheManager
  - 本地查詢優化（按日期索引）
  - 緩存失效策略

  方法:
  - getCachedWorkouts() -> [WorkoutV2]
  - saveWorkouts(_ workouts: [WorkoutV2])
  - clearCache()
  ```

#### Phase 3: Use Cases Implementation (Day 3)
- [ ] **實現 GetWorkoutsInRangeUseCase**
  ```
  業務邏輯:
  1. 從 Repository 獲取訓練記錄
  2. 按日期範圍過濾
  3. 按活動類型過濾（可選）
  4. 排序（按日期降序）
  ```

- [ ] **實現 SyncWorkoutFromHealthKitUseCase**
  ```
  業務邏輯:
  1. 檢查 HealthKit 授權
  2. 從 HealthKit 讀取訓練記錄
  3. 與現有記錄去重
  4. 上傳到後端 API
  5. 更新本地緩存
  ```

- [ ] **實現 CalculateWorkoutStatsUseCase**
  ```
  業務邏輯:
  1. 計算總距離
  2. 計算平均配速
  3. 計算心率區間分布
  4. 計算訓練強度
  ```

- [ ] **實現 GroupWorkoutsByActivityUseCase**
  ```
  業務邏輯:
  1. 按活動類型分組
  2. 計算每種類型的統計數據
  ```

#### Phase 4: Presentation Layer (Day 4)
- [ ] **重構 WorkoutDetailViewModel**
  ```
  移除:
  - 對 UnifiedWorkoutManager.shared 的依賴
  - 對 WorkoutV2Service 的直接調用
  - 內部業務邏輯（移至 Use Cases）

  新增:
  - 依賴注入（Use Cases）
  - 統一狀態管理（ViewState<WorkoutDetail>）
  ```

- [ ] **更新 DI 註冊**
  ```
  DependencyContainer:
  - registerWorkoutModule()
  - makeGetWorkoutsInRangeUseCase()
  - makeSyncWorkoutFromHealthKitUseCase()
  - makeCalculateWorkoutStatsUseCase()
  ```

- [ ] **更新相關 Views**
  - 確保 Views 使用新的 ViewModel 初始化方式
  - 更新 Preview Providers

#### Phase 5: 測試與驗證 (Day 5)
- [ ] **單元測試 (Use Cases)**
  ```
  測試覆蓋:
  - GetWorkoutsInRangeUseCase: 正常流程、空結果、過濾邏輯
  - SyncWorkoutFromHealthKitUseCase: 成功同步、授權失敗、網路錯誤
  - CalculateWorkoutStatsUseCase: 各種訓練類型的統計計算

  目標覆蓋率: > 90%
  ```

- [ ] **整合測試 (Repository)**
  ```
  測試場景:
  - 雙軌緩存策略驗證
  - 數據同步流程驗證
  - 錯誤處理驗證

  目標覆蓋率: > 80%
  ```

- [ ] **回歸測試 (UI 功能)**
  ```
  測試場景:
  - 訓練記錄列表顯示
  - 訓練詳情頁顯示
  - HealthKit 同步功能
  - Garmin/Strava 同步功能

  驗證: 所有功能正常，無退化
  ```

- [ ] **性能測試**
  ```
  測試指標:
  - 載入 1000 條訓練記錄的時間 (< 1s)
  - 記憶體使用 (無異常增長)
  - 緩存命中率 (> 80%)
  ```

- [ ] **更新文檔**
  - 創建 `Workout-Feature-Architecture.md`
  - 更新 API 文檔
  - 更新測試報告

---

### 1.4 驗收標準

#### 必須達成
- ✅ 所有組件遵循 Clean Architecture 分層
- ✅ Repository Pattern 完整實現
- ✅ 至少 3 個 Use Cases 實現
- ✅ ViewModel 使用依賴注入
- ✅ 單元測試覆蓋率 > 85%
- ✅ 所有 UI 功能正常工作
- ✅ 無編譯警告

#### 期望達成
- ✅ 5 個 Use Cases 完整實現
- ✅ 單元測試覆蓋率 > 90%
- ✅ 整合測試覆蓋率 > 80%
- ✅ 性能無退化

---

## Feature 2: UserProfile Feature ✅

**優先級**: 🔥 高
**預計時間**: 3 個工作日
**複雜度**: ⭐⭐ (中)
**狀態**: ✅ 架構層完成 (80%) - Views 待遷移

---

### 2.1 實現狀態

#### ✅ 已完成 - Clean Architecture 層

| 層級 | 狀態 | 檔案 |
|------|------|------|
| **Domain - Errors** | ✅ | `UserProfileError.swift` |
| **Domain - Repositories** | ✅ | `UserProfileRepository.swift`, `UserPreferencesRepository.swift` |
| **Domain - Use Cases** | ✅ | 8 個 Use Cases (見下方) |
| **Data - DataSources** | ✅ | 4 個 DataSources (Remote + Local) |
| **Data - Repositories** | ✅ | `UserProfileRepositoryImpl.swift`, `UserPreferencesRepositoryImpl.swift` |
| **Presentation - ViewModel** | ✅ | `UserProfileFeatureViewModel.swift` |
| **DI Container** | ✅ | `registerUserProfileModule()` + 工廠方法 |

#### ✅ 已完成 - Views 遷移 (8/13 核心完成)

**核心 UserProfile Views (8 個)**

| View | 狀態 | 備註 |
|------|------|------|
| `UserProfileView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `TimezoneSettingsView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `LanguageSettingsView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `DataSourceSelectionView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `OnboardingContainerView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `HeartRateSetupAlertView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `HeartRateZoneInfoView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |
| `HeartRateZoneEditorView.swift` | ✅ | 已使用 UserProfileFeatureViewModel |

**額外清理 (2 個)**

| View | 狀態 | 備註 |
|------|------|------|
| `HRVTrendChartView.swift` | ✅ | 已移除未使用的 userPreferenceManager |
| `SleepHeartRateChartView.swift` | ✅ | 已移除未使用的 userPreferenceManager |

#### ⚠️ 待 Training Feature 遷移 (5 個 Views)

這些 Views 使用 Training 相關屬性，將在實現 **Training Feature** 時遷移:

| View | 當前使用 | 使用的屬性 | 計劃 | 優先級 |
|------|---------|-----------|------|--------|
| `TrainingDaysSetupView.swift` | `UserPreferencesManager.shared` | `preferWeekDays`, `preferWeekDaysLongRun` | TrainingFeatureViewModel | 🔄 Training Feature |
| `TrainingPlanView.swift` | `UserPreferencesManager.shared` | HR prompt settings | TrainingFeatureViewModel | 🔄 Training Feature |
| `TrainingPlanOverviewView.swift` | `UserPreferencesManager.shared` | `weekOfTraining` | TrainingFeatureViewModel | 🔄 Training Feature |
| `WeeklyVolumeChartView.swift` | `UserPreferencesManager.shared` | `timezonePreference` | TrainingFeatureViewModel | 🔄 Training Feature |
| `MyAchievementView.swift` | `UserManager.shared` | `UserManager`, `dataSourcePreference` | TrainingFeatureViewModel | 🔄 Training Feature |

---

### 2.2 已實現架構

#### 目錄結構 (已完成)
```
Features/UserProfile/
├── Domain/
│   ├── Errors/
│   │   └── UserProfileError.swift          ✅
│   ├── Repositories/
│   │   ├── UserProfileRepository.swift     ✅
│   │   └── UserPreferencesRepository.swift ✅
│   └── UseCases/
│       ├── GetUserProfileUseCase.swift     ✅
│       ├── UpdateUserProfileUseCase.swift  ✅
│       ├── GetHeartRateZonesUseCase.swift  ✅
│       ├── UpdateHeartRateZonesUseCase.swift ✅
│       ├── GetUserTargetsUseCase.swift     ✅
│       ├── CreateTargetUseCase.swift       ✅
│       ├── SyncUserPreferencesUseCase.swift ✅
│       └── CalculateUserStatsUseCase.swift ✅
│
├── Data/
│   ├── DataSources/
│   │   ├── UserProfileRemoteDataSource.swift  ✅
│   │   ├── UserProfileLocalDataSource.swift   ✅
│   │   ├── UserPreferencesRemoteDataSource.swift ✅
│   │   └── UserPreferencesLocalDataSource.swift  ✅
│   └── Repositories/
│       ├── UserProfileRepositoryImpl.swift    ✅
│       └── UserPreferencesRepositoryImpl.swift ✅
│
└── Presentation/
    └── ViewModels/
        └── UserProfileFeatureViewModel.swift  ✅
```

#### Use Cases 定義 (已實現)

| Use Case | 職責 | Input | Output |
|---------|------|-------|--------|
| `GetUserProfileUseCase` | 獲取用戶資料 (支援緩存) | `forceRefresh: Bool` | `profile: User, fromCache: Bool` |
| `UpdateUserProfileUseCase` | 更新用戶資料 | `updates: [String: Any]` | `updatedProfile: User` |
| `GetHeartRateZonesUseCase` | 獲取心率區間 | - | `zones: [HeartRateZone], maxHR, restingHR` |
| `UpdateHeartRateZonesUseCase` | 更新心率參數並重算區間 | `maxHR: Int, restingHR: Int` | `zones: [HeartRateZone]` |
| `GetUserTargetsUseCase` | 獲取比賽目標 | - | `targets: [Target], mainRace: Target?` |
| `CreateTargetUseCase` | 創建新目標 | `target: Target` | - |
| `SyncUserPreferencesUseCase` | 從用戶資料同步偏好 | `user: User` | - |
| `CalculateUserStatsUseCase` | 計算用戶統計 | - | `statistics: UserStatistics?` |

#### 關鍵實現特色

1. **雙軌緩存策略** (Dual-Track Caching)
   - Track A: 立即返回緩存資料
   - Track B: 背景更新最新資料

2. **心率區間計算** (Heart Rate Reserve Formula)
   ```
   Zone HR = Resting HR + (Max HR - Resting HR) × Zone%
   ```

3. **Task 取消處理**
   - 所有 catch 區塊過濾 `SystemError.taskCancelled`
   - 避免錯誤顯示 ErrorView

4. **依賴注入**
   ```swift
   // 使用方式
   let viewModel = UserProfileFeatureViewModel()  // 自動註冊
   // 或
   let viewModel = DependencyContainer.shared.makeUserProfileFeatureViewModel()
   ```

---

### 2.3 下一步 - Views 遷移

#### 遷移範例
```swift
// ❌ 舊寫法
struct UserProfileView: View {
    @StateObject private var userManager = UserManager.shared
    @StateObject private var prefsManager = UserPreferencesManager.shared
}

// ✅ 新寫法
struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileFeatureViewModel()

    var body: some View {
        switch viewModel.profileState {
        case .loading:
            LoadingView()
        case .loaded(let user):
            ProfileContent(user: user)
        case .error(let error):
            ErrorView(error: error)
        }
    }
}
```

---

### 2.4 驗收標準

#### ✅ 已達成
- ✅ Repository Pattern 完整實現
- ✅ 8 個 Use Cases 實現 (超過目標 4 個)
- ✅ ViewModel 使用依賴注入
- ✅ 編譯成功 (0 errors)
- ✅ Task 取消錯誤處理
- ✅ 雙軌緩存策略實現
- ✅ 核心 UserProfile Views 遷移 (8/13)
- ✅ 廢棄標記完成 (UserManager, UserPreferencesManager, UserProfileViewModel)
- ✅ Backward compatibility properties 添加

#### 📋 待 Training Feature 完成
- [ ] 5 個 Training 相關 Views 遷移
- [ ] 單元測試覆蓋率 > 85%
- [ ] 整合測試覆蓋率 > 80%
- [ ] 最終刪除廢棄的 Managers (在所有 Features 完成後)

---

## Feature 3: VDOT Feature ⚠️

**優先級**: ⚠️ 中
**預計時間**: 3 個工作日
**複雜度**: ⭐⭐⭐ (中高)
**狀態**: 📋 規劃中

---

### 3.1 當前架構分析

#### 現有組件
- **Manager**: `VDOTManager.swift`
- **Service**: `VDOTService.swift`
- **ViewModel**: `VDOTViewMode.swift`, `VDOTChartViewModelV2.swift`

#### 主要問題
- ❌ VDOT 計算邏輯散落在 Manager 和 Service 中
- ❌ ViewModel 直接依賴 Manager Singleton
- ❌ 缺乏明確的業務邏輯封裝

---

### 3.2 目標架構設計

#### 目錄結構
```
Features/VDOT/
├── Domain/
│   ├── Repositories/
│   │   └── VDOTRepository.swift
│   ├── UseCases/
│   │   ├── CalculateVDOTUseCase.swift
│   │   ├── GetVDOTHistoryUseCase.swift
│   │   ├── PredictRaceTimeUseCase.swift
│   │   └── SuggestTrainingPaceUseCase.swift
│   └── Errors/
│       └── VDOTError.swift
│
├── Data/
│   ├── Repositories/
│   │   └── VDOTRepositoryImpl.swift
│   └── DataSources/
│       ├── VDOTRemoteDataSource.swift
│       └── VDOTLocalDataSource.swift
│
└── Presentation/
    └── ViewModels/
        └── VDOTViewModel.swift
```

#### Use Cases 定義

| Use Case | 職責 | 輸入 | 輸出 |
|---------|------|------|------|
| `CalculateVDOTUseCase` | 根據跑步成績計算 VDOT | `distance`, `time` | `VDOT` |
| `GetVDOTHistoryUseCase` | 獲取 VDOT 歷史趨勢 | `userId`, `dateRange` | `[VDOTRecord]` |
| `PredictRaceTimeUseCase` | 預測比賽完賽時間 | `vdot`, `distance` | `predictedTime` |
| `SuggestTrainingPaceUseCase` | 建議訓練配速 | `vdot`, `trainingType` | `paceRange` |

---

### 3.3 重構步驟清單

#### Phase 1: Domain Layer (Day 1)
- [ ] 創建 Domain 目錄結構
- [ ] 定義 `VDOTRepository.swift` 協議
- [ ] 定義 `VDOTError.swift` 錯誤類型
- [ ] 創建核心 Use Cases:
  - `CalculateVDOTUseCase.swift`
  - `PredictRaceTimeUseCase.swift`

#### Phase 2: Data Layer (Day 2)
- [ ] 創建 Data 目錄結構
- [ ] 實現 `VDOTRepositoryImpl.swift`
  - 整合 `VDOTManager` 和 `VDOTService`
- [ ] 創建 DataSources:
  - `VDOTRemoteDataSource.swift`
  - `VDOTLocalDataSource.swift`
- [ ] 實現剩餘 Use Cases:
  - `GetVDOTHistoryUseCase.swift`
  - `SuggestTrainingPaceUseCase.swift`

#### Phase 3: ViewModel & 測試 (Day 3)
- [ ] 重構 `VDOTViewModel`
- [ ] 更新 DI 註冊
- [ ] 單元測試 (覆蓋率 > 90%)
- [ ] 整合測試 (覆蓋率 > 80%)
- [ ] 回歸測試
- [ ] 更新文檔

---

### 3.4 驗收標準

#### 必須達成
- ✅ Repository Pattern 完整實現
- ✅ 至少 3 個 Use Cases 實現
- ✅ VDOT 計算邏輯準確無誤
- ✅ 單元測試覆蓋率 > 85%

---

## Feature 4: TrainingReadiness Feature ⚠️

**優先級**: ⚠️ 中
**預計時間**: 4 個工作日
**複雜度**: ⭐⭐⭐⭐ (高)
**狀態**: 📋 規劃中

---

### 4.1 當前架構分析

#### 現有組件
- **Manager**: `TrainingReadinessManager.swift`, `HRVManager.swift`
- **Service**: `TrainingReadinessService.swift`, `HealthDataService.swift`
- **ViewModel**: `TrainingReadinessViewModel.swift`, `HRVChartViewModelV2.swift`

#### 主要問題
- ❌ 數據來源複雜（HRV, Sleep, Workout, HealthKit）
- ❌ 準備度計算邏輯未封裝為 Use Case
- ❌ ViewModel 職責過重

---

### 4.2 目標架構設計

#### 目錄結構
```
Features/TrainingReadiness/
├── Domain/
│   ├── Repositories/
│   │   ├── TrainingReadinessRepository.swift
│   │   └── HealthDataRepository.swift
│   ├── UseCases/
│   │   ├── CalculateReadinessScoreUseCase.swift
│   │   ├── GetHRVTrendUseCase.swift
│   │   ├── GetSleepQualityUseCase.swift
│   │   └── AnalyzeRecoveryStatusUseCase.swift
│   └── Errors/
│       └── ReadinessError.swift
│
├── Data/
│   ├── Repositories/
│   │   ├── TrainingReadinessRepositoryImpl.swift
│   │   └── HealthDataRepositoryImpl.swift
│   └── DataSources/
│       ├── HealthDataRemoteDataSource.swift
│       └── HealthDataLocalDataSource.swift
│
└── Presentation/
    └── ViewModels/
        └── TrainingReadinessViewModel.swift
```

#### Use Cases 定義

| Use Case | 職責 | 輸入 | 輸出 |
|---------|------|------|------|
| `CalculateReadinessScoreUseCase` | 計算訓練準備度評分 | `userId`, `date` | `ReadinessScore` |
| `GetHRVTrendUseCase` | 獲取 HRV 趨勢分析 | `userId`, `dateRange` | `HRVTrend` |
| `GetSleepQualityUseCase` | 獲取睡眠質量數據 | `userId`, `date` | `SleepQuality` |
| `AnalyzeRecoveryStatusUseCase` | 分析恢復狀態 | `userId` | `RecoveryStatus` |

---

### 4.3 重構步驟清單

#### Phase 1: Domain Layer (Day 1)
- [ ] 創建 Domain 目錄結構
- [ ] 定義 Repositories:
  - `TrainingReadinessRepository.swift`
  - `HealthDataRepository.swift`
- [ ] 定義 `ReadinessError.swift`
- [ ] 創建核心 Use Cases:
  - `CalculateReadinessScoreUseCase.swift`
  - `GetHRVTrendUseCase.swift`

#### Phase 2: Data Layer (Day 2)
- [ ] 創建 Data 目錄結構
- [ ] 實現 Repositories:
  - `TrainingReadinessRepositoryImpl.swift`
  - `HealthDataRepositoryImpl.swift`
- [ ] 創建 DataSources:
  - `HealthDataRemoteDataSource.swift`
  - `HealthDataLocalDataSource.swift`

#### Phase 3: Use Cases (Day 3)
- [ ] 實現剩餘 Use Cases:
  - `GetSleepQualityUseCase.swift`
  - `AnalyzeRecoveryStatusUseCase.swift`
- [ ] 整合多數據源邏輯（HRV + Sleep + Workout）

#### Phase 4: ViewModel & 測試 (Day 4)
- [ ] 重構 `TrainingReadinessViewModel`
- [ ] 重構 `HRVChartViewModel`
- [ ] 更新 DI 註冊
- [ ] 單元測試 (覆蓋率 > 90%)
- [ ] 整合測試 (覆蓋率 > 80%)
- [ ] 回歸測試
- [ ] 更新文檔

---

### 4.4 驗收標準

#### 必須達成
- ✅ Repository Pattern 完整實現
- ✅ 至少 4 個 Use Cases 實現
- ✅ 準備度計算邏輯準確
- ✅ 多數據源整合正確
- ✅ 單元測試覆蓋率 > 85%

---

## Feature 5: Authentication Feature ⚠️

**優先級**: ⚠️ 中
**預計時間**: 3 個工作日
**複雜度**: ⭐⭐ (中)
**狀態**: 📋 規劃中

---

### 5.1 當前架構分析

#### 現有組件
- **Service**: `AuthenticationService.swift`, `EmailAuthService.swift`
- **ViewModel**: `EmailLoginViewModel.swift`, `RegisterEmailViewModel.swift`

#### 主要問題
- ❌ Token 管理邏輯散落
- ❌ 安全性考量不夠完善
- ❌ 缺乏明確的 Repository 層

---

### 5.2 目標架構設計

#### 目錄結構
```
Features/Authentication/
├── Domain/
│   ├── Repositories/
│   │   └── AuthenticationRepository.swift
│   ├── UseCases/
│   │   ├── LoginWithEmailUseCase.swift
│   │   ├── RegisterUserUseCase.swift
│   │   ├── RefreshTokenUseCase.swift
│   │   └── LogoutUseCase.swift
│   └── Errors/
│       └── AuthenticationError.swift
│
├── Data/
│   ├── Repositories/
│   │   └── AuthenticationRepositoryImpl.swift
│   └── DataSources/
│       ├── AuthenticationRemoteDataSource.swift
│       └── TokenStorageDataSource.swift
│
└── Presentation/
    └── ViewModels/
        ├── EmailLoginViewModel.swift
        └── RegisterEmailViewModel.swift
```

#### 安全性考量
- Token 存儲使用 Keychain
- 自動刷新 Token 機制
- 登出時清除所有敏感資料

---

### 5.3 重構步驟清單

#### Phase 1: Domain Layer (Day 1)
- [ ] 創建 Domain 目錄結構
- [ ] 定義 `AuthenticationRepository.swift` 協議
- [ ] 定義 `AuthenticationError.swift` 錯誤類型
- [ ] 創建 Use Cases:
  - `LoginWithEmailUseCase.swift`
  - `RegisterUserUseCase.swift`
  - `RefreshTokenUseCase.swift`
  - `LogoutUseCase.swift`

#### Phase 2: Data Layer (Day 2)
- [ ] 創建 Data 目錄結構
- [ ] 實現 `AuthenticationRepositoryImpl.swift`
  - 整合 `AuthenticationService`
  - Token 管理邏輯
- [ ] 創建 DataSources:
  - `AuthenticationRemoteDataSource.swift`
  - `TokenStorageDataSource.swift` (使用 Keychain)

#### Phase 3: ViewModel & 測試 (Day 3)
- [ ] 重構 ViewModels:
  - `EmailLoginViewModel.swift`
  - `RegisterEmailViewModel.swift`
- [ ] 更新 DI 註冊
- [ ] 單元測試 (覆蓋率 > 90%)
- [ ] 安全性測試
  - Token 存儲安全性
  - 自動刷新機制
  - 登出清除敏感資料
- [ ] 回歸測試
- [ ] 更新文檔

---

### 5.4 驗收標準

#### 必須達成
- ✅ Repository Pattern 完整實現
- ✅ 至少 4 個 Use Cases 實現
- ✅ Token 使用 Keychain 存儲
- ✅ 自動刷新 Token 機制正常
- ✅ 安全性測試通過
- ✅ 單元測試覆蓋率 > 85%

---

## Feature 6: Integration Features ℹ️

**優先級**: ℹ️ 低
**預計時間**: 4 個工作日
**複雜度**: ⭐⭐⭐ (中高)
**狀態**: 📋 規劃中

---

### 6.1 Garmin Integration (Day 1-2)

#### 目標架構
```
Features/GarminIntegration/
├── Domain/
│   ├── Repositories/
│   │   └── GarminRepository.swift
│   ├── UseCases/
│   │   ├── ConnectGarminAccountUseCase.swift
│   │   ├── DisconnectGarminAccountUseCase.swift
│   │   └── SyncGarminWorkoutsUseCase.swift
│   └── Errors/
│       └── GarminError.swift
│
├── Data/
│   ├── Repositories/
│   │   └── GarminRepositoryImpl.swift
│   └── DataSources/
│       └── GarminRemoteDataSource.swift
│
└── Presentation/
    └── ViewModels/
        └── GarminConnectionViewModel.swift
```

#### 重構步驟
- [ ] Day 1: Domain & Data Layer
- [ ] Day 2: Use Cases, ViewModel, 測試

---

### 6.2 Strava Integration (Day 3-4)

#### 目標架構
```
Features/StravaIntegration/
├── Domain/
│   ├── Repositories/
│   │   └── StravaRepository.swift
│   ├── UseCases/
│   │   ├── ConnectStravaAccountUseCase.swift
│   │   ├── DisconnectStravaAccountUseCase.swift
│   │   └── SyncStravaWorkoutsUseCase.swift
│   └── Errors/
│       └── StravaError.swift
│
├── Data/
│   ├── Repositories/
│   │   └── StravaRepositoryImpl.swift
│   └── DataSources/
│       └── StravaRemoteDataSource.swift
│
└── Presentation/
    └── ViewModels/
        └── StravaConnectionViewModel.swift
```

#### 重構步驟
- [ ] Day 3: Domain & Data Layer
- [ ] Day 4: Use Cases, ViewModel, 測試

---

### 6.3 驗收標準

#### 必須達成
- ✅ Garmin 連接/斷開功能正常
- ✅ Strava 連接/斷開功能正常
- ✅ 訓練記錄同步正確
- ✅ Repository Pattern 完整實現
- ✅ 單元測試覆蓋率 > 80%

---

## 通用重構檢查清單

所有 Features 重構時必須檢查：

### Domain Layer ✅
- [ ] Repository Protocol 定義清晰
- [ ] Use Cases 職責單一
- [ ] 錯誤類型完整定義
- [ ] 無外部依賴（純業務邏輯）

### Data Layer ✅
- [ ] Repository Implementation 正確
- [ ] DataSources 職責明確
- [ ] 雙軌緩存策略實現（如適用）
- [ ] 錯誤處理完整

### Presentation Layer ✅
- [ ] ViewModel 使用依賴注入
- [ ] 移除對 Singleton 的依賴
- [ ] 統一狀態管理
- [ ] UI 邏輯與業務邏輯分離

### DI Container ✅
- [ ] `register{Feature}Module()` 方法創建
- [ ] Use Case 工廠方法創建
- [ ] 依賴生命週期管理正確

### 測試 ✅
- [ ] Use Cases 單元測試 (覆蓋率 > 90%)
- [ ] Repository 整合測試 (覆蓋率 > 80%)
- [ ] ViewModel 測試 (覆蓋率 > 80%)
- [ ] 回歸測試通過

### 文檔 ✅
- [ ] 架構文檔創建
- [ ] API 文檔更新
- [ ] 測試報告生成

---

**文檔版本**: 1.0
**撰寫日期**: 2026-01-03
**維護者**: Paceriz iOS Team
**參考**: ARCH-005 TrainingPlan Reference Implementation
