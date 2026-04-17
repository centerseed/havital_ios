# God Object 拆分計畫

## 1. UserManager 拆分

**現有：** 648 行，7+ 職責

### 拆分結果

```
UserManager (648 行)
    ↓ 拆分為
├── UserRepository         (~150 行) - Profile CRUD
├── HeartRateZonesRepository (~100 行) - 心率區間
├── UserTargetsRepository  (~100 行) - Target 管理
└── PersonalBestRepository (~150 行) - PB 追蹤
```

### 職責對應

| 原職責 | 新歸屬 |
|--------|--------|
| `loadData()`, `refreshData()` | UserRepository |
| `loadHeartRateZones()` | HeartRateZonesRepository |
| `updateHeartRateZones()` | HeartRateZonesRepository |
| `loadTargets()` | UserTargetsRepository |
| `updateTarget()` | UserTargetsRepository |
| `detectPersonalBestUpdates()` | PersonalBestRepository |
| `celebratePersonalBest()` | PersonalBestRepository |
| 認證狀態監聽 | 移至 AuthRepository |

### 遷移步驟

1. **建立 Protocol**
   ```swift
   protocol UserRepository {
       func getProfile() async throws -> User
       func updateProfile(_ user: User) async throws
       func deleteAccount() async throws
   }
   ```

2. **提取 DataSources**
   - 從現有 `UserManager` 提取 API 呼叫到 `UserRemoteDataSource`
   - 從現有 `UserCacheManager` 提取到 `UserLocalDataSource`

3. **實作 RepositoryImpl**
   - 保留雙軌緩存邏輯

4. **更新 ViewModel**
   - `UserProfileViewModel` 注入 `UserRepository`

5. **Facade 向後兼容**
   ```swift
   extension UserManager {
       static var shared: UserManager {
           DependencyContainer.shared.resolve()
       }
   }
   ```

---

## 2. TrainingPlanViewModel 拆分

**現有：** 2500+ 行

### 拆分結果

```
TrainingPlanViewModel (2500+ 行)
    ↓ 拆分為
├── WeeklyPlanViewModel       (~200 行) - 週計畫載入/顯示
├── TrainingOverviewViewModel (~150 行) - 訓練概覽
├── WorkoutTrackingViewModel  (~200 行) - Workout 追蹤
├── IntensityViewModel        (~150 行) - 強度計算
├── EditScheduleViewModel     (~300 行) - 編輯排程
└── WeeklySummaryViewModel    (~200 行) - 週回顧
```

### 職責對應

| 原職責 | 新歸屬 |
|--------|--------|
| `loadWeeklyPlan()` | WeeklyPlanViewModel |
| `generateNewWeeklyPlan()` | WeeklyPlanViewModel |
| `loadTrainingOverview()` | TrainingOverviewViewModel |
| `loadWorkoutsByDay()` | WorkoutTrackingViewModel |
| `loadCurrentWeekIntensity()` | IntensityViewModel |
| `editingDays`, `saveEditedSchedule()` | EditScheduleViewModel |
| `loadWeeklySummary()` | WeeklySummaryViewModel |
| `confirmAdjustments()` | EditScheduleViewModel |

### 遷移步驟

1. **建立 Repository**
   ```swift
   protocol TrainingPlanRepository {
       func getWeeklyPlan(planId: String) async throws -> WeeklyPlan
       func getOverview() async throws -> TrainingPlanOverview
       func generateWeeklyPlan(week: Int) async throws -> WeeklyPlan
       // ...
   }
   ```

2. **提取第一個 ViewModel (WeeklyPlanViewModel)**
   - 使用 ViewState<WeeklyPlan>
   - 注入 TrainingPlanRepository

3. **更新 View**
   - TrainingPlanView 使用新的 WeeklyPlanViewModel
   - 用 @StateObject 持有

4. **逐一提取其他 ViewModel**
   - 每個 ViewModel 獨立測試
   - 確認功能正常後再繼續

5. **清理舊 ViewModel**
   - 標記 deprecated
   - 最後刪除

---

## 3. AuthenticationService 拆分

**現有：** 1125 行

### 拆分結果

```
AuthenticationService (1125 行)
    ↓ 拆分為
├── AuthRepository (Protocol)
├── FirebaseAuthDataSource    (~200 行) - Firebase SDK
├── BackendAuthDataSource     (~150 行) - 後端 API
├── AuthRepositoryImpl        (~200 行) - 協調層
└── LoginViewModel           (~150 行) - UI 狀態
```

### 職責對應

| 原職責 | 新歸屬 |
|--------|--------|
| `signInWithGoogle()` | FirebaseAuthDataSource |
| `signInWithApple()` | FirebaseAuthDataSource |
| `signInWithEmail()` | FirebaseAuthDataSource |
| `getIdToken()` | FirebaseAuthDataSource |
| Backend API 驗證 | BackendAuthDataSource |
| 用戶 Profile 獲取 | 移至 UserRepository |
| Onboarding 狀態 | 移至 OnboardingRepository |
| FCM Token 同步 | 移至 NotificationService |
| Cache 清除 | 移至 CacheEventBus |

### 遷移步驟

1. **定義 Protocol**
   ```swift
   protocol AuthRepository {
       func signInWithGoogle() async throws -> User
       func signInWithApple(nonce: String, token: String) async throws -> User
       func signInWithEmail(email: String, password: String) async throws -> User
       func signOut() async throws
       func deleteAccount() async throws
   }
   ```

2. **提取 DataSources**
   - FirebaseAuthDataSource: 純 Firebase SDK 封裝
   - BackendAuthDataSource: 後端 API 呼叫

3. **實作 AuthRepositoryImpl**
   - 協調 Firebase + Backend
   - 處理 Token 刷新

4. **更新 ViewModel**
   - LoginViewModel 注入 AuthRepository

---

## 4. Onboarding Views 拆分

**現有：** 13 個 ViewModel 嵌入 View 檔案

### 拆分結果

```
Views/Onboarding/
├── PersonalBestView.swift (含 ViewModel)
├── TrainingOverviewView.swift (含 ViewModel)
├── ...
    ↓ 拆分為
Features/Onboarding/
├── Presentation/
│   ├── Views/
│   │   ├── PersonalBestView.swift
│   │   ├── TrainingOverviewView.swift
│   │   └── ...
│   └── ViewModels/
│       ├── PersonalBestViewModel.swift
│       ├── TrainingOverviewViewModel.swift
│       └── ...
├── Domain/
│   └── Repositories/
│       └── OnboardingRepository.swift
└── Data/
    └── ...
```

### 遷移步驟

1. **建立 OnboardingRepository**
   ```swift
   protocol OnboardingRepository {
       func savePersonalBest(_ pb: PersonalBest) async throws
       func saveTarget(_ target: Target) async throws
       func completeOnboarding() async throws
   }
   ```

2. **提取 ViewModel 到獨立檔案**
   - 每個 ViewModel 一個檔案
   - 注入 Repository

3. **移除 View 中的 Service 呼叫**
   - 所有 Service 呼叫改為 Repository
   - View 只透過 ViewModel 操作

4. **更新 View**
   - 使用 @StateObject 持有 ViewModel
   - 使用 ViewState<T> 管理狀態

---

## 5. 共用模式

### ViewModel 模板

```swift
@MainActor
final class ExampleViewModel: ObservableObject {
    // 單一狀態來源
    @Published var state: ViewState<DataType> = .loading

    // Protocol 依賴 (DI)
    private let repository: ExampleRepository
    private let logger: Logger

    // TaskManageable
    let taskRegistry = TaskRegistry()

    init(repository: ExampleRepository, logger: Logger = .shared) {
        self.repository = repository
        self.logger = logger
    }

    func loadData() async {
        state = .loading
        do {
            let data = try await repository.getData()
            state = .loaded(data)
        } catch {
            let domainError = error.toDomainError()
            if case .cancellationFailure = domainError { return }
            state = .error(domainError)
        }
    }

    deinit {
        cancelAllTasks()
    }
}

extension ExampleViewModel: TaskManageable {}
```

### Repository 模板

```swift
protocol ExampleRepository {
    func getData() async throws -> DataType
    func refreshData() async throws -> DataType
}

final class ExampleRepositoryImpl: ExampleRepository {
    private let remoteDataSource: ExampleRemoteDataSource
    private let localDataSource: ExampleLocalDataSource
    private let mapper: ExampleMapper

    init(...) { ... }

    func getData() async throws -> DataType {
        // Track A: 緩存優先
        if let cached = localDataSource.get(), !localDataSource.isExpired() {
            Task.detached { await self.refreshInBackground() }
            return mapper.toEntity(cached)
        }

        // Track B: API
        let dto = try await remoteDataSource.get()
        localDataSource.save(dto)
        return mapper.toEntity(dto)
    }
}
```

### View 模板

```swift
struct ExampleView: View {
    @StateObject private var viewModel: ExampleViewModel

    init(viewModel: ExampleViewModel = DependencyContainer.shared.resolve()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        content
            .onAppear {
                Task { await viewModel.loadData() }
                    .tracked(from: "ExampleView: onAppear")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .loaded(let data):
            ContentView(data: data)
        case .error(let error):
            ErrorView(error: error) {
                Task { await viewModel.loadData() }
            }
        case .empty:
            EmptyStateView(message: "No data")
        }
    }
}
```
