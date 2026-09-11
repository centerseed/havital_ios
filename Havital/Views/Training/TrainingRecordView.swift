import SwiftUI
import HealthKit

// MARK: - TrainingRecordView (Redesigned — Paceriz Design System)
//
// Changes from original:
//   1. Replaced List with ScrollView + lazy VStack for full visual control
//   2. Added horizontal-scroll filter chip row (全部 / 輕鬆跑 / 節奏跑 / 間歇 / 長距離)
//   3. Added grouping logic by recency (今天 / 昨天 / 上週 / month-based older)
//   4. Group header shows count + total km
//   5. WorkoutV2RowView receives planMatched derived here
//   Unchanged: loadWorkouts / pagination flow, WorkoutDetailViewV2 routing

struct TrainingRecordView: View {
    @StateObject private var viewModel = TrainingRecordViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    /// 分組小計是這一頁自己現算的量，單位切換要當場重畫（T-0366）。
    @ObservedObject private var unitManager = UnitManager.shared
    @State private var selectedWorkout: WorkoutV2?
    @State private var showingWorkoutDetail = false
    @State private var heartRateData: [(Date, Double)] = []
    @State private var paceData: [(Date, Double)] = []
    @State private var showInfoSheet = false

    // Filter chip state: nil = 全部
    @State private var selectedFilter: String? = nil

    // MARK: - Filter Options
    // `id` is a stable English key used for selection state; `localizedLabel` is displayed.
    private struct FilterOption {
        let id: String
        let localizedLabel: String
        let trainingTypes: [String]
    }

    private var filterOptions: [FilterOption] {
        [
            FilterOption(id: "all",       localizedLabel: L10n.Record.Filter.all.localized,     trainingTypes: []),
            // lsd（Long Slow Distance）顯示標籤為「長距離」(見 WorkoutV2RowView.displayNameForTrainingType)，
            // 故歸在「長距離」filter，與卡片標籤一致（issue #101：標籤長距離卻在長距離分頁篩不到）。
            FilterOption(id: "easy_run",  localizedLabel: L10n.Record.Filter.easyRun.localized,  trainingTypes: ["easy_run", "easy", "recovery_run", "recovery"]),
            FilterOption(id: "tempo",     localizedLabel: L10n.Record.Filter.tempo.localized,    trainingTypes: ["tempo", "threshold", "fartlek"]),
            FilterOption(id: "interval",  localizedLabel: L10n.Record.Filter.interval.localized, trainingTypes: ["interval"]),
            FilterOption(id: "long_run",  localizedLabel: L10n.Record.Filter.longRun.localized,  trainingTypes: ["long_run", "long", "lsd"]),
        ]
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !viewModel.hasWorkouts {
                    ProgressView(NSLocalizedString("training.loading_records", comment: "Loading training records..."))
                } else {
                    workoutContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(NSLocalizedString("record.title", comment: "Training Log"))
                        .font(AppFont.title3())
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInfoSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                DeviceInfoSheetView()
            }
            .sheet(item: $selectedWorkout) { workout in
                NavigationStack {
                    WorkoutDetailViewV2(workout: workout)
                }
            }
            .task {
                await TrackedTask("TrainingRecordView: loadWorkouts") {
                    await viewModel.loadWorkouts(healthKitManager: healthKitManager)
                }.value
            }
            .refreshable {
                await TrackedTask("TrainingRecordView: refreshWorkouts") {
                    await viewModel.refreshWorkouts(healthKitManager: healthKitManager)
                }.value
            }
        }
    }

    // MARK: - Main content

    private var workoutContent: some View {
        VStack(spacing: 0) {
            // Filter chip row
            filterChipRow

            // Grouped workout scroll
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    if filteredWorkouts.isEmpty && !viewModel.isLoading {
                        emptyStateContent
                    } else {
                        ForEach(groupedWorkouts, id: \.title) { group in
                            groupSection(group)
                        }

                        // Load more trigger
                        loadMoreTrigger
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .overlay {
                if viewModel.workouts.isEmpty && !viewModel.isLoading {
                    Color.clear
                }
            }
            // 篩選結果為空時畫面上沒有任何 row，checkForLoadMore 的 onAppear 永遠不會發生，
            // 後面幾頁裡符合該分類的紀錄就再也載不到（T-0460）。改由已載入總數的變化驅動：
            // 每載進一頁就再判斷一次，直到篩到東西或後端說沒有更多（hasMoreData 為 false）。
            .task(id: loadMoreProbe) {
                if selectedFilter != nil && filteredWorkouts.isEmpty {
                    loadMoreIfNeeded()
                }
            }
        }
        .alert(NSLocalizedString("error.load_failed", comment: "Load Error"), isPresented: errorBinding) {
            Button(NSLocalizedString("common.confirm", comment: "Confirm")) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Filter Chip Row

    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(filterOptions, id: \.id) { option in
                    filterChip(option)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func filterChip(_ option: FilterOption) -> some View {
        let isSelected = (option.id == "all" && selectedFilter == nil)
            || (option.id != "all" && selectedFilter == option.id)

        return Text(option.localizedLabel)
            .font(AppFont.label())
            .lineLimit(1)
            .fixedSize()
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(isSelected ? PacerizColor.blue : Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedFilter = option.id == "all" ? nil : option.id
                }
            }
    }

    // MARK: - Grouping

    struct WorkoutGroup {
        let title: String
        let workouts: [WorkoutV2]
        var totalKm: Double {
            workouts.compactMap { $0.distanceMeters }.reduce(0, +) / 1000.0
        }
    }

    private var filteredWorkouts: [WorkoutV2] {
        guard let filter = selectedFilter else {
            return viewModel.workouts
        }
        let option = filterOptions.first { $0.id == filter }
        guard let types = option?.trainingTypes, !types.isEmpty else {
            return viewModel.workouts
        }
        return viewModel.workouts.filter { workout in
            guard let trainingType = workout.trainingType else { return false }
            return types.contains(trainingType.lowercased())
        }
    }

    private var groupedWorkouts: [WorkoutGroup] {
        let calendar = Calendar.current

        // 「上週」＝上一個日曆週（週一起算）；滾動 7 天視窗會把本週的紀錄標成
        // 「上週」（2026-09-11 裁決）。本週非今天／昨天的那幾天自己一格「本週稍早」——
        // 併進月份桶會讓它們排在「上週」下面，讀起來像消失了（同日使用者回報）。
        let thisWeekStart = App2WeekCalendar.currentWeekStart(reference: Date(), calendar: calendar)
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart)
        let todayStart = calendar.startOfDay(for: Date())

        var groups: [WorkoutGroup] = []
        var todayItems: [WorkoutV2] = []
        var yesterdayItems: [WorkoutV2] = []
        var earlierThisWeekItems: [WorkoutV2] = []
        var lastWeekItems: [WorkoutV2] = []
        var olderBuckets: [String: [WorkoutV2]] = [:]
        var olderOrder: [String] = []

        for workout in filteredWorkouts {
            let date = workout.startDate
            if calendar.isDateInToday(date) {
                todayItems.append(workout)
            } else if calendar.isDateInYesterday(date) {
                yesterdayItems.append(workout)
            } else if date >= thisWeekStart, date < todayStart {
                earlierThisWeekItems.append(workout)
            } else if let lastWeekStart, date >= lastWeekStart, date < thisWeekStart {
                lastWeekItems.append(workout)
            } else {
                // Group by month string e.g. "2026年4月"
                let monthKey = monthGroupKey(for: date, calendar: calendar)
                if olderBuckets[monthKey] == nil {
                    olderOrder.append(monthKey)
                    olderBuckets[monthKey] = []
                }
                olderBuckets[monthKey]?.append(workout)
            }
        }

        if !todayItems.isEmpty { groups.append(WorkoutGroup(title: L10n.Record.Group.today.localized, workouts: todayItems)) }
        if !yesterdayItems.isEmpty { groups.append(WorkoutGroup(title: L10n.Record.Group.yesterday.localized, workouts: yesterdayItems)) }
        if !earlierThisWeekItems.isEmpty {
            groups.append(WorkoutGroup(title: L10n.Record.Group.earlierThisWeek.localized, workouts: earlierThisWeekItems))
        }
        if !lastWeekItems.isEmpty { groups.append(WorkoutGroup(title: L10n.Record.Group.lastWeek.localized, workouts: lastWeekItems)) }
        for key in olderOrder {
            if let items = olderBuckets[key], !items.isEmpty {
                groups.append(WorkoutGroup(title: key, workouts: items))
            }
        }

        return groups
    }

    private func monthGroupKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return L10n.Record.Group.older.localized }
        return L10n.Record.Group.monthGroupFormat.localized(with: year, month)
    }

    // MARK: - Section rendering

    private func groupSection(_ group: WorkoutGroup) -> some View {
        Section {
            ForEach(group.workouts, id: \.id) { workout in
                workoutCard(workout, allInGroup: group.workouts)
                    .padding(.bottom, 10)
                    .onAppear { checkForLoadMore(workout) }
            }
        } header: {
            groupHeader(group)
        }
    }

    private func groupHeader(_ group: WorkoutGroup) -> some View {
        HStack {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(group.title)
                    .font(AppFont.bodyStrong())
                    .foregroundColor(.secondary)
                Text(L10n.Record.Group.runCountFormat.localized(with: group.workouts.count))
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            Spacer()
            if group.totalKm > 0 {
                Text(L10n.Record.Group.totalDistanceFormat.localized(
                    with: unitManager.currentUnitSystem.formatDistance(group.totalKm)
                ))
                    .font(AppFont.micro().monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Workout card

    private func workoutCard(_ workout: WorkoutV2, allInGroup: [WorkoutV2]) -> some View {
        Button {
            selectedWorkout = workout
        } label: {
            WorkoutV2RowView(
                workout: workout,
                isUploaded: true,
                uploadTime: workout.startDate,
                planMatched: derivePlanMatched(workout)
            )
        }
        .buttonStyle(.plain)
    }

    /// Plan matched: true only if dailyPlanSummary is present with a matching trainingType.
    /// No fake data — if field absent, returns nil (chip omitted).
    private func derivePlanMatched(_ workout: WorkoutV2) -> Bool? {
        guard let summary = workout.dailyPlanSummary,
              let planType = summary.trainingType,
              let workoutType = workout.trainingType else { return nil }
        return planType.lowercased() == workoutType.lowercased()
    }

    /// VDOT delta vs. previous workout in the full list (not filtered).
    /// Returns nil if current or previous VDOT is absent.
    // MARK: - Load more

    private var loadMoreTrigger: some View {
        Group {
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView(NSLocalizedString("training.loading_more_records", comment: "Loading more records..."))
                        .font(AppFont.caption())
                        .padding()
                    Spacer()
                }
            }
        }
    }

    /// 空篩選續載的驅動值：已載入總數或所選分類一變就重新判斷一次。
    private var loadMoreProbe: String {
        "\(selectedFilter ?? "all")-\(viewModel.workouts.count)"
    }

    private func checkForLoadMore(_ workout: WorkoutV2) {
        // 以「目前實際渲染的清單」最後一筆為觸發點。比對未篩選的 viewModel.workouts.last
        // 會讓分類分頁幾乎不觸發分頁載入——那一筆通常被篩掉、不會 onAppear（T-0460）。
        let isLastItem = workout.id == filteredWorkouts.last?.id
        if isLastItem { loadMoreIfNeeded() }
    }

    private func loadMoreIfNeeded() {
        guard !viewModel.isLoadingMore && viewModel.hasMoreData else { return }
        TrackedTask("TrainingRecordView: loadMoreWorkouts") {
            await viewModel.loadMoreWorkouts()
        }
    }

    // MARK: - Empty state

    private var emptyStateContent: some View {
        ContentUnavailableView(
            NSLocalizedString("record.no_records", comment: "No Training Records"),
            systemImage: "figure.run",
            description: Text(NSLocalizedString("record.no_records_description", comment: "No workout records available"))
        )
        .padding(.top, 80)
    }

    // MARK: - Helpers

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in }
        )
    }
}

#Preview {
    TrainingRecordView()
        .environmentObject(HealthKitManager())
}
