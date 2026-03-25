# FRD: Training V2 UI/UX 設計規格

**文件版本**: 2.0
**建立日期**: 2025-01-17
**最後更新**: 2025-01-17
**狀態**: Draft
**相關文件**: [FRD-TRAINING-V2-INTEGRATION.md](FRD-TRAINING-V2-INTEGRATION.md)

---

## 1. 概述

### 1.1 設計目標

Training V2 UI 設計的核心目標：

1. **保持 V1 的直觀性** - 用戶一進入就看到本週課表、跑量、強度，無需額外點擊
2. **擴展計畫透明度** - 提供完整的訓練計畫概覽（階段、方法論、週預覽）作為可選查看
3. **最小化學習成本** - 與 V1 UI 保持高度一致，用戶無感知升級
4. **漸進式資訊揭露** - 主要資訊立即可見，詳細資訊按需查看

### 1.2 設計原則

- **零點擊原則** - 關鍵資訊（跑量、強度、本週課表）一進入就能看到
- **保持 V1 佈局** - TrainingProgressCard → WeekOverviewCard → 每日課表
- **V2 擴展作為增強** - Plan Overview 作為可選查看，不干擾主流程
- **快速載入體驗** - 優先顯示快取資料，背景更新

### 1.3 與 V1 的差異對比

| 面向 | V1 | V2 |
|-----|----|----|
| **主頁面佈局** | TrainingProgressCard → WeekOverviewCard → 每日課表 | **完全相同** ✅ |
| **一進入就看到** | 跑量、強度、本週課表 | **完全相同** ✅ |
| **計畫概覽** | 工具列 → Training Overview Sheet | 工具列 → **Plan Overview Sheet (擴展版)** ⭐ |
| **週預覽** | 無 | **整合在 Plan Overview Sheet 中** ⭐ |
| **訓練階段** | Overview 中僅顯示文字描述 | **階段時間軸 + 里程碑視覺化** ⭐ |
| **方法論說明** | 無 | **新增方法論卡片** ⭐ |

---

## 2. 主頁面設計（與 V1 完全一致）

### 2.1 頁面結構

```swift
struct TrainingPlanV2View: View {
    @StateObject private var viewModel = TrainingPlanV2ViewModel()
    @State private var showPlanOverview = false  // ⭐ V2 新增

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    switch viewModel.planStatus {
                    case .ready(let weeklyPlan):
                        // 1️⃣ 訓練進度卡片（與 V1 相同）
                        TrainingProgressCardV2(viewModel: viewModel, plan: weeklyPlan)

                        // 2️⃣ 週總覽卡片（與 V1 相同）
                        WeekOverviewCardV2(viewModel: viewModel, plan: weeklyPlan)

                        // 3️⃣ 週時間軸（與 V1 相同）
                        WeekTimelineViewV2(viewModel: viewModel, plan: weeklyPlan)

                    case .noPlan:
                        NewWeekPromptView(viewModel: viewModel)

                    case .completed:
                        FinalWeekPromptView(viewModel: viewModel)

                    case .loading:
                        ProgressView()

                    case .error(let error):
                        ErrorView(error: error)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                await viewModel.refreshWeeklyPlan()
            }
            .navigationTitle(viewModel.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左側按鈕 - 快速進入計畫概覽
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showPlanOverview = true
                    }) {
                        Image(systemName: "doc.text.below.ecg")
                            .foregroundColor(.primary)
                    }
                }

                // 右側選單
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showUserProfile = true }) {
                            Label("個人資料", systemImage: "person.circle")
                        }

                        Button(action: { showPlanOverview = true }) {
                            Label("訓練計畫概覽", systemImage: "doc.text.below.ecg")
                        }

                        Button(action: { showTrainingProgress = true }) {
                            Label("訓練進度", systemImage: "chart.line.uptrend.xyaxis")
                        }

                        Button(action: { showEditSchedule = true }) {
                            Label("編輯課表", systemImage: "slider.horizontal.3")
                        }

                        Divider()

                        Button(action: { showContactPaceriz = true }) {
                            Label("聯絡 Paceriz", systemImage: "envelope.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showPlanOverview) {
                PlanOverviewSheet(viewModel: viewModel)  // ⭐ V2 新增
            }
        }
    }
}
```

### 2.2 組件設計（複用 V1 邏輯）

#### 1️⃣ TrainingProgressCardV2

**用途**: 顯示整體訓練週數進度和當前階段

**佈局**: 與 V1 `TrainingProgressCard` 完全相同

```
┌────────────────────────────────────────┐
│  📊 訓練進度              第 5 週 / 共 16 週 ›│
├────────────────────────────────────────┤
│  ████████████░░░░░░░░░░░░░░░░░░░░░░   │  ← 多階段彩色進度條
│  🟢 Base Building      第 3-8 週       │  ← 當前階段標記
└────────────────────────────────────────┘
```

**資料來源**:
- `PlanOverviewV2.totalWeeks` - 總週數
- `WeeklyPlanV2.weekOfPlan` - 當前週數
- `PlanOverviewV2.trainingStages` - 階段資訊（繪製彩色進度條）

**互動**: 點擊 → 打開 TrainingProgressView（與 V1 相同）

#### 2️⃣ WeekOverviewCardV2

**用途**: 顯示本週跑量和強度分配

**佈局**: 與 V1 `WeekOverviewCard` 完全相同

```
┌────────────────────────────────────────┐
│  📅 本週總覽                           │
├────────────────────────────────────────┤
│  🏃 週跑量: 32.5 km / 35 km  (93%)    │
│  ██████████████████░░░                │  ← 跑量進度條
│                                        │
│  ⚡ 強度分配                          │
│  🟢 低強度   90 / 100 分鐘  ██████░   │
│  🔵 中強度   30 / 40 分鐘   ████░     │
│  🟠 高強度   10 / 15 分鐘   ███░      │
└────────────────────────────────────────┘
```

**資料來源**:
- `WeeklyPlanV2.weeklyDistance` - 目標跑量
- 本週完成的訓練記錄（從 HealthKit 計算）
- `WeeklyPlanV2.intensityDistribution` - 強度分配目標
- 實際完成的強度（從訓練記錄計算）

#### 3️⃣ WeekTimelineViewV2

**用途**: 顯示本週 7 天的每日課表

**佈局**: 與 V1 `WeekTimelineView` 完全相同

```
┌────────────────────────────────────────┐
│  週一 01/20  🟢 Easy Run               │  ← 可展開/收合
│  • 6 km @ Zone 2 (130-145 bpm)        │
│  ☑️ 已完成 (6.2 km, 36:30)            │
├────────────────────────────────────────┤
│  週二 01/21  🔴 Interval Training ⭐   │  ← 今日高亮
│  • 10 km (熱身 2km + 6×800m + 緩和 2km)│
│  [ ] 未完成                            │
├────────────────────────────────────────┤
│  週三 01/22  🟢 Recovery Run           │
│  週四 01/23  🔵 Tempo Run              │
│  週五 01/24  ⚪ Rest                   │
│  週六 01/25  🟢 LSD                    │
│  週日 01/26  🟢 Easy Run               │
└────────────────────────────────────────┘
```

**資料來源**:
- `WeeklyPlanV2.dailyWorkouts` - 每日訓練計畫
- 訓練記錄（HealthKit）- 完成狀態

**組件**: `DailyTrainingCardV2`（複用 V1 的 `DailyTrainingCard` 邏輯）

---

## 3. Plan Overview Sheet 設計（⭐ V2 專屬）

### 3.1 觸發方式

1. 點擊工具列左側按鈕（📊 圖示）
2. 點擊工具列右側選單 → "訓練計畫概覽"
3. 點擊 TrainingProgressCard → 訓練進度頁面 → "查看計畫概覽"

### 3.2 Sheet 結構

```swift
struct PlanOverviewSheet: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let overview = viewModel.planOverview {
                        // 1. 目標資訊卡片
                        TargetInfoCard(overview: overview)

                        // 2. 訓練階段時間軸
                        TrainingStagesTimeline(overview: overview, currentWeek: viewModel.currentWeek)

                        // 3. 方法論說明（可摺疊）
                        if let methodology = overview.methodologyOverview {
                            MethodologyCard(methodology: methodology)
                        }

                        // 4. 週預覽網格（簡化版）
                        WeeklyPreviewGrid(
                            weeklyPreviews: overview.weeklyPreview,
                            currentWeek: viewModel.currentWeek,
                            onWeekSelected: { week in
                                dismiss()
                                viewModel.switchToWeek(week)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("訓練計畫概覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

### 3.3 組件詳細設計

#### 1. 目標資訊卡片 (TargetInfoCard)

```
┌──────────────────────────────────────────┐
│  🏃 2025 台北馬拉松                       │
│                                           │
│  📅 賽事日期: 2025/12/20 (D-45)          │
│  📏 距離: 全程馬拉松 (42.2 km)            │
│  ⏱️  目標時間: 3:45:00 (配速 5:20/km)    │
│  📊 訓練週數: 16 週 (目前第 5 週)         │
│                                           │
│  🎯 目標評估:                             │
│  「根據您的最佳成績 3:55 和最近訓練       │
│   表現，此目標具有挑戰性但可達成。需要    │
│   保持一致的訓練強度...」                 │
└──────────────────────────────────────────┘
```

**資料來源**: `PlanOverviewV2` (targetName, raceDate, distanceKm, targetPace, targetTime, totalWeeks, targetEvaluate)

#### 2. 訓練階段時間軸 (TrainingStagesTimeline)

```
┌──────────────────────────────────────────┐
│  📍 訓練階段                              │
├──────────────────────────────────────────┤
│                                           │
│  [Conversion] → [  Base  ] → [Build] → [Peak] → [Taper] → 🏁
│    Week 1-2      Week 3-8   W9-12  W13-14  W15-16
│                     ↑ 當前
│                                           │
│  🟢 Base Building (第 3-8 週)            │
│  ┌────────────────────────────────────┐  │
│  │ 🎯 訓練重點: 建立有氧基礎            │
│  │ 📊 週跑量: 35-45 km                 │
│  │ 💪 關鍵訓練: Easy Run, LSD, Tempo   │
│  │ 📈 強度: 80% 低 / 15% 中 / 5% 高    │
│  └────────────────────────────────────┘  │
│                                           │
│  📌 里程碑                               │
│  • Week 4: 首次 10K LSD                  │
│  • Week 8: 半程測試                      │
│  • Week 12: 高強度週                     │
│  • Week 14: 最大跑量                     │
└──────────────────────────────────────────┘
```

**資料來源**:
- `PlanOverviewV2.trainingStages` - 階段列表
- `PlanOverviewV2.milestones` - 里程碑

**互動**:
- 點擊某階段 → 展開該階段詳細說明
- 當前階段預設展開並高亮

#### 3. 方法論說明 (MethodologyCard)

```
┌──────────────────────────────────────────┐
│  📚 訓練方法論: Paceriz Balanced          │
│  [展開 ▼]                                 │
└──────────────────────────────────────────┘

展開後:
┌──────────────────────────────────────────┐
│  📚 訓練方法論: Paceriz Balanced          │
│                                           │
│  🧠 訓練哲學:                             │
│  「平衡強度分配，兼顧有氧基礎與速度       │
│   耐力,適合中階跑者進行系統化訓練」      │
│                                           │
│  ⚡ 強度風格: Balanced (平衡型)          │
│                                           │
│  📊 強度分配:                             │
│  ███████████████░░░░░ 75% 低強度         │
│  ████░░░░░░░░░░░░░░░░ 20% 中強度         │
│  █░░░░░░░░░░░░░░░░░░░  5% 高強度         │
│                                           │
│  [收起 ▲]                                 │
└──────────────────────────────────────────┘
```

**資料來源**: `PlanOverviewV2.methodologyOverview`

**狀態**: 預設收起，點擊展開/收合

#### 4. 週預覽網格 (WeeklyPreviewGrid) ⭐

**設計目標**: 顯示每週的訓練架構預覽（訓練類型、跑量、強度）

```
┌──────────────────────────────────────────┐
│  📅 16 週課表預覽                         │
├──────────────────────────────────────────┤
│                                           │
│  ┌──────────┐ ┌──────────┐ ┌────────┐  │
│  │ Week 1   │ │ Week 2   │ │ Week 3 │  │
│  │ 25 km    │ │ 28 km    │ │ 32 km  │  │
│  │ 🟢🟢🔵🟢 │ │ 🟢🔵🟢🟢 │ │🟢🔵🔴🟢│  │  ← 每日訓練類型圖示
│  │ 🟢⚪🟢   │ │ 🟢⚪🟢   │ │🟢⚪🟢  │  │     (7 個圖示)
│  │ Base     │ │ Base     │ │ Base   │  │
│  └──────────┘ └──────────┘ └────────┘  │
│                                           │
│  ┌──────────┐ ┌──────────┐ ┌────────┐  │
│  │ Week 4   │ │ Week 5⭐ │ │ Week 6 │  │  ← 當前週高亮
│  │ 35 km    │ │ 30 km    │ │ 38 km  │  │
│  │ 🟢🔵🔴🟢 │ │ 🟢🟢🟢🟢 │ │🟢🔴🔵🟢│  │
│  │ 🟢⚪🟢   │ │ 🟢⚪🟢   │ │🟢⚪🟢  │  │
│  │ Base     │ │ Recovery │ │ Build  │  │
│  │ 🎖️ 10K   │ │          │ │        │  │  ← 里程碑標記（若有）
│  └──────────┘ └──────────┘ └────────┘  │
│                                           │
│  ... (繼續至 Week 16)                     │
│                                           │
│  💡 點擊週卡片可切換到該週查看            │
└──────────────────────────────────────────┘

圖示說明:
🟢 Easy/Recovery Run (低強度)    ⚪ Rest (休息)
🔵 Tempo/Threshold (中強度)      🔴 Interval/Speed (高強度)
🟠 Hill (坡道訓練)               🟣 Cross Training (交叉訓練)

重點訓練標記: isKeyWorkout = true 時，圖示加粗或放大 1.3x
```

**週卡片詳細結構**:

```
┌────────────────────┐
│  Week 5 (第5週) ⭐ │  ← 週數 + 當前週標記
├────────────────────┤
│  📊 32 km          │  ← 目標週跑量 (targetKm)
├────────────────────┤
│  🟢 🔵 🔴 🟢       │  ← 每日訓練類型圖示 (dailySchedule)
│  🟢 ⚪ 🟢          │     • 週一到週日，共 7 個圖示
│                    │     • 重點訓練 (isKeyWorkout) 加粗/放大
├────────────────────┤
│  📈 75/20/5        │  ← 強度分配百分比 (intensityDistribution)
│                    │     (低/中/高)
├────────────────────┤
│  🏃 Base Building  │  ← 所屬階段 (stageId)
├────────────────────┤
│  🎖️ 首次 10K LSD   │  ← 里程碑 (milestoneRef, 若有)
└────────────────────┘
```

**訓練類型圖示映射**:

| trainingType | 圖示 | 顏色 | 說明 |
|-------------|------|------|------|
| `easy_run`, `recovery` | 🟢 | 綠色 | 輕鬆跑/恢復跑 |
| `lsd` | 🟢 (加粗) | 深綠 | 長距離慢跑 |
| `tempo`, `threshold` | 🔵 | 藍色 | 節奏跑/閾值跑 |
| `interval`, `speed` | 🔴 | 紅色 | 間歇跑/速度訓練 |
| `hill` | 🟠 | 橘色 | 坡道訓練 |
| `rest` | ⚪ | 灰色 | 休息日 |
| `cross_training` | 🟣 | 紫色 | 交叉訓練 |

**重點訓練標記** (isKeyWorkout = true):
- 圖示放大 1.3x
- 使用更深的顏色
- 可選：加上外框

**互動**:
- 點擊週卡片 → 關閉 Sheet → 主頁面切換到該週（呼叫 `viewModel.switchToWeek(week)`）

**資料來源**: `PlanOverviewV2.weeklyPreview: [WeeklyPreviewV2]`

**欄位對應**:
```swift
struct WeeklyPreviewV2 {
    let week: Int                               → 卡片標題 "Week N"
    let stageId: String                         → 階段標籤 "Base Building"
    let targetKm: Double                        → 跑量顯示 "32 km"
    let dailySchedule: [DailyScheduleItemV2]   → ⭐ 7 個訓練類型圖示
    let intensityDistribution: IntensityDistributionV2  → 強度百分比 "75/20/5"
    let milestoneRef: String?                   → 里程碑圖示/文字
}

struct DailyScheduleItemV2 {
    let dayOfWeek: Int          → 圖示位置（1-7 對應週一到週日）
    let trainingType: String    → 圖示種類和顏色
    let isKeyWorkout: Bool      → 是否加粗/放大圖示
}
```

**佈局策略**:

- **iPhone SE**: 每行 2 個週卡片，卡片高度 100pt
- **iPhone 標準**: 每行 2-3 個週卡片，卡片高度 120pt
- **iPhone Pro Max**: 每行 3 個週卡片，卡片高度 140pt
- **iPad**: 每行 4-5 個週卡片，卡片高度 160pt

---

## 4. 資料流與狀態管理

### 4.1 ViewModel 架構

```swift
@MainActor
final class TrainingPlanV2ViewModel: ObservableObject {

    // MARK: - Dependencies

    private let repository: TrainingPlanV2Repository
    private let versionRouter: TrainingVersionRouter

    // MARK: - Published State

    @Published var planStatus: PlanStatus = .loading
    @Published var planOverview: PlanOverviewV2?
    @Published var currentWeek: Int = 1
    @Published var selectedWeek: Int = 1
    @Published var weeklyPlan: WeeklyPlanV2?
    @Published var weeklySummary: WeeklySummaryV2?

    // MARK: - Computed Properties

    var trainingPlanName: String {
        planOverview?.targetName ?? "訓練計畫"
    }

    // MARK: - Initialization

    func initialize() async {
        // 1. 載入 Plan Overview (快取優先)
        await loadPlanOverview()

        // 2. 載入本週課表 (快取優先)
        await loadCurrentWeekPlan()

        // 3. 載入訓練記錄
        await loadWorkouts()
    }

    // MARK: - Data Loading

    func loadPlanOverview() async {
        do {
            planOverview = try await repository.getOverview()
        } catch {
            // 處理錯誤
        }
    }

    func loadCurrentWeekPlan() async {
        guard let overview = planOverview else { return }

        do {
            weeklyPlan = try await repository.getWeeklyPlan(week: currentWeek)
            planStatus = .ready(weeklyPlan!)
        } catch {
            planStatus = .error(error)
        }
    }

    func switchToWeek(_ week: Int) async {
        selectedWeek = week
        await loadWeeklyPlan(week: week)
    }
}

enum PlanStatus {
    case loading
    case ready(WeeklyPlanV2)
    case noPlan
    case completed
    case error(Error)
}
```

### 4.2 資料載入優先順序

1. **Plan Overview** (立即載入，顯示訓練進度卡片)
   - Track A: 從快取讀取 → 立即顯示
   - Track B: 背景呼叫 API → 靜默更新

2. **Weekly Plan** (立即載入，顯示本週課表)
   - Track A: 從快取讀取 → 立即顯示
   - Track B: 背景呼叫 API → 靜默更新

3. **Workout Records** (立即載入，顯示完成狀態)
   - 從 HealthKit 查詢本週訓練記錄
   - 計算完成跑量和強度

4. **Weekly Preview** (延遲載入，僅在打開 Plan Overview Sheet 時載入)
   - 從 Plan Overview 中已包含，無需額外 API 調用

---

## 5. 實作優先順序

### Phase 4.1: 核心 UI 組件（與 V1 對齊）
- [ ] TrainingProgressCardV2
- [ ] WeekOverviewCardV2
- [ ] WeekTimelineViewV2
- [ ] DailyTrainingCardV2

### Phase 4.2: Plan Overview Sheet（V2 專屬）
- [ ] PlanOverviewSheet 框架
- [ ] TargetInfoCard
- [ ] TrainingStagesTimeline
- [ ] MethodologyCard（可摺疊）

### Phase 4.3: 週預覽網格（簡化版）
- [ ] WeeklyPreviewGrid
- [ ] 簡化週卡片設計
- [ ] 點擊切換週次邏輯

### Phase 4.4: ViewModel 與資料流
- [ ] TrainingPlanV2ViewModel
- [ ] 雙軌快取實作
- [ ] 週切換邏輯

---

## 6. 成功指標

- [ ] 主頁面載入速度 < 1 秒
- [ ] 用戶進入即可看到本週課表（與 V1 相同）
- [ ] Plan Overview Sheet 載入速度 < 0.5 秒
- [ ] 週切換響應 < 0.3 秒
- [ ] VoiceOver 支援完整
- [ ] 用戶滿意度: "與 V1 使用體驗一致" > 90%

---

**文件維護者**: iOS Team
**下次審核日期**: TBD
