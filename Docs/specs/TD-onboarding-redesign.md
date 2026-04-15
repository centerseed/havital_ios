---
type: TD
id: TD-onboarding-redesign
status: Draft
l2_entity: onboarding
created: 2026-04-15
updated: 2026-04-15
decisions_updated: 2026-04-15
---

# 技術設計：Onboarding 流程重新設計

## 1. 架構設計

### 1.1 ViewModel 共享方案（解決 M6）

**現狀問題**：每個 Onboarding View 都在 `init` 中透過 `@StateObject` 建立獨立的 `OnboardingFeatureViewModel` 實例。例如：

- `PersonalBestView`: `@StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())`
- `WeeklyDistanceSetupView`: 同上
- `GoalTypeSelectionView`: 同上
- `TrainingDaysSetupView`: 同上
- `MethodologySelectionView`: `@StateObject private var viewModel = OnboardingFeatureViewModel()`
- `StartStageSelectionView`: 同上

每次建新實例 = 跨步驟資料全部丟失，返回時狀態重置，重複 API 呼叫。

**技術方案：EnvironmentObject 注入共享 ViewModel**

在 `OnboardingContainerView` 建立單一 `OnboardingFeatureViewModel` 實例，透過 `.environmentObject()` 注入到整個 NavigationStack 子樹。所有步驟 View 改用 `@EnvironmentObject` 接收。

```swift
// OnboardingContainerView.swift
struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingFeatureViewModel

    init(isReonboarding: Bool) {
        self.isReonboarding = isReonboarding
        _viewModel = StateObject(wrappedValue: DependencyContainer.shared.makeOnboardingFeatureViewModel())
    }

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            // ... root view ...
            .navigationDestination(for: OnboardingCoordinator.Step.self) { step in
                destinationView(for: step)
            }
        }
        .environmentObject(viewModel)  // 注入共享 ViewModel
    }
}

// 各步驟 View
struct PersonalBestView: View {
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel
    // 移除 @StateObject 建立
}
```

**選擇理由**：

- SwiftUI 原生機制，無額外依賴
- `@EnvironmentObject` 在 NavigationStack 子樹中自動傳遞，包括 `.navigationDestination` 產生的 View
- 生命週期由 `OnboardingContainerView` 的 `@StateObject` 管理，整個 onboarding 流程期間只有一個實例
- Preview 需要手動注入 `.environmentObject()`，但這是標準做法

**替代方案（被否決）**：

| 方案 | 否決原因 |
|------|----------|
| Singleton ViewModel | 違反 Factory pattern 原則，ViewModel 不應是 Singleton |
| OnboardingCoordinator 持有 ViewModel | Coordinator 職責是導航，不應持有業務邏輯 |
| 傳參（每個 View init 接收 viewModel） | 15 個 View 全部改 init signature，且 `.navigationDestination` 閉包不方便傳遞 |

**影響範圍**：

- 需修改的 View：PersonalBestView, WeeklyDistanceSetupView, GoalTypeSelectionView, TrainingDaysSetupView, MethodologySelectionView, StartStageSelectionView, TrainingOverviewView, OnboardingView（共 8 個）
- 不需修改的 View：OnboardingIntroView, DataSourceSelectionView, HeartRateZoneInfoView, BackfillPromptView, MaintenanceRaceDistanceView, TrainingWeeksSetupView（這些使用獨立 ViewModel 或無 ViewModel）
- Re-onboarding 流程：同樣受益，因為共享同一個 NavigationStack

**決策（2026-04-15 更新）**：`OnboardingView`（RaceSetup 頁面）原使用獨立的 `OnboardingViewModel`。經第一性原理分析後，決定**合併到 `OnboardingFeatureViewModel`**：

- Onboarding 是單一目標的資料收集流程，所有步驟最終匯聚成一個動作 `createTarget`
- 兩個 ViewModel 的資料不獨立：完賽時間需要距離、距離可能來自賽事資料庫、目標類型決定走哪條路
- 分開只是製造需要同步的間接耦合
- 單一事實來源，不需要透過 Coordinator 搬資料

**需要搬移的邏輯**：
- `OnboardingViewModel.createTarget()` → `OnboardingFeatureViewModel.createTarget()`
- `OnboardingViewModel.loadAvailableTargets()` → `OnboardingFeatureViewModel.loadAvailableTargets()`
- `OnboardingViewModel` 持有的賽事相關狀態（`targetName`, `targetDate`, `targetDistance`, `targetTime` 等）→ 搬到 `OnboardingFeatureViewModel`
- `OnboardingView`（RaceSetup）改用 `@EnvironmentObject` 接收共享 ViewModel
- 移除 `OnboardingViewModel.swift`

**影響範圍**：
- Task F2 工作量增加約 2h（從 2h → 4h）
- 需修改的 View 增加 `OnboardingView`（RaceSetup），共 9 個 View 改用 `@EnvironmentObject`
- 賽事選擇邏輯（Race API 載入、精選賽事、搜尋篩選等）也整合到 `OnboardingFeatureViewModel`，不再需要獨立的 `RaceSetupEntryViewModel`

---

### 1.2 Race API 整合方案

#### 1.2.1 Feature 模組結構

遵循現有 `TrainingPlanV2` 模組的 Clean Architecture 結構：

```
Havital/Features/Race/
├── Data/
│   ├── DTOs/
│   │   └── RaceDTO.swift              # snake_case + CodingKeys
│   ├── DataSources/
│   │   └── RaceRemoteDataSource.swift  # API 呼叫
│   ├── Mappers/
│   │   └── RaceMapper.swift            # DTO → Entity
│   └── Repositories/
│       └── RaceRepositoryImpl.swift     # 實作 + DI 註冊
├── Domain/
│   ├── Entities/
│   │   └── RaceEvent.swift             # camelCase Entity
│   └── Repositories/
│       └── RaceRepository.swift        # Protocol
└── (Presentation 層在 Onboarding Views 中，不另建)
```

#### 1.2.2 Domain Entity

```swift
// RaceEvent.swift — Domain Layer
struct RaceEvent: Identifiable, Equatable {
    let raceId: String
    let name: String
    let region: String
    let eventDate: Date
    let city: String
    let location: String?
    let distances: [RaceDistance]
    let entryStatus: String?
    let isCurated: Bool
    let courseType: String?
    let tags: [String]

    var id: String { raceId }

    /// 距離賽事天數
    var daysUntilEvent: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: eventDate).day ?? 0
    }

    /// 是否時間不足（< 4 週）
    var isTimeTight: Bool {
        daysUntilEvent < 28
    }
}

struct RaceDistance: Identifiable, Equatable {
    let distanceKm: Double
    let name: String

    var id: Double { distanceKm }
}
```

#### 1.2.3 DTO（Data Layer）

```swift
// RaceDTO.swift — Data Layer
struct RaceDTO: Codable {
    let raceId: String
    let name: String
    let region: String
    let eventDate: String          // "YYYY-MM-DD"
    let city: String
    let location: String?
    let distances: [RaceDistanceDTO]
    let entryStatus: String?
    let isCurated: Bool?
    let courseType: String?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case raceId = "race_id"
        case name, region
        case eventDate = "event_date"
        case city, location, distances
        case entryStatus = "entry_status"
        case isCurated = "is_curated"
        case courseType = "course_type"
        case tags
    }
}

struct RaceDistanceDTO: Codable {
    let distanceKm: Double
    let name: String

    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case name
    }
}

struct RaceListResponseDTO: Codable {
    let races: [RaceDTO]
    let total: Int
    let limit: Int
    let offset: Int
}
```

#### 1.2.4 Repository Protocol

```swift
// RaceRepository.swift — Domain Layer
protocol RaceRepository {
    /// 查詢賽事列表（支援篩選）
    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> [RaceEvent]
}
```

#### 1.2.5 Graceful Degradation 策略（整合到 OnboardingFeatureViewModel）

**決策（2026-04-15 更新）**：不新增獨立的 `RaceSetupEntryView` 和 `RaceSetupEntryViewModel`。賽事選擇邏輯整合到 `OnboardingFeatureViewModel`，UI 直接在現有 `OnboardingView`（RaceSetup）中實作三態切換。

```swift
// OnboardingFeatureViewModel 新增賽事相關狀態
@MainActor
class OnboardingFeatureViewModel: ObservableObject {
    // ... 現有屬性 ...

    // 賽事 API 狀態
    @Published var raceEvents: [RaceEvent] = []
    @Published var isRaceAPIAvailable: Bool = true
    @Published var isLoadingRaces: Bool = false
    @Published var selectedRaceEvent: RaceEvent? = nil
    @Published var selectedRaceDistance: RaceDistance? = nil

    // 地區切換（P0-10 AC5）
    @Published var selectedRegion: String = "tw"  // tw | jp

    private let raceRepository: RaceRepository

    func loadCuratedRaces() async {
        isLoadingRaces = true
        do {
            raceEvents = try await raceRepository.getRaces(
                region: selectedRegion, distanceMin: nil, distanceMax: nil,
                dateFrom: nil, dateTo: nil, query: nil,
                curatedOnly: true, limit: 50, offset: nil
            )
            isRaceAPIAvailable = !raceEvents.isEmpty
        } catch {
            isRaceAPIAvailable = false
            Logger.warn("[Onboarding] Race API unavailable: \(error.localizedDescription)")
        }
        isLoadingRaces = false
    }

    func selectRaceEvent(_ event: RaceEvent, distance: RaceDistance) {
        selectedRaceEvent = event
        selectedRaceDistance = distance
        // 自動填入賽事資訊到目標設定
        targetName = event.name
        targetDate = event.eventDate
        targetDistance = distance.distanceKm
    }
}
```

**OnboardingView（RaceSetup）三態 UI**（Designer 定案）：

- **狀態 1（初始）**：頂部顯示「從賽事資料庫選擇」卡片（GoalTypeCard 風格，淡藍底+藍框），下方用「或手動輸入」分隔線接手動表單
- **狀態 2（已選賽事）**：卡片變為 accentColor 填充摘要卡（白字顯示賽事名/城市/日期/距離+倒數 badge），隱藏手動輸入區域，只保留「目標完賽時間」編輯+「更換賽事」按鈕
- **狀態 3（API 不可用）**：完全隱藏資料庫入口和分隔線，直接顯示手動輸入表單（`isRaceAPIAvailable == false`）

符合 spec P0-10 AC11: "Given 後台賽事 API 不可用或回傳空列表...Then 不顯示「從賽事資料庫選擇」入口，直接顯示手動輸入表單"。

---

### 1.3 統一佈局組件設計

#### 1.3.1 OnboardingPageTemplate

建立統一的頁面 template，所有 onboarding View 套用：

```swift
struct OnboardingPageTemplate<Content: View>: View {
    let title: String?
    let ctaTitle: String
    let ctaEnabled: Bool
    let isLoading: Bool
    let skipTitle: String?        // nil = 不顯示跳過按鈕
    let ctaAction: () -> Void
    let skipAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // 可捲動內容區
            ScrollView {
                content()
                    .padding(.horizontal, 24)      // 統一水平 padding
                    .padding(.bottom, 120)          // 為底部 CTA 留空間
            }

            // 固定底部 CTA 區域
            OnboardingBottomCTA(
                ctaTitle: ctaTitle,
                ctaEnabled: ctaEnabled,
                isLoading: isLoading,
                skipTitle: skipTitle,
                ctaAction: ctaAction,
                skipAction: skipAction
            )
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

#### 1.3.2 OnboardingBottomCTA

統一的底部 CTA 組件，固定在螢幕底部：

```swift
struct OnboardingBottomCTA: View {
    let ctaTitle: String
    let ctaEnabled: Bool
    let isLoading: Bool
    let skipTitle: String?
    let ctaAction: () -> Void
    let skipAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            // 主 CTA 按鈕
            Button(action: ctaAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text(ctaTitle)
                        .font(AppFont.headline())
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!ctaEnabled || isLoading)
            .padding(.vertical, 16)
            .background(ctaEnabled ? Color.accentColor : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)                       // 統一圓角 12pt
            .padding(.horizontal, 24)               // 統一水平 padding

            // 跳過按鈕（D2 設計決策：主 CTA 下方文字連結）
            if let skipTitle = skipTitle, let skipAction = skipAction {
                Button(action: skipAction) {
                    Text(skipTitle)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
            }

            Spacer().frame(height: 16)              // 統一底部間距
        }
        .background(Color(.systemBackground))
    }
}
```

#### 1.3.3 佈局規範常數

```swift
enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 24
    static let ctaCornerRadius: CGFloat = 12
    static let ctaBottomPadding: CGFloat = 16
    static let ctaHorizontalPadding: CGFloat = 24
    static let contentBottomPadding: CGFloat = 120  // 為底部 CTA 留空間
    static let sectionSpacing: CGFloat = 24
    static let titleFont = AppFont.title2()
    static let descriptionFont = AppFont.bodySmall()
}
```

---

### 1.4 進度指示器技術方案

#### 1.4.1 ProgressBar 組件

```swift
struct OnboardingProgressBar: View {
    let progress: Double   // 0.0 ~ 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景軌道
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)

                // 進度條
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}
```

#### 1.4.2 進度計算邏輯

放在 `OnboardingCoordinator` 中，依據 D1 設計決策：GoalType 之前的步驟佔前半段，之後根據實際路徑均分後半段。

```swift
// OnboardingCoordinator 新增
@Published private(set) var maxReachedProgress: Double = 0.0

var currentProgress: Double {
    // 前半段：intro ~ goalType（固定 7 步，佔 0 ~ 0.5）
    // 後半段：根據選擇的路徑動態計算（佔 0.5 ~ 1.0）
    let newProgress = calculateProgress()
    // 只進不退
    if newProgress > maxReachedProgress {
        maxReachedProgress = newProgress
    }
    return maxReachedProgress
}
```

分支步驟數對照表：

| 路徑 | GoalType 之後的步驟 | 後半段步數 |
|------|---------------------|-----------|
| race_run（時間充足）| raceSetup → methodology → trainingDays → overview | 4 |
| race_run（時間緊張）| raceSetup → methodology → startStage → trainingDays → overview | 5 |
| beginner | trainingWeeksSetup → trainingDays → overview | 3 |
| maintenance | trainingWeeksSetup → maintenanceRaceDistance → trainingDays → overview | 4 |
| maintenance（多方法論）| methodology → trainingWeeksSetup → maintenanceRaceDistance → trainingDays → overview | 5 |

進度條會嵌入 `OnboardingContainerView` 的 NavigationStack 頂部，所有頁面共享。

---

## 2. 任務拆分

### 前置任務（基礎設施）

#### Task F1: 建立統一佈局組件（OnboardingPageTemplate + OnboardingBottomCTA）
**對應 Spec**: P0-1, P0-2, P0-3
**依賴**: 無
**預估工時**: 2h

**Done Criteria**:
- [ ] 建立 `OnboardingPageTemplate` 組件，支援 ScrollView 內容 + 固定底部 CTA
- [ ] 建立 `OnboardingBottomCTA` 組件，支援主 CTA + 可選跳過按鈕（D2 設計決策）
- [ ] 建立 `OnboardingLayout` 常數（padding: 24pt, cornerRadius: 12pt）
- [ ] CTA disabled 狀態視覺差異明顯：enabled 用 `Color.accentColor`，disabled 用 `Color.gray.opacity(0.4)`（P1-2 一併解決）
- [ ] 所有頁面的 CTA 按鈕位置、大小、圓角一致（AC: P0-1）
- [ ] CTA 始終固定在螢幕底部可見位置，不隨內容捲動（AC: P0-1, P0-2）
- [ ] Clean build 通過

#### Task F2: ViewModel 共享改造 + OnboardingViewModel 合併（M6 修復）
**對應 Spec**: P0-9, P0-10（部分：ViewModel 層面）
**依賴**: P0-6（需要 RaceRepository Protocol），可與 F1 並行
**預估工時**: 4h

**Done Criteria**:
- [ ] `OnboardingContainerView` 建立單一 `OnboardingFeatureViewModel` 實例，透過 `.environmentObject()` 注入
- [ ] 以下 View 改用 `@EnvironmentObject`: PersonalBestView, WeeklyDistanceSetupView, GoalTypeSelectionView, TrainingDaysSetupView, MethodologySelectionView, StartStageSelectionView, TrainingOverviewView, **OnboardingView（RaceSetup）**
- [ ] 移除這些 View 中的 `@StateObject private var viewModel` 宣告
- [ ] **合併 `OnboardingViewModel` 邏輯到 `OnboardingFeatureViewModel`**：
  - [ ] 搬移 `createTarget()` 方法
  - [ ] 搬移 `loadAvailableTargets()` 方法
  - [ ] 搬移賽事相關狀態（`targetName`, `targetDate`, `targetDistance`, `targetTime` 等）
  - [ ] 新增賽事 API 狀態（`raceEvents`, `isRaceAPIAvailable`, `isLoadingRaces`, `selectedRaceEvent`, `selectedRaceDistance`, `selectedRegion`）
  - [ ] 新增 `loadCuratedRaces()` 方法（依賴 `RaceRepository`）
  - [ ] 新增 `selectRaceEvent(_:distance:)` 方法（自動填入賽事資訊）
- [ ] **移除 `OnboardingViewModel.swift`**
- [ ] `OnboardingFeatureViewModel` 依賴 `RaceRepository` Protocol（不是 Impl）
- [ ] `DependencyContainer.makeOnboardingFeatureViewModel()` 更新為注入 `RaceRepository`
- [ ] AC 驗證（P0-9 AC1）：在 PersonalBestView 輸入 PB → 前進到 WeeklyDistance → 返回 PersonalBest → PB 數據保留不重置
- [ ] AC 驗證（P0-9 AC2）：GoalType 選擇目標 → MethodologySelection 能直接讀取目標類型，不重新 API 載入
- [ ] AC 驗證（P0-9 AC3）：步驟 A 已取得的 API 資料，步驟 B 不重複發送 API 請求
- [ ] Re-onboarding 流程正常運作（PersonalBest 作為根視圖時也能正確注入 ViewModel）
- [ ] Clean build 通過

#### Task F3: 進度指示器實作
**對應 Spec**: P1-1
**依賴**: F1（需要知道佈局位置）
**預估工時**: 2h

**Done Criteria**:
- [ ] 建立 `OnboardingProgressBar` 組件
- [ ] `OnboardingCoordinator` 新增 `currentProgress` 和 `maxReachedProgress` 計算邏輯
- [ ] 進度條嵌入 `OnboardingContainerView`，所有步驟可見
- [ ] AC 驗證：不同分支（race_run / beginner / maintenance）顯示正確的步驟比例
- [ ] AC 驗證：返回上一步時，進度條維持最高到達位置，不回退（D1 設計決策）
- [ ] Clean build 通過

---

### P0 任務

#### Task P0-1: 套用統一佈局到所有 Onboarding View（批次 1：前半段）
**對應 Spec**: P0-1, P0-2, P0-3, P0-6
**依賴**: F1, F2
**預估工時**: 3h

**涉及檔案**:
- `OnboardingIntroView.swift`
- `DataSourceSelectionView.swift`
- `HeartRateZoneInfoView.swift`
- `PersonalBestView.swift`
- `WeeklyDistanceSetupView.swift`

**Done Criteria**:
- [ ] 所有 5 個 View 套用 `OnboardingPageTemplate`
- [ ] `OnboardingIntroView`: 移除 ScrollView 內的 Spacer（P0-2 修復），CTA 按鈕固定底部，不被推出螢幕
- [ ] `DataSourceSelectionView`: 移除 `.navigationBarHidden(true)`（P0-6），顯示 navigation bar 和返回按鈕（P0-7）
- [ ] `PersonalBestView`: 移除 toolbar 的「下一步」按鈕，統一用底部 CTA（P0-3）
- [ ] `WeeklyDistanceSetupView`: 移除 toolbar 的「跳過」和「下一步」，統一用底部 CTA + 跳過文字連結（P0-3, D2）
- [ ] 所有頁面水平 padding 統一 24pt、CTA cornerRadius 統一 12pt（P0-1）
- [ ] AC 驗證：iPhone SE 到 iPhone Pro Max 所有尺寸下 CTA 不超出螢幕（P0-2）
- [ ] AC 驗證：DataSourceSelectionView 有可見返回按鈕（P0-7）
- [ ] Clean build 通過

#### Task P0-2: 套用統一佈局到所有 Onboarding View（批次 2：後半段）
**對應 Spec**: P0-1, P0-3, P0-6
**依賴**: F1, F2
**預估工時**: 3h

**涉及檔案**:
- `GoalTypeSelectionView.swift`
- `OnboardingView.swift`（RaceSetup）
- `MethodologySelectionView.swift`
- `StartStageSelectionView.swift`
- `TrainingWeeksSetupView.swift`
- `MaintenanceRaceDistanceView.swift`
- `TrainingDaysSetupView.swift`
- `TrainingOverviewView.swift`

**Done Criteria**:
- [ ] 所有 8 個 View 套用 `OnboardingPageTemplate`
- [ ] `GoalTypeSelectionView`: 移除底部 `Spacer()`，使用 OnboardingBottomCTA
- [ ] `OnboardingView`: 移除 toolbar 的「下一步」按鈕（P0-3），統一用底部 CTA
- [ ] `MethodologySelectionView`: 統一底部 CTA 樣式
- [ ] 所有頁面 navigation bar 可見，有返回按鈕（P0-6）
- [ ] 所有頁面水平 padding、CTA 樣式一致
- [ ] AC 驗證：任何非首頁步驟都有可見返回按鈕（P0-6）
- [ ] Clean build 通過

#### Task P0-3: 每週跑量輸入精度改善
**對應 Spec**: P0-4
**依賴**: P0-1（佈局需先統一）
**預估工時**: 1h

**涉及檔案**:
- `WeeklyDistanceSetupView.swift`

**Done Criteria**:
- [ ] 將 Slider 替換為分段式輸入或非線性 Slider（常見範圍 0-60km 佔 70% 軌道，60-180km 佔 30%），或改用 Stepper + 數字輸入的組合
- [ ] AC 驗證：用戶能在 3 秒內精確設定到 15km，無需反覆微調（P0-4）
- [ ] AC 驗證：每次步進不超過 5km（P0-4）
- [ ] 保留 Stepper（步進 1km），移除或改善 Slider
- [ ] Clean build 通過

**技術建議**：移除 Slider，只保留 Stepper（步進 1km）並加大數字顯示。或改用帶預設值的快捷按鈕（10km / 20km / 30km / 40km+）搭配 Stepper 微調。

#### Task P0-4: 距離與時間編輯器佔比修復
**對應 Spec**: P0-5
**依賴**: 無
**預估工時**: 1h

**涉及檔案**:
- `RaceDistanceTimeEditorSheet.swift`

**Done Criteria**:
- [ ] 距離 Picker 改為 `.segmented` 或 `.menu` 樣式（不用 `.inline` 佔滿螢幕）
- [ ] AC 驗證：picker 佔螢幕不超過 60%（P0-5）
- [ ] AC 驗證：用戶能同時看到距離選擇和時間設定（P0-5）
- [ ] AC 驗證：完成選擇後一鍵確認退出（已有 Done 按鈕，確認仍有效）
- [ ] Clean build 通過

#### Task P0-5: 硬編碼中文改 i18n
**對應 Spec**: P0-8
**依賴**: 無
**預估工時**: 0.5h

**涉及檔案**:
- `RaceDistanceTimeEditorSheet.swift`

**Done Criteria**:
- [ ] `getCommonTimes(for:)` 函式中所有硬編碼中文改用 `NSLocalizedString`
- [ ] 繁中/英文 .strings 檔案都新增對應翻譯 key
- [ ] AC 驗證：app 語言為英文時，所有文字顯示英文，無中文殘留（P0-8）
- [ ] AC 驗證：app 語言為繁中時，正確顯示繁中（P0-8）
- [ ] Clean build 通過

#### Task P0-6: Race Feature 模組建立（DTO / Entity / Repository / DataSource）
**對應 Spec**: P0-10
**依賴**: 無（純新增，不影響現有程式碼）
**預估工時**: 2h

**涉及檔案（全部新建）**:
- `Havital/Features/Race/Domain/Entities/RaceEvent.swift`
- `Havital/Features/Race/Domain/Repositories/RaceRepository.swift`
- `Havital/Features/Race/Data/DTOs/RaceDTO.swift`
- `Havital/Features/Race/Data/Mappers/RaceMapper.swift`
- `Havital/Features/Race/Data/DataSources/RaceRemoteDataSource.swift`
- `Havital/Features/Race/Data/Repositories/RaceRepositoryImpl.swift`

**Done Criteria**:
- [ ] `RaceEvent` Entity（camelCase），不帶 Codable
- [ ] `RaceDTO`（snake_case + CodingKeys）
- [ ] `RaceMapper` 負責 DTO → Entity 轉換，包含日期字串解析
- [ ] `RaceRemoteDataSource` 實作 `GET /v2/races` 呼叫，使用 `APICallHelper`，支援所有 query 參數
- [ ] `RaceRepository` Protocol 定義 `getRaces(...)` 方法，參數對應 API spec 附錄 B 所有篩選參數
- [ ] `RaceRepositoryImpl` 實作 Protocol，串接 DataSource + Mapper
- [ ] DI 註冊：`DependencyContainer` 新增 `registerRaceModule()`
- [ ] API 呼叫加 `.tracked(from: "RaceRemoteDS: getRaces")`
- [ ] Clean build 通過

#### Task P0-7: 賽事選擇 UI 實作
**對應 Spec**: P0-10（全部 12 條 AC）
**依賴**: P0-6, F1, F2, P0-2
**預估工時**: 4h

**涉及檔案（新建 + 修改）**:
- 修改 `Havital/Views/Onboarding/OnboardingView.swift`（RaceSetup：整合三態 UI）
- 新建 `Havital/Views/Onboarding/RaceEventListView.swift`（賽事列表頁，含地區切換器和搜尋）
- 新建 `Havital/Views/Onboarding/RaceDistanceSelectionSheet.swift`（多距離選擇 Sheet）
- 新建 `Havital/Views/Onboarding/InlineWarningBanner.swift`（倒數不足提示 banner）
- 修改 `OnboardingContainerView.swift`（新增 step 對應）
- 修改 `OnboardingCoordinator.swift`（新增 step enum）

**Done Criteria**:

OnboardingView（RaceSetup）三態 UI：
- [ ] 狀態 1（初始）：頂部顯示「從賽事資料庫選擇」卡片（GoalTypeCard 風格，淡藍底+藍框），下方用「或手動輸入」分隔線接手動表單（P0-10 AC1）
- [ ] 狀態 2（已選賽事）：卡片變為 accentColor 填充摘要卡（白字顯示賽事名/城市/日期/距離+倒數 badge），隱藏手動輸入區域，只保留「目標完賽時間」編輯+「更換賽事」按鈕（P0-10 AC7）
- [ ] 狀態 3（API 不可用）：完全隱藏資料庫入口和分隔線，直接顯示手動輸入表單（P0-10 AC11）

RaceEventListView（賽事列表頁）：
- [ ] 顯示精選賽事列表，每項顯示名稱、城市、日期、可選距離（P0-10 AC2）
- [ ] 搜尋功能：輸入關鍵字即時過濾（P0-10 AC3）
- [ ] 距離篩選：選擇距離條件（如「半馬」）後列表過濾（P0-10 AC4）
- [ ] 地區切換器：頁面頂部提供 Segmented Control（台灣|日本），用戶主動切換，不依賴裝置語系（P0-10 AC5）
- [ ] 過期賽事規則：只隱藏 `event_date` 已過期的賽事；`entry_status=closed` 仍顯示，以橘色 badge 標示報名已截止（P0-10 AC10）

RaceDistanceSelectionSheet（多距離選擇）：
- [ ] 多距離賽事以 Dialog/Sheet 彈出距離選擇，不跳轉新頁面（P0-10 AC6）
- [ ] 用戶點選距離即選中，自動 dismiss Sheet（P0-10 AC6）

選擇完成後行為：
- [ ] 選擇完成後回到 OnboardingView，賽事名稱、距離、日期自動填入，顯示「距離賽事還有 X 天」倒數（P0-10 AC7）
- [ ] 倒數天數不足 4 週時顯示 InlineWarningBanner 提示（P0-10 AC8）
- [ ] 選完賽事設定完賽時間後按下一步，流程正常進入後續步驟（P0-10 AC9）
- [ ] 選擇距離後顯示常見完賽時間參考（P0-10 AC12）

導航與架構：
- [ ] `OnboardingCoordinator.Step` 新增 `raceEventList`（不需要 `raceSetupEntry`——入口已整合到 OnboardingView）
- [ ] OnboardingView 點擊「從賽事資料庫選擇」卡片 → NavigationStack push 到 `raceEventList`
- [ ] 所有新建 View 使用 `OnboardingPageTemplate`，佈局一致
- [ ] API 呼叫加 `.tracked(from: "RaceEventListView: loadRaces")`
- [ ] Clean build 通過

---

### P1 任務

#### Task P1-1: 心率區間設定頁優化
**對應 Spec**: P1-3
**依賴**: F1（佈局）, F2（ViewModel 共享）
**預估工時**: 2h

**涉及檔案**:
- `HeartRateZoneInfoView.swift`
- 可能需修改 `OnboardingFeatureViewModel.swift`（新增預設心率計算邏輯）

**Done Criteria**:
- [ ] 基於用戶年齡/性別提供預設心率值（最大心率 = 220 - 年齡）（P1-3 AC1）
- [ ] 頁面顯示說明文字：「可先使用預設值，日後再更新」（P1-3 AC2）
- [ ] 使用預設值按下一步後，值被正確儲存（P1-3 AC3）
- [ ] 手動修改後，不再顯示「使用預設值」提示（P1-3 AC4）
- [ ] Profile/設定中有提示引導更新心率數據（P1-3 AC5）——注意：此項可能超出 onboarding 範圍，標記為延後
- [ ] Clean build 通過

#### Task P1-2: Disabled 按鈕可辨識度提升
**對應 Spec**: P1-2
**依賴**: F1（已在 OnboardingBottomCTA 中處理）
**預估工時**: 0.5h

**Done Criteria**:
- [ ] `OnboardingBottomCTA` 的 disabled 狀態使用 `Color.gray.opacity(0.4)`，enabled 使用 `Color.accentColor`（P1-2 AC1）
- [ ] 從 disabled → enabled 有動畫過渡（`.animation(.easeInOut, value: ctaEnabled)`）（P1-2 AC2）
- [ ] Clean build 通過

**注意**：此任務大部分已在 F1 中完成，P1-2 只需確認並微調。

#### Task P1-3: 賽事列表體驗優化
**對應 Spec**: P1-4
**依賴**: P0-7
**預估工時**: 1h

**Done Criteria**:
- [ ] 賽事列表使用 `LazyVStack` 確保捲動流暢（P1-4 AC1）
- [ ] 搜尋使用 debounce（300ms 內不重複觸發）（P1-4 AC2）
- [ ] 列表按日期排序，最近在前（P1-4 AC3）
- [ ] Clean build 通過

---

### P2 任務

#### Task P2-1: PB 輸入優化
**對應 Spec**: P2-1
**依賴**: P0-1
**預估工時**: 1.5h

**Done Criteria**:
- [ ] PB 時間輸入改為更緊湊的形式（如數字鍵盤 or compact picker）
- [ ] 輸入控制元件佔螢幕不超過 40%（P2-1 AC1）
- [ ] 5K PB 25:30 能在 5 秒內完成設定（P2-1 AC2）
- [ ] Clean build 通過

#### Task P2-2: 步驟間過場動畫
**對應 Spec**: P2-2
**依賴**: P0-1, P0-2
**預估工時**: 1h

**Done Criteria**:
- [ ] 自訂 NavigationStack transition 動畫
- [ ] 動畫流暢無掉幀，時長不超過 350ms（P2-2 AC1）
- [ ] Clean build 通過

---

## 3. Spec AC ↔ 任務對照表

> Spec P0-10 共 12 條 AC（含 AC5 地區切換器、AC6 多距離 Sheet、AC10 過期賽事規則，為 2026-04-15 新增）。

| Spec AC | 任務 | Done Criteria 對應 |
|---------|------|-------------------|
| P0-1 AC1: CTA 位置/大小/圓角/間距一致 | F1 + P0-1 + P0-2 | F1 建組件，P0-1/P0-2 套用到所有 View |
| P0-1 AC2: CTA 固定底部，不被推出/不隨捲動 | F1 + P0-1 + P0-2 | OnboardingPageTemplate 的 VStack + ScrollView 結構保證 |
| P0-1 AC3: 標題字型/水平間距/CTA 樣式一致 | F1 + P0-1 + P0-2 | OnboardingLayout 常數 + 統一套用 |
| P0-2 AC1: IntroView CTA 可見無需捲動 | P0-1 | 移除 Spacer，CTA 固定底部 |
| P0-2 AC2: 所有螢幕尺寸下 CTA 不超出 | P0-1 | OnboardingPageTemplate 保證固定底部 |
| P0-3 AC1: 每頁只有一個「下一步」入口 | P0-1 + P0-2 | 移除所有 toolbar 按鈕 |
| P0-3 AC2: 跳過按鈕為次要文字連結 | F1 | OnboardingBottomCTA skipTitle 參數 |
| P0-4 AC1: 15km 精確設定 3 秒內 | P0-3 | Stepper 步進 1km 或快捷按鈕 |
| P0-4 AC2: 步進不超過 5km | P0-3 | Stepper 步進 1km |
| P0-5 AC1: picker 佔螢幕不超過 60% | P0-4 | 距離 picker 改 segmented/menu |
| P0-5 AC2: 一鍵確認退出 | P0-4 | 已有 Done 按鈕 |
| P0-6 AC1: 非首頁步驟有可見返回按鈕 | P0-1 + P0-2 | 移除 navigationBarHidden |
| P0-6 AC2: DataSourceSelection 有返回方式 | P0-1 | 移除 `.navigationBarHidden(true)` |
| P0-7 AC1: DataSourceSelection 可返回到 Intro | P0-1 | 移除 `.navigationBarHidden(true)`，NavigationStack 自動提供返回按鈕 |
| P0-8 AC1: 英文下無中文殘留 | P0-5 | getCommonTimes 改 NSLocalizedString |
| P0-8 AC2: 繁中下正確顯示 | P0-5 | .strings 檔案新增翻譯 |
| P0-9 AC1: PB 數據返回時保留 | F2 | EnvironmentObject 共享 ViewModel |
| P0-9 AC2: 跨步驟讀取 GoalType 不重新載入 | F2 | 共享 ViewModel，onAppear 不重複呼叫 |
| P0-9 AC3: 已取得資料不重複 API 請求 | F2 | 共享 ViewModel，資料已在記憶體中 |
| P0-10 AC1: 賽事設定頁兩個入口 | P0-7 | OnboardingView 三態 UI — 狀態 1 顯示「從賽事資料庫選擇」卡片 + 手動輸入表單 |
| P0-10 AC2: 精選賽事列表（名稱/城市/日期/距離）| P0-7 | RaceEventListView 顯示精選列表 |
| P0-10 AC3: 搜尋即時過濾 | P0-7 | RaceEventListView 搜尋功能 |
| P0-10 AC4: 距離篩選 | P0-7 | RaceEventListView 距離篩選 |
| P0-10 AC5: 地區切換器（台灣/日本 Segmented Control）| P0-7 | RaceEventListView 頂部 Segmented Control，用戶主動切換 |
| P0-10 AC6: 多距離賽事以 Sheet 選距離，選完自動 dismiss | P0-7 | RaceDistanceSelectionSheet，點選即 dismiss |
| P0-10 AC7: 選完自動填入 + 倒數天數 | P0-7 | selectRaceEvent 回填 + 摘要卡倒數 badge |
| P0-10 AC8: 不足 4 週顯示提示 | P0-7 | InlineWarningBanner + isTimeTight |
| P0-10 AC9: 設定完賽時間後流程正常進後續步驟 | P0-7 | 導航邏輯 |
| P0-10 AC10: 只隱藏過期賽事，entry_status=closed 仍顯示（橘色 badge）| P0-7 | 過期篩選邏輯 + badge UI |
| P0-10 AC11: API 不可用 graceful degradation | P0-7 | 狀態 3：隱藏資料庫入口，直接顯示手動表單 |
| P0-10 AC12: 選距離後顯示常見完賽時間參考 | P0-7 | 複用 RaceDistanceTimeEditorSheet |
| P1-1 AC1: 進度指示器可見 | F3 | OnboardingProgressBar |
| P1-1 AC2: 分支比例正確 | F3 | 動態步數計算 |
| P1-1 AC3: 只進不退 | F3 | maxReachedProgress |
| P1-2 AC1: disabled 視覺差異明顯 | F1 + P1-2 | opacity 差異 |
| P1-2 AC2: enabled 動畫反饋 | P1-2 | .animation modifier |
| P1-3 AC1: 預設心率值 | P1-1 | 220 - age 計算 |
| P1-3 AC2: 說明文字 | P1-1 | UI 文案 |
| P1-3 AC3: 預設值正確儲存 | P1-1 | 儲存邏輯 |
| P1-3 AC4: 手動修改後無提示 | P1-1 | 狀態判斷 |
| P1-3 AC5: Profile 提示更新 | P1-1 | 標記延後 |
| P1-4 AC1: 捲動流暢 | P1-3 | LazyVStack |
| P1-4 AC2: 搜尋 300ms 內 | P1-3 | debounce |
| P1-4 AC3: 日期排序 | P1-3 | sorted by eventDate |
| P2-1 AC1: PB 控件佔比 ≤40% | P2-1 | compact picker |
| P2-1 AC2: 5 秒內完成 PB 輸入 | P2-1 | 操作效率 |
| P2-2 AC1: 轉場動畫 ≤350ms | P2-2 | 自訂 transition |

---

## 4. 任務依賴圖

```
F1（佈局組件）──┐
               ├──→ P0-1（佈局批次1）──→ P0-3（WeeklyDistance 精度）
F2（ViewModel 共享 + 合併）──┤                          
               ├──→ P0-2（佈局批次2）
               │
               ├──→ P1-1（心率區間）
               │
F3（進度指示器）──┘   （依賴 F1）

P0-4（picker 佔比）    ← 無依賴
P0-5（i18n）           ← 無依賴
P0-6（Race 模組）      ← 無依賴
                        ↓
                   F2 依賴 P0-6（RaceRepository 注入）

P0-7（賽事選擇 UI）    ← 依賴 P0-6, F1, F2, P0-2

P1-2（disabled 按鈕）  ← 依賴 F1（大部分已完成）
P1-3（賽事列表優化）   ← 依賴 P0-7

P2-1（PB 優化）        ← 依賴 P0-1
P2-2（過場動畫）       ← 依賴 P0-1, P0-2
```

**建議執行順序**：

第一批（可並行）：F1 + P0-4 + P0-5 + P0-6
第二批（依賴第一批）：F2（依賴 P0-6 的 RaceRepository Protocol）+ P0-1 + P0-2 + F3
第三批（依賴第二批）：P0-3 + P0-7 + P1-1 + P1-2
第四批：P1-3 + P2-1 + P2-2

---

## 5. 風險與注意事項

### 5.1 不確定的技術點

1. **`@EnvironmentObject` 在 `.navigationDestination` 中的傳遞**：SwiftUI 文件確認 `NavigationStack` 會向 destination view 傳遞 environment，但在某些 iOS 版本（16.0 early builds）曾有 bug。需在實作後用最低支援的 iOS 版本驗證。如果失敗，fallback 方案：在 `destinationView(for:)` 中手動加 `.environmentObject(viewModel)`。

2. **Race API 回傳格式**：Spec 附錄 B 定義了格式，但實際 API 回傳可能有差異（例如 optional 欄位多寡、日期格式）。DTO 設計時所有非必要欄位都標為 Optional，Mapper 做防禦性解析。

### 5.2 替代方案與選擇理由

| 決策 | 選擇 | 替代 | 理由 |
|------|------|------|------|
| ViewModel 共享 | EnvironmentObject | Singleton / Coordinator 持有 | SwiftUI 原生，生命週期明確 |
| OnboardingViewModel 處置 | 合併到 OnboardingFeatureViewModel | 保持獨立 + Coordinator 搬資料 | 單一事實來源，資料不獨立（完賽時間需距離、距離可能來自賽事資料庫），分開只是製造間接耦合 |
| RaceSetup 入口設計 | OnboardingView 內三態切換 | 新增 RaceSetupEntryView 獨立入口頁 | Designer 定案，減少頁面跳轉，用戶體驗更流暢 |
| 多距離選擇 | Sheet 彈出，選完自動 dismiss | 獨立頁面 raceEventDistanceSelection | Designer 定案（P0-10 AC6），減少導航深度 |
| 佈局統一 | 共用 Template 組件 | ViewModifier | Template 可控制完整佈局結構，ViewModifier 只能裝飾 |
| 進度計算位置 | OnboardingCoordinator | 獨立 ProgressManager | Coordinator 已有步驟和路徑資訊，無需新建 |
| 賽事搜尋 | 遠端 API 搜尋 | 先拉全部再本地搜 | API 支援 query 參數，避免拉太多資料 |

### 5.3 需要用戶確認的決策

~~1. OnboardingView（RaceSetup）的 ViewModel 處置~~ ✅ 已決策（2026-04-15）：合併到 OnboardingFeatureViewModel。理由見 1.1。

~~2. RaceSetup 流程改造幅度~~ ✅ 已決策（2026-04-15）：不新增 RaceSetupEntryView，直接在 OnboardingView 中整合三態 UI。Designer 已定案。

無待確認事項。

### 5.4 最壞情況與修正成本

1. **EnvironmentObject 注入失敗（runtime crash）**：如果某個 View 沒有在 environment 中找到 ViewModel，SwiftUI 會 crash。修正成本低（加 `.environmentObject()` 或改用 optional binding），但需要確保所有入口（包括 Preview、re-onboarding）都正確注入。

2. **佈局統一後迴歸問題**：15 個 View 全部改動佈局，某些 View 可能有特殊的鍵盤互動、sheet 彈出等行為受影響。修正成本中等，需要 QA 逐頁驗證。

3. **Race API 不穩定**：如果 API 偶爾超時或回傳異常，影響用戶體驗。已有 graceful degradation 設計（隱藏入口，fallback 到手動輸入），修正成本低。

### 5.5 Re-onboarding 影響評估

Re-onboarding 從 PersonalBest 開始，跳過 intro/dataSource/heartRateZone。ViewModel 共享改造後：

- `OnboardingContainerView` 的 `isReonboarding` 參數決定根視圖（PersonalBest vs Intro）
- 共享的 ViewModel 在 ContainerView 建立，無論哪個根視圖都能正確注入
- 進度指示器需要處理：re-onboarding 起始進度應從 PersonalBest 對應的位置開始，而非 0

---

## 6. Spec 衝突偵測

Spec 衝突檢查：**無衝突**。

- `SPEC-iap-paywall-pricing-and-trial-protection.md`：IAP paywall 在 onboarding 完成後觸發，不影響 onboarding 流程內部。
- `SPEC-subscription-management-and-status-ui.md`：訂閱管理在主 app 內，與 onboarding 無交集。
- Spec 自身聲明已確認與上述兩份 spec 無衝突。

---

## 7. Spec 介面合約清單

### 7.1 Race API 介面（Spec 附錄 B）

| 參數 | 類型 | 對應 Repository 方法參數 | 對應 Done Criteria |
|------|------|------------------------|-------------------|
| region | String? | `region` | P0-6 |
| distance_km | Float? | 未映射（使用 distance_min/max 替代） | P0-6: 技術設計選擇用範圍篩選替代精確值，因 UI 用距離分類（半馬/全馬）而非精確值 |
| distance_min | Float? | `distanceMin` | P0-6 |
| distance_max | Float? | `distanceMax` | P0-6 |
| date_from | String? | `dateFrom` | P0-6 |
| date_to | String? | `dateTo` | P0-6 |
| q | String? | `query` | P0-6 |
| curated_only | Bool? | `curatedOnly` | P0-6 |
| limit | Int? | `limit` | P0-6 |
| offset | Int? | `offset` | P0-6 |

### 7.2 新增 Coordinator Step

| Step | 顯示條件 | 目的 |
|------|---------|------|
| raceEventList | OnboardingView 點擊「從賽事資料庫選擇」卡片 | 瀏覽/搜尋/篩選賽事 |

**已移除的 Step**（2026-04-15 更新）：
- ~~`raceSetupEntry`~~：入口已整合到 OnboardingView 三態 UI 中，不需要獨立頁面
- ~~`raceEventDistanceSelection`~~：距離選擇改為 Sheet（P0-10 AC6），不需要獨立的 NavigationStack step

### 7.3 OnboardingFeatureViewModel 新增介面（2026-04-15 更新）

合併 `OnboardingViewModel` 後，`OnboardingFeatureViewModel` 新增以下介面：

| 方法/屬性 | 類型 | 說明 |
|-----------|------|------|
| `raceEvents` | `@Published [RaceEvent]` | 賽事列表 |
| `isRaceAPIAvailable` | `@Published Bool` | 賽事 API 是否可用 |
| `isLoadingRaces` | `@Published Bool` | 賽事列表載入中 |
| `selectedRaceEvent` | `@Published RaceEvent?` | 已選賽事 |
| `selectedRaceDistance` | `@Published RaceDistance?` | 已選距離 |
| `selectedRegion` | `@Published String` | 地區（tw/jp） |
| `loadCuratedRaces()` | `async` | 載入精選賽事 |
| `selectRaceEvent(_:distance:)` | sync | 選擇賽事+距離，自動填入目標設定 |
| `createTarget()` | `async throws` | 原 OnboardingViewModel 的建立目標方法 |
| `loadAvailableTargets()` | `async throws` | 原 OnboardingViewModel 的載入可用目標 |
