# ARCH-003: 遷移路線圖

**版本**: 1.0
**最後更新**: 2025-12-30
**狀態**: 🔄 規劃中

---

## 目錄

1. [遷移原則](#遷移原則)
2. [Week 3: Repository Pattern 實作](#week-3-repository-pattern-實作)
3. [Week 4: 統一狀態管理](#week-4-統一狀態管理)
4. [Week 5: 錯誤處理標準化](#week-5-錯誤處理標準化)
5. [Week 6: UseCase Layer (可選)](#week-6-usecase-layer-可選)
6. [測試策略](#測試策略)
7. [風險評估](#風險評估)

---

## 遷移原則

### 核心原則

1. **漸進式遷移** - 不進行大規模重構，逐模組遷移
2. **保留優勢** - 保留雙軌緩存、UnifiedCacheManager、API 追蹤系統
3. **向後兼容** - 新架構與舊架構並存，逐步替換
4. **測試驅動** - 每個遷移步驟都有對應測試
5. **最小影響** - 優先遷移獨立模組，減少對其他模組的影響

### 遷移優先級

| 優先級 | 模組 | 原因 |
|--------|------|------|
| 🔥 High | TrainingPlan | 核心功能，代碼較集中，易於遷移 |
| 🔥 High | Workout | 高頻使用，已有 UnifiedWorkoutManager |
| ⚠️ Medium | User | 依賴性較低，適合驗證架構 |
| ⚠️ Medium | Target | 獨立模組，易於遷移 |
| ℹ️ Low | Onboarding | 複雜度低，可最後處理 |

### 遷移策略

**階段 1: 建立基礎建設** (Week 3)
- 定義 Repository Protocol
- 實作 Repository Implementation
- 建立 DI Container
- 遷移 1-2 個核心模組驗證架構

**階段 2: 統一狀態管理** (Week 4)
- 定義 ViewState<T> 枚舉
- 重構 ViewModel 使用單一狀態
- 更新 UI 層以支援新狀態系統

**階段 3: 錯誤處理標準化** (Week 5)
- 定義 DomainError 類型
- Repository 返回 Result 或自定義 Either
- 統一錯誤轉換與顯示

**階段 4: UseCase Layer (可選)** (Week 6)
- 封裝複雜業務邏輯為 UseCase
- ViewModel 依賴 UseCase 而非直接依賴 Repository

---

## Week 3: Repository Pattern 實作

**目標**: 引入 Repository Pattern 和依賴反轉原則

**預估工作量**: 3-5 天

### 任務清單

#### 1. 建立目錄結構 (0.5 天)

```bash
# 創建 features 目錄結構
mkdir -p features/training_plan/domain/{entities,repositories,errors}
mkdir -p features/training_plan/data/{repositories,datasources/{remote,local},models,mappers}
mkdir -p features/training_plan/presentation/{views,viewmodels,states}

# 創建 Core DI 目錄
mkdir -p core/di
```

#### 2. 定義 Domain Layer (1 天)

**2.1 定義 Repository Protocol**

創建 `features/training_plan/domain/repositories/TrainingPlanRepository.swift`:

```swift
protocol TrainingPlanRepository {
    func getOverview() async throws -> TrainingPlanOverview
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func generateWeeklyPlan(week: Int) async throws -> WeeklyPlan
    func getCurrentWeek() async throws -> Int
}
```

**2.2 定義 Entities**

移動現有的 `WeeklyPlan.swift`, `TrainingPlanOverview.swift` 到:
`features/training_plan/domain/entities/`

確保 Entities 不包含持久化邏輯 (如 Codable conformance 可保留用於序列化)。

**2.3 定義 Domain Errors**

創建 `features/training_plan/domain/errors/TrainingPlanError.swift`:

```swift
enum TrainingPlanError: Error {
    case invalidWeek(Int)
    case invalidPlanContent
    case planNotFound(String)
}
```

#### 3. 實作 Data Layer (1.5 天)

**3.1 創建 DTOs**

創建 `features/training_plan/data/models/WeeklyPlanDTO.swift`:

```swift
struct WeeklyPlanDTO: Codable {
    let id: String
    let weekOfPlan: Int
    let planId: String
    let dailyWorkouts: [DailyWorkoutDTO]
    // ...

    enum CodingKeys: String, CodingKey {
        case id
        case weekOfPlan = "week_of_plan"
        // ...
    }
}
```

**3.2 創建 Remote DataSource**

創建 `features/training_plan/data/datasources/remote/TrainingPlanRemoteDataSource.swift`:

```swift
class TrainingPlanRemoteDataSource {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanDTO {
        let data = try await httpClient.get("/plan/race_run/weekly/\(planId)")
        return try JSONDecoder().decode(WeeklyPlanDTO.self, from: data)
    }

    // 其他 API 方法...
}
```

**3.3 創建 Local DataSource**

創建 `features/training_plan/data/datasources/local/TrainingPlanLocalDataSource.swift`:

```swift
class TrainingPlanLocalDataSource {
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

    func getWeeklyPlan(planId: String) -> WeeklyPlanDTO? {
        return weeklyPlanCache.load(suffix: planId)
    }

    func saveWeeklyPlan(_ dto: WeeklyPlanDTO) {
        weeklyPlanCache.save(dto, suffix: dto.id)
    }

    // 其他緩存方法...
}
```

**3.4 創建 Mapper**

創建 `features/training_plan/data/mappers/TrainingPlanMapper.swift`:

```swift
class TrainingPlanMapper {
    static let shared = TrainingPlanMapper()

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
        // DTO → Entity 轉換邏輯
    }
}
```

**3.5 實作 Repository**

創建 `features/training_plan/data/repositories/TrainingPlanRepositoryImpl.swift`:

```swift
class TrainingPlanRepositoryImpl: TrainingPlanRepository {
    private let remoteDataSource: TrainingPlanRemoteDataSource
    private let localDataSource: TrainingPlanLocalDataSource
    private let mapper: TrainingPlanMapper

    init(
        remoteDataSource: TrainingPlanRemoteDataSource,
        localDataSource: TrainingPlanLocalDataSource,
        mapper: TrainingPlanMapper = .shared
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        // Track A: 檢查緩存
        if let cachedDTO = localDataSource.getWeeklyPlan(planId: planId),
           !localDataSource.isExpired(planId: planId) {
            // 背景刷新 (Track B)
            Task.detached { [weak self] in
                await self?.refreshInBackground(planId: planId)
            }
            return mapper.mapToEntity(dto: cachedDTO)
        }

        // 無緩存: 從 API 載入
        return try await fetchAndCacheWeeklyPlan(planId: planId)
    }

    // 其他方法...
}
```

#### 4. 建立 DI Container (0.5 天)

創建 `core/di/DependencyContainer.swift`:

```swift
class DependencyContainer {
    static let shared = DependencyContainer()

    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]

    private init() {
        registerDependencies()
    }

    private func registerDependencies() {
        // 註冊 Core
        register(HTTPClient.shared, for: HTTPClient.self)

        // 註冊 Data Layer
        register(
            TrainingPlanRemoteDataSource(httpClient: resolve()),
            for: TrainingPlanRemoteDataSource.self
        )
        register(
            TrainingPlanLocalDataSource(),
            for: TrainingPlanLocalDataSource.self
        )

        // 註冊 Repository (作為 Protocol)
        register(
            TrainingPlanRepositoryImpl(
                remoteDataSource: resolve(),
                localDataSource: resolve()
            ) as TrainingPlanRepository,
            for: TrainingPlanRepository.self
        )

        // 註冊 ViewModel Factory
        registerFactory(for: TrainingPlanViewModel.self) {
            TrainingPlanViewModel(repository: self.resolve())
        }
    }

    func register<T>(_ service: T, for type: T.Type) {
        services[String(describing: type)] = service
    }

    func registerFactory<T>(for type: T.Type, factory: @escaping () -> T) {
        factories[String(describing: type)] = factory
    }

    func resolve<T>() -> T {
        let key = String(describing: T.self)
        if let factory = factories[key] {
            return factory() as! T
        }
        guard let service = services[key] as? T else {
            fatalError("No service registered for \(T.self)")
        }
        return service
    }
}
```

#### 5. 更新 ViewModel (0.5 天)

修改 `TrainingPlanViewModel.swift`:

```swift
class TrainingPlanViewModel: ObservableObject {
    // ✅ 改為依賴 Protocol
    private let repository: TrainingPlanRepository  // 不再是 TrainingPlanManager.shared

    // ✅ 依賴注入
    init(repository: TrainingPlanRepository) {
        self.repository = repository
    }

    func loadWeeklyPlan(planId: String) async {
        isLoading = true
        do {
            // ✅ 調用 Repository Protocol 方法
            let plan = try await repository.getWeeklyPlan(planId: planId)
            weeklyPlan = plan
            isLoading = false
        } catch {
            // 錯誤處理...
        }
    }
}
```

#### 6. 更新 View (0.5 天)

修改 `TrainingPlanView.swift`:

```swift
struct TrainingPlanView: View {
    // ✅ 從 DI Container 獲取 ViewModel
    @StateObject private var viewModel: TrainingPlanViewModel

    init() {
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.resolve())
    }

    var body: some View {
        // UI 保持不變...
    }
}
```

#### 7. 測試 (0.5 天)

創建 `TrainingPlanRepositoryImplTests.swift`:

```swift
class TrainingPlanRepositoryImplTests: XCTestCase {
    var sut: TrainingPlanRepositoryImpl!
    var mockRemote: MockTrainingPlanRemoteDataSource!
    var mockLocal: MockTrainingPlanLocalDataSource!

    override func setUp() {
        mockRemote = MockTrainingPlanRemoteDataSource()
        mockLocal = MockTrainingPlanLocalDataSource()
        sut = TrainingPlanRepositoryImpl(
            remoteDataSource: mockRemote,
            localDataSource: mockLocal
        )
    }

    func testGetWeeklyPlan_withCache_returnsFromCache() async throws {
        // Given
        let cachedDTO = WeeklyPlanDTO.mock()
        mockLocal.getWeeklyPlanResult = cachedDTO

        // When
        let result = try await sut.getWeeklyPlan(planId: "plan_123")

        // Then
        XCTAssertEqual(result.id, cachedDTO.id)
        XCTAssertFalse(mockRemote.getWeeklyPlanCalled)
    }
}
```

### Week 3 完成標準

- ✅ TrainingPlan 模組完全遷移到 Repository Pattern
- ✅ DI Container 正常運作
- ✅ ViewModel 通過 Protocol 依賴 Repository
- ✅ 雙軌緩存策略保持運作
- ✅ 單元測試覆蓋率 > 80%
- ✅ 現有功能無退化

---

## Week 4: 統一狀態管理

**目標**: 引入統一的 ViewState 枚舉，簡化 UI 狀態管理

**預估工作量**: 2-3 天

### 任務清單

#### 1. 定義 ViewState 枚舉 (0.5 天)

創建 `shared/states/ViewState.swift`:

```swift
/// 通用 View 狀態枚舉
enum ViewState<T> {
    case loading
    case loaded(T)
    case error(DomainError)
    case empty
}

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

/// Equatable conformance (for testing)
extension ViewState: Equatable where T: Equatable {
    static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.loaded(let a), .loaded(let b)):
            return a == b
        case (.error, .error):
            return true  // 簡化比較
        case (.empty, .empty):
            return true
        default:
            return false
        }
    }
}
```

#### 2. 重構 ViewModel (1 天)

修改 `TrainingPlanViewModel.swift`:

```swift
class TrainingPlanViewModel: ObservableObject {
    // ❌ 移除多個 @Published 屬性
    // @Published var isLoading = false
    // @Published var weeklyPlan: WeeklyPlan?
    // @Published var error: Error?

    // ✅ 單一狀態源
    @Published var weeklyPlanState: ViewState<WeeklyPlan> = .loading
    @Published var overviewState: ViewState<TrainingPlanOverview> = .loading

    private let repository: TrainingPlanRepository

    func loadWeeklyPlan(planId: String) async {
        weeklyPlanState = .loading  // ✅ 單一賦值

        do {
            let plan = try await repository.getWeeklyPlan(planId: planId)
            weeklyPlanState = .loaded(plan)  // ✅ 單一賦值
        } catch {
            weeklyPlanState = .error(error.toDomainError())  // ✅ 單一賦值
        }
    }

    func refreshWeeklyPlan(planId: String) async {
        weeklyPlanState = .loading
        do {
            let plan = try await repository.refreshWeeklyPlan(planId: planId)
            weeklyPlanState = .loaded(plan)
        } catch {
            weeklyPlanState = .error(error.toDomainError())
        }
    }
}
```

#### 3. 更新 View (1 天)

修改 `TrainingPlanView.swift`:

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel

    var body: some View {
        NavigationView {
            viewStateContent  // ✅ 單一狀態處理
                .navigationTitle("訓練計畫")
        }
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

    // ✅ 清晰的狀態分支處理
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

#### 4. 創建共享 UI 組件 (0.5 天)

創建 `shared/widgets/ErrorView.swift`:

```swift
struct ErrorView: View {
    let error: DomainError
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(error.errorDescription ?? "未知錯誤")
                .font(.body)
                .multilineTextAlignment(.center)

            Button("重試") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

創建 `shared/widgets/EmptyStateView.swift`:

```swift
struct EmptyStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

#### 5. 測試 (0.5 天)

創建 `TrainingPlanViewModelTests.swift`:

```swift
@MainActor
class TrainingPlanViewModelTests: XCTestCase {
    var sut: TrainingPlanViewModel!
    var mockRepository: MockTrainingPlanRepository!

    override func setUp() async throws {
        mockRepository = MockTrainingPlanRepository()
        sut = TrainingPlanViewModel(repository: mockRepository)
    }

    func testLoadWeeklyPlan_success_updatesStateToLoaded() async {
        // Given
        let expectedPlan = WeeklyPlan.mock()
        mockRepository.getWeeklyPlanResult = .success(expectedPlan)

        // When
        await sut.loadWeeklyPlan(planId: "plan_123")

        // Then
        XCTAssertEqual(sut.weeklyPlanState, .loaded(expectedPlan))
    }

    func testLoadWeeklyPlan_failure_updatesStateToError() async {
        // Given
        mockRepository.getWeeklyPlanResult = .failure(.networkFailure(URLError(.notConnectedToInternet)))

        // When
        await sut.loadWeeklyPlan(planId: "plan_123")

        // Then
        if case .error = sut.weeklyPlanState {
            // Success
        } else {
            XCTFail("Expected error state")
        }
    }
}
```

### Week 4 完成標準

- ✅ ViewState<T> 枚舉定義完成
- ✅ TrainingPlan 模組 ViewModel 遷移到單一狀態
- ✅ TrainingPlan 模組 View 更新使用 ViewState
- ✅ 共享 ErrorView 和 EmptyStateView 組件
- ✅ ViewModel 單元測試覆蓋率 > 80%
- ✅ UI 狀態轉換邏輯簡化

---

## Week 5: 錯誤處理標準化

**目標**: 統一錯誤處理機制，使用 DomainError 類型

**預估工作量**: 2-3 天

### 任務清單

#### 1. 定義 DomainError (0.5 天)

創建 `core/errors/DomainError.swift`:

```swift
/// 領域錯誤類型
enum DomainError: Error {
    case networkFailure(Error)
    case serverFailure(statusCode: Int, message: String)
    case cacheFailure
    case cancellationFailure
    case authFailure
    case validationFailure(String)
    case unknown(Error)
}

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

/// Error → DomainError 轉換擴展
extension Error {
    func toDomainError() -> DomainError {
        if let domainError = self as? DomainError {
            return domainError
        }

        if let urlError = self as? URLError {
            switch urlError.code {
            case .cancelled:
                return .cancellationFailure
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkFailure(urlError)
            default:
                return .networkFailure(urlError)
            }
        }

        return .unknown(self)
    }
}
```

#### 2. 更新 Repository 錯誤處理 (1 天)

修改 `TrainingPlanRepositoryImpl.swift`:

```swift
class TrainingPlanRepositoryImpl: TrainingPlanRepository {
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        do {
            // Track A: 檢查緩存
            if let cachedDTO = localDataSource.getWeeklyPlan(planId: planId),
               !localDataSource.isExpired(planId: planId) {
                Task.detached { [weak self] in
                    await self?.refreshInBackground(planId: planId)
                }
                return mapper.mapToEntity(dto: cachedDTO)
            }

            // Track B: 從 API 載入
            let dto = try await remoteDataSource.getWeeklyPlan(planId: planId)
            localDataSource.saveWeeklyPlan(dto)
            return mapper.mapToEntity(dto: dto)

        } catch {
            // ✅ 統一錯誤轉換
            throw error.toDomainError()
        }
    }

    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        do {
            let dto = try await remoteDataSource.getWeeklyPlan(planId: planId)
            localDataSource.saveWeeklyPlan(dto)
            return mapper.mapToEntity(dto: dto)
        } catch {
            throw error.toDomainError()
        }
    }
}
```

#### 3. 更新 ViewModel 錯誤處理 (0.5 天)

修改 `TrainingPlanViewModel.swift`:

```swift
class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlanState: ViewState<WeeklyPlan> = .loading

    func loadWeeklyPlan(planId: String) async {
        weeklyPlanState = .loading

        do {
            let plan = try await repository.getWeeklyPlan(planId: planId)
            weeklyPlanState = .loaded(plan)
        } catch {
            // ✅ 統一錯誤處理
            let domainError = error.toDomainError()

            // 忽略取消錯誤
            if case .cancellationFailure = domainError {
                logger.debug("任務已取消，忽略錯誤")
                return
            }

            weeklyPlanState = .error(domainError)
            logger.error("載入週計畫失敗: \(domainError.localizedDescription)")
        }
    }
}
```

#### 4. 更新 HTTPClient 錯誤處理 (0.5 天)

修改 `HTTPClient.swift`:

```swift
class HTTPClient {
    func get(_ path: String) async throws -> Data {
        do {
            // HTTP 請求邏輯...
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DomainError.unknown(NSError(domain: "InvalidResponse", code: -1))
            }

            // ✅ 檢查 HTTP 狀態碼
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw DomainError.serverFailure(
                    statusCode: httpResponse.statusCode,
                    message: message
                )
            }

            return data

        } catch {
            // ✅ 統一錯誤轉換
            throw error.toDomainError()
        }
    }
}
```

#### 5. 測試 (0.5 天)

更新測試以驗證錯誤處理:

```swift
func testLoadWeeklyPlan_networkError_returnsNetworkFailure() async {
    // Given
    mockRepository.getWeeklyPlanError = URLError(.notConnectedToInternet)

    // When
    await sut.loadWeeklyPlan(planId: "plan_123")

    // Then
    if case .error(let domainError) = sut.weeklyPlanState,
       case .networkFailure = domainError {
        // Success
    } else {
        XCTFail("Expected network failure error")
    }
}

func testLoadWeeklyPlan_cancellationError_doesNotUpdateState() async {
    // Given
    mockRepository.getWeeklyPlanError = URLError(.cancelled)

    // When
    await sut.loadWeeklyPlan(planId: "plan_123")

    // Then
    // State should remain as .loading (not updated to .error)
    XCTAssertEqual(sut.weeklyPlanState, .loading)
}
```

### Week 5 完成標準

- ✅ DomainError 枚舉定義完成
- ✅ Repository 統一拋出 DomainError
- ✅ ViewModel 統一處理 DomainError
- ✅ HTTPClient 返回 DomainError
- ✅ 取消錯誤不更新 UI 狀態
- ✅ 錯誤處理測試覆蓋率 > 80%

---

## Week 6: UseCase Layer (可選)

**目標**: 封裝複雜業務邏輯為可測試的 UseCase

**預估工作量**: 1-2 天

**優先級**: ℹ️ Low (可根據實際需求決定是否實作)

### 任務清單

#### 1. 定義 UseCase Protocol (0.5 天)

創建 `core/usecases/UseCase.swift`:

```swift
/// UseCase 基礎協議
protocol UseCase {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async throws -> Output
}

/// 無輸入的 UseCase
protocol NoInputUseCase {
    associatedtype Output

    func execute() async throws -> Output
}
```

#### 2. 創建具體 UseCase (0.5 天)

創建 `features/training_plan/domain/usecases/GetWeeklyPlanUseCase.swift`:

```swift
/// 獲取週計畫 UseCase
class GetWeeklyPlanUseCase: UseCase {
    struct Input {
        let planId: String
        let forceRefresh: Bool
    }

    typealias Output = WeeklyPlan

    private let repository: TrainingPlanRepository

    init(repository: TrainingPlanRepository) {
        self.repository = repository
    }

    func execute(_ input: Input) async throws -> WeeklyPlan {
        if input.forceRefresh {
            return try await repository.refreshWeeklyPlan(planId: input.planId)
        }
        return try await repository.getWeeklyPlan(planId: input.planId)
    }
}
```

創建 `features/training_plan/domain/usecases/GenerateWeeklyPlanUseCase.swift`:

```swift
/// 生成週計畫 UseCase (包含驗證邏輯)
class GenerateWeeklyPlanUseCase: UseCase {
    typealias Input = Int  // week number
    typealias Output = WeeklyPlan

    private let repository: TrainingPlanRepository
    private let validator: WeeklyPlanValidator

    init(
        repository: TrainingPlanRepository,
        validator: WeeklyPlanValidator = .shared
    ) {
        self.repository = repository
        self.validator = validator
    }

    func execute(_ input: Int) async throws -> WeeklyPlan {
        // 1. 驗證週數
        let currentWeek = try await repository.getCurrentWeek()
        guard validator.isValidWeek(input, currentWeek: currentWeek) else {
            throw TrainingPlanError.invalidWeek(input)
        }

        // 2. 生成計畫
        let plan = try await repository.generateWeeklyPlan(week: input)

        // 3. 驗證計畫內容
        guard validator.isValidPlan(plan) else {
            throw TrainingPlanError.invalidPlanContent
        }

        return plan
    }
}
```

#### 3. 更新 ViewModel 使用 UseCase (0.5 天)

修改 `TrainingPlanViewModel.swift`:

```swift
class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlanState: ViewState<WeeklyPlan> = .loading

    // ✅ 依賴 UseCase
    private let getWeeklyPlanUseCase: GetWeeklyPlanUseCase
    private let generateWeeklyPlanUseCase: GenerateWeeklyPlanUseCase

    init(
        getWeeklyPlanUseCase: GetWeeklyPlanUseCase,
        generateWeeklyPlanUseCase: GenerateWeeklyPlanUseCase
    ) {
        self.getWeeklyPlanUseCase = getWeeklyPlanUseCase
        self.generateWeeklyPlanUseCase = generateWeeklyPlanUseCase
    }

    func loadWeeklyPlan(planId: String, forceRefresh: Bool = false) async {
        weeklyPlanState = .loading

        do {
            let input = GetWeeklyPlanUseCase.Input(
                planId: planId,
                forceRefresh: forceRefresh
            )
            let plan = try await getWeeklyPlanUseCase.execute(input)
            weeklyPlanState = .loaded(plan)
        } catch {
            weeklyPlanState = .error(error.toDomainError())
        }
    }

    func generateWeeklyPlan(week: Int) async {
        weeklyPlanState = .loading

        do {
            let plan = try await generateWeeklyPlanUseCase.execute(week)
            weeklyPlanState = .loaded(plan)
        } catch {
            weeklyPlanState = .error(error.toDomainError())
        }
    }
}
```

#### 4. 更新 DI Container (0.5 天)

修改 `DependencyContainer.swift`:

```swift
private func registerDependencies() {
    // ... 其他註冊 ...

    // 註冊 UseCases
    registerFactory(for: GetWeeklyPlanUseCase.self) {
        GetWeeklyPlanUseCase(repository: self.resolve())
    }

    registerFactory(for: GenerateWeeklyPlanUseCase.self) {
        GenerateWeeklyPlanUseCase(repository: self.resolve())
    }

    // 更新 ViewModel 註冊
    registerFactory(for: TrainingPlanViewModel.self) {
        TrainingPlanViewModel(
            getWeeklyPlanUseCase: self.resolve(),
            generateWeeklyPlanUseCase: self.resolve()
        )
    }
}
```

### Week 6 完成標準

- ✅ UseCase Protocol 定義完成
- ✅ GetWeeklyPlanUseCase 實作完成
- ✅ GenerateWeeklyPlanUseCase 實作完成
- ✅ ViewModel 通過 UseCase 訪問業務邏輯
- ✅ UseCase 單元測試覆蓋率 > 90%

---

## 測試策略

### 單元測試優先級

| 層級 | 測試覆蓋率目標 | 重點 |
|-----|---------------|------|
| **Domain Layer** | > 90% | UseCases, Entity 業務方法 |
| **Data Layer** | > 80% | Repository, DataSource |
| **Presentation Layer** | > 80% | ViewModel 狀態轉換 |

### Mock 策略

**Repository Mock**:
```swift
class MockTrainingPlanRepository: TrainingPlanRepository {
    var getWeeklyPlanResult: Result<WeeklyPlan, Error>?
    var getWeeklyPlanCalled = false

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        getWeeklyPlanCalled = true
        switch getWeeklyPlanResult {
        case .success(let plan):
            return plan
        case .failure(let error):
            throw error
        case .none:
            fatalError("getWeeklyPlanResult not set")
        }
    }
}
```

**DataSource Mock**:
```swift
class MockTrainingPlanRemoteDataSource {
    var getWeeklyPlanResult: WeeklyPlanDTO?
    var getWeeklyPlanCalled = false

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlanDTO {
        getWeeklyPlanCalled = true
        guard let result = getWeeklyPlanResult else {
            throw DomainError.unknown(NSError(domain: "Mock", code: -1))
        }
        return result
    }
}
```

---

## 風險評估

### 高風險項目

#### 1. 雙軌緩存邏輯遷移

**風險**: 雙軌緩存是核心優勢，遷移時可能破壞現有邏輯

**緩解措施**:
- ✅ 在 Repository 層保持相同的雙軌邏輯
- ✅ 完整的單元測試驗證緩存行為
- ✅ 灰度發布，逐步遷移模組

#### 2. Singleton 依賴替換

**風險**: 現有代碼大量使用 `.shared` Singleton，替換可能導致崩潰

**緩解措施**:
- ✅ 漸進式遷移，新舊架構並存
- ✅ 保留 Singleton 作為臨時適配器
- ✅ 優先遷移獨立模組

#### 3. 測試覆蓋率不足

**風險**: 現有測試較少，遷移後可能引入回退

**緩解措施**:
- ✅ 遷移前先補充關鍵路徑測試
- ✅ 遷移過程中保持測試先行
- ✅ 每週進行回歸測試

### 中風險項目

#### 4. DI Container 引入複雜度

**風險**: 手動 DI 容易出錯，註冊遺漏導致崩潰

**緩解措施**:
- ✅ 使用 Protocol + 泛型減少註冊錯誤
- ✅ 單元測試驗證 DI Container
- ✅ 提供清晰的註冊文檔

---

## 下一步

1. ✅ 完成遷移路線圖 (本文檔)
2. 🔄 開始 Week 3: Repository Pattern 實作
3. ⏳ Week 4: 統一狀態管理
4. ⏳ Week 5: 錯誤處理標準化
5. ⏳ Week 6: UseCase Layer (可選)

---

**文檔版本**: 1.0
**撰寫日期**: 2025-12-30
**規劃基於**: Clean Architecture 最佳實踐 + iOS 實際情況
