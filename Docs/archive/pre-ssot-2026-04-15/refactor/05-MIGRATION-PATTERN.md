# Service → Repository 遷移模式

本文檔記錄了從 Service 直接調用遷移到 Repository 模式的完整流程，為其他模組提供參考。

## 目錄

1. [遷移概述](#遷移概述)
2. [架構對比](#架構對比)
3. [遷移步驟](#遷移步驟)
4. [代碼模板](#代碼模板)
5. [測試策略](#測試策略)
6. [常見問題](#常見問題)

## 遷移概述

### 為什麼遷移？

**舊架構問題**:
- ❌ ViewModel 直接調用 Service（職責不清）
- ❌ 沒有統一的緩存策略
- ❌ 錯誤處理不一致
- ❌ 難以測試（無法注入依賴）
- ❌ 重複的邏輯分散在多處

**新架構優勢**:
- ✅ 清晰的職責分離
- ✅ 雙軌緩存策略（立即顯示 + 背景更新）
- ✅ 統一的錯誤處理（DomainError）
- ✅ 可測試性（依賴注入）
- ✅ 邏輯集中管理

### 遷移策略

採用 **內部重構（Internal Refactoring）** 而非完全重寫：

```
保留外部接口 + 替換內部實現 = 最小風險
```

## 架構對比

### 舊架構（Service 直接調用）

```
┌─────────────────────────────────────┐
│  TrainingPlanView                   │
│  (SwiftUI)                          │
└──────────────┬──────────────────────┘
               │ @ObservedObject
               ↓
┌─────────────────────────────────────┐
│  TrainingPlanViewModel (2589 行)    │
│  - 直接調用 Service                  │
│  - 自己管理緩存                      │
│  - 自己處理錯誤                      │
└──────────────┬──────────────────────┘
               │ .shared
               ↓
┌─────────────────────────────────────┐
│  TrainingPlanService (Singleton)     │
│  - HTTP 調用                        │
│  - 簡單緩存（不一致）                │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│  HTTPClient / APIParser             │
└─────────────────────────────────────┘
```

**問題**:
1. ViewModel 過於龐大（2589 行）
2. 職責混亂（UI 邏輯 + 數據邏輯 + 緩存邏輯）
3. Singleton 難以測試
4. 緩存策略不一致

### 新架構（Clean Architecture）

```
┌─────────────────────────────────────┐
│  TrainingPlanView                   │
│  (Presentation Layer)               │
└──────────────┬──────────────────────┘
               │ @ObservedObject
               ↓
┌─────────────────────────────────────┐
│  TrainingPlanViewModel              │
│  - 只管理 UI 狀態                    │
│  - 使用 Repository                  │
└──────────────┬──────────────────────┘
               │ 依賴注入
               ↓
┌─────────────────────────────────────┐
│  TrainingPlanRepository (Protocol)  │ ← Domain Layer
│  - 定義業務操作                      │
└──────────────┬──────────────────────┘
               │ 實現
               ↓
┌─────────────────────────────────────┐
│  TrainingPlanRepositoryImpl         │ ← Data Layer
│  - 雙軌緩存策略                      │
│  - 協調 Remote + Local              │
└─────┬────────────────────┬──────────┘
      │                    │
      ↓                    ↓
┌──────────────┐   ┌──────────────────┐
│ RemoteDS     │   │ LocalDS          │
│ (API)        │   │ (Cache)          │
└──────────────┘   └──────────────────┘
```

**優勢**:
1. ViewModel 專注 UI 邏輯
2. Repository 處理數據協調
3. 可測試性提升（依賴注入）
4. 統一的緩存策略

## 遷移步驟

### 步驟 1: 創建 Domain 層（30 分鐘）

#### 1.1 創建 Repository 協議

**文件**: `Features/[Module]/Domain/Repositories/[Module]Repository.swift`

```swift
// Features/TrainingPlan/Domain/Repositories/TrainingPlanRepository.swift
protocol TrainingPlanRepository {
    // 查詢操作（支援緩存）
    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func getOverview() async throws -> TrainingPlanOverview
    func getPlanStatus() async throws -> PlanStatusResponse

    // 強制刷新（跳過緩存）
    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan
    func refreshOverview() async throws -> TrainingPlanOverview

    // 寫操作
    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan
    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan

    // 緩存管理
    func clearCache() async
    func preloadData() async
}
```

**命名規範**:
- 協議名: `[Module]Repository`
- 方法名: `get[Entity]`, `create[Entity]`, `update[Entity]`, `delete[Entity]`
- 刷新方法: `refresh[Entity]`

### 步驟 2: 創建 Data 層（2-3 小時）

#### 2.1 創建 RemoteDataSource

**文件**: `Features/[Module]/Data/DataSources/[Module]RemoteDataSource.swift`

```swift
// Features/TrainingPlan/Data/DataSources/TrainingPlanRemoteDataSource.swift
final class TrainingPlanRemoteDataSource {
    private let httpClient: HTTPClient
    private let parser: APIParser

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        let rawData = try await httpClient.request(
            path: "/plan/race_run/weekly/\(planId)",
            method: .GET
        )
        return try ResponseProcessor.extractData(
            WeeklyPlan.self,
            from: rawData,
            using: parser
        )
    }

    // ... 其他 API 方法
}
```

**職責**: 只負責 API 調用，不處理緩存

#### 2.2 創建 LocalDataSource

**文件**: `Features/[Module]/Data/DataSources/[Module]LocalDataSource.swift`

```swift
// Features/TrainingPlan/Data/DataSources/TrainingPlanLocalDataSource.swift
final class TrainingPlanLocalDataSource {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private enum Keys {
        static let weeklyPlanPrefix = "weekly_plan_v2_"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let weeklyPlan: TimeInterval = 7 * 24 * 60 * 60  // 7 天
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // 保存
    func saveWeeklyPlan(_ plan: WeeklyPlan, planId: String) {
        let key = Keys.weeklyPlanPrefix + planId
        do {
            let data = try encoder.encode(plan)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
            Logger.debug("[LocalDataSource] Saved: \(planId)")
        } catch {
            Logger.error("[LocalDataSource] Save failed: \(error)")
        }
    }

    // 讀取
    func getWeeklyPlan(planId: String) -> WeeklyPlan? {
        let key = Keys.weeklyPlanPrefix + planId
        guard let data = defaults.data(forKey: key) else { return nil }

        do {
            return try decoder.decode(WeeklyPlan.self, from: data)
        } catch {
            Logger.debug("[LocalDataSource] Decode failed: \(error)")
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: key + Keys.timestampSuffix)
            return nil
        }
    }

    // 檢查過期
    func isWeeklyPlanExpired(planId: String) -> Bool {
        let key = Keys.weeklyPlanPrefix + planId + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.weeklyPlan
    }

    // 刪除
    func removeWeeklyPlan(planId: String) {
        let key = Keys.weeklyPlanPrefix + planId
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + Keys.timestampSuffix)
    }
}
```

**職責**:
- 緩存存取
- TTL 管理
- 不處理業務邏輯

**TTL 建議**:
- 週計劃: 7 天
- 訓練概覽: 24 小時
- 計劃狀態: 8 小時

#### 2.3 創建 RepositoryImpl

**文件**: `Features/[Module]/Data/Repositories/[Module]RepositoryImpl.swift`

```swift
// Features/TrainingPlan/Data/Repositories/TrainingPlanRepositoryImpl.swift
final class TrainingPlanRepositoryImpl: TrainingPlanRepository {
    private let remoteDataSource: TrainingPlanRemoteDataSource
    private let localDataSource: TrainingPlanLocalDataSource

    init(
        remoteDataSource: TrainingPlanRemoteDataSource = TrainingPlanRemoteDataSource(),
        localDataSource: TrainingPlanLocalDataSource = TrainingPlanLocalDataSource()
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - 雙軌緩存策略

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        Logger.debug("[Repository] getWeeklyPlan: \(planId)")

        // Track A: 立即返回緩存
        if let cached = localDataSource.getWeeklyPlan(planId: planId),
           !localDataSource.isWeeklyPlanExpired(planId: planId) {
            Logger.debug("[Repository] Cache hit: \(planId)")

            // Track B: 背景刷新
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshWeeklyPlanInBackground(planId: planId)
            }

            return cached
        }

        // 無緩存或已過期
        Logger.debug("[Repository] Cache miss, fetching from API: \(planId)")
        return try await fetchAndCacheWeeklyPlan(planId: planId)
    }

    // MARK: - Private Methods

    private func fetchAndCacheWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        let plan = try await remoteDataSource.getWeeklyPlan(planId: planId)
        localDataSource.saveWeeklyPlan(plan, planId: planId)
        return plan
    }

    private func refreshWeeklyPlanInBackground(planId: String) async {
        do {
            let plan = try await remoteDataSource.getWeeklyPlan(planId: planId)
            localDataSource.saveWeeklyPlan(plan, planId: planId)
            Logger.debug("[Repository] Background refresh success: \(planId)")
        } catch {
            // 背景刷新失敗不影響已顯示的緩存
            Logger.debug("[Repository] Background refresh failed: \(error)")
        }
    }
}
```

**雙軌緩存模式**:
```
getWeeklyPlan()
  ├── Track A: 立即返回緩存（主線程）
  │     └── 用戶看到數據（快）
  │
  └── Track B: 背景更新（異步）
        └── 更新緩存（新）
```

### 步驟 3: 註冊依賴（15 分鐘）

**文件**: `Features/[Module]/Data/Repositories/[Module]RepositoryImpl.swift` (擴展)

```swift
// MARK: - DependencyContainer Registration
extension DependencyContainer {
    func register[Module]Module() {
        // DataSources
        register(
            [Module]RemoteDataSource(),
            for: [Module]RemoteDataSource.self
        )
        register(
            [Module]LocalDataSource(),
            for: [Module]LocalDataSource.self
        )

        // Repository
        let repository = [Module]RepositoryImpl(
            remoteDataSource: resolve(),
            localDataSource: resolve()
        )
        register(
            repository as [Module]Repository,
            forProtocol: [Module]Repository.self
        )

        Logger.debug("[DI] [Module] module registered")
    }
}
```

### 步驟 4: 遷移 ViewModel（1-2 小時）

#### 4.1 添加 Repository 屬性

```swift
class TrainingPlanViewModel: ObservableObject {
    // 🆕 Clean Architecture: 使用 Repository 而不是直接調用 Service
    private let trainingPlanRepository: TrainingPlanRepository

    // 保留所有現有的 @Published 屬性不變
    @Published var weeklyPlan: WeeklyPlan?
    @Published var planStatus: PlanStatus = .loading
    // ... 其他 48 個 @Published 屬性
}
```

#### 4.2 修改 init 支持依賴注入

```swift
init(repository: TrainingPlanRepository? = nil) {
    // 🆕 Clean Architecture: 初始化 Repository (可注入以便測試)
    if let repository = repository {
        self.trainingPlanRepository = repository
    } else {
        // 生產環境：從 DI Container 獲取
        if !DependencyContainer.shared.isRegistered(TrainingPlanRepository.self) {
            DependencyContainer.shared.registerTrainingPlanModule()
        }
        self.trainingPlanRepository = DependencyContainer.shared.resolve()
    }

    // ... 保留原有的初始化邏輯
}
```

#### 4.3 替換 API 調用

**替換模式**:

```swift
// ❌ 舊代碼
let plan = try await TrainingPlanService.shared.getWeeklyPlanById(planId: planId)

// ✅ 新代碼
// 🆕 Clean Architecture: 使用 Repository 替代直接調用 Service
let plan = try await trainingPlanRepository.getWeeklyPlan(planId: planId)
```

**查找並替換所有調用**:
```bash
# 搜索所有 Service 調用
grep -n "TrainingPlanService.shared" TrainingPlanViewModel.swift

# 常見的替換：
# - getWeeklyPlanById → getWeeklyPlan
# - getPlanStatus → getPlanStatus
# - createWeeklyPlan → createWeeklyPlan
# - modifyWeeklyPlan → modifyWeeklyPlan
```

#### 4.4 保持外部接口不變

**關鍵原則**: 所有 @Published 屬性和 public 方法保持不變

```swift
// ✅ 保持不變
@Published var weeklyPlan: WeeklyPlan?
@Published var planStatus: PlanStatus = .loading
@Published var isLoading: Bool = false

// ✅ 方法簽名保持不變
func loadWeeklyPlan() async {
    // 只改內部實現
}

func generateNextWeekPlan() async {
    // 只改內部實現
}
```

### 步驟 5: 修復 Preview 文件（15 分鐘）

```swift
// PreviewHelpers/WeeklyPlanPreviewView.swift
class PreviewViewModel: TrainingPlanViewModel {
    init() {  // ❌ 移除 override
        super.init(repository: nil)  // ✅ 調用新的 init
        // Preview 專用設置
    }
}
```

### 步驟 6: 測試構建（10 分鐘）

```bash
cd /Users/wubaizong/havital/apps/ios/Havital
xcodebuild clean build \
    -project Havital.xcodeproj \
    -scheme Havital \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 代碼模板

### Repository 協議模板

```swift
// Features/[Module]/Domain/Repositories/[Module]Repository.swift
protocol [Module]Repository {
    // 讀取操作（支援緩存）
    func get[Entity](id: String) async throws -> [Entity]

    // 刷新操作（跳過緩存）
    func refresh[Entity](id: String) async throws -> [Entity]

    // 寫入操作
    func create[Entity](params: [Params]) async throws -> [Entity]
    func update[Entity](id: String, params: [Params]) async throws -> [Entity]
    func delete[Entity](id: String) async throws

    // 緩存管理
    func clearCache() async
}
```

### RemoteDataSource 模板

```swift
// Features/[Module]/Data/DataSources/[Module]RemoteDataSource.swift
final class [Module]RemoteDataSource {
    private let httpClient: HTTPClient
    private let parser: APIParser

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.httpClient = httpClient
        self.parser = parser
    }

    func get[Entity](id: String) async throws -> [Entity] {
        let rawData = try await httpClient.request(
            path: "/api/[module]/[entity]/\(id)",
            method: .GET
        )
        return try ResponseProcessor.extractData(
            [Entity].self,
            from: rawData,
            using: parser
        )
    }
}
```

### LocalDataSource 模板

```swift
// Features/[Module]/Data/DataSources/[Module]LocalDataSource.swift
final class [Module]LocalDataSource {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private enum Keys {
        static let [entity]Prefix = "[entity]_v1_"
        static let timestampSuffix = "_timestamp"
    }

    private enum TTL {
        static let [entity]: TimeInterval = 24 * 60 * 60  // 24 小時
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func save[Entity](_ entity: [Entity], id: String) {
        let key = Keys.[entity]Prefix + id
        do {
            let data = try encoder.encode(entity)
            defaults.set(data, forKey: key)
            defaults.set(Date(), forKey: key + Keys.timestampSuffix)
        } catch {
            Logger.error("[LocalDataSource] Save failed: \(error)")
        }
    }

    func get[Entity](id: String) -> [Entity]? {
        let key = Keys.[entity]Prefix + id
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode([Entity].self, from: data)
    }

    func is[Entity]Expired(id: String) -> Bool {
        let key = Keys.[entity]Prefix + id + Keys.timestampSuffix
        guard let timestamp = defaults.object(forKey: key) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > TTL.[entity]
    }
}
```

## 測試策略

詳見 [測試策略文檔](04-TESTING-STRATEGY.md)

### 快速測試腳本

```bash
# 運行所有測試
./Scripts/test_training_plan.sh all

# 只測試 Repository
./Scripts/test_training_plan.sh repository

# 清理構建後測試
./Scripts/test_training_plan.sh all --clean
```

## 常見問題

### Q1: 是否需要完全重寫 ViewModel？

**不需要**。採用內部重構策略：
- ✅ 保留所有 @Published 屬性
- ✅ 保留所有 public 方法簽名
- ✅ 只替換內部的 Service 調用為 Repository

### Q2: 如何處理現有的緩存邏輯？

**遷移到 Repository**：
1. 將 ViewModel 中的緩存代碼移到 LocalDataSource
2. Repository 統一管理緩存策略
3. ViewModel 不再關心緩存細節

### Q3: 雙軌緩存會增加 API 調用嗎？

**不會**：
- Track A 返回緩存後，用戶已經看到數據
- Track B 背景更新不阻塞 UI
- 下次訪問時看到最新數據
- 實際 API 調用次數不變

### Q4: Preview 文件報錯怎麼辦？

移除 `override` 關鍵字，調用新的 init：
```swift
// ❌ 舊代碼
override init() { super.init() }

// ✅ 新代碼
init() { super.init(repository: nil) }
```

### Q5: 如何確保遷移正確？

1. ✅ 構建成功（xcodebuild）
2. ✅ 單元測試通過
3. ✅ 手動測試主要流程
4. ✅ 檢查日誌（緩存命中/未命中）

### Q6: 遷移後如何回退？

使用 Git：
```bash
# 查看改動
git diff

# 回退所有改動
git checkout -- .

# 回退特定文件
git checkout -- TrainingPlanViewModel.swift
```

## 下一個模組

遵循同樣的模式遷移其他模組：
1. User 模組（UserManager 648 行）
2. Workout 模組（UnifiedWorkoutManager 1049 行）
3. Onboarding 模組
4. Settings 模組

## 檢查清單

遷移前檢查：
- [ ] 閱讀遷移模式文檔
- [ ] 準備測試數據 (Fixtures)
- [ ] 創建 Git 分支

遷移時檢查：
- [ ] 創建 Repository 協議
- [ ] 創建 RemoteDataSource
- [ ] 創建 LocalDataSource
- [ ] 創建 RepositoryImpl
- [ ] 註冊依賴到 DI Container
- [ ] 修改 ViewModel init
- [ ] 替換所有 Service 調用
- [ ] 修復 Preview 文件

遷移後檢查：
- [ ] 構建成功
- [ ] 單元測試通過
- [ ] 手動測試通過
- [ ] 代碼審查
- [ ] 提交 Pull Request

## 參考資料

- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)
- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-using-factories-in-swift/)
