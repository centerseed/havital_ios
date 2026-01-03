# ARCH-002: Clean Architecture 設計

**版本**: 1.0
**最後更新**: 2025-12-30
**狀態**: 🔄 規劃中

---

## 目錄

1. [目標架構概覽](#目標架構概覽)
2. [Presentation Layer 設計](#presentation-layer-設計)
3. [Domain Layer 設計](#domain-layer-設計)
4. [Data Layer 設計](#data-layer-設計)
5. [Core Layer 設計](#core-layer-設計)
6. [依賴注入策略](#依賴注入策略)
7. [完整範例](#完整範例)

---

## 目標架構概覽

### 四層架構

```
┌──────────────────────────────────────────────────────────┐
│                   Presentation Layer                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │  Views   │  │ViewModels│  │ViewState │               │
│  │ (SwiftUI)│  │(@Published│  │  Enum    │               │
│  │          │  │   state) │  │          │               │
│  └────┬─────┘  └────┬─────┘  └──────────┘               │
│       │             │ 使用                                │
│       └─────────────┼─────────────────────────────────────┤
│                     ▼                                     │
│                 Domain Layer                              │
│  ┌──────────┐  ┌──────────┐  ┌────────────────┐         │
│  │ Entities │  │ UseCases │  │ Repository     │         │
│  │ (Models) │  │(Business │  │ (Protocol)     │         │
│  │          │  │  Logic)  │  │                │         │
│  └──────────┘  └────┬─────┘  └───────┬────────┘         │
│                     │ 調用           │ 定義             │
├─────────────────────┼────────────────┼──────────────────┤
│                     ▼                ▼                   │
│                  Data Layer                              │
│  ┌──────────┐  ┌──────────────────────────┐             │
│  │   DTOs   │  │ Repository (Impl)        │             │
│  │          │  │  ├── Remote DataSource   │             │
│  │          │  │  │    (API 調用)         │             │
│  │          │  │  └── Local DataSource    │             │
│  └────┬─────┘  │       (Cache 管理)       │             │
│       │        └──────────────────────────┘             │
│       │ 轉換為 Entity                                    │
├───────┼──────────────────────────────────────────────────┤
│       ▼                                                  │
│    Core Layer                                            │
│  ┌─────────┐  ┌─────────┐  ┌──────┐  ┌────────┐        │
│  │HTTPClient│  │  Cache  │  │  DI  │  │ Utils  │        │
│  └─────────┘  └─────────┘  └──────┘  └────────┘        │
└──────────────────────────────────────────────────────────┘
```

### 依賴規則

**核心原則**: 依賴方向永遠向內 (從外層到內層)

```
Presentation → Domain → Data → Core
     ↓           ↓       ↓       ↓
   Views    Entities   DTOs   Network
ViewModels  UseCases  Repos   Cache
            Protocols
```

**依賴反轉**: Domain 層定義 Repository Protocol，Data 層實作

---

## Presentation Layer 設計

### 職責

- ✅ UI 渲染與用戶交互
- ✅ 綁定 ViewModel 狀態
- ✅ 處理用戶輸入
- ❌ **不應**包含業務邏輯
- ❌ **不應**直接調用 API

### 組件結構

```
features/
├── training_plan/
│   ├── presentation/
│   │   ├── views/
│   │   │   ├── TrainingPlanView.swift
│   │   │   ├── WeeklyPlanDetailView.swift
│   │   │   └── WorkoutCardView.swift
│   │   ├── viewmodels/
│   │   │   └── TrainingPlanViewModel.swift
│   │   └── states/
│   │       └── TrainingPlanViewState.swift
```

### ViewState 設計

**統一狀態枚舉** (取代多個 @Published 屬性):

```swift
/// 通用 View 狀態枚舉
enum ViewState<T> {
    case loading
    case loaded(T)
    case error(DomainError)
    case empty  // 可選: 無數據狀態
}

/// 擴展: 便利方法
extension ViewState {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var data: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: DomainError? {
        if case .error(let err) = self { return err }
        return nil
    }
}
```

### ViewModel 設計

**原則**:
- 僅包含 UI 狀態和 UI 邏輯
- 依賴 Repository Protocol (不依賴具體實作)
- 使用依賴注入 (非 Singleton)

**範例**: TrainingPlanViewModel

```swift
import SwiftUI
import Combine

/// Training Plan ViewModel
@MainActor
class TrainingPlanViewModel: ObservableObject {
    // MARK: - Published State

    /// 單一狀態源
    @Published var weeklyPlanState: ViewState<WeeklyPlan> = .loading
    @Published var overviewState: ViewState<TrainingPlanOverview> = .loading

    // MARK: - Dependencies

    private let repository: TrainingPlanRepository  // ✅ Protocol 依賴
    private let logger: Logger

    // MARK: - Initialization

    init(
        repository: TrainingPlanRepository,  // ✅ 依賴注入
        logger: Logger = Logger.shared
    ) {
        self.repository = repository
        self.logger = logger
    }

    // MARK: - Public Methods

    /// 載入週計畫
    func loadWeeklyPlan(planId: String) async {
        weeklyPlanState = .loading

        do {
            let plan = try await repository.getWeeklyPlan(planId: planId)
            weeklyPlanState = .loaded(plan)
            logger.debug("成功載入週計畫: \(planId)")
        } catch {
            let domainError = error.toDomainError()
            weeklyPlanState = .error(domainError)
            logger.error("載入週計畫失敗: \(domainError)")
        }
    }

    /// 刷新週計畫 (強制從 API)
    func refreshWeeklyPlan(planId: String) async {
        weeklyPlanState = .loading

        do {
            let plan = try await repository.refreshWeeklyPlan(planId: planId)
            weeklyPlanState = .loaded(plan)
        } catch {
            weeklyPlanState = .error(error.toDomainError())
        }
    }

    /// 生成新週計畫
    func generateWeeklyPlan(week: Int) async {
        weeklyPlanState = .loading

        do {
            let plan = try await repository.generateWeeklyPlan(week: week)
            weeklyPlanState = .loaded(plan)
        } catch {
            weeklyPlanState = .error(error.toDomainError())
        }
    }
}
```

### View 設計

**範例**: TrainingPlanView

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel

    // ✅ 依賴注入 ViewModel (由 DI Container 提供)
    init(viewModel: TrainingPlanViewModel = DependencyContainer.shared.resolve()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // ✅ 根據單一狀態源渲染 UI
        viewStateContent
            .onAppear {
                Task {
                    await viewModel.loadWeeklyPlan(planId: "plan_123_1")
                }.tracked(from: "TrainingPlanView: onAppear")
            }
            .refreshable {
                await Task {
                    await viewModel.refreshWeeklyPlan(planId: "plan_123_1")
                }.tracked(from: "TrainingPlanView: refreshable").value
            }
    }

    @ViewBuilder
    private var viewStateContent: some View {
        switch viewModel.weeklyPlanState {
        case .loading:
            ProgressView("載入中...")

        case .loaded(let plan):
            WeeklyPlanContentView(plan: plan)

        case .error(let error):
            ErrorView(
                error: error,
                retryAction: {
                    Task {
                        await viewModel.loadWeeklyPlan(planId: "plan_123_1")
                    }.tracked(from: "TrainingPlanView: retry")
                }
            )

        case .empty:
            EmptyStateView(message: "尚無訓練計畫")
        }
    }
}
```

---

## Domain Layer 設計

### 職責

- ✅ 定義業務實體 (Entities)
- ✅ 定義業務規則 (UseCases)
- ✅ 定義資料訪問介面 (Repository Protocols)
- ✅ 定義領域錯誤 (DomainError)
- ❌ **不依賴**外層 (Presentation)
- ❌ **不依賴**實作細節 (Data Layer)

### 組件結構

```
features/
├── training_plan/
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── TrainingPlanOverview.swift
│   │   │   ├── WeeklyPlan.swift
│   │   │   └── DailyWorkout.swift
│   │   ├── repositories/
│   │   │   └── TrainingPlanRepository.swift  // Protocol
│   │   ├── usecases/
│   │   │   ├── GetWeeklyPlanUseCase.swift
│   │   │   ├── GenerateWeeklyPlanUseCase.swift
│   │   │   └── RefreshWeeklyPlanUseCase.swift
│   │   └── errors/
│   │       └── TrainingPlanError.swift
```

### Entities (實體)

**定義業務模型** (不包含持久化邏輯):

```swift
/// 週計畫實體
struct WeeklyPlan {
    let id: String
    let weekOfPlan: Int
    let planId: String
    let dailyWorkouts: [DailyWorkout]
    let totalDistance: Double
    let totalDuration: Int

    // ✅ 業務邏輯方法
    func getWorkout(for date: Date) -> DailyWorkout? {
        dailyWorkouts.first { workout in
            Calendar.current.isDate(workout.date, inSameDayAs: date)
        }
    }

    var isRestWeek: Bool {
        dailyWorkouts.allSatisfy { $0.workoutType == .rest }
    }
}

/// 每日訓練實體
struct DailyWorkout {
    let id: String
    let date: Date
    let workoutType: WorkoutType
    let targetDistance: Double?
    let targetPace: Double?
    let description: String
}

enum WorkoutType: String {
    case easy = "輕鬆跑"
    case tempo = "節奏跑"
    case interval = "間歇跑"
    case long = "長距離"
    case rest = "休息"
}
```

### Repository Protocol

**定義資料訪問介面** (不包含實作細節):

```swift
/// Training Plan Repository Protocol
protocol TrainingPlanRepository {
    /// 獲取訓練計畫概覽
    func getOverview() async throws -> TrainingPlanOverview

    /// 獲取週計畫 (優先從緩存)
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan

    /// 刷新週計畫 (強制從 API)
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan

    /// 生成新週計畫
    func generateWeeklyPlan(week: Int) async throws -> WeeklyPlan

    /// 獲取當前週數
    func getCurrentWeek() async throws -> Int
}
```

### UseCases (用例)

**封裝單一業務流程** (可選，簡單情況下可直接使用 Repository):

```swift
/// 獲取週計畫 UseCase
class GetWeeklyPlanUseCase {
    private let repository: TrainingPlanRepository

    init(repository: TrainingPlanRepository) {
        self.repository = repository
    }

    /// 執行用例
    /// - Parameters:
    ///   - planId: 計畫 ID
    ///   - forceRefresh: 是否強制刷新
    func execute(planId: String, forceRefresh: Bool = false) async throws -> WeeklyPlan {
        if forceRefresh {
            return try await repository.refreshWeeklyPlan(planId: planId)
        }
        return try await repository.getWeeklyPlan(planId: planId)
    }
}

/// 生成週計畫 UseCase (包含複雜業務邏輯)
class GenerateWeeklyPlanUseCase {
    private let repository: TrainingPlanRepository
    private let validator: WeeklyPlanValidator

    init(
        repository: TrainingPlanRepository,
        validator: WeeklyPlanValidator = .shared
    ) {
        self.repository = repository
        self.validator = validator
    }

    func execute(week: Int) async throws -> WeeklyPlan {
        // 1. 驗證週數
        let currentWeek = try await repository.getCurrentWeek()
        guard validator.isValidWeek(week, currentWeek: currentWeek) else {
            throw TrainingPlanError.invalidWeek(week)
        }

        // 2. 生成計畫
        let plan = try await repository.generateWeeklyPlan(week: week)

        // 3. 驗證計畫內容
        guard validator.isValidPlan(plan) else {
            throw TrainingPlanError.invalidPlanContent
        }

        return plan
    }
}
```

### Domain Errors

**定義領域錯誤** (明確的錯誤類型):

```swift
enum DomainError: Error {
    case networkFailure(Error)
    case serverFailure(statusCode: Int, message: String)
    case cacheFailure
    case cancellationFailure
    case authFailure
    case validationFailure(String)
    case unknown(Error)
}

/// 擴展: 用戶友好訊息
extension DomainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return "網路連線失敗，請檢查網路設定"
        case .serverFailure(let code, let message):
            return "伺服器錯誤 (\(code)): \(message)"
        case .cacheFailure:
            return "本地資料讀取失敗"
        case .cancellationFailure:
            return "操作已取消"
        case .authFailure:
            return "認證失敗，請重新登入"
        case .validationFailure(let reason):
            return "資料驗證失敗: \(reason)"
        case .unknown(let error):
            return "未知錯誤: \(error.localizedDescription)"
        }
    }
}

/// 擴展: Error → DomainError 轉換
extension Error {
    func toDomainError() -> DomainError {
        if let domainError = self as? DomainError {
            return domainError
        }

        if let urlError = self as? URLError {
            switch urlError.code {
            case .cancelled:
                return .cancellationFailure
            default:
                return .networkFailure(urlError)
            }
        }

        return .unknown(self)
    }
}
```

---

## Data Layer 設計

### 職責

- ✅ 實作 Repository Protocol
- ✅ 協調 Remote 和 Local DataSource
- ✅ 實現雙軌緩存策略
- ✅ DTO → Entity 轉換
- ❌ **不包含**業務邏輯

### 組件結構

```
features/
├── training_plan/
│   ├── data/
│   │   ├── repositories/
│   │   │   └── TrainingPlanRepositoryImpl.swift
│   │   ├── datasources/
│   │   │   ├── remote/
│   │   │   │   └── TrainingPlanRemoteDataSource.swift
│   │   │   └── local/
│   │   │       └── TrainingPlanLocalDataSource.swift
│   │   ├── models/
│   │   │   ├── WeeklyPlanDTO.swift
│   │   │   └── TrainingPlanOverviewDTO.swift
│   │   └── mappers/
│   │       └── TrainingPlanMapper.swift
```

### Repository Implementation

**實作 Repository Protocol**:

```swift
/// Training Plan Repository 實作
class TrainingPlanRepositoryImpl: TrainingPlanRepository {
    // MARK: - Dependencies

    private let remoteDataSource: TrainingPlanRemoteDataSource
    private let localDataSource: TrainingPlanLocalDataSource
    private let mapper: TrainingPlanMapper
    private let logger: Logger

    // MARK: - Initialization

    init(
        remoteDataSource: TrainingPlanRemoteDataSource,
        localDataSource: TrainingPlanLocalDataSource,
        mapper: TrainingPlanMapper = .shared,
        logger: Logger = Logger.shared
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
        self.logger = logger
    }

    // MARK: - TrainingPlanRepository Implementation

    /// 獲取週計畫 (雙軌緩存策略)
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        // Track A: 檢查本地緩存
        if let cachedDTO = localDataSource.getWeeklyPlan(planId: planId),
           !localDataSource.isExpired(planId: planId) {
            logger.debug("從緩存載入週計畫: \(planId)")

            // 背景刷新 (Track B)
            Task.detached { [weak self] in
                await self?.refreshInBackground(planId: planId)
            }

            return mapper.mapToEntity(dto: cachedDTO)
        }

        // 無緩存: 從 API 載入
        logger.debug("從 API 載入週計畫: \(planId)")
        return try await fetchAndCacheWeeklyPlan(planId: planId)
    }

    /// 刷新週計畫 (強制從 API)
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        logger.debug("強制刷新週計畫: \(planId)")
        return try await fetchAndCacheWeeklyPlan(planId: planId)
    }

    /// 生成新週計畫
    func generateWeeklyPlan(week: Int) async throws -> WeeklyPlan {
        let dto = try await remoteDataSource.generateWeeklyPlan(week: week)
        localDataSource.saveWeeklyPlan(dto)
        return mapper.mapToEntity(dto: dto)
    }

    /// 獲取當前週數
    func getCurrentWeek() async throws -> Int {
        let overview = try await getOverview()
        return overview.currentWeek
    }

    func getOverview() async throws -> TrainingPlanOverview {
        // 類似的雙軌邏輯
        if let cachedDTO = localDataSource.getOverview(),
           !localDataSource.isOverviewExpired() {
            Task.detached { [weak self] in
                await self?.refreshOverviewInBackground()
            }
            return mapper.mapToEntity(dto: cachedDTO)
        }

        let dto = try await remoteDataSource.getOverview()
        localDataSource.saveOverview(dto)
        return mapper.mapToEntity(dto: dto)
    }

    // MARK: - Private Methods

    /// 從 API 獲取並緩存週計畫
    private func fetchAndCacheWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        let dto = try await remoteDataSource.getWeeklyPlan(planId: planId)
        localDataSource.saveWeeklyPlan(dto)
        return mapper.mapToEntity(dto: dto)
    }

    /// 背景刷新週計畫
    private func refreshInBackground(planId: String) async {
        do {
            let dto = try await remoteDataSource.getWeeklyPlan(planId: planId)
            localDataSource.saveWeeklyPlan(dto)
            logger.debug("背景刷新成功: \(planId)")
        } catch {
            logger.error("背景刷新失敗: \(error.localizedDescription)")
            // 背景刷新失敗不影響已顯示的緩存
        }
    }

    private func refreshOverviewInBackground() async {
        do {
            let dto = try await remoteDataSource.getOverview()
            localDataSource.saveOverview(dto)
        } catch {
            logger.error("背景刷新概覽失敗: \(error.localizedDescription)")
        }
    }
}
```

### Remote DataSource

**負責 API 調用**:

```swift
/// Training Plan Remote DataSource (API 層)
class TrainingPlanRemoteDataSource {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 獲取週計畫 (返回 DTO)
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanDTO {
        let data = try await httpClient.get(
            "/plan/race_run/weekly/\(planId)"
        )
        return try JSONDecoder().decode(WeeklyPlanDTO.self, from: data)
    }

    /// 生成週計畫
    func generateWeeklyPlan(week: Int) async throws -> WeeklyPlanDTO {
        let data = try await httpClient.post(
            "/plan/race_run/weekly",
            body: ["week": week]
        )
        return try JSONDecoder().decode(WeeklyPlanDTO.self, from: data)
    }

    /// 獲取訓練概覽
    func getOverview() async throws -> TrainingPlanOverviewDTO {
        let data = try await httpClient.get("/plan/race_run/status")
        return try JSONDecoder().decode(TrainingPlanOverviewDTO.self, from: data)
    }
}
```

### Local DataSource

**負責本地緩存**:

```swift
/// Training Plan Local DataSource (緩存層)
class TrainingPlanLocalDataSource {
    // ✅ 複用現有的 UnifiedCacheManager
    private let overviewCache = UnifiedCacheManager<TrainingPlanOverviewDTO>(
        cacheKey: "training_plan_overview",
        ttlPolicy: .permanent,
        componentName: "TrainingPlanLocalDataSource"
    )

    private let weeklyPlanCache = MultiKeyCacheManager<WeeklyPlanDTO>(
        baseKey: "weekly_plan_week",
        ttlPolicy: .permanent,
        componentName: "TrainingPlanLocalDataSource"
    )

    /// 獲取週計畫
    func getWeeklyPlan(planId: String) -> WeeklyPlanDTO? {
        return weeklyPlanCache.load(suffix: planId)
    }

    /// 保存週計畫
    func saveWeeklyPlan(_ dto: WeeklyPlanDTO) {
        weeklyPlanCache.save(dto, suffix: dto.id)
    }

    /// 檢查是否過期
    func isExpired(planId: String) -> Bool {
        return weeklyPlanCache.isExpired(suffix: planId)
    }

    /// 獲取概覽
    func getOverview() -> TrainingPlanOverviewDTO? {
        return overviewCache.load()
    }

    /// 保存概覽
    func saveOverview(_ dto: TrainingPlanOverviewDTO) {
        overviewCache.save(dto)
    }

    func isOverviewExpired() -> Bool {
        return overviewCache.isExpired()
    }
}
```

### DTOs (Data Transfer Objects)

**API 響應模型**:

```swift
/// 週計畫 DTO (與 API JSON 結構對應)
struct WeeklyPlanDTO: Codable {
    let id: String
    let weekOfPlan: Int
    let planId: String
    let dailyWorkouts: [DailyWorkoutDTO]
    let totalDistance: Double
    let totalDuration: Int

    enum CodingKeys: String, CodingKey {
        case id
        case weekOfPlan = "week_of_plan"
        case planId = "plan_id"
        case dailyWorkouts = "daily_workouts"
        case totalDistance = "total_distance"
        case totalDuration = "total_duration"
    }
}

struct DailyWorkoutDTO: Codable {
    let id: String
    let date: Int  // Unix timestamp
    let workoutType: String
    let targetDistance: Double?
    let targetPace: Double?
    let description: String

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case workoutType = "workout_type"
        case targetDistance = "target_distance"
        case targetPace = "target_pace"
        case description
    }
}
```

### Mapper (DTO ↔ Entity)

**負責 DTO → Entity 轉換**:

```swift
/// Training Plan Mapper
class TrainingPlanMapper {
    static let shared = TrainingPlanMapper()

    /// DTO → Entity
    func mapToEntity(dto: WeeklyPlanDTO) -> WeeklyPlan {
        return WeeklyPlan(
            id: dto.id,
            weekOfPlan: dto.weekOfPlan,
            planId: dto.planId,
            dailyWorkouts: dto.dailyWorkouts.map(mapToEntity),
            totalDistance: dto.totalDistance,
            totalDuration: dto.totalDuration
        )
    }

    func mapToEntity(dto: DailyWorkoutDTO) -> DailyWorkout {
        return DailyWorkout(
            id: dto.id,
            date: Date(timeIntervalSince1970: TimeInterval(dto.date)),
            workoutType: WorkoutType(rawValue: dto.workoutType) ?? .rest,
            targetDistance: dto.targetDistance,
            targetPace: dto.targetPace,
            description: dto.description
        )
    }

    func mapToEntity(dto: TrainingPlanOverviewDTO) -> TrainingPlanOverview {
        // 類似轉換邏輯
    }
}
```

---

## Core Layer 設計

### 職責

- ✅ 網路通訊 (HTTPClient)
- ✅ 緩存基礎建設 (UnifiedCacheManager)
- ✅ 依賴注入 (DI Container)
- ✅ 工具函式與擴展

### 組件結構

```
core/
├── network/
│   ├── HTTPClient.swift
│   └── APISourceTracking.swift
├── cache/
│   ├── UnifiedCacheManager.swift
│   └── MultiKeyCacheManager.swift
├── di/
│   └── DependencyContainer.swift
└── utils/
    ├── Logger.swift
    └── Extensions.swift
```

### 保留現有優勢

**✅ 保留**:
- HTTPClient (已優秀實作)
- UnifiedCacheManager (泛型緩存)
- MultiKeyCacheManager (多鍵緩存)
- APISourceTracking (API 追蹤)
- TaskManageable (任務管理)

---

## 依賴注入策略

### DI Container 設計

**簡單的服務定位器模式** (不使用第三方框架):

```swift
/// Dependency Injection Container
class DependencyContainer {
    static let shared = DependencyContainer()

    private var services: [String: Any] = [:]

    private init() {
        registerDependencies()
    }

    /// 註冊所有依賴
    private func registerDependencies() {
        // MARK: - Core Layer

        register(HTTPClient.shared, for: HTTPClient.self)
        register(Logger.shared, for: Logger.self)

        // MARK: - Data Layer

        // Remote DataSources
        register(
            TrainingPlanRemoteDataSource(httpClient: resolve()),
            for: TrainingPlanRemoteDataSource.self
        )

        // Local DataSources
        register(
            TrainingPlanLocalDataSource(),
            for: TrainingPlanLocalDataSource.self
        )

        // Mappers
        register(TrainingPlanMapper.shared, for: TrainingPlanMapper.self)

        // MARK: - Domain Layer - Repositories

        register(
            TrainingPlanRepositoryImpl(
                remoteDataSource: resolve(),
                localDataSource: resolve(),
                mapper: resolve()
            ) as TrainingPlanRepository,  // ✅ 註冊為 Protocol 類型
            for: TrainingPlanRepository.self
        )

        // MARK: - Presentation Layer - ViewModels

        // ViewModels 使用 Factory 註冊 (每次創建新實例)
        registerFactory(for: TrainingPlanViewModel.self) {
            TrainingPlanViewModel(repository: self.resolve())
        }
    }

    /// 註冊服務
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }

    /// 註冊 Factory (每次返回新實例)
    private var factories: [String: () -> Any] = [:]

    func registerFactory<T>(for type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }

    /// 解析服務
    func resolve<T>() -> T {
        let key = String(describing: T.self)

        // 優先檢查 Factory
        if let factory = factories[key] {
            return factory() as! T
        }

        // 返回 Singleton
        guard let service = services[key] as? T else {
            fatalError("No registered service for type \(T.self)")
        }
        return service
    }
}

/// 便利擴展
extension DependencyContainer {
    /// 解析 ViewModel (從 SwiftUI View 使用)
    static func makeTrainingPlanViewModel() -> TrainingPlanViewModel {
        return shared.resolve()
    }
}
```

### SwiftUI View 中使用 DI

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel

    init() {
        // ✅ 從 DI Container 解析 ViewModel
        _viewModel = StateObject(wrappedValue: DependencyContainer.makeTrainingPlanViewModel())
    }

    var body: some View {
        // ...
    }
}
```

---

## 完整範例

### 範例: 載入週計畫完整流程

```
1. TrainingPlanView (UI)
   ↓ user taps "載入"
2. TrainingPlanViewModel.loadWeeklyPlan()
   state = .loading
   ↓ calls
3. TrainingPlanRepository.getWeeklyPlan()  // Protocol
   ↓ actual implementation
4. TrainingPlanRepositoryImpl.getWeeklyPlan()
   ├─ Track A: TrainingPlanLocalDataSource.getWeeklyPlan()
   │  ↓ returns WeeklyPlanDTO?
   │  ↓ mapper.mapToEntity(dto) → WeeklyPlan
   │  ↓ 立即返回
   │  └─ Task.detached { refreshInBackground() }
   │
   └─ Track B: TrainingPlanRemoteDataSource.getWeeklyPlan()
      ↓ calls
      HTTPClient.get("/plan/race_run/weekly/...")
      ↓ returns Data
      ↓ JSONDecoder.decode(WeeklyPlanDTO.self)
      ↓ localDataSource.saveWeeklyPlan(dto)
      ↓ mapper.mapToEntity(dto) → WeeklyPlan
      ↓ returns
5. ViewModel receives WeeklyPlan
   state = .loaded(plan)
   ↓ triggers
6. SwiftUI View Re-render
   switch state {
   case .loaded(let plan):
       WeeklyPlanContentView(plan: plan)
   }
```

### 完整代碼範例

詳見:
- `Presentation`: TrainingPlanView.swift, TrainingPlanViewModel.swift
- `Domain`: TrainingPlanRepository.swift (Protocol), WeeklyPlan.swift (Entity)
- `Data`: TrainingPlanRepositoryImpl.swift, TrainingPlanRemoteDataSource.swift, TrainingPlanLocalDataSource.swift
- `Core`: HTTPClient.swift, UnifiedCacheManager.swift, DependencyContainer.swift

---

## 測試策略

### Domain Layer 測試

```swift
class GetWeeklyPlanUseCaseTests: XCTestCase {
    var sut: GetWeeklyPlanUseCase!
    var mockRepository: MockTrainingPlanRepository!

    override func setUp() {
        mockRepository = MockTrainingPlanRepository()
        sut = GetWeeklyPlanUseCase(repository: mockRepository)
    }

    func testExecute_withForceRefresh_callsRefreshWeeklyPlan() async throws {
        // Given
        let expectedPlan = WeeklyPlan.mock()
        mockRepository.refreshWeeklyPlanResult = expectedPlan

        // When
        let result = try await sut.execute(planId: "plan_123", forceRefresh: true)

        // Then
        XCTAssertEqual(result, expectedPlan)
        XCTAssertTrue(mockRepository.refreshWeeklyPlanCalled)
    }
}
```

### Data Layer 測試

```swift
class TrainingPlanRepositoryImplTests: XCTestCase {
    var sut: TrainingPlanRepositoryImpl!
    var mockRemote: MockTrainingPlanRemoteDataSource!
    var mockLocal: MockTrainingPlanLocalDataSource!

    func testGetWeeklyPlan_withCache_returnsFromCache() async throws {
        // Given
        let cachedDTO = WeeklyPlanDTO.mock()
        mockLocal.getWeeklyPlanResult = cachedDTO

        // When
        let result = try await sut.getWeeklyPlan(planId: "plan_123")

        // Then
        XCTAssertEqual(result.id, cachedDTO.id)
        XCTAssertFalse(mockRemote.getWeeklyPlanCalled)  // 不應調用 API
    }
}
```

---

## 下一步

1. ✅ 完成架構設計 (本文檔)
2. 🔄 制定遷移路線圖 ([ARCH-003](./ARCH-003-Migration-Roadmap.md))
3. ⏳ Week 3 實作: Repository Pattern
4. ⏳ Week 4 實作: 統一狀態管理

---

**文檔版本**: 1.0
**撰寫日期**: 2025-12-30
**設計基於**: Clean Architecture + iOS 最佳實踐
