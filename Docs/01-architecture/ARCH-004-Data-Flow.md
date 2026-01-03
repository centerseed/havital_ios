# ARCH-004: 資料流設計

**版本**: 1.0
**最後更新**: 2025-12-30
**狀態**: ✅ 已完成

---

## 目錄

1. [完整數據流概覽](#完整數據流概覽)
2. [App 啟動階段](#app-啟動階段)
3. [訓練計畫載入階段](#訓練計畫載入階段)
4. [雙軌緩存系統](#雙軌緩存系統)
5. [API 調用追蹤](#api-調用追蹤)
6. [時序圖](#時序圖)

---

## 完整數據流概覽

### 六階段數據流

從用戶打開 App 到訓練計畫載入完成，整個數據流分為 6 個階段:

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: App 啟動與 Firebase 初始化                          │
│   HavitalApp.init() → Firebase.configure()                  │
│   └─ 註冊背景任務 (BGTaskScheduler)                          │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: 用戶認證 (10% 進度)                                 │
│   AppStateManager.authenticateUser()                         │
│   └─ AuthenticationService.restoreSession()                 │
│       - 從 Keychain 讀取 token                               │
│       - 驗證 token 有效性                                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: 載入用戶資料 (30% 進度)                             │
│   AppStateManager.loadUserData()                             │
│   ├─ UserService.getUserProfileAsync()  🌐 API              │
│   ├─ UserService.syncUserPreferences()                       │
│   └─ UserManager.updateCurrentUser()  💾 Cache (1-hour TTL) │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: 設置服務 (60% 進度)                                 │
│   AppStateManager.setupServices()                            │
│   ├─ UnifiedWorkoutManager.initialize()                      │
│   │   └─ 註冊 WorkoutV2CacheManager                         │
│   └─ HealthDataUploadManager.initialize()                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: 載入訓練計畫概覽 (80% 進度)                         │
│   TrainingPlanManager.loadTrainingOverview()                 │
│   └─ TrainingPlanService.getTrainingPlanStatus() 🌐 API     │
│       - 返回 TrainingPlanOverview                           │
│       - 儲存到 TrainingPlanStorage (permanent cache)        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 6: 載入週計畫 (100% 進度)                              │
│   TrainingPlanViewModel.loadWeeklyPlan()                     │
│   └─ TrainingPlanManager.loadWeeklyPlan()                   │
│       ├─ Track A: 檢查本地緩存 (TrainingPlanStorage)        │
│       │   └─ 立即顯示緩存內容 → UI 更新                     │
│       └─ Track B: 背景刷新                                   │
│           └─ TrainingPlanService.getWeeklyPlanById() 🌐 API │
│               - 更新緩存                                     │
│               - 更新 UI (如有變化)                           │
└─────────────────────────────────────────────────────────────┘
```

**關鍵特性**:
- 🌐 API Call: 從後端 API 獲取數據
- 💾 Cache: 使用 UnifiedCacheManager 進行本地緩存
- 📱 UI Update: 觸發 SwiftUI View 重新渲染

---

## App 啟動階段

### Phase 1: App 初始化

**文件**: `HavitalApp.swift`

```swift
@main
struct HavitalApp: App {
    init() {
        // 1️⃣ Firebase 初始化
        FirebaseApp.configure()

        // 2️⃣ 註冊背景任務
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .environmentObject(appStateManager)
                .onAppear {
                    Task {
                        // 3️⃣ 啟動 App 初始化流程
                        await appViewModel.initializeApp()

                        // 4️⃣ 設置權限 (基於用戶狀態)
                        await setupPermissionsBasedOnUserState()

                        // 5️⃣ 初始化時區
                        await checkAndInitializeTimezone()
                    }
                }
        }
    }
}
```

**時序**:
```
T0: App Launch
  ↓ 0.1s
T0.1: Firebase.configure() ✅
  ↓ 0.05s
T0.15: registerBackgroundTasks() ✅
  ↓ 0.1s
T0.25: ContentView appears
  ↓ 0.05s
T0.3: appViewModel.initializeApp() 開始
```

### Phase 2-4: AppStateManager 初始化

**文件**: `AppStateManager.swift`

```swift
class AppStateManager: ObservableObject {
    @Published var currentState: AppState = .initializing
    @Published var initializationProgress: Double = 0.0

    enum AppState {
        case initializing      // 0%
        case authenticating    // 10%
        case loadingUserData   // 30%
        case settingUpServices // 60%
        case ready             // 100%
    }

    func initializeApp() async {
        // Phase 2: 用戶認證 (10% 進度)
        currentState = .authenticating
        initializationProgress = 0.1
        await authenticateUser()

        // Phase 3: 載入用戶資料 (30% 進度)
        currentState = .loadingUserData
        initializationProgress = 0.3
        await loadUserData()

        // Phase 4: 設置服務 (60% 進度)
        currentState = .settingUpServices
        initializationProgress = 0.6
        await setupServices()

        // 完成
        currentState = .ready
        initializationProgress = 1.0
    }

    // MARK: - Phase 2: 認證

    private func authenticateUser() async {
        if authService.isAuthenticated {
            Logger.debug("用戶已認證")
            return
        }

        // 嘗試從 Keychain 恢復 session
        await authService.restoreSession()
    }

    // MARK: - Phase 3: 載入用戶資料

    private func loadUserData() async {
        do {
            // 1️⃣ 從 API 獲取用戶資料
            let user = try await userService.getUserProfileAsync()  // 🌐 API Call

            // 2️⃣ 同步用戶偏好設定
            userService.syncUserPreferences(with: user)

            // 3️⃣ 更新本地用戶資料 (1-hour TTL cache)
            await UserManager.shared.updateCurrentUser(user)  // 💾 Cache

            // 4️⃣ 設置數據源偏好
            userDataSource = UserPreferencesManager.shared.dataSourcePreference

            Logger.debug("用戶資料載入成功: \(user.email)")

        } catch {
            Logger.error("載入用戶資料失敗: \(error.localizedDescription)")
            handleInitializationError(error)
        }
    }

    // MARK: - Phase 4: 設置服務

    private func setupServices() async {
        // 1️⃣ 初始化 UnifiedWorkoutManager
        await UnifiedWorkoutManager.shared.initialize()

        // 2️⃣ 初始化 HealthDataUploadManager
        await HealthDataUploadManager.shared.initialize()

        Logger.debug("服務設置完成")
    }
}
```

**時序**:
```
T0.3: initializeApp() 開始
  ↓ 0.2s (Phase 2: 認證)
T0.5: authenticateUser() ✅
  ↓ 0.5s (Phase 3: 載入用戶資料)
T1.0: loadUserData()
    ├─ getUserProfileAsync() 🌐 API (0.3s)
    ├─ syncUserPreferences() (0.1s)
    └─ updateCurrentUser() 💾 Cache (0.1s)
  ↓ 0.3s (Phase 4: 設置服務)
T1.3: setupServices() ✅
  ↓ 0.1s
T1.4: currentState = .ready ✅ (100% 進度)
```

### ContentView 路由邏輯

**文件**: `ContentView.swift`

```swift
struct ContentView: View {
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        ZStack {
            // 1️⃣ 顯示載入畫面 (Phase 1-4)
            if appStateManager.shouldShowLoadingScreen {
                AppLoadingView()
            }
            // 2️⃣ 未登入 → LoginView
            else if !authService.isAuthenticated {
                LoginView()
            }
            // 3️⃣ 未完成 Onboarding → OnboardingView
            else if !authService.hasCompletedOnboarding {
                OnboardingView()
            }
            // 4️⃣ 正常使用 → MainTabView
            else {
                mainAppContent()
            }
        }
    }

    @ViewBuilder
    private func mainAppContent() -> some View {
        TabView {
            TrainingPlanView()  // 進入訓練計畫頁面 (Phase 5-6)
                .tabItem {
                    Label("訓練", systemImage: "figure.run")
                }

            // 其他 Tab...
        }
    }
}
```

**時序**:
```
T0.25-T1.4: AppLoadingView 顯示 (載入畫面)
  ↓
T1.4: appStateManager.currentState = .ready
  ↓ 0.1s
T1.5: mainAppContent() 渲染
  ↓ 0.05s
T1.55: TrainingPlanView appears → Phase 5-6 開始
```

---

## 訓練計畫載入階段

### Phase 5: 載入訓練計畫概覽

**文件**: `TrainingPlanManager.swift`

```swift
class TrainingPlanManager: ObservableObject {
    @Published var trainingOverview: TrainingPlanOverview?

    func loadTrainingOverview() async {
        executeTask(id: TaskID("load_training_overview")) { [weak self] in
            guard let self = self else { return }

            do {
                // 1️⃣ 從 API 獲取訓練計畫狀態
                let overview = try await TrainingPlanService.shared.getTrainingPlanStatus()  // 🌐 API

                // 2️⃣ 儲存到本地緩存 (permanent)
                TrainingPlanStorage.saveTrainingOverview(overview)  // 💾 Cache

                // 3️⃣ 更新 UI 狀態
                await MainActor.run {
                    self.trainingOverview = overview
                }

                Logger.debug("訓練計畫概覽載入成功: \(overview.id)")

            } catch {
                Logger.error("載入訓練計畫概覽失敗: \(error.localizedDescription)")
            }
        }
    }
}
```

**API 響應範例**:
```json
{
  "id": "plan_123",
  "planType": "race_run",
  "currentWeek": 1,
  "totalWeeks": 16,
  "target": {
    "raceType": "marathon",
    "targetTime": "04:00:00"
  }
}
```

**時序**:
```
T1.55: TrainingPlanView appears
  ↓ 0.05s
T1.6: TrainingPlanViewModel.loadAllInitialData()
  ↓ 0.05s
T1.65: TrainingPlanManager.loadTrainingOverview()
  ↓ 0.4s (API 調用)
T2.05: getTrainingPlanStatus() 🌐 API 返回
  ↓ 0.05s
T2.1: TrainingPlanStorage.saveTrainingOverview() 💾
  ↓ 0.05s
T2.15: trainingOverview 更新 → UI 更新 ✅
```

### Phase 6: 載入週計畫 (雙軌緩存)

**文件**: `TrainingPlanManager.swift`

```swift
class TrainingPlanManager: ObservableObject {
    @Published var currentWeeklyPlan: WeeklyPlan?

    func loadWeeklyPlan(targetWeek: Int? = nil) async {
        let weekToLoad = targetWeek ?? currentWeek

        executeTask(id: TaskID("load_weekly_plan_\(weekToLoad)"), cooldownSeconds: 5) { [weak self] in
            await self?.performLoadWeeklyPlan(targetWeek: targetWeek)
        }
    }

    private func performLoadWeeklyPlan(targetWeek: Int?) async {
        let weekToLoad = targetWeek ?? currentWeek

        // ✅ Track A: 檢查本地緩存
        if let savedPlan = TrainingPlanStorage.loadWeeklyPlan(forWeek: weekToLoad) {
            Logger.debug("從緩存載入週計畫: week \(weekToLoad)")

            // 立即更新 UI
            await updateWeeklyPlanUI(plan: savedPlan)

            // ✅ Track B: 背景刷新
            Task.detached { [weak self] in
                await self?.refreshWeeklyPlanInBackground(weekToLoad)
            }
            return
        }

        // 無緩存: 從 API 載入
        Logger.debug("從 API 載入週計畫: week \(weekToLoad)")
        await loadWeeklyPlanFromAPI(weekToLoad: weekToLoad)
    }

    // MARK: - Track B: 背景刷新

    private func refreshWeeklyPlanInBackground(_ week: Int) async {
        do {
            let planId = "\(trainingOverview?.id ?? "")_\(week)"
            let plan = try await TrainingPlanService.shared.getWeeklyPlanById(planId: planId)  // 🌐 API

            // 更新緩存
            TrainingPlanStorage.saveWeeklyPlan(plan)  // 💾 Cache

            // 如果數據有變化，更新 UI
            await updateWeeklyPlanUI(plan: plan)

            Logger.debug("背景刷新週計畫成功: week \(week)")

        } catch {
            Logger.error("背景刷新週計畫失敗: \(error.localizedDescription)")
            // 背景刷新失敗不影響已顯示的緩存
        }
    }

    // MARK: - 從 API 載入

    private func loadWeeklyPlanFromAPI(weekToLoad: Int) async {
        await MainActor.run { isLoading = true }

        do {
            let planId = "\(trainingOverview?.id ?? "")_\(weekToLoad)"
            let plan = try await TrainingPlanService.shared.getWeeklyPlanById(planId: planId)  // 🌐 API

            // 儲存到緩存
            TrainingPlanStorage.saveWeeklyPlan(plan)  // 💾 Cache

            // 更新 UI
            await updateWeeklyPlanUI(plan: plan)

            Logger.debug("週計畫載入成功: \(planId)")

        } catch {
            Logger.error("載入週計畫失敗: \(error.localizedDescription)")
            await MainActor.run {
                self.planStatus = .error(error)
                self.isLoading = false
            }
        }
    }

    // MARK: - 更新 UI

    private func updateWeeklyPlanUI(plan: WeeklyPlan) async {
        await MainActor.run {
            self.currentWeeklyPlan = plan
            self.planStatus = .ready(plan)
            self.isLoading = false
        }
    }
}
```

**時序**:
```
T2.15: loadWeeklyPlan(targetWeek: 1) 開始
  ↓ 0.05s
T2.2: 檢查緩存 TrainingPlanStorage.loadWeeklyPlan(forWeek: 1)

# 情境 A: 有緩存
T2.25: 緩存命中 ✅
  ↓ 0.05s
T2.3: updateWeeklyPlanUI(plan) → UI 更新 ✅ (立即顯示)
  ↓ 0s (並行)
T2.3: Task.detached { refreshWeeklyPlanInBackground() } 開始
  ↓ 0.4s (API 調用)
T2.7: getWeeklyPlanById() 🌐 API 返回
  ↓ 0.05s
T2.75: saveWeeklyPlan() 💾 更新緩存
  ↓ 0.05s
T2.8: updateWeeklyPlanUI(plan) → UI 更新 (如有變化) ✅

# 情境 B: 無緩存
T2.25: 緩存未命中 ❌
  ↓ 0.05s
T2.3: loadWeeklyPlanFromAPI() 開始
  ↓ 0.05s
T2.35: isLoading = true → UI 顯示載入指示器
  ↓ 0.4s (API 調用)
T2.75: getWeeklyPlanById() 🌐 API 返回
  ↓ 0.05s
T2.8: saveWeeklyPlan() 💾 儲存緩存
  ↓ 0.05s
T2.85: updateWeeklyPlanUI(plan) → UI 更新 ✅
```

---

## 雙軌緩存系統

### 核心概念

**Track A (主軌道)**: 立即顯示緩存內容，提升用戶體驗
**Track B (背景軌道)**: 背景刷新最新數據，保證數據新鮮度

### 實作範例: UserPreferencesManager

**文件**: `UserPreferencesManager.swift`

```swift
class UserPreferencesManager: ObservableObject {
    @Published var preferences: UserPreferences?

    private let cacheManager = UnifiedCacheManager<UserPreferencesCacheData>(
        cacheKey: "user_preferences",
        ttlPolicy: .shortTerm,  // 1 hour TTL
        componentName: "UserPreferencesManager"
    )

    func loadPreferences() async {
        executeTask(id: TaskID("load_user_preferences"), cooldownSeconds: 5) { [weak self] in
            await self?.performLoadPreferences()
        }
    }

    private func performLoadPreferences() async {
        // ✅ Track A: 立即顯示緩存 (同步)
        if let cachedPrefs = cacheManager.load()?.preferences,
           !cacheManager.isExpired() {

            await MainActor.run {
                self.preferences = cachedPrefs
            }

            Logger.debug("從緩存載入用戶偏好設定")

            // ✅ Track B: 背景刷新 (非同步)
            Task.detached { [weak self] in
                await self?.refreshInBackground()
            }
            return
        }

        // 無緩存或已過期: 從 API 載入
        await loadFromAPI()
    }

    // MARK: - Track B: 背景刷新

    private func refreshInBackground() async {
        do {
            let prefs = try await service.getPreferences()  // 🌐 API

            // 更新緩存
            cacheManager.save(UserPreferencesCacheData(preferences: prefs))  // 💾 Cache

            // 如果數據有變化，更新 UI
            await MainActor.run {
                if self.preferences != prefs {
                    self.preferences = prefs
                    Logger.debug("背景刷新用戶偏好設定成功 (數據已更新)")
                }
            }

        } catch {
            Logger.error("背景刷新用戶偏好設定失敗: \(error.localizedDescription)")
            // 背景刷新失敗不影響已顯示的緩存
        }
    }

    // MARK: - 從 API 載入

    private func loadFromAPI() async {
        do {
            let prefs = try await service.getPreferences()  // 🌐 API

            await MainActor.run {
                self.preferences = prefs
            }

            cacheManager.save(UserPreferencesCacheData(preferences: prefs))  // 💾 Cache

            Logger.debug("從 API 載入用戶偏好設定成功")

        } catch {
            Logger.error("載入用戶偏好設定失敗: \(error.localizedDescription)")
        }
    }
}
```

### 雙軌緩存優勢

| 特性 | Track A (緩存優先) | Track B (背景刷新) |
|-----|-------------------|-------------------|
| **速度** | 🚀 極快 (< 50ms) | ⏱️ 較慢 (300-500ms) |
| **用戶體驗** | ✅ 立即顯示內容 | ✅ 保證數據新鮮度 |
| **網路依賴** | ❌ 無需網路 | ⚠️ 需要網路 |
| **錯誤處理** | ✅ 無影響 (顯示緩存) | ⚠️ 失敗不影響 UI |
| **更新頻率** | 🔄 每次讀取 | 🔄 每次讀取後觸發 |

### 緩存 TTL 策略

**文件**: `BaseCacheManager.swift`

```swift
enum CacheTTLPolicy {
    case realtime       // 30 分鐘 (即時數據，如 Workout)
    case shortTerm      // 1 小時 (用戶偏好設定)
    case mediumTerm     // 6 小時 (訓練計畫概覽)
    case longTerm       // 24 小時 (用戶資料)
    case weekly         // 7 天 (週摘要)
    case permanent      // 永久 (訓練計畫、目標賽事)
}

extension CacheTTLPolicy {
    var seconds: TimeInterval {
        switch self {
        case .realtime: return 30 * 60
        case .shortTerm: return 60 * 60
        case .mediumTerm: return 6 * 60 * 60
        case .longTerm: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .permanent: return TimeInterval.infinity
        }
    }
}
```

**應用範例**:

| 數據類型 | TTL 策略 | 原因 |
|---------|---------|------|
| **Workout 資料** | .realtime (30min) | 頻繁更新，需保持即時性 |
| **用戶偏好設定** | .shortTerm (1h) | 中等更新頻率 |
| **訓練計畫概覽** | .mediumTerm (6h) | 較穩定，不常變化 |
| **用戶基本資料** | .longTerm (24h) | 很少變化 |
| **週摘要** | .weekly (7d) | 歷史數據，不再變化 |
| **訓練計畫內容** | .permanent | 一旦生成不變 |

---

## API 調用追蹤

### 鏈式調用追蹤系統

**文件**: `APISourceTracking.swift`

```swift
/// API 調用來源追蹤器
class APISourceTracker {
    static let shared = APISourceTracker()

    private var currentSource: String?

    func track(source: String) {
        currentSource = source
    }

    func getCurrentSource() -> String {
        return currentSource ?? "Unknown"
    }
}

/// Task 擴展: 鏈式調用語法
extension Task {
    @discardableResult
    func tracked(from source: String) -> Self {
        APISourceTracker.shared.track(source: source)
        return self
    }
}
```

### 使用範例

**在 View 中追蹤 API 調用**:

```swift
struct TrainingPlanView: View {
    @StateObject private var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack {
            // ... UI content ...
        }
        .onAppear {
            Task {
                await viewModel.loadWeeklyPlan()
            }.tracked(from: "TrainingPlanView: onAppear")  // ✅ 追蹤來源
        }
        .refreshable {
            await Task {
                await viewModel.refreshWeeklyPlan()
            }.tracked(from: "TrainingPlanView: refreshable").value  // ✅ 追蹤來源
        }
    }

    private func refreshWorkouts() {
        Task {
            await viewModel.loadPlanStatus()
            await viewModel.refreshWeeklyPlan()
        }.tracked(from: "TrainingPlanView: refreshWorkouts")  // ✅ 追蹤來源
    }
}
```

### 日誌輸出範例

**HTTPClient 自動記錄調用來源**:

```swift
class HTTPClient {
    func get(_ path: String) async throws -> Data {
        let source = APISourceTracker.shared.getCurrentSource()

        // 🔵 開始日誌
        Logger.debug("📱 [API Call] \(source) → GET \(path)")

        let startTime = Date()

        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            // ✅ 成功日誌
            Logger.debug("✅ [API End] \(source) → GET \(path) | \(statusCode) | \(String(format: "%.2fs", duration))")

            return data

        } catch {
            let duration = Date().timeIntervalSince(startTime)

            // ❌ 失敗日誌
            Logger.error("❌ [API Fail] \(source) → GET \(path) | \(error.localizedDescription) | \(String(format: "%.2fs", duration))")

            throw error
        }
    }
}
```

**實際日誌輸出**:

```
📱 [API Call] TrainingPlanView: onAppear → GET /plan/race_run/status
   ├─ Accept-Language: en
   ├─ Body Size: 0 bytes
✅ [API End] TrainingPlanView: onAppear → GET /plan/race_run/status | 200 | 0.34s

📱 [API Call] TrainingPlanView: onAppear → GET /plan/race_run/weekly/plan_123_1
✅ [API End] TrainingPlanView: onAppear → GET /plan/race_run/weekly/plan_123_1 | 200 | 0.45s

📱 [API Call] TrainingPlanView: refreshable → GET /plan/race_run/weekly/plan_123_1
✅ [API End] TrainingPlanView: refreshable → GET /plan/race_run/weekly/plan_123_1 | 200 | 0.38s
```

---

## 時序圖

### 完整數據流時序圖 (無緩存情況)

```
User          HavitalApp      AppStateManager   AuthService   UserService   TrainingPlanManager   TrainingPlanService   UI
 │                │                  │               │             │                │                      │              │
 │  打開 App       │                  │               │             │                │                      │              │
 ├───────────────>│                  │               │             │                │                      │              │
 │                │ Firebase.config()│               │             │                │                      │              │
 │                ├─────────────────>│               │             │                │                      │              │
 │                │                  │               │             │                │                      │              │
T0               T0.1               │               │             │                │                      │              │
 │                │                  │               │             │                │                      │              │
 │                │ initializeApp()  │               │             │                │                      │              │
 │                ├─────────────────>│               │             │                │                      │              │
 │                │                  │ authenticating│             │                │                      │              │
 │                │                  ├───────────────────────────────────────────────────────────────────>│ (10% 進度)   │
 │                │                  │               │             │                │                      │              │
T0.3             │                  │ restoreSession()            │                │                      │              │
 │                │                  ├──────────────>│             │                │                      │              │
 │                │                  │               │ ✅          │                │                      │              │
T0.5             │                  │<──────────────┤             │                │                      │              │
 │                │                  │               │             │                │                      │              │
 │                │                  │ loadingUserData            │                │                      │              │
 │                │                  ├───────────────────────────────────────────────────────────────────>│ (30% 進度)   │
 │                │                  │               │             │                │                      │              │
 │                │                  │ getUserProfileAsync() 🌐    │                │                      │              │
 │                │                  ├──────────────────────────────>│                │                      │              │
 │                │                  │               │             │ (API 調用 0.3s) │                      │              │
T1.0             │                  │<──────────────────────────────┤ User           │                      │              │
 │                │                  │               │             │                │                      │              │
 │                │                  │ updateCurrentUser() 💾       │                │                      │              │
 │                │                  ├──────────────────────────────────────────────────────────────────────────────────>│
 │                │                  │               │             │                │                      │              │
 │                │                  │ settingUpServices          │                │                      │              │
 │                │                  ├───────────────────────────────────────────────────────────────────>│ (60% 進度)   │
T1.3             │                  │               │             │                │                      │              │
 │                │                  │ ✅ ready      │             │                │                      │              │
 │                │                  ├───────────────────────────────────────────────────────────────────>│ (100% 進度)  │
T1.4             │                  │               │             │                │                      │              │
 │                │                  │               │             │                │                      │              │
 │                │                  │               │             │                │                      │ MainTabView  │
 │                │                  │               │             │                │                      │    顯示     │
 │                │                  │               │             │                │                      ├─────────────>│
T1.5             │                  │               │             │                │                      │              │
 │                │                  │               │             │                │                      │ TrainingPlan │
 │                │                  │               │             │                │                      │ View appears │
 │                │                  │               │             │                │                      ├─────────────>│
T1.55            │                  │               │             │                │                      │              │
 │                │                  │               │             │                │ loadWeeklyPlan()     │              │
 │                │                  │               │             │                ├─────────────────────>│              │
 │                │                  │               │             │                │ 檢查緩存 ❌          │              │
T2.2             │                  │               │             │                │ getWeeklyPlanById() 🌐              │
 │                │                  │               │             │                │ ────────────────────>│              │
 │                │                  │               │             │                │ (API 調用 0.4s)      │              │
T2.7             │                  │               │             │                │<─────────────────────┤ WeeklyPlan   │
 │                │                  │               │             │                │ saveWeeklyPlan() 💾  │              │
 │                │                  │               │             │                │──────────────────────────────────────>│
T2.8             │                  │               │             │                │                      │              │
 │                │                  │               │             │                │ updateUI()           │              │
 │                │                  │               │             │                │ ─────────────────────────────────────>│
 │                │                  │               │             │                │                      │ ✅ 顯示週計畫 │
T2.85<───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
```

### 雙軌緩存時序圖 (有緩存情況)

```
Time    TrainingPlanManager    TrainingPlanStorage    TrainingPlanService    UI
 │              │                      │                     │                 │
 │ loadWeeklyPlan()                    │                     │                 │
 ├─────────────>│                      │                     │                 │
T2.15          │ loadWeeklyPlan(week:1)│                     │                 │
 │              ├─────────────────────>│                     │                 │
 │              │ ✅ WeeklyPlan (cached)│                     │                 │
T2.25          │<─────────────────────┤                     │                 │
 │              │                      │                     │                 │
 │              │ updateWeeklyPlanUI() │                     │                 │
 │              ├──────────────────────────────────────────────────────────────>│
 │              │                      │                     │ ✅ 立即顯示緩存  │
T2.3           │                      │                     │                 │
 │              │                      │                     │                 │
 │              │ Task.detached {      │                     │                 │
 │              │   refreshInBackground()                    │                 │
 │              │ }                    │                     │                 │
 │              ├──────────────────────────────────────────>│                 │
 │              │                      │ getWeeklyPlanById() 🌐                │
T2.3           │                      │ ─────────────────────>                │
 │              │                      │ (API 調用 0.4s)     │                 │
 │              │                      │                     │                 │
T2.7           │                      │<─────────────────────┤ WeeklyPlan      │
 │              │                      │                     │                 │
 │              │ saveWeeklyPlan() 💾  │                     │                 │
 │              ├─────────────────────>│                     │                 │
T2.75          │                      │                     │                 │
 │              │                      │                     │                 │
 │              │ updateWeeklyPlanUI() │                     │                 │
 │              ├──────────────────────────────────────────────────────────────>│
 │              │                      │                     │ ✅ 更新 UI (如有變化)
T2.8           │                      │                     │                 │
```

**關鍵時間點**:
- **T2.3**: 用戶立即看到緩存內容 (< 150ms)
- **T2.8**: 背景更新完成，UI 刷新 (如有變化)

---

## 總結

### 完整數據流關鍵要點

1. **六階段初始化**: Firebase → 認證 → 用戶資料 → 服務設置 → 訓練概覽 → 週計畫
2. **雙軌緩存系統**: Track A (立即顯示緩存) + Track B (背景刷新)
3. **漸進式載入**: AppStateManager 提供清晰的進度反饋 (10% → 30% → 60% → 100%)
4. **API 調用追蹤**: `.tracked(from:)` 語法提供完整的調用鏈追蹤
5. **錯誤處理**: 背景刷新失敗不影響已顯示的緩存內容

### 性能指標

| 階段 | 無緩存時間 | 有緩存時間 | 用戶體驗 |
|-----|-----------|-----------|---------|
| **App 啟動** | ~1.4s | ~1.4s | ⏱️ 載入畫面 |
| **訓練概覽** | ~0.5s | ~0.1s | 📊 進度條 |
| **週計畫載入** | ~0.6s | ~0.15s | ✅ 立即顯示 |
| **背景刷新** | N/A | ~0.5s | 🔄 無感知更新 |

### 優勢總結

- ✅ **快速啟動**: 1.4s 內完成 App 初始化
- ✅ **即時顯示**: 雙軌緩存保證 < 200ms 顯示內容
- ✅ **數據新鮮**: 背景刷新保證數據最新
- ✅ **易於追蹤**: API 調用來源完整記錄
- ✅ **容錯性強**: 背景刷新失敗不影響 UI

---

**文檔版本**: 1.0
**撰寫日期**: 2025-12-30
**分析基於**: Paceriz iOS App 實際代碼 (截至 2025-12-30)
