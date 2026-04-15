# 目標架構設計

## Clean Architecture 層級

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Views      │  │  ViewModels  │  │  ViewState   │       │
│  │  (SwiftUI)   │←─│ (@Published) │  │    <T>       │       │
│  └──────────────┘  └──────┬───────┘  └──────────────┘       │
│                           │ via DI                           │
├───────────────────────────┼──────────────────────────────────┤
│                           ↓                                  │
│                     DOMAIN LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Entities   │  │  UseCases    │  │ Repositories │       │
│  │   (Models)   │  │  (Optional)  │  │  (Protocol)  │       │
│  └──────────────┘  └──────┬───────┘  └──────┬───────┘       │
├───────────────────────────┼──────────────────┼───────────────┤
│                           ↓                  ↓               │
│                      DATA LAYER                              │
│  ┌──────────────┐  ┌────────────────────────────────┐       │
│  │    DTOs      │  │   Repository Implementation    │       │
│  │              │  │  ┌────────────┐ ┌────────────┐ │       │
│  │              │  │  │   Remote   │ │   Local    │ │       │
│  │              │  │  │ DataSource │ │ DataSource │ │       │
│  └──────────────┘  │  └────────────┘ └────────────┘ │       │
│                    │  ┌────────────────────────┐    │       │
│                    │  │   Mapper (DTO↔Entity)  │    │       │
│                    │  └────────────────────────┘    │       │
│                    └────────────────────────────────┘       │
├─────────────────────────────────────────────────────────────┤
│                       CORE LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  HTTPClient  │  │ TaskRegistry │  │ DI Container │       │
│  │  APIParser   │  │ CacheEventBus│  │              │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

**依賴方向（只能向內）：**
```
Presentation → Domain → Data → Core
```

---

## 目錄結構

```
Havital/
├── Features/
│   ├── TrainingPlan/
│   │   ├── Domain/
│   │   │   ├── Entities/
│   │   │   │   ├── WeeklyPlan.swift
│   │   │   │   └── TrainingPlanOverview.swift
│   │   │   ├── Repositories/
│   │   │   │   └── TrainingPlanRepository.swift (Protocol)
│   │   │   └── Errors/
│   │   │       └── TrainingPlanError.swift
│   │   ├── Data/
│   │   │   ├── Repositories/
│   │   │   │   └── TrainingPlanRepositoryImpl.swift
│   │   │   ├── DataSources/
│   │   │   │   ├── TrainingPlanRemoteDataSource.swift
│   │   │   │   └── TrainingPlanLocalDataSource.swift
│   │   │   ├── DTOs/
│   │   │   │   └── WeeklyPlanDTO.swift
│   │   │   └── Mappers/
│   │   │       └── TrainingPlanMapper.swift
│   │   └── Presentation/
│   │       ├── ViewModels/
│   │       │   ├── WeeklyPlanViewModel.swift
│   │       │   └── TrainingOverviewViewModel.swift
│   │       └── Views/
│   │           └── TrainingPlanView.swift
│   │
│   ├── User/
│   │   ├── Domain/...
│   │   ├── Data/...
│   │   └── Presentation/...
│   │
│   ├── Authentication/
│   │   ├── Domain/...
│   │   ├── Data/...
│   │   └── Presentation/...
│   │
│   ├── Workout/
│   │   ├── Domain/...
│   │   ├── Data/...
│   │   └── Presentation/...
│   │
│   └── Onboarding/
│       ├── Domain/...
│       ├── Data/...
│       └── Presentation/...
│
├── Shared/
│   ├── States/
│   │   └── ViewState.swift
│   ├── Errors/
│   │   └── DomainError.swift
│   └── Components/
│       ├── ErrorView.swift
│       └── EmptyStateView.swift
│
├── Core/
│   ├── DI/
│   │   └── DependencyContainer.swift
│   ├── Network/
│   │   ├── HTTPClient.swift (現有)
│   │   └── APIParser.swift (現有)
│   └── Utils/
│       └── TaskManageable.swift (現有)
│
└── Legacy/ (遷移期間暫存)
    ├── Managers/
    └── Services/
```

---

## 核心設計模式

### 1. ViewState<T> 統一狀態

**取代：** 多個 @Published 變數

```swift
enum ViewState<T: Equatable>: Equatable {
    case loading
    case loaded(T)
    case error(DomainError)
    case empty
}

// ViewModel 只需一個狀態變數
@Published var state: ViewState<WeeklyPlan> = .loading
```

**優點：**
- 狀態不可能矛盾（不會同時 loading 又有 error）
- View 用 switch 處理所有狀態
- 取消錯誤不會顯示 ErrorView

---

### 2. Repository 模式 + 雙軌緩存

**保留現有雙軌緩存邏輯，遷移到 Repository：**

```swift
protocol TrainingPlanRepository {
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func generateWeeklyPlan(week: Int) async throws -> WeeklyPlan
}

class TrainingPlanRepositoryImpl: TrainingPlanRepository {
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        // Track A: 檢查緩存
        if let cached = localDataSource.get(planId), !isExpired(planId) {
            // Track B: 背景更新
            Task.detached { await self.refreshInBackground(planId) }
            return mapper.toEntity(cached)
        }

        // 無緩存時從 API 獲取
        let dto = try await remoteDataSource.get(planId)
        localDataSource.save(dto)
        return mapper.toEntity(dto)
    }
}
```

---

### 3. DependencyContainer

**Service Locator 模式，取代 Singleton：**

```swift
final class DependencyContainer {
    static let shared = DependencyContainer()

    private var singletons: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]

    func register<T>(_ service: T, for type: T.Type) { ... }
    func registerFactory<T>(for type: T.Type, factory: @escaping () -> T) { ... }
    func resolve<T>() -> T { ... }
}

// 使用方式
let vm: WeeklyPlanViewModel = DependencyContainer.shared.resolve()
```

**向後兼容：**

```swift
// 遷移期間保留 .shared 介面
extension TrainingPlanManager {
    static var shared: TrainingPlanManager {
        DependencyContainer.shared.resolve()
    }
}
```

---

### 4. 錯誤處理

**統一錯誤類型：**

```swift
enum DomainError: Error, Equatable {
    case networkFailure(String)
    case serverError(Int, String)
    case notFound
    case unauthorized
    case validationFailure(String)
    case cancellationFailure  // 取消錯誤，不顯示 ErrorView
    case unknown(String)
}

extension Error {
    func toDomainError() -> DomainError {
        if let httpError = self as? HTTPError {
            switch httpError {
            case .noConnection: return .networkFailure("No connection")
            case .cancelled: return .cancellationFailure
            // ...
            }
        }
        return .unknown(localizedDescription)
    }
}
```

---

## 層級職責定義

| 層級 | 職責 | 不負責 |
|------|------|--------|
| **View** | UI 渲染、用戶輸入 | 業務邏輯、API 呼叫、狀態計算 |
| **ViewModel** | UI 狀態管理、用戶操作處理 | 業務邏輯、緩存、API 呼叫 |
| **Repository (Protocol)** | 定義數據存取介面 | 實作細節 |
| **RepositoryImpl** | 數據來源協調、緩存策略 | HTTP 通信、JSON 解析 |
| **RemoteDataSource** | API 請求、DTO 返回 | 緩存、業務邏輯 |
| **LocalDataSource** | 本地存儲、過期檢查 | API 請求、業務邏輯 |
| **Mapper** | DTO ↔ Entity 轉換 | 業務邏輯 |
| **Entity** | 業務數據模型 | 序列化細節 |
| **DTO** | API 數據模型 | 業務邏輯 |
