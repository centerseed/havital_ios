import SwiftUI
import HealthKit

// MARK: - TrainingRecordView (Redesigned — Paceriz Design System)
//
// Changes from original:
//   1. Replaced List with ScrollView + lazy VStack for full visual control
//   2. Added horizontal-scroll filter chip row (全部 / 輕鬆跑 / 節奏跑 / 間歇 / 長距離)
//   3. Added grouping logic by recency (今天 / 昨天 / 本週稍早 / 上週 / month-based older)
//   4. Group header shows count + total km
//   5. WorkoutV2RowView receives planMatched + vdotDelta derived here
//   Unchanged: loadWorkouts / pagination flow, WorkoutDetailViewV2 routing

struct TrainingRecordView: View {
    @StateObject private var viewModel = TrainingRecordViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var selectedWorkout: WorkoutV2?
    @State private var showingWorkoutDetail = false
    @State private var heartRateData: [(Date, Double)] = []
    @State private var paceData: [(Date, Double)] = []
    @State private var showInfoSheet = false

    // Filter chip state: nil = 全部
    @State private var selectedFilter: String? = nil

    // MARK: - Filter Options
    private let filterOptions: [(label: String, trainingTypes: [String])] = [
        ("全部", []),
        ("輕鬆跑", ["easy_run", "easy", "recovery_run", "recovery", "lsd"]),
        ("節奏跑", ["tempo", "threshold", "fartlek"]),
        ("間歇", ["interval"]),
        ("長距離", ["long_run", "long"]),
    ]

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
        // Plain HStack (no horizontal ScrollView) — 5 short chips fit iPhone 17 Pro 393pt width.
        HStack(spacing: 6) {
            ForEach(filterOptions, id: \.label) { option in
                filterChip(option)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func filterChip(_ option: (label: String, trainingTypes: [String])) -> some View {
        let isSelected = (option.label == "全部" && selectedFilter == nil)
            || (option.label != "全部" && selectedFilter == option.label)

        return Text(option.label)
            .font(AppFont.label())
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(isSelected ? PacerizColor.blue : Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedFilter = option.label == "全部" ? nil : option.label
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
        let option = filterOptions.first { $0.label == filter }
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
        let today = Date()

        // Determine week interval for "this week"
        let thisWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today)

        // Previous week
        let lastWeekStart: Date? = thisWeekInterval.flatMap {
            calendar.date(byAdding: .weekOfYear, value: -1, to: $0.start)
        }
        let lastWeekInterval: DateInterval? = lastWeekStart.flatMap {
            calendar.dateInterval(of: .weekOfYear, for: $0)
        }

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
            } else if let interval = thisWeekInterval, interval.contains(date) {
                // Same week but not today or yesterday
                earlierThisWeekItems.append(workout)
            } else if let interval = lastWeekInterval, interval.contains(date) {
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

        if !todayItems.isEmpty { groups.append(WorkoutGroup(title: "今天", workouts: todayItems)) }
        if !yesterdayItems.isEmpty { groups.append(WorkoutGroup(title: "昨天", workouts: yesterdayItems)) }
        if !earlierThisWeekItems.isEmpty { groups.append(WorkoutGroup(title: "本週稍早", workouts: earlierThisWeekItems)) }
        if !lastWeekItems.isEmpty { groups.append(WorkoutGroup(title: "上週", workouts: lastWeekItems)) }
        for key in olderOrder {
            if let items = olderBuckets[key], !items.isEmpty {
                groups.append(WorkoutGroup(title: key, workouts: items))
            }
        }

        return groups
    }

    private func monthGroupKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return "更早" }
        return "\(year)年\(month)月"
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
                Text("\(group.workouts.count) 次跑步")
                    .font(AppFont.micro())
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            Spacer()
            if group.totalKm > 0 {
                Text(String(format: "共 %.1f km", group.totalKm))
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
                planMatched: derivePlanMatched(workout),
                vdotDelta: deriveVdotDelta(workout)
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
    private func deriveVdotDelta(_ workout: WorkoutV2) -> Double? {
        let all = viewModel.workouts  // sorted desc by date
        guard let currentVdot = workout.dynamicVdot,
              let idx = all.firstIndex(where: { $0.id == workout.id }),
              idx + 1 < all.count,
              let prevVdot = all[idx + 1].dynamicVdot else { return nil }
        return currentVdot - prevVdot
    }

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

    private func checkForLoadMore(_ workout: WorkoutV2) {
        let isLastItem = workout.id == viewModel.workouts.last?.id
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
