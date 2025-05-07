# Havital iOS App Architecture

This document describes the high-level architecture and directory structure of the Havital iOS application.

## Project Structure

```
Havital/                  # Main workspace
├── Havital.xcodeproj     # Xcode project file
├── HavitalApp.swift      # App entry point (SwiftUI)
├── Info.plist            # App configuration
├── GoogleService-Info.plist
├── Havital.entitlements
├── Assets.xcassets        # App assets (images, colors)
├── Extensions/           # Swift extensions for core types
├── Managers/             # Singleton managers (e.g., UserManager)
├── Models/               # Data models and domain objects
├── Services/             # API, networking, external services
├── Storage/              # Local persistence (e.g., CoreData, UserDefaults)
├── ViewModels/           # MVVM view models
├── Views/                # SwiftUI views and subcomponents
├── Utils/                # Utility helpers and shared code
├── Theme/                # UI theming, color palettes, fonts
├── Resources/            # Static resources (JSON, fonts, icons)
└── Preview Content/      # SwiftUI previews mocks

HavitalTests/             # Unit tests target
HavitalUITests/           # UI tests target
```

## Architectural Pattern

The app follows the **MVVM** (Model-View-ViewModel) pattern:

- **Models**: Define the domain data structures (`Models/`).
- **ViewModels**: Handle business logic and state (`ViewModels/`).
- **Views**: Present UI and bind to view models (`Views/`).

Additional layers:

- **Services**: Encapsulate networking and external API calls.
- **Managers**: Handle app-wide singletons and coordination (e.g., user session).
- **Storage**: Abstract local persistence mechanisms.
- **Utils**: General-purpose helpers.
- **Theme**: Centralize design tokens (colors, typography).

## Key Directories

### Extensions
- Swift extensions that augment Foundation, SwiftUI, or custom types.

### Managers
- Singleton classes managing global state or processes (e.g., authentication, notifications).
- HealthKitManager: handles HealthKit authorization, permissions, and data queries (workouts, heart rate, sleep metrics). Core entry point for any HealthKit-related feature.
- WorkoutBackgroundManager: configures and manages background delivery of workout samples from HealthKit, schedules sync events.
- HeartRateZonesManager & Bridge: processes raw heart rate samples to compute training zones and interval thresholds.

### Models
- Plain data objects, often conforming to `Codable` for JSON mapping.

### Services
- HTTP clients, API request definitions, response parsing.
- WorkoutService: CRUD operations for workout records, communicates with backend endpoints to fetch/post workout data.
- WorkoutBackgroundUploader: batches and uploads offline-collected workout data when connectivity is available.
- ProfileService: manages user profile endpoints (fetch/update user data).
- MetricsService: aggregates and posts user performance metrics (e.g., weekly plans, achievements).

### Storage
- Persistence layer (Core Data stacks, caching, UserDefaults wrappers).

### ViewModels
- Combine-based publishers, form validation, data transformations.

### Views
- SwiftUI screens and reusable components organized by feature (e.g., `UserProfileView`, `TrainingPlanView`).

### Utils
- Helper functions, date formatters, logging, miscellaneous tools.
- Logger Utility
  - Path: `Havital/Utils/Logger.swift`
  - 日誌等級 (LogLevel): `debug`, `info`, `warn`, `error`
  - Build Config:
    - `#if DEBUG`: 輸出 `debug` 以上的日誌
    - `#else`: 輸出 `warn` 以上的日誌
  - 調用方式:
    - `Logger.debug("訊息")`
    - `Logger.info("訊息", tag: "Tag")`
    - `Logger.warn("訊息")`
    - `Logger.error("錯誤訊息")`

### Theme
- Color scheme, font styles, layout constants.

### Resources
- App icons, JSON fixtures, custom fonts, asset catalogs.

## Conclusion

This modular structure promotes separation of concerns, testability, and scalability. Each layer has a clear responsibility.

## View-ViewModel-Service 呼叫流程

1. **View 層 (SwiftUI)**
   - 使用按鈕動作或 `.task` modifier 呼叫 ViewModel。
   - 決定是否隨 UI 取消：
     - 可取消: `Task { await viewModel.method() }` / `.task { await ... }`
     - 不可取消: `Task.detached(priority: .userInitiated) { await viewModel.method() }`

2. **ViewModel 層**
   - 處理業務邏輯、狀態管理、重試與錯誤。
   - 更新 UI 狀態透過 `await MainActor.run { ... }`。
   - 隔離取消時包裝 Service 呼叫: `Task.detached { await Service.call() }`

3. **Service 層**
   - 純粹網路請求: 只用 `URLSession.data(for:)`，解析 `Decodable`。
   - 包含重試機制與日誌（含 HTTP status code）。
   - 不處理取消或 UI 生命週期。

> 新增元件請依此分層呼叫流程，確保 Service 層純粹、取消邏輯集中於 ViewModel。

## 同步處理週計劃與選擇週次

- **週計劃載入流程**：
  1. View 透過 `.task` 或操作觸發 `loadAllInitialData(healthKitManager:)` 或 `loadWeeklyPlan()`；
  2. ViewModel 先呼叫 `TrainingPlanStorage.loadWeeklyPlan()`，若本地有舊資料，立即更新 `weeklyPlan` 和 UI；
  3. 同時在背景非同步呼叫 `TrainingPlanService.shared.getWeeklyPlan(caller:)` 獲取最新週計劃；
  4. 若獲取成功，呼叫 `TrainingPlanStorage.saveWeeklyPlan(newPlan)` 並 `await MainActor.run` 更新 `weeklyPlan`、`currentPlanWeek`、`selectedWeek`，並重新計算週日期資訊。

- **週次選擇邏輯**：
  - `selectedWeek` 綁定於 UI 選單，下拉列表由 `availableWeeks` 動態產生，範圍為 `[1...currentTrainingWeek]`；
  - 使用者切換 `selectedWeek`：
    1. 若本地已有對應週資料，直接顯示；
    2. 否則呼叫 `getWeeklyPlan(caller:)` 下載、儲存後更新。

- **顯示週次與視圖切換**：
  - 若 `currentTrainingWeek > plan.totalWeeks`，顯示 `FinalWeekPromptView`；
  - 否則若 `selectedWeek < currentTrainingWeek` 且 `noWeeklyPlanAvailable == true`，顯示 `NewWeekPromptView`；
  - 否則顯示 `WeekOverviewCard` 與 `DailyTrainingListView`，呈現週概覽與日訓練列表。
