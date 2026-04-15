# ARCH-005: TrainingPlan Feature - Clean Architecture 參考實現

**版本**: 1.0
**最後更新**: 2026-01-03
**狀態**: ✅ 已實現

---

## 概述

本文檔以 TrainingPlan Feature 作為 Clean Architecture 的**參考實現**，為其他 Feature 的重構提供具體範例和最佳實踐。

TrainingPlan Feature 完整展示了：
- **分層架構**: Presentation → Domain → Data
- **依賴注入**: 使用 DependencyContainer
- **Use Case 模式**: 封裝業務邏輯
- **Repository Pattern**: 抽象數據來源

---

## 目錄結構

```
Features/TrainingPlan/
├── Domain/                          # 領域層（核心業務邏輯）
│   ├── Repositories/
│   │   ├── TrainingPlanRepository.swift    # Repository 協議
│   │   └── WorkoutRepository.swift         # Workout 資料協議
│   ├── UseCases/
│   │   ├── LoadWeeklyWorkoutsUseCase.swift # 載入週訓練記錄
│   │   └── AggregateWorkoutMetricsUseCase.swift # 聚合訓練指標
│   └── Errors/
│       └── TrainingPlanError.swift         # 領域錯誤定義
│
├── Data/                            # 數據層（實現細節）
│   ├── Repositories/
│   │   ├── TrainingPlanRepositoryImpl.swift # Repository 實現
│   │   └── WorkoutRepositoryImpl.swift      # Workout Repository 實現
│   └── DataSources/
│       ├── TrainingPlanRemoteDataSource.swift # 遠端資料來源
│       └── TrainingPlanLocalDataSource.swift  # 本地緩存
│
└── Presentation/                    # 表現層
    └── ViewModels/
        ├── TrainingPlanViewModel.swift      # 主協調 ViewModel
        ├── WeeklyPlanViewModel.swift        # 週計畫 ViewModel
        └── WeeklySummaryViewModel.swift     # 週回顧 ViewModel
```

---

## 核心架構模式

### 1. Repository Protocol（領域層）

**位置**: `Domain/Repositories/`

Repository 協議定義於 Domain 層，**只包含介面，不涉及實現細節**。

```swift
// ✅ CORRECT: Domain Layer 只定義協議
protocol TrainingPlanRepository {
    // 讀取操作
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func getOverview() async throws -> TrainingPlanOverview
    func getPlanStatus() async throws -> PlanStatusResponse

    // 寫入操作
    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan
    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary

    // 刷新操作（跳過緩存）
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func refreshPlanStatus() async throws -> PlanStatusResponse

    // 緩存管理
    func clearCache() async
}
```

**關鍵原則**:
- 協議只包含業務操作的抽象定義
- 不包含任何 HTTP、緩存、序列化等實現細節
- 返回 Domain Entity（如 `WeeklyPlan`），而非 DTO

---

### 2. Repository Implementation（數據層）

**位置**: `Data/Repositories/`

Repository 實現封裝了**數據獲取策略**，包括：
- 遠端 API 調用
- 本地緩存
- 雙軌緩存策略

```swift
// ✅ CORRECT: Data Layer 實現協議
final class TrainingPlanRepositoryImpl: TrainingPlanRepository {

    // MARK: - Dependencies
    private let remoteDataSource: TrainingPlanRemoteDataSource
    private let localDataSource: TrainingPlanLocalDataSource

    // MARK: - Dual-Track Caching
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        // Track A: 立即返回緩存
        if let cached = localDataSource.getWeeklyPlan(planId: planId) {
            // Track B: 背景刷新
            Task.detached { [weak self] in
                try? await self?.refreshWeeklyPlan(planId: planId)
            }
            return cached
        }

        // 沒有緩存時，從 API 獲取
        let plan = try await remoteDataSource.fetchWeeklyPlan(planId: planId)
        localDataSource.saveWeeklyPlan(plan, planId: planId)
        return plan
    }
}
```

**雙軌緩存策略說明**:

```
用戶請求數據
    ↓
[檢查本地緩存]
    ↓
┌─────────────────────────────┐
│ 有緩存                       │ 無緩存
│ Track A: 立即返回緩存 (同步)   │ 直接從 API 獲取
│ Track B: 背景刷新 (非同步)     │
└─────────────────────────────┘
    ↓                          ↓
UI 立即顯示                   等待 API 響應
背景更新後自動刷新             完成後顯示
```

---

### 3. Use Case 模式（領域層）

**位置**: `Domain/UseCases/`

Use Case 封裝**單一業務操作**，是 Clean Architecture 的核心。

```swift
// ✅ CORRECT: Use Case 封裝業務邏輯
struct LoadWeeklyWorkoutsUseCase {

    // MARK: - Dependencies（通過初始化注入）
    private let workoutRepository: WorkoutRepository

    init(workoutRepository: WorkoutRepository) {
        self.workoutRepository = workoutRepository
    }

    // MARK: - Execute（單一入口點）
    func execute(
        weekInfo: WeekDateInfo,
        activityTypes: Set<String> = ["running", "walking", "hiking"]
    ) -> [Int: [WorkoutV2]] {
        // 1. 從 Repository 獲取原始數據
        let workouts = workoutRepository.getWorkoutsInDateRange(
            startDate: weekInfo.startDate,
            endDate: weekInfo.endDate
        )

        // 2. 執行業務邏輯（按天分組）
        return groupWorkoutsByDay(workouts, weekInfo: weekInfo, activityTypes: activityTypes)
    }

    // MARK: - Private Business Logic
    private func groupWorkoutsByDay(...) -> [Int: [WorkoutV2]] {
        // 純粹的業務邏輯，無外部依賴
    }
}
```

**Use Case 設計原則**:

| 原則 | 說明 |
|-----|------|
| **單一職責** | 每個 Use Case 只做一件事 |
| **無副作用** | 不直接修改 UI 狀態 |
| **可測試** | 所有依賴通過初始化注入 |
| **命名規範** | `動詞 + 名詞 + UseCase`（如 `LoadWeeklyWorkoutsUseCase`） |

---

### 4. ViewModel 組合模式（表現層）

**位置**: `Presentation/ViewModels/`

ViewModel 負責**協調 Use Cases 和管理 UI 狀態**。

```swift
// ✅ CORRECT: ViewModel 組合 Use Cases
@MainActor
class TrainingPlanViewModel: ObservableObject {

    // MARK: - Dependencies（通過 DI 注入）
    private let repository: TrainingPlanRepository
    private let loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase
    private let aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase

    // MARK: - Child ViewModels（組合模式）
    @Published var weeklyPlanVM: WeeklyPlanViewModel
    @Published var summaryVM: WeeklySummaryViewModel

    // MARK: - UI State
    @Published var planStatus: PlanStatus = .loading
    @Published var workoutsByDayV2: [Int: [WorkoutV2]] = [:]
    @Published var currentWeekDistance: Double = 0.0
    @Published var currentWeekIntensity: WeeklyPlan.IntensityTotalMinutes = .init(low: 0, medium: 0, high: 0)

    // MARK: - Initialization with DI
    init(
        repository: TrainingPlanRepository,
        loadWeeklyWorkoutsUseCase: LoadWeeklyWorkoutsUseCase,
        aggregateWorkoutMetricsUseCase: AggregateWorkoutMetricsUseCase,
        weeklyPlanVM: WeeklyPlanViewModel? = nil,
        summaryVM: WeeklySummaryViewModel? = nil
    ) {
        self.repository = repository
        self.loadWeeklyWorkoutsUseCase = loadWeeklyWorkoutsUseCase
        self.aggregateWorkoutMetricsUseCase = aggregateWorkoutMetricsUseCase
        self.weeklyPlanVM = weeklyPlanVM ?? WeeklyPlanViewModel(repository: repository)
        self.summaryVM = summaryVM ?? WeeklySummaryViewModel(repository: repository)

        setupBindings()
    }

    // MARK: - Convenience Init (with DI Container)
    convenience init() {
        let container = DependencyContainer.shared

        // 確保模組已註冊
        if !container.isRegistered(TrainingPlanRepository.self) {
            container.registerTrainingPlanModule()
        }
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        // 解析依賴
        let repository: TrainingPlanRepository = container.resolve()
        let loadUseCase = container.makeLoadWeeklyWorkoutsUseCase()
        let aggregateUseCase = container.makeAggregateWorkoutMetricsUseCase()

        self.init(
            repository: repository,
            loadWeeklyWorkoutsUseCase: loadUseCase,
            aggregateWorkoutMetricsUseCase: aggregateUseCase
        )
    }

    // MARK: - Business Operations（使用 Use Cases）
    func loadWorkoutsForCurrentWeek() async {
        guard let weekInfo = getWeekInfo() else { return }

        // ✅ 使用 Use Case 執行業務邏輯
        let grouped = loadWeeklyWorkoutsUseCase.execute(weekInfo: weekInfo)

        await MainActor.run {
            self.workoutsByDayV2 = grouped
        }

        await loadCurrentWeekMetrics()
    }

    private func loadCurrentWeekMetrics() async {
        guard let weekInfo = getWeekInfo() else { return }

        // ✅ 使用 Use Case 計算指標
        let metrics = aggregateWorkoutMetricsUseCase.execute(weekInfo: weekInfo)

        await MainActor.run {
            self.currentWeekDistance = metrics.totalDistanceKm
            self.currentWeekIntensity = metrics.intensity
        }
    }
}
```

**ViewModel 職責邊界**:

| ✅ ViewModel 應該做 | ❌ ViewModel 不應該做 |
|-------------------|---------------------|
| 協調 Use Cases | 直接訪問 HTTP/Database |
| 管理 UI 狀態 | 實現業務邏輯 |
| 處理用戶交互事件 | 知道具體的 API 端點 |
| 轉換 Domain 數據為 UI 格式 | 處理 JSON 序列化 |

---

### 5. 依賴注入（DependencyContainer）

**位置**: `Core/DI/DependencyContainer.swift`

使用 DependencyContainer 管理所有依賴的生命週期。

```swift
// ✅ CORRECT: 模組化註冊
extension DependencyContainer {

    /// 註冊 TrainingPlan 模組的所有依賴
    func registerTrainingPlanModule() {
        guard !isRegistered(TrainingPlanRepository.self) else { return }

        // 1. 註冊 DataSources
        let remoteDataSource = TrainingPlanRemoteDataSource()
        let localDataSource = TrainingPlanLocalDataSource()
        register(remoteDataSource, for: TrainingPlanRemoteDataSource.self)
        register(localDataSource, for: TrainingPlanLocalDataSource.self)

        // 2. 註冊 Repository
        let repository = TrainingPlanRepositoryImpl(
            remoteDataSource: remoteDataSource,
            localDataSource: localDataSource
        )
        register(repository as TrainingPlanRepository, forProtocol: TrainingPlanRepository.self)
    }

    /// 註冊 Workout 模組
    func registerWorkoutModule() {
        guard !isRegistered(WorkoutRepository.self) else { return }

        let repository = WorkoutRepositoryImpl.shared
        register(repository as WorkoutRepository, forProtocol: WorkoutRepository.self)
    }

    /// 創建 Use Case 工廠方法
    func makeLoadWeeklyWorkoutsUseCase() -> LoadWeeklyWorkoutsUseCase {
        if !isRegistered(WorkoutRepository.self) {
            registerWorkoutModule()
        }
        let repository: WorkoutRepository = resolve()
        return LoadWeeklyWorkoutsUseCase(workoutRepository: repository)
    }
}
```

**DI 最佳實踐**:

1. **模組化註冊**: 每個 Feature 有自己的 `registerXxxModule()` 方法
2. **惰性註冊**: 只在需要時註冊依賴
3. **Protocol 註冊**: 使用 `forProtocol:` 註冊協議類型
4. **工廠方法**: Use Cases 使用工廠方法創建

---

## 數據流圖

### 完整數據流

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                        │
│  ┌──────────────────┐     ┌─────────────────────────────────┐   │
│  │  TrainingPlanView │────▶│   TrainingPlanViewModel          │   │
│  └──────────────────┘     │   ├── weeklyPlanVM               │   │
│                           │   ├── summaryVM                   │   │
│                           │   ├── loadWeeklyWorkoutsUseCase  │   │
│                           │   └── aggregateMetricsUseCase    │   │
│                           └─────────────┬───────────────────┘   │
└─────────────────────────────────────────┼───────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Domain Layer                             │
│  ┌───────────────────────────────┐  ┌────────────────────────┐  │
│  │  LoadWeeklyWorkoutsUseCase    │  │  AggregateMetricsUseCase│  │
│  │  - execute(weekInfo)          │  │  - execute(weekInfo)    │  │
│  └───────────────┬───────────────┘  └───────────┬────────────┘  │
│                  │                               │               │
│                  ▼                               ▼               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  WorkoutRepository (Protocol)                              │  │
│  │  TrainingPlanRepository (Protocol)                         │  │
│  └───────────────────────────────┬───────────────────────────┘  │
└──────────────────────────────────┼──────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Data Layer                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  WorkoutRepositoryImpl                                       ││
│  │  TrainingPlanRepositoryImpl                                  ││
│  │  ├── remoteDataSource (HTTP API)                            ││
│  │  └── localDataSource (UserDefaults/Cache)                   ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## 命名規範

### 文件命名

| 類型 | 命名格式 | 範例 |
|-----|---------|------|
| Repository Protocol | `{Feature}Repository.swift` | `TrainingPlanRepository.swift` |
| Repository Impl | `{Feature}RepositoryImpl.swift` | `TrainingPlanRepositoryImpl.swift` |
| Use Case | `{動詞}{名詞}UseCase.swift` | `LoadWeeklyWorkoutsUseCase.swift` |
| ViewModel | `{Feature}ViewModel.swift` | `TrainingPlanViewModel.swift` |
| DataSource | `{Feature}{Remote/Local}DataSource.swift` | `TrainingPlanRemoteDataSource.swift` |

### 方法命名

| 操作類型 | 命名格式 | 範例 |
|---------|---------|------|
| 獲取（支援緩存） | `get{Entity}` | `getWeeklyPlan()` |
| 刷新（跳過緩存） | `refresh{Entity}` | `refreshWeeklyPlan()` |
| 創建 | `create{Entity}` | `createWeeklySummary()` |
| 更新 | `update{Entity}` | `updateModifications()` |
| 刪除 | `delete{Entity}` / `clear{Entity}` | `clearCache()` |

---

## 錯誤處理

### Domain 錯誤定義

```swift
// Domain/Errors/TrainingPlanError.swift
enum TrainingPlanError: Error, Equatable {
    case weeklyPlanNotFound(planId: String)
    case overviewNotFound
    case noPlan
    case invalidPlanStatus
    case cacheExpired
    case networkError(String)
    case parsingError(String)
}

// 轉換為通用 DomainError
extension TrainingPlanError {
    func toDomainError() -> DomainError {
        switch self {
        case .weeklyPlanNotFound(let planId):
            return .notFound("Weekly plan not found: \(planId)")
        case .networkError(let message):
            return .networkFailure(message)
        // ...
        }
    }
}
```

---

## 測試策略

### Use Case 測試

```swift
final class LoadWeeklyWorkoutsUseCaseTests: XCTestCase {

    func testExecute_ReturnsGroupedWorkouts() {
        // Given
        let mockRepository = MockWorkoutRepository()
        mockRepository.stubbedWorkouts = [/* test data */]
        let useCase = LoadWeeklyWorkoutsUseCase(workoutRepository: mockRepository)

        // When
        let result = useCase.execute(weekInfo: testWeekInfo)

        // Then
        XCTAssertEqual(result.keys.count, 3)  // 3 天有訓練
    }
}
```

### ViewModel 測試

```swift
final class TrainingPlanViewModelTests: XCTestCase {

    func testLoadWorkouts_UpdatesState() async {
        // Given
        let mockRepository = MockTrainingPlanRepository()
        let mockLoadUseCase = MockLoadWeeklyWorkoutsUseCase()
        let viewModel = TrainingPlanViewModel(
            repository: mockRepository,
            loadWeeklyWorkoutsUseCase: mockLoadUseCase,
            aggregateWorkoutMetricsUseCase: MockAggregateUseCase()
        )

        // When
        await viewModel.loadWorkoutsForCurrentWeek()

        // Then
        XCTAssertFalse(viewModel.workoutsByDayV2.isEmpty)
    }
}
```

---

## 重構其他 Feature 的檢查清單

當重構其他 Feature 到 Clean Architecture 時，確保：

### 1. Domain Layer
- [ ] 創建 `{Feature}Repository.swift` 協議
- [ ] 創建必要的 Use Cases（每個業務操作一個）
- [ ] 定義 `{Feature}Error.swift` 錯誤類型

### 2. Data Layer
- [ ] 創建 `{Feature}RepositoryImpl.swift` 實現
- [ ] 創建 `{Feature}RemoteDataSource.swift`
- [ ] 創建 `{Feature}LocalDataSource.swift`（如需緩存）
- [ ] 實現雙軌緩存策略（如適用）

### 3. Presentation Layer
- [ ] 重構 ViewModel 使用 Use Cases
- [ ] 移除 ViewModel 對 Service/Manager 的直接依賴
- [ ] 所有依賴通過初始化注入

### 4. DI Container
- [ ] 創建 `register{Feature}Module()` 方法
- [ ] 創建 Use Case 工廠方法
- [ ] 在 App 啟動時註冊模組

---

## 常見問題

### Q: 什麼時候需要創建 Use Case？

**A**: 當業務邏輯需要被：
- 多個 ViewModel 共用
- 單獨測試
- 明確命名和文檔化

簡單的 CRUD 操作可以直接通過 Repository。

### Q: ViewModel 可以直接調用 Repository 嗎？

**A**: 可以，但建議：
- 簡單讀寫：直接調用 Repository
- 複雜邏輯：封裝為 Use Case

### Q: DataSource 和 Repository 的區別？

**A**:
- **DataSource**: 處理單一數據來源（API 或本地存儲）
- **Repository**: 協調多個 DataSource，決定數據策略

---

**文檔版本**: 1.0
**撰寫日期**: 2026-01-03
**維護者**: Paceriz iOS Team
