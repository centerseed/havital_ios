# FRD-006: Manager 層重構為 UseCase 層

**版本**: 2.0
**最後更新**: 2025-12-31
**狀態**: 🔄 規劃中
**優先級**: ⚠️ Medium
**預估工作量**: 3-5 天

---

## 功能概述

將當前的 Manager 層重構為標準 Clean Architecture 的 UseCase 層，解決命名混淆和職責不清的問題，使架構符合 Clean Architecture 規範。

---

## 問題陳述

### 當前架構問題

#### 1. 命名混淆
當前架構使用 "Manager" 作為層級名稱，但這**不是** Clean Architecture 的標準術語：

```
當前架構：
View → ViewModel → Manager → Repository → DataSource
                    ↑
                 這實際上是 UseCase！
```

**正確的 Clean Architecture 應該是：**
```
View → ViewModel → UseCase → Repository → DataSource
                    ↑
              Domain Layer 的核心
```

#### 2. 職責不清

當前 Manager 混合了多種職責：
- **Use Case 職責**：封裝業務邏輯流程
- **狀態管理**：持有 `@Published` 屬性
- **協調器職責**：協調多個 Repository 操作
- **快取策略**：實現雙軌快取邏輯

這違反了**單一職責原則**（Single Responsibility Principle）。

#### 3. 違反 Clean Architecture 分層

當前 Manager 層的問題：

| 問題 | 影響 | 範例 |
|------|------|------|
| **Manager 同時處理業務邏輯和狀態** | 難以測試、難以重用 | `UserManager` 既有業務邏輯又有 `@Published` 屬性 |
| **一個 Manager 包含多個 Use Case** | 違反單一職責原則 | `UnifiedWorkoutManager` 包含同步、上傳、獲取統計等多個業務流程 |
| **難以在 ViewModel 間重用業務邏輯** | 代碼重複 | 多個 ViewModel 需要相同的業務流程時無法共享 |

---

## 業務目標

### 核心目標

1. **正確的架構命名**：將 Manager 重命名為 UseCase，符合 Clean Architecture 標準
2. **職責分離**：UseCase 僅負責業務邏輯，狀態管理回歸 ViewModel
3. **提高可重用性**：UseCase 可在多個 ViewModel 間共享
4. **提高可測試性**：UseCase 獨立測試，無需依賴 ViewModel 或 UI

### 成功指標

- 所有 Manager 類別重構為 UseCase
- UseCase 單元測試覆蓋率 > 90%
- ViewModel 代碼行數減少 30%（業務邏輯移到 UseCase）
- 業務邏輯可在多個 ViewModel 間重用

---

## 當前 Manager 分析

### 現有 Manager 清單

根據 `Havital/Managers/` 目錄分析，共有 **32 個 Manager 文件**：

#### 核心業務 Managers（應轉為 UseCase）

| Manager | 職責 | 對應的 UseCase 類別 |
|---------|------|-------------------|
| **UserManager** | 用戶資料獲取、認證、個人最佳成績 | `features/user/domain/usecases/` |
| **UnifiedWorkoutManager** | 訓練記錄同步、HealthKit 整合 | `features/workout/domain/usecases/` |
| **TrainingPlanManager** | 訓練計劃生成、週計劃管理 | `features/training_plan/domain/usecases/` |
| **TargetManager** | 賽事目標 CRUD | `features/target/domain/usecases/` |
| **WeeklySummaryManager** | 每週總結計算 | `features/training_plan/domain/usecases/` |
| **VDOTManager** | VDOT 計算與更新 | `features/user/domain/usecases/` |
| **HRVManager** | HRV 數據管理 | `features/user/domain/usecases/` |
| **TrainingReadinessManager** | 訓練準備度計算 | `features/training_plan/domain/usecases/` |
| **TrainingIntensityManager** | 訓練強度計算 | `features/training_plan/domain/usecases/` |
| **HeartRateZonesManager** | 心率區間計算 | `features/user/domain/usecases/` |
| **WeeklyVolumeManager** | 每週訓練量計算 | `features/training_plan/domain/usecases/` |

#### 基礎設施 Managers（保留或移到 Core）

| Manager | 職責 | 處置方式 |
|---------|------|---------|
| **HealthKitManager** | HealthKit 框架封裝 | 移到 `Core/HealthKit/` |
| **GarminManager** | Garmin SDK 封裝 | 移到 `Core/Integration/Garmin/` |
| **StravaManager** | Strava SDK 封裝 | 移到 `Core/Integration/Strava/` |
| **LanguageManager** | 多語言管理 | 移到 `Core/Localization/` |
| **AppStateManager** | App 生命週期管理 | 移到 `Core/App/` |
| **FeatureFlagManager** | 功能開關管理 | 移到 `Core/FeatureFlags/` |

#### 協調器 Managers（移到 Core/Coordinators）

| Manager | 職責 | 處置方式 |
|---------|------|---------|
| **OnboardingCoordinator** | 新用戶引導流程 | 移到 `Core/Coordinators/` |
| **OnboardingBackfillCoordinator** | 新用戶數據回填 | 移到 `Core/Coordinators/` |
| **HealthKitObserverCoordinator** | HealthKit 觀察器協調 | 移到 `Core/HealthKit/` |
| **WorkoutBackgroundManager** | 背景任務管理 | 移到 `Core/BackgroundTasks/` |

#### 輔助 Managers（保留或移到對應位置）

| Manager | 職責 | 處置方式 |
|---------|------|---------|
| **CalendarManager** | 日曆計算 | 移到 `Core/Utils/` |
| **SyncNotificationManager** | 同步通知 | 移到 `Core/Notifications/` |
| **AppRatingManager** | App 評分提示 | 移到 `Core/App/` |
| **UserPreferencesManager** | 用戶偏好設定 | 移到 `features/user/domain/usecases/` |
| **HealthDataUploadManagerV2** | 健康數據上傳 | 合併到 `features/workout/domain/usecases/` |
| **HeartRateZonesBridge** | 心率區間橋接 | 移到 `Core/Utils/` |

---

## 目標架構設計

### Clean Architecture 分層

```
📱 Presentation Layer
   ├─ Views (SwiftUI)
   └─ ViewModels (@MainActor, @Published state)
      ↓ 調用
🎯 Domain Layer
   ├─ Entities (Models)
   ├─ Repository Protocols
   └─ UseCases (業務邏輯封裝)
      ↓ 調用
💾 Data Layer
   ├─ Repository Implementations
   └─ DataSources (Remote/Local)
      ↓ 調用
🔧 Core Layer (橫跨所有 Feature)
   ├─ Networking (HTTPClient, APIParser)
   ├─ Storage (BaseCacheManager)
   ├─ HealthKit (HealthKitManager)
   ├─ Integration (Garmin, Strava)
   └─ Utils (共用工具)
```

### UseCase 設計原則

#### 1. 單一職責原則

每個 UseCase 封裝**單一業務流程**：

```swift
// ✅ CORRECT - 單一職責
class GetUserProfileUseCase {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute() async throws -> User {
        return try await repository.getUserProfile()
    }
}

// ✅ CORRECT - 另一個單一職責
class RefreshUserProfileUseCase {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute() async throws -> User {
        return try await repository.refreshUserProfile()
    }
}
```

#### 2. 依賴注入

UseCase 通過構造函數注入依賴：

```swift
// ✅ CORRECT - 構造函數注入
class SyncWorkoutsUseCase {
    private let workoutRepository: WorkoutRepository
    private let healthKitManager: HealthKitManager

    init(
        workoutRepository: WorkoutRepository,
        healthKitManager: HealthKitManager
    ) {
        self.workoutRepository = workoutRepository
        self.healthKitManager = healthKitManager
    }

    func execute(startDate: Date, endDate: Date) async throws -> [WorkoutV2] {
        // 1. 從 HealthKit 獲取資料
        let hkWorkouts = try await healthKitManager.fetchWorkouts(
            startDate: startDate,
            endDate: endDate
        )

        // 2. 轉換為領域模型
        let workouts = hkWorkouts.map { WorkoutV2(from: $0) }

        // 3. 批量上傳
        let result = try await workoutRepository.batchUploadWorkouts(workouts)

        return workouts
    }
}
```

#### 3. 無狀態設計

UseCase **不應該**持有 `@Published` 狀態，狀態管理由 ViewModel 負責：

```swift
// ❌ WRONG - UseCase 不應該有 @Published
class GetUserProfileUseCase: ObservableObject {
    @Published var user: User?  // ❌ 錯誤！
    @Published var isLoading = false  // ❌ 錯誤！
}

// ✅ CORRECT - 狀態管理在 ViewModel
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false

    private let getUserProfileUseCase: GetUserProfileUseCase

    func loadProfile() async {
        isLoading = true
        do {
            let user = try await getUserProfileUseCase.execute()
            await MainActor.run { self.user = user }
        } catch {
            // 處理錯誤
        }
        isLoading = false
    }
}
```

#### 4. 可組合設計

複雜業務流程可由多個 UseCase 組合：

```swift
// ✅ CORRECT - 組合多個 UseCase
class CompleteOnboardingUseCase {
    private let getUserProfileUseCase: GetUserProfileUseCase
    private let syncWorkoutsUseCase: SyncWorkoutsUseCase
    private let generateTrainingPlanUseCase: GenerateTrainingPlanUseCase

    init(
        getUserProfileUseCase: GetUserProfileUseCase,
        syncWorkoutsUseCase: SyncWorkoutsUseCase,
        generateTrainingPlanUseCase: GenerateTrainingPlanUseCase
    ) {
        self.getUserProfileUseCase = getUserProfileUseCase
        self.syncWorkoutsUseCase = syncWorkoutsUseCase
        self.generateTrainingPlanUseCase = generateTrainingPlanUseCase
    }

    func execute() async throws {
        // 1. 獲取用戶資料
        let user = try await getUserProfileUseCase.execute()

        // 2. 同步訓練記錄
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate)!
        _ = try await syncWorkoutsUseCase.execute(startDate: startDate, endDate: endDate)

        // 3. 生成訓練計劃
        try await generateTrainingPlanUseCase.execute(targetId: user.primaryTargetId)
    }
}
```

---

## 功能需求

### 1. UseCase Protocol 定義

#### 1.1 標準 UseCase Protocol

```swift
/// 標準 UseCase 協議（有輸入參數）
protocol UseCase {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async throws -> Output
}
```

#### 1.2 NoInputUseCase Protocol

```swift
/// 無輸入參數的 UseCase 協議
protocol NoInputUseCase {
    associatedtype Output

    func execute() async throws -> Output
}
```

### 2. 具體 UseCase 實作範例

#### 2.1 User Domain UseCases

**目錄結構**：
```
features/user/domain/usecases/
├── GetUserProfileUseCase.swift
├── RefreshUserProfileUseCase.swift
├── UpdatePersonalBestUseCase.swift
├── UpdateDataSourceUseCase.swift
├── DeleteUserUseCase.swift
├── GetHRVDataUseCase.swift
├── GetVDOTUseCase.swift
└── CalculateHeartRateZonesUseCase.swift
```

**對應關係**：
- `UserManager.performLoadUserProfile()` → `GetUserProfileUseCase`
- `UserManager.performRefreshUserProfile()` → `RefreshUserProfileUseCase`
- `UserManager.updatePersonalBest()` → `UpdatePersonalBestUseCase`
- `HRVManager.loadHRVData()` → `GetHRVDataUseCase`
- `VDOTManager.calculateVDOT()` → `GetVDOTUseCase`
- `HeartRateZonesManager.calculateZones()` → `CalculateHeartRateZonesUseCase`

#### 2.2 Workout Domain UseCases

**目錄結構**：
```
features/workout/domain/usecases/
├── SyncWorkoutsUseCase.swift
├── UploadWorkoutUseCase.swift
├── BatchUploadWorkoutsUseCase.swift
├── GetWorkoutStatsUseCase.swift
├── GetWorkoutDetailUseCase.swift
├── DeleteWorkoutUseCase.swift
└── BackfillWorkoutsUseCase.swift
```

**對應關係**：
- `UnifiedWorkoutManager.syncWorkouts()` → `SyncWorkoutsUseCase`
- `UnifiedWorkoutManager.uploadWorkout()` → `UploadWorkoutUseCase`
- `UnifiedWorkoutManager.getWorkoutStats()` → `GetWorkoutStatsUseCase`
- `HealthDataUploadManagerV2.backfillWorkouts()` → `BackfillWorkoutsUseCase`

#### 2.3 Training Plan Domain UseCases

**目錄結構**：
```
features/training_plan/domain/usecases/
├── GetTrainingOverviewUseCase.swift
├── GetWeeklyPlanUseCase.swift
├── GenerateWeeklyPlanUseCase.swift
├── UpdateWeeklyPlanUseCase.swift
├── GetWeeklySummaryUseCase.swift
├── CalculateWeeklyVolumeUseCase.swift
├── CalculateTrainingReadinessUseCase.swift
└── CalculateTrainingIntensityUseCase.swift
```

**對應關係**：
- `TrainingPlanManager.loadTrainingOverview()` → `GetTrainingOverviewUseCase`
- `TrainingPlanManager.loadWeeklyPlan()` → `GetWeeklyPlanUseCase`
- `TrainingPlanManager.generatePlan()` → `GenerateWeeklyPlanUseCase`
- `WeeklySummaryManager.calculateSummary()` → `GetWeeklySummaryUseCase`
- `WeeklyVolumeManager.calculateVolume()` → `CalculateWeeklyVolumeUseCase`

### 3. ViewModel 整合

#### 3.1 重構前 vs 重構後

**重構前（使用 Manager）**：
```swift
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false

    private let userManager = UserManager.shared  // ❌ 使用 Singleton

    func loadProfile() async {
        isLoading = true
        // UserManager 內部處理業務邏輯
        await userManager.performLoadUserProfile()
        user = userManager.currentUser  // ❌ 從 Manager 取狀態
        isLoading = false
    }
}
```

**重構後（使用 UseCase）**：
```swift
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false

    private let getUserProfileUseCase: GetUserProfileUseCase  // ✅ 依賴注入

    init(getUserProfileUseCase: GetUserProfileUseCase) {
        self.getUserProfileUseCase = getUserProfileUseCase
    }

    func loadProfile() async {
        isLoading = true
        do {
            let user = try await getUserProfileUseCase.execute()
            await MainActor.run { self.user = user }
        } catch {
            // 處理錯誤
        }
        isLoading = false
    }
}
```

**優勢**：
- ✅ ViewModel 職責清晰：僅負責 UI 狀態管理
- ✅ UseCase 可測試：可注入 Mock Repository
- ✅ UseCase 可重用：其他 ViewModel 也可使用

#### 3.2 DI Container 註冊

```swift
// DependencyContainer.swift
class DependencyContainer {
    // MARK: - Repositories
    func makeUserRepository() -> UserRepository {
        return UserRepositoryImpl.shared
    }

    // MARK: - UseCases
    func makeGetUserProfileUseCase() -> GetUserProfileUseCase {
        return GetUserProfileUseCase(
            repository: makeUserRepository()
        )
    }

    func makeRefreshUserProfileUseCase() -> RefreshUserProfileUseCase {
        return RefreshUserProfileUseCase(
            repository: makeUserRepository()
        )
    }

    // MARK: - ViewModels
    func makeUserProfileViewModel() -> UserProfileViewModel {
        return UserProfileViewModel(
            getUserProfileUseCase: makeGetUserProfileUseCase()
        )
    }
}
```

---

## 非功能需求

### 可測試性

- UseCase 可獨立測試，無需 ViewModel
- UseCase 可使用 Mock Repository 測試
- 業務邏輯測試覆蓋率 > 90%

### 可重用性

- UseCase 可在多個 ViewModel 間重用
- UseCase 可組合形成更複雜的業務流程
- 業務邏輯集中管理，避免重複

### 可維護性

- 業務規則變更僅需修改 UseCase
- UseCase 職責單一，易於理解
- 新增業務邏輯易於擴展

---

## 遷移策略

### Phase 1: 建立 UseCase 基礎設施 (0.5 天)

1. 定義 UseCase 和 NoInputUseCase 協議
2. 在各 feature 下建立 `domain/usecases/` 目錄
3. 建立 UseCase 命名和組織規範文檔

### Phase 2: 重構核心業務 Managers (2 天)

**優先順序**：
1. **UserManager** → User Domain UseCases
2. **TargetManager** → Target Domain UseCases
3. **TrainingPlanManager** → Training Plan Domain UseCases
4. **UnifiedWorkoutManager** → Workout Domain UseCases

**每個 Manager 的重構步驟**：
1. 分析 Manager 中的業務方法
2. 為每個業務方法創建對應的 UseCase
3. 在 DI Container 註冊 UseCases
4. 更新 ViewModels 使用 UseCases
5. 刪除 Manager 類別

### Phase 3: 重構輔助 Managers (1 天)

將輔助 Managers 移到適當位置：
- 基礎設施 Managers → `Core/` 對應目錄
- 協調器 Managers → `Core/Coordinators/`
- 計算 Managers → 對應 feature 的 UseCases

### Phase 4: 整合測試與驗證 (0.5 天)

1. 編寫 UseCase 單元測試
2. 更新 ViewModel 測試使用 Mock UseCases
3. 執行整合測試驗證完整流程
4. 確認編譯無錯誤

### Phase 5: 文檔更新 (0.5 天)

1. 更新架構文檔
2. 更新開發規範
3. 更新 Code Review Checklist
4. 建立 UseCase 開發指南

---

## 驗收標準

### 功能驗收

- [ ] 所有核心業務 Managers 已轉為 UseCases
- [ ] 所有 ViewModels 使用 UseCases 而非 Managers
- [ ] DI Container 正確註冊所有 UseCases
- [ ] 基礎設施 Managers 移到 Core 層
- [ ] 編譯無錯誤，所有功能正常運行

### 測試驗收

- [ ] UseCase 單元測試覆蓋率 > 90%
- [ ] ViewModel 測試使用 Mock UseCases
- [ ] 整合測試驗證完整業務流程

### 代碼質量驗收

- [ ] ViewModel 代碼行數減少（業務邏輯移到 UseCase）
- [ ] UseCase 職責單一，無複雜分支
- [ ] 業務邏輯集中在 UseCase，無重複代碼
- [ ] 無 Singleton Managers（除基礎設施類）

### 架構驗收

- [ ] 符合 Clean Architecture 分層規範
- [ ] UseCase 命名和組織符合 Feature-First 原則
- [ ] 依賴方向正確：Presentation → Domain → Data

---

## 依賴關係

### 前置依賴

- ✅ Repository Pattern 已實作
- ✅ Feature-First 目錄結構已建立
- ✅ DI Container 已建立

### 後續影響

- 未來新增業務邏輯優先使用 UseCase
- 複雜業務流程可組合多個 UseCases
- ViewModel 僅負責 UI 狀態管理

---

## 風險與緩解措施

### 中風險

#### 風險 1: 大規模重構可能引入 Bug
**影響**: 業務邏輯遷移過程中可能引入錯誤
**緩解措施**:
- 逐個 Manager 重構，每次重構後測試
- 保留 Manager 代碼直到 UseCase 驗證完成
- 編寫完整的單元測試和整合測試

#### 風險 2: ViewModel 依賴變更影響現有代碼
**影響**: 大量 ViewModel 需要更新建構子
**緩解措施**:
- 使用 DI Container 集中管理依賴
- 逐步遷移，保持向後兼容
- 編寫遷移腳本自動化重構

### 低風險

#### 風險 3: UseCase 職責劃分不清
**影響**: UseCase 之間職責重疊或耦合
**緩解措施**:
- 遵循單一職責原則
- Code Review 確保職責清晰
- 定期重構，保持設計簡潔

---

## 設計決策

### 決策 1: 使用 Protocol 而非 Abstract Class

**原因**:
- Swift 偏好 Protocol-Oriented Programming
- 更靈活的組合能力
- 易於測試（Mock 實現）

### 決策 2: UseCase 不持有狀態

**原因**:
- 保持業務邏輯純粹性
- 提高可重用性
- 易於測試和並發使用

### 決策 3: 每個業務方法獨立為 UseCase

**原因**:
- 遵循單一職責原則
- 提高可組合性
- 易於理解和維護

### 決策 4: 保留基礎設施 Managers

**原因**:
- HealthKitManager、GarminManager 等封裝框架，不是業務邏輯
- 這些屬於 Core Layer，不是 Domain Layer
- 保持框架封裝的一致性

---

## 參考文檔

- [ARCH-002: Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [ARCH-003: 遷移路線圖](../01-architecture/ARCH-003-Migration-Roadmap.md)
- [FRD-001: Repository Pattern 實作](./FRD-001-Repository-Pattern.md)
- Flutter 版本: ARCH-002 分層架構設計（UseCase 模式參考）
- Clean Architecture by Robert C. Martin

---

**文檔版本**: 2.0
**撰寫日期**: 2025-12-31
**負責人**: iOS Team
**審核人**: Tech Lead
