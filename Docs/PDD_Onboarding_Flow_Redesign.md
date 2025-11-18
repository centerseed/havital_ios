# PDD: Onboarding Flow Redesign

## Document Info
- **Created**: 2024-11-18
- **Author**: Claude
- **Status**: Draft
- **Related Issues**: 簡化 Onboarding 流程，提升用戶信任感

## 1. Overview

### 1.1 Background
當前 Onboarding 流程過於冗長，包含過多步驟，且缺乏明確的信任感建立點。用戶在完成設定後，無法清楚理解 Paceriz 的訓練邏輯和價值。

### 1.2 Goals
1. **簡化流程**：從 7+ 步縮減至 5-6 步，完成時間從 4-5 分鐘縮短至 2.5-3 分鐘
2. **建立信任**：透過「訓練總覽」展示完整訓練規劃，讓用戶相信平台專業度
3. **新手友好**：針對新手提供「第一個 5km 計畫」快速入口
4. **清晰預期**：明確說明週循環（週回顧 + 週課表）的運作方式

### 1.3 Non-Goals
- 不改動後端 API 架構（除非必要）
- 不移除現有功能，只調整順序和呈現方式
- 不影響重新設定目標的流程（保持獨立）

---

## 2. Current State Analysis

### 2.1 Current Onboarding Flow

```
當前流程（首次使用）：
1. OnboardingIntroView (intro + 功能說明)
2. DataSourceSelectionView (綁定數據源)
3. OnboardingView (設定目標賽事)
4. [條件性] StartStageSelectionView (時間緊張時選擇起始階段)
5. HeartRateZoneInfoView (心率區間設定)
6. PersonalBestView (最佳成績)
7. WeeklyDistanceSetupView (週跑量設定)
8. [完成] 進入主畫面

耗時：約 4-5 分鐘
步驟數：7-8 步
```

### 2.2 Current Re-onboarding Flow

```
當前流程（從個人資料重新設定）：
1. 直接進入 OnboardingView (設定新目標)
2. [條件性] StartStageSelectionView
3. HeartRateZoneInfoView (通常跳過)
4. PersonalBestView (通常跳過)
5. WeeklyDistanceSetupView (通常跳過)
6. [完成] 進入主畫面

問題：會重複不必要的步驟
```

### 2.3 Key Issues
1. **步驟過多**：7-8 個步驟讓用戶疲勞
2. **順序不合理**：先設定目標，後了解能力（應該反過來）
3. **缺乏信任感**：沒有展示訓練計畫的專業度
4. **新手不友好**：沒有明確的「新手路徑」
5. **重複設定**：重新設定目標時會重複不必要步驟

---

## 3. Proposed Solution

### 3.1 New Onboarding Flow (首次使用)

```
新流程：
1. OnboardingIntroView (簡化版 intro)                    [5秒]
2. HeartRateZoneInputView (心率資料輸入)                 [20秒]
3. DataSourceBindingView (綁定數據源 + backfill)        [30秒]
4. PersonalBestInputView (最佳成績輸入，可跳過)          [30秒]
5. WeeklyVolumeInputView (週跑量選擇，可跳過)           [10秒]
6. GoalTypeSelectionView (目標類型選擇)                  [10秒]
   ├─ [新手路徑] 自動設定 5km 目標 → Step 8
   └─ [進階路徑] → Step 7
7. GoalRaceSetupView (目標賽事 + 訓練日設定)            [50秒]
8. TrainingOverviewView (訓練總覽展示)                  [60秒閱讀]
9. WeeklyCycleExplanationView (週循環說明)              [30秒]
10. [完成] 進入主畫面

總耗時：約 2.5-3 分鐘
步驟數：5-6 步（新手 5 步，進階 6 步）
```

### 3.2 New Re-onboarding Flow (重新設定目標)

```
新流程（從個人資料進入）：
1. 直接進入 GoalRaceSetupView (設定新目標)
2. TrainingOverviewView (訓練總覽展示)
3. [完成] 進入主畫面

總耗時：約 1 分鐘
步驟數：2 步
關鍵：跳過所有已設定的步驟（心率、數據源、最佳成績、週跑量）
```

---

## 4. Detailed Design

### 4.1 Step 1: OnboardingIntroView (簡化版)

**目標**：5秒內完成，極簡設計

**UI 設計**：
```swift
struct OnboardingIntroView: View {
    @State private var navigateToNextStep = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image("paceriz_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            // 標題
            Text("歡迎使用 Paceriz")
                .font(.largeTitle)
                .fontWeight(.bold)

            // 副標題（一句話說明價值）
            Text("你的智能跑步教練\n每週為你量身打造訓練計畫")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // 開始按鈕
            Button("開始設定") {
                navigateToNextStep = true
            }
            .buttonStyle(.prominent)

            NavigationLink(
                destination: HeartRateZoneInputView(),
                isActive: $navigateToNextStep
            ) { EmptyView() }
        }
        .padding()
    }
}
```

**多國語言 Keys**：
- `onboarding.welcome_title` = "歡迎使用 Paceriz"
- `onboarding.welcome_subtitle` = "你的智能跑步教練\n每週為你量身打造訓練計畫"
- `onboarding.start_setup` = "開始設定"

---

### 4.2 Step 2: HeartRateZoneInputView (心率資料輸入)

**目標**：20秒完成，必填項目

**變更**：將現有的 `HeartRateZoneInfoView` 簡化為輸入模式

**UI 設計**：
```swift
struct HeartRateZoneInputView: View {
    @State private var restingHR: Int = 60
    @State private var maxHR: Int = 185
    @State private var navigateToNextStep = false

    var body: some View {
        Form {
            Section(
                header: Text("設定你的心率區間"),
                footer: Text("我們需要心率資料來規劃訓練強度")
            ) {
                Stepper("安靜心率：\(restingHR) bpm", value: $restingHR, in: 40...100)
                Stepper("最大心率：\(maxHR) bpm", value: $maxHR, in: 160...220)

                Button("不確定？用年齡估算") {
                    // 用年齡計算（220 - age）
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("下一步") {
                    saveHeartRateZones()
                    navigateToNextStep = true
                }
            }
        }

        NavigationLink(
            destination: DataSourceBindingView(),
            isActive: $navigateToNextStep
        ) { EmptyView() }
    }

    private func saveHeartRateZones() {
        // 儲存到 UserPreferenceManager
        UserPreferenceManager.shared.maxHeartRate = maxHR
        UserPreferenceManager.shared.restingHeartRate = restingHR
    }
}
```

---

### 4.3 Step 3: DataSourceBindingView (綁定數據源 + backfill)

**目標**：30秒完成，backfill 在背景執行

**變更**：重用現有的 `DataSourceSelectionView`，但移除不必要的說明

**關鍵改動**：
1. **觸發 backfill**：選擇數據源後立即觸發 backfill API
2. **不等待完成**：backfill 在背景執行，用戶可繼續下一步
3. **顯示狀態**：簡單顯示「同步中...」但不阻擋流程

```swift
// 在 DataSourceSelectionView 中加入
private func handleAppleHealthSelection() async throws {
    try await healthKitManager.requestAuthorization()
    userPreferenceManager.dataSourcePreference = .appleHealth
    try await UserService.shared.updateDataSource(DataSourceType.appleHealth.rawValue)

    // 🆕 觸發 backfill（不等待完成）
    Task.detached {
        await WorkoutSyncManager.shared.triggerBackfill(days: 14)
    }
}
```

---

### 4.4 Step 4: PersonalBestInputView (最佳成績輸入)

**目標**：30秒完成，**可跳過**

**變更**：簡化現有的 `PersonalBestView`

**UI 設計**：
```swift
struct PersonalBestInputView: View {
    @State private var has5K: Bool = false
    @State private var has10K: Bool = false
    @State private var hasHalfMarathon: Bool = false
    @State private var hasFullMarathon: Bool = false

    @State private var time5K: (Int, Int, Int) = (0, 0, 0) // 時, 分, 秒
    // ... 其他距離類似

    var body: some View {
        Form {
            Section(
                header: Text("你的最佳成績"),
                footer: Text("這能幫助我們了解你的跑步能力\n沒有紀錄可留空")
            ) {
                Toggle("5K 最佳", isOn: $has5K)
                if has5K {
                    TimePickerRow(time: $time5K)
                }

                Toggle("10K 最佳", isOn: $has10K)
                if has10K {
                    TimePickerRow(time: $time10K)
                }

                // ... 半馬、全馬類似
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("下一步") {
                    savePersonalBests()
                    navigateToNextStep = true
                }
            }
        }
    }

    private func savePersonalBests() {
        // 只儲存有勾選的成績
        Task {
            if has5K {
                let totalSeconds = time5K.0 * 3600 + time5K.1 * 60 + time5K.2
                try? await UserService.shared.updatePersonalBestData([
                    "distance_km": 5.0,
                    "complete_time": totalSeconds
                ])
            }
            // ... 其他距離類似
        }
    }
}
```

**關鍵**：允許完全跳過，不強制填寫

---

### 4.5 Step 5: WeeklyVolumeInputView (週跑量選擇)

**目標**：10秒完成，**可跳過**

**UI 設計**：
```swift
struct WeeklyVolumeInputView: View {
    @State private var selectedVolume: WeeklyVolume = .unknown

    enum WeeklyVolume: String, CaseIterable {
        case zero_to_10 = "0-10 km"
        case ten_to_20 = "10-20 km"
        case twenty_to_30 = "20-30 km"
        case thirty_to_50 = "30-50 km"
        case fifty_plus = "50+ km"
        case unknown = "不確定"

        var description: String {
            switch self {
            case .zero_to_10: return "剛開始跑步"
            case .ten_to_20: return "偶爾訓練"
            case .twenty_to_30: return "規律訓練"
            case .thirty_to_50: return "認真訓練"
            case .fifty_plus: return "大量訓練"
            case .unknown: return "不確定"
            }
        }
    }

    var body: some View {
        Form {
            Section(
                header: Text("你目前的週跑量"),
                footer: Text("不用很精確，大概就好")
            ) {
                ForEach(WeeklyVolume.allCases, id: \.self) { volume in
                    Button {
                        selectedVolume = volume
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(volume.rawValue)
                                    .foregroundColor(.primary)
                                Text(volume.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedVolume == volume {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("下一步") {
                    saveWeeklyVolume()
                    navigateToNextStep = true
                }
            }
        }
    }

    private func saveWeeklyVolume() {
        UserDefaults.standard.set(selectedVolume.rawValue, forKey: "weeklyVolume")
    }
}
```

---

### 4.6 Step 6: GoalTypeSelectionView (目標類型選擇) ⭐ 新增關鍵步驟

**目標**：10秒完成，根據最佳成績和週跑量自動判斷

**判斷邏輯**：
```swift
func shouldShowBeginnerPath() -> Bool {
    // 判斷條件：沒有最佳成績 + 週跑量 < 10km 或不確定
    let hasNoPB = !hasAnyPersonalBest()
    let lowVolume = weeklyVolume == .zero_to_10 || weeklyVolume == .unknown
    return hasNoPB && lowVolume
}
```

**UI 設計**：
```swift
struct GoalTypeSelectionView: View {
    @State private var selectedGoalType: GoalType = .beginner5K

    enum GoalType {
        case beginner5K    // 新手 5km 計畫
        case raceGoal      // 設定目標賽事
    }

    var shouldShowBeginnerPath: Bool {
        // 從 UserDefaults 讀取最佳成績和週跑量
        // ...判斷邏輯
    }

    var body: some View {
        VStack(spacing: 24) {
            if shouldShowBeginnerPath {
                // 顯示新手推薦
                Text("選擇你的訓練目標")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    // 推薦選項
                    goalCard(
                        type: .beginner5K,
                        icon: "figure.run",
                        title: "第一個 5km 計畫",
                        subtitle: "⭐ 推薦",
                        description: "從零開始，8-10 週完成 5km\n適合剛開始跑步的你",
                        isRecommended: true
                    )

                    // 備選
                    goalCard(
                        type: .raceGoal,
                        icon: "flag.fill",
                        title: "設定目標賽事",
                        subtitle: "",
                        description: "如果你有明確的比賽計畫",
                        isRecommended: false
                    )
                }
            } else {
                // 直接進入賽事設定（不顯示此畫面）
                EmptyView()
                    .onAppear {
                        // 直接跳到 GoalRaceSetupView
                    }
            }

            Button("繼續") {
                handleGoalTypeSelection()
            }
            .buttonStyle(.prominent)
        }
        .padding()
    }

    private func handleGoalTypeSelection() {
        if selectedGoalType == .beginner5K {
            // 自動設定新手 5km 目標
            createBeginner5KGoal()
            // 跳到 Step 8 (TrainingOverviewView)
        } else {
            // 進入 Step 7 (GoalRaceSetupView)
        }
    }

    private func createBeginner5KGoal() {
        let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        let target = Target(
            id: UUID().uuidString,
            type: "race_run",
            name: NSLocalizedString("onboarding.beginner_5k_challenge", comment: "初心者一個月5km挑戰"),
            distanceKm: 5,
            targetTime: 35 * 60, // 7分速 * 5km = 35分鐘
            targetPace: "7:00",
            raceDate: Int(oneMonthLater.timeIntervalSince1970),
            isMainRace: true,
            trainingWeeks: 4
        )

        Task {
            try? await UserService.shared.createTarget(target)
        }
    }
}
```

**多國語言 Keys**：
- `onboarding.beginner_5k_challenge` (en) = "Beginner 5K Challenge (1 Month)"
- `onboarding.beginner_5k_challenge` (zh-TW) = "初心者一個月5km挑戰"
- `onboarding.beginner_5k_challenge` (ja) = "初心者1ヶ月5kmチャレンジ"

---

### 4.7 Step 7: GoalRaceSetupView (目標賽事 + 訓練日設定)

**目標**：50秒完成，合併原本的 OnboardingView 和訓練日設定

**變更**：
1. 保留現有的 `OnboardingView` 設定目標部分
2. 在同一畫面加入訓練日設定
3. 給出訓練日建議但不強制

**UI 設計**：
```swift
struct GoalRaceSetupView: View {
    @StateObject private var viewModel = GoalRaceSetupViewModel()

    var body: some View {
        Form {
            // === 目標賽事設定 ===
            Section(header: Text("你的目標賽事")) {
                TextField("賽事名稱", text: $viewModel.raceName)
                DatePicker("比賽日期", selection: $viewModel.raceDate, in: Date()...)
                Text("距離比賽：\(viewModel.trainingWeeks) 週")
                    .foregroundColor(.secondary)
            }

            Section(header: Text("賽事距離")) {
                Picker("選擇距離", selection: $viewModel.selectedDistance) {
                    Text("5K").tag("5")
                    Text("10K").tag("10")
                    Text("半馬").tag("21.0975")
                    Text("全馬").tag("42.195")
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("目標完賽時間")) {
                HStack {
                    Picker("時", selection: $viewModel.targetHours) {
                        ForEach(0...6, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    Text("時")

                    Picker("分", selection: $viewModel.targetMinutes) {
                        ForEach(0..<60, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    Text("分")
                }

                Text("平均配速：\(viewModel.targetPace)")
                    .foregroundColor(.secondary)
            }

            // === 訓練日設定 ===
            Section(
                header: Text("訓練日設定"),
                footer: Text(viewModel.trainingDaysSuggestion)
            ) {
                TrainingDaysSelector(selectedDays: $viewModel.selectedTrainingDays)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("生成訓練計畫") {
                    Task {
                        if await viewModel.createTargetAndProceed() {
                            // 導航到 TrainingOverviewView
                        }
                    }
                }
            }
        }
    }
}

class GoalRaceSetupViewModel: ObservableObject {
    // ... 現有的 OnboardingViewModel 屬性
    @Published var selectedTrainingDays: Set<Int> = [] // 1-7 代表週一到週日

    var trainingDaysSuggestion: String {
        let distance = Double(selectedDistance) ?? 42.195
        if distance >= 21.0975 {
            return "💡 全馬/半馬建議每週至少 5 天訓練（非強制）"
        } else {
            return "💡 10K 建議每週至少 3 天訓練（非強制）"
        }
    }

    func createTargetAndProceed() async -> Bool {
        // 1. 創建目標（現有邏輯）
        let success = await createTarget()

        // 2. 儲存訓練日設定
        if success {
            UserDefaults.standard.set(Array(selectedTrainingDays), forKey: "trainingDays")
        }

        return success
    }
}

struct TrainingDaysSelector: View {
    @Binding var selectedDays: Set<Int>
    let dayNames = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                Button {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(dayNames[day - 1])
                        .frame(width: 40, height: 40)
                        .background(selectedDays.contains(day) ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                        .cornerRadius(20)
                }
            }
        }

        Text("已選擇：\(selectedDays.count) 天")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

---

### 4.8 Step 8: TrainingOverviewView (訓練總覽展示) ⭐⭐⭐ 核心信任感建立

**目標**：60秒閱讀，展示完整訓練規劃（時間軸視覺化）

**API 調用**：
```swift
// 呼叫產生訓練總覽 API
let overview = try await TrainingPlanService.shared.postTrainingPlanOverview()
```

**UI 設計（選項 2：時間軸視覺化 + 可展開詳情）**：

```swift
struct TrainingOverviewView: View {
    @StateObject private var viewModel = TrainingOverviewViewModel()
    @State private var expandedPhases: Set<Int> = [1] // 預設展開第一階段

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // === 目標資訊卡片 ===
                goalInfoCard

                Divider()

                // === target_evaluate 和 training_highlight ===
                if !viewModel.overview.targetEvaluate.isEmpty {
                    targetEvaluateSection
                }

                if !viewModel.overview.trainingHighlight.isEmpty {
                    trainingHighlightSection
                }

                Divider()

                // === 時間軸視覺化 ===
                Text("你的訓練規劃")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                timelineView

                // === 開始訓練按鈕 ===
                Button("開始訓練") {
                    viewModel.proceedToNextStep()
                }
                .buttonStyle(.prominent)
                .padding()
            }
            .padding(.vertical)
        }
        .navigationTitle("訓練總覽")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTrainingOverview()
        }
    }

    private var goalInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.overview.trainingPlanName)
                .font(.title3)
                .fontWeight(.semibold)

            HStack {
                Label("距離：\(viewModel.targetDistanceText)", systemImage: "arrow.left.and.right")
                Spacer()
                Label("目標：\(viewModel.targetTimeText)", systemImage: "timer")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Text("訓練週期：\(viewModel.overview.totalWeeks) 週")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var targetEvaluateSection: some View {
        DisclosureGroup(
            isExpanded: $viewModel.showTargetEvaluate,
            content: {
                Text(viewModel.overview.targetEvaluate)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            },
            label: {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.accentColor)
                    Text("目標可行性評估")
                        .font(.headline)
                }
            }
        )
        .padding(.horizontal)
    }

    private var trainingHighlightSection: some View {
        DisclosureGroup(
            isExpanded: $viewModel.showTrainingHighlight,
            content: {
                Text(viewModel.overview.trainingHighlight)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            },
            label: {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    Text("訓練重點說明")
                        .font(.headline)
                }
            }
        )
        .padding(.horizontal)
    }

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.overview.trainingStageDescription.enumerated()), id: \.offset) { index, stage in
                TimelinePhaseRow(
                    phase: stage,
                    phaseNumber: index + 1,
                    isExpanded: expandedPhases.contains(index + 1),
                    isFirst: index == 0,
                    isLast: index == viewModel.overview.trainingStageDescription.count - 1,
                    onToggle: {
                        if expandedPhases.contains(index + 1) {
                            expandedPhases.remove(index + 1)
                        } else {
                            expandedPhases.insert(index + 1)
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct TimelinePhaseRow: View {
    let phase: TrainingStage
    let phaseNumber: Int
    let isExpanded: Bool
    let isFirst: Bool
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // === 時間軸視覺 ===
            VStack(spacing: 0) {
                // 上方連接線
                if !isFirst {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 2, height: 20)
                }

                // 圓點
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)

                // 下方連接線
                if !isLast {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(width: 12)

            // === 階段內容 ===
            VStack(alignment: .leading, spacing: 8) {
                // 階段標題
                Button(action: onToggle) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phase.stageName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("第 \(phase.weekStart)-\(phase.weekEnd ?? phase.weekStart) 週")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 展開內容
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        // 訓練重點
                        VStack(alignment: .leading, spacing: 4) {
                            Text("訓練重點")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(phase.trainingFocus)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        // 階段描述
                        if !phase.stageDescription.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("階段說明")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(phase.stageDescription)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }

                if !isLast {
                    Divider()
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

class TrainingOverviewViewModel: ObservableObject {
    @Published var overview: TrainingPlanOverview?
    @Published var isLoading = true
    @Published var showTargetEvaluate = false // 預設折疊
    @Published var showTrainingHighlight = false // 預設折疊

    var targetDistanceText: String {
        // 從目標讀取並格式化
        "42.195 km"
    }

    var targetTimeText: String {
        // 從目標讀取並格式化
        "3小時30分"
    }

    func loadTrainingOverview() async {
        isLoading = true
        do {
            // 🆕 呼叫產生訓練總覽 API
            overview = try await TrainingPlanService.shared.postTrainingPlanOverview()
            isLoading = false
        } catch {
            print("載入訓練總覽失敗: \(error)")
            isLoading = false
        }
    }

    func proceedToNextStep() {
        // 導航到 WeeklyCycleExplanationView
    }
}
```

**關鍵設計要點**：
1. ✅ 預設展開第一階段，讓用戶立即看到內容
2. ✅ 其他階段可點擊展開，避免過長
3. ✅ 使用時間軸視覺化，清晰展示階段順序
4. ✅ `target_evaluate` 和 `training_highlight` 預設折疊，避免干擾
5. ✅ 這是信任感建立的核心畫面！

---

### 4.9 Step 9: WeeklyCycleExplanationView (週循環說明)

**目標**：30秒閱讀，說明 Paceriz 運作方式

**UI 設計**：
```swift
struct WeeklyCycleExplanationView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Paceriz 會陪著你跑")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                cycleExplanationRow(
                    icon: "calendar",
                    title: "每週一早上",
                    items: [
                        "📊 週回顧：分析上週訓練狀況",
                        "📅 週課表：根據你的狀態動態調整"
                    ]
                )

                cycleExplanationRow(
                    icon: "figure.run",
                    title: "每天",
                    items: [
                        "🏃 訓練建議：今天該做什麼訓練",
                        "💓 配速和心率區間",
                        "📝 訓練注意事項"
                    ]
                )
            }
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            Text("訓練計畫會跟著你的狀態調整\n不是死板的課表，而是智能教練")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("開始第一週訓練") {
                completeOnboarding()
            }
            .buttonStyle(.prominent)
            .padding(.horizontal)
        }
        .padding()
    }

    private func cycleExplanationRow(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func completeOnboarding() {
        authService.hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // 🆕 產生第一週課表
        Task {
            try? await TrainingPlanService.shared.createWeeklyPlan(targetWeek: 1)
        }
    }
}
```

---

## 5. Implementation Plan

### 5.1 Phase 1: Core Flow (P0)

**目標**：實現基本的簡化流程

**Tasks**：
1. ✅ 創建 `HeartRateZoneInputView`（簡化版心率輸入）
2. ✅ 修改 `DataSourceSelectionView` 觸發 backfill
3. ✅ 創建 `PersonalBestInputView`（支援跳過）
4. ✅ 創建 `WeeklyVolumeInputView`（選項式）
5. ✅ 創建 `GoalTypeSelectionView`（新手路徑判斷）
6. ✅ 修改 `OnboardingView` → `GoalRaceSetupView`（加入訓練日設定）
7. ✅ 創建 `TrainingOverviewView`（時間軸視覺化）
8. ✅ 創建 `WeeklyCycleExplanationView`
9. ✅ 修改 `ContentView` 流程判斷邏輯

**估時**：5-7 天

---

### 5.2 Phase 2: Re-onboarding Flow (P1)

**目標**：實現重新設定目標的簡化流程

**Tasks**：
1. ✅ 修改 `ContentView` 判斷 `isReonboardingMode` 時直接進入 `GoalRaceSetupView`
2. ✅ 在 `GoalRaceSetupView` 中跳過已設定的項目
3. ✅ 確保 `TrainingOverviewView` 在重新設定時也正常顯示

**估時**：1-2 天

---

### 5.3 Phase 3: Polish & Testing (P1)

**Tasks**：
1. ✅ 新增多國語言支援（en, zh-TW, ja）
2. ✅ 調整 UI/UX 細節（動畫、過渡效果）
3. ✅ 測試各種情境（新手、有經驗、重新設定）
4. ✅ 錯誤處理和邊界情況
5. ✅ 性能優化（backfill 背景執行）

**估時**：2-3 天

---

## 6. API Changes

### 6.1 New API Requirements

**無需新增 API**，使用現有 API：

1. ✅ `POST /plan/race_run/overview` - 產生訓練總覽
2. ✅ `POST /plan/race_run/weekly/v2` - 產生週課表
3. ✅ `POST /user/target` - 創建目標
4. ✅ `PUT /user/personal_best` - 更新最佳成績

### 6.2 API Response Enhancements (Optional, P2)

**建議後端加強 TrainingPlanOverview 回傳內容**：

```json
{
  "id": "overview_123",
  "main_race_id": "race_456",
  "target_evaluate": "✅ 目標配速與當前能力差距合理（40秒/km）\n✅ 距離比賽還有 18 週，時間充足\n✅ 訓練頻率穩定（每週 4 次）\n\n以你的訓練基礎和目標日期，完成目標的可能性：⭐⭐⭐⭐ (高)\n\n我們會為你規劃漸進式訓練計畫，預計 10-12 週後可達成目標配速",
  "total_weeks": 18,
  "training_hightlight": "• 前 6 週重點建立有氧基礎，提升耐力\n• 第 7-12 週逐步增加訓練量，引入節奏跑\n• 第 13-16 週強化目標配速能力，模擬比賽\n• 最後 2 週減量調整，確保身體充分恢復",
  "training_plan_name": "全馬 3:30 訓練計畫",
  "training_stage_discription": [
    {
      "stage_name": "有氧基礎期",
      "stage_id": "base",
      "stage_description": "建立有氧基礎，養成訓練習慣",
      "training_focus": "• 建立有氧基礎\n• 提升長跑耐力\n• 養成訓練習慣",
      "week_start": 1,
      "week_end": 6
    },
    // ... 其他階段
  ],
  "created_at": "2024-11-18T10:30:00Z"
}
```

**關鍵**：
- `target_evaluate` 提供目標可行性評估（富文本，支援換行和符號）
- `training_hightlight` 提供訓練重點摘要（富文本）
- `training_focus` 使用 bullet points（• 符號）

---

## 7. Data Flow

### 7.1 First-time Onboarding Data Flow

```
Step 1: OnboardingIntroView
  ↓ (無資料傳遞)

Step 2: HeartRateZoneInputView
  ↓ Save to: UserPreferenceManager
     - maxHeartRate: Int
     - restingHeartRate: Int

Step 3: DataSourceBindingView
  ↓ Save to: UserPreferenceManager + Backend
     - dataSourcePreference: DataSourceType
     - 觸發: Backfill API (背景執行)

Step 4: PersonalBestInputView
  ↓ Save to: Backend (UserService.updatePersonalBestData)
     - 5K, 10K, HalfMarathon, Marathon PBs
     - 可跳過（不儲存）

Step 5: WeeklyVolumeInputView
  ↓ Save to: UserDefaults
     - weeklyVolume: String ("0-10 km", "10-20 km", etc.)
     - 可跳過（儲存為 "unknown"）

Step 6: GoalTypeSelectionView
  ↓ 判斷邏輯 → 兩條路徑
     ├─ 新手 → 自動創建 5km 目標 → Step 8
     └─ 進階 → Step 7

Step 7: GoalRaceSetupView
  ↓ Save to: Backend (UserService.createTarget)
     - Target (賽事資訊)
     - trainingDays: [Int] → UserDefaults

Step 8: TrainingOverviewView
  ↓ API Call: POST /plan/race_run/overview
     ← Response: TrainingPlanOverview
     - 展示給用戶（不儲存）

Step 9: WeeklyCycleExplanationView
  ↓ Complete Onboarding
     - Set: hasCompletedOnboarding = true
     - API Call: POST /plan/race_run/weekly/v2 (產生第一週)
```

### 7.2 Re-onboarding Data Flow

```
Trigger: UserProfileView.startReonboarding()
  ↓ Set: isReonboardingMode = true

ContentView 判斷
  ↓ 直接進入: GoalRaceSetupView

Step 1: GoalRaceSetupView
  ↓ 讀取現有資料（預填）
     - 心率區間 (from UserPreferenceManager)
     - 訓練日 (from UserDefaults)
  ↓ Save: 新的 Target

Step 2: TrainingOverviewView
  ↓ API Call: POST /plan/race_run/overview

Complete
  ↓ Set: isReonboardingMode = false
        hasCompletedOnboarding = true
```

---

## 8. Testing Plan

### 8.1 Unit Tests

**需要測試的邏輯**：

1. **新手路徑判斷邏輯**：
   ```swift
   func test_shouldShowBeginnerPath_noPBAndLowVolume_returnsTrue()
   func test_shouldShowBeginnerPath_hasPB_returnsFalse()
   func test_shouldShowBeginnerPath_highVolume_returnsFalse()
   ```

2. **自動創建新手 5km 目標**：
   ```swift
   func test_createBeginner5KGoal_createsCorrectTarget()
   func test_beginner5KGoal_hasCorrectPace() // 7分速
   func test_beginner5KGoal_hasCorrectDuration() // 4週
   ```

3. **訓練日建議邏輯**：
   ```swift
   func test_trainingDaysSuggestion_marathon_suggests5Days()
   func test_trainingDaysSuggestion_10K_suggests3Days()
   ```

### 8.2 Integration Tests

**需要測試的流程**：

1. **完整新手流程**：
   ```
   Intro → 心率 → 數據源 → 跳過PB → 跳過週跑量
   → 新手5km → 訓練總覽 → 週循環說明 → 完成
   ```

2. **完整進階流程**：
   ```
   Intro → 心率 → 數據源 → 輸入PB → 輸入週跑量
   → 設定賽事 → 訓練總覽 → 週循環說明 → 完成
   ```

3. **重新設定流程**：
   ```
   個人資料 → 重新設定目標 → 訓練總覽 → 完成
   ```

### 8.3 UI Tests

**需要測試的交互**：

1. ✅ 時間軸展開/折疊功能
2. ✅ 訓練日選擇器
3. ✅ target_evaluate 和 training_highlight 的 DisclosureGroup
4. ✅ 各步驟間的導航流程

---

## 9. Localization

### 9.1 New Localization Keys

**英文 (en)**:
```
// Beginner 5K
"onboarding.beginner_5k_challenge" = "Beginner 5K Challenge (1 Month)";
"onboarding.beginner_5k_description" = "Start from zero, complete 5km in 8-10 weeks\nPerfect for beginners";

// Goal Type Selection
"onboarding.choose_your_goal" = "Choose Your Training Goal";
"onboarding.race_goal" = "Set Race Goal";
"onboarding.race_goal_description" = "If you have a specific race plan";

// Weekly Volume
"onboarding.weekly_volume_title" = "Your Current Weekly Running Volume";
"onboarding.weekly_volume_footer" = "Don't need to be precise, approximate is fine";
"onboarding.volume_beginner" = "Just started running";
"onboarding.volume_occasional" = "Occasional training";
"onboarding.volume_regular" = "Regular training";
"onboarding.volume_serious" = "Serious training";
"onboarding.volume_heavy" = "Heavy training";
"onboarding.volume_unknown" = "Not sure";

// Training Overview
"onboarding.training_overview_title" = "Your Training Plan";
"onboarding.target_evaluate" = "Goal Feasibility Assessment";
"onboarding.training_highlight" = "Training Highlights";
"onboarding.start_training" = "Start Training";

// Weekly Cycle
"onboarding.paceriz_with_you" = "Paceriz Will Run With You";
"onboarding.every_monday" = "Every Monday Morning";
"onboarding.weekly_review" = "📊 Weekly Review: Analyze last week's training";
"onboarding.weekly_plan" = "📅 Weekly Plan: Adjust based on your status";
"onboarding.everyday" = "Every Day";
"onboarding.training_suggestion" = "🏃 Training Suggestion: What to do today";
"onboarding.pace_hr_zone" = "💓 Pace and heart rate zones";
"onboarding.training_notes" = "📝 Training notes";
"onboarding.adaptive_plan" = "Training plan adapts to your status\nNot a rigid schedule, but an intelligent coach";
"onboarding.start_first_week" = "Start First Week Training";
```

**繁體中文 (zh-TW)**:
```
"onboarding.beginner_5k_challenge" = "初心者一個月5km挑戰";
"onboarding.beginner_5k_description" = "從零開始，8-10 週完成 5km\n適合剛開始跑步的你";
// ... 其他翻譯
```

**日文 (ja)**:
```
"onboarding.beginner_5k_challenge" = "初心者1ヶ月5kmチャレンジ";
"onboarding.beginner_5k_description" = "ゼロから始めて、8-10週間で5kmを完走\n初心者に最適";
// ... 其他翻譯
```

---

## 10. Migration Strategy

### 10.1 Backward Compatibility

**處理已完成舊版 Onboarding 的用戶**：

1. ✅ 保留 `hasCompletedOnboarding` flag
2. ✅ 新增 `onboardingVersion` 記錄版本
   ```swift
   UserDefaults.standard.set(2, forKey: "onboardingVersion")
   ```
3. ✅ 舊用戶不受影響，直接進入主畫面

**處理進行中的 Onboarding**：

- 舊版流程進行到一半的用戶，保持舊流程完成
- 版本更新後，重置 onboarding 狀態，使用新流程

### 10.2 Feature Flag

**使用 Feature Flag 控制新舊流程**：

```swift
enum OnboardingFlowVersion {
    case v1  // 舊版流程
    case v2  // 新版流程（本 PDD）
}

class FeatureFlagManager {
    var onboardingFlowVersion: OnboardingFlowVersion {
        // 從遠端配置或本地設定讀取
        return .v2
    }
}
```

**ContentView 判斷邏輯**：
```swift
if !authService.hasCompletedOnboarding {
    if FeatureFlagManager.shared.onboardingFlowVersion == .v2 {
        NewOnboardingFlowView()  // 新流程
    } else {
        OnboardingIntroView()    // 舊流程
    }
}
```

---

## 11. Success Metrics

### 11.1 Quantitative Metrics

**目標值**：

| 指標 | 當前 | 目標 | 測量方式 |
|------|------|------|----------|
| **完成率** | ~70% | >85% | 完成 Onboarding / 開始 Onboarding |
| **完成時間** | 4-5 分鐘 | 2.5-3 分鐘 | 從 Intro 到完成的時間中位數 |
| **第二週留存** | ? | >60% | 完成 Onboarding 後第二週仍活躍 |
| **新手 5km 採用率** | 0% | >30% | 選擇新手路徑的用戶比例 |

### 11.2 Qualitative Metrics

**用戶回饋**：
- "訓練總覽讓我相信這是專業的課表"
- "流程很快，沒有冗長的說明"
- "我知道接下來每週會發生什麼"

---

## 12. Risks & Mitigation

### 12.1 Risk: Backfill 未完成就進入後續步驟

**問題**：用戶在 backfill 完成前就設定完目標，可能導致訓練總覽不準確

**緩解方案**：
1. ✅ Backfill 在背景執行，不阻擋流程
2. ✅ 訓練總覽主要依賴「最佳成績」和「週跑量」，不依賴 backfill 數據
3. ✅ 第一週課表會等待 backfill 完成（或使用預設值）

---

### 12.2 Risk: 新手 5km 目標配速不合理

**問題**：7分速對某些新手可能太快

**緩解方案**：
1. ✅ 後端會根據用戶實際狀況調整配速
2. ✅ 新手計畫重點是「完成」而非「速度」
3. ✅ 用戶可在設定中修改目標

---

### 12.3 Risk: 訓練總覽載入失敗

**問題**：API 呼叫失敗導致無法顯示訓練總覽

**緩解方案**：
```swift
if let error = viewModel.error {
    // 顯示錯誤並提供重試
    VStack {
        Text("載入訓練總覽失敗")
        Button("重試") {
            Task { await viewModel.loadTrainingOverview() }
        }
        Button("暫時跳過") {
            // 繼續到下一步
        }
    }
}
```

---

## 13. Open Questions

### Q1: 是否需要在訓練總覽中顯示具體的配速範圍？

**現狀**：TrainingStage 只有 `training_focus` 文字描述

**建議**：
- Phase 1: 保持現狀（只顯示文字）
- Phase 2: 後端加入 `target_paces` 結構化資料

### Q2: 新手 5km 計畫是否需要獨立的訓練總覽？

**現狀**：新手也會呼叫 `POST /plan/race_run/overview`

**建議**：
- 後端判斷距離 = 5km 且週數 = 4，回傳新手友好的訓練總覽
- 不需要額外 API

### Q3: 重新設定目標時，是否要刪除舊的週課表？

**現狀**：未明確定義

**建議**：
- 後端在產生新的訓練總覽時，自動 archive 舊課表
- 保留歷史記錄，不刪除

---

## 14. Appendix

### 14.1 File Structure

```
Havital/
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingIntroView.swift           [修改] 簡化版
│   │   ├── HeartRateZoneInputView.swift        [新增]
│   │   ├── DataSourceBindingView.swift         [修改] 觸發 backfill
│   │   ├── PersonalBestInputView.swift         [新增] 支援跳過
│   │   ├── WeeklyVolumeInputView.swift         [新增]
│   │   ├── GoalTypeSelectionView.swift         [新增] 關鍵分支
│   │   ├── GoalRaceSetupView.swift             [修改] 合併訓練日
│   │   ├── TrainingOverviewView.swift          [新增] ⭐ 核心
│   │   ├── WeeklyCycleExplanationView.swift    [新增]
│   │   └── Components/
│   │       ├── TimelinePhaseRow.swift          [新增]
│   │       └── TrainingDaysSelector.swift      [新增]
│   └── ContentView.swift                       [修改] 流程判斷
├── ViewModels/
│   ├── GoalRaceSetupViewModel.swift            [新增]
│   └── TrainingOverviewViewModel.swift         [新增]
└── Services/
    ├── TrainingPlanService.swift               [無需修改]
    └── WorkoutSyncManager.swift                [修改] 加入 triggerBackfill
```

### 14.2 Related Documents

- `Docs/TRAINING_WEEKS_CALCULATION.md` - 訓練週數計算邏輯
- `Docs/API_TRACKING_EXAMPLES.md` - API 追蹤系統
- `CLAUDE.md` - 專案架構原則

---

## 15. Approval

- **Product Owner**: __________ (Date: ______)
- **Tech Lead**: __________ (Date: ______)
- **Designer**: __________ (Date: ______)

---

**End of Document**
