import SwiftUI
import HealthKit

// MARK: - ViewModel

/// TrainingCalendarViewModel
/// 負責 TrainingCalendarView 的數據邏輯
/// ✅ Clean Architecture: 注入兩個 Repository（WorkoutRepository + MonthlyStatsRepository）
@MainActor
class TrainingCalendarViewModel: ObservableObject {
    @Published var workouts: [WorkoutV2] = []
    @Published var monthlySummaries: [MonthlyRunningSummary] = []
    @Published var isLoading = false
    @Published var isLoadingMonthlySummaries = false

    private let workoutRepository: WorkoutRepository
    private let monthlyStatsRepository: MonthlyStatsRepository

    /// ✅ Event subscriber ID for cleanup
    private var eventSubscriberId: String?

    init(workoutRepository: WorkoutRepository = DependencyContainer.shared.resolve(),
         monthlyStatsRepository: MonthlyStatsRepository = DependencyContainer.shared.resolve()) {
        print("🚀🚀🚀 [TrainingCalendarViewModel] Init started 🚀🚀🚀")
        print("🚀 WorkoutRepository: \(String(describing: type(of: workoutRepository)))")
        print("🚀 MonthlyStatsRepository: \(String(describing: type(of: monthlyStatsRepository)))")

        self.workoutRepository = workoutRepository
        self.monthlyStatsRepository = monthlyStatsRepository

        // Generate unique ID for this instance
        self.eventSubscriberId = "TrainingCalendarViewModel_\(UUID().uuidString)"

        Logger.debug("[TrainingCalendarViewModel] ✅ Init completed, subscriberId: \(eventSubscriberId ?? "nil")")

        // ✅ 訂閱 CacheEventBus .userLogout 事件
        setupEventSubscriptions()

        // 初始載入緩存數據
        Task {
            await loadCachedWorkouts()
        }
    }

    /// 設置事件訂閱
    private func setupEventSubscriptions() {
        guard let subscriberId = eventSubscriberId else { return }

        // ✅ Fix Data Race: 確保回調在 MainActor 中執行
        CacheEventBus.shared.subscribe(forIdentifier: subscriberId) { [weak self] reason in
            guard case .userLogout = reason else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                Logger.debug("[TrainingCalendarViewModel] 收到 userLogout 事件，清除月度統計緩存")
                await self.monthlyStatsRepository.clearCache()
                self.workouts = []
            }
        }
    }

    /// ✅ Fix Memory Leak: Unsubscribe on deinit
    deinit {
        if let subscriberId = eventSubscriberId {
            CacheEventBus.shared.unsubscribe(forIdentifier: subscriberId)
            Logger.debug("[TrainingCalendarViewModel] Unsubscribed from CacheEventBus")
        }
    }

    private func loadCachedWorkouts() async {
        // 嘗試獲取緩存數據顯示初始狀態
        let cached = await workoutRepository.getAllWorkoutsAsync()
        if !cached.isEmpty {
            self.workouts = cached
        }
    }

    /// 載入指定月份的訓練數據（整合 local workouts + monthly stats）
    /// ✅ Clean Architecture: 使用 MonthlyStatsRepository 獲取月度數據（自動處理緩存）
    func loadWorkoutsForMonth(month: Date) async {
        print("🔥🔥🔥 loadWorkoutsForMonth called for: \(month) 🔥🔥🔥")
        isLoading = true
        let calendar = Calendar.current

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            isLoading = false
            return
        }

        // Extract year and month
        let year = calendar.component(.year, from: month)
        let monthNumber = calendar.component(.month, from: month)

        // ✅ Track A: 獲取本地 workouts（用於詳細顯示，如心率、配速曲線等）
        print("📊 [TrainingCalendar] 開始載入 \(year)-\(String(format: "%02d", monthNumber))")
        let localWorkouts = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: startOfMonth,
            endDate: endOfMonth
        )
        print("📊 [TrainingCalendar] 本地 workouts: \(localWorkouts.count) 筆")

        // ✅ Track B: 獲取月度統計（補充歷史資料 - MonthlyStatsRepository 自動處理緩存）
        // MonthlyStatsRepositoryImpl 已實現「只同步一次」邏輯：
        // - 如果該月已緩存 → 直接返回緩存數據，不調用 API
        // - 如果未緩存 → 調用 /v2/workout/monthly_stats API 並緩存結果
        print("📊 [TrainingCalendar] 🌐 開始調用 monthlyStatsRepository.getMonthlyStats(\(year), \(monthNumber))")
        var monthlyStats: [DailyStat] = []
        do {
            monthlyStats = try await monthlyStatsRepository.getMonthlyStats(year: year, month: monthNumber)
            print("📊 [TrainingCalendar] ✅ 月度統計成功: \(monthlyStats.count) 筆")
        } catch {
            print("📊 [TrainingCalendar] ❌ 月度統計失敗: \(error.localizedDescription)")
            monthlyStats = []
        }

        // ✅ 合併數據：本地優先，月度統計補充空白日期
        let mergedWorkouts = mergeWorkoutsWithMonthlyStats(
            localWorkouts: localWorkouts,
            monthlyStats: monthlyStats
        )

        self.workouts = mergedWorkouts
        self.isLoading = false

        print("📊 [TrainingCalendar] 🏁 載入完成 - 本地: \(localWorkouts.count), 月度補充: \(monthlyStats.count), 合併後: \(mergedWorkouts.count)")
    }

    /// 載入最近幾個月的跑量與平均配速摘要。
    func loadRecentMonthlySummaries(anchorMonth: Date = Date(), monthCount: Int = 6) async {
        guard !isLoadingMonthlySummaries else { return }
        isLoadingMonthlySummaries = true
        defer { isLoadingMonthlySummaries = false }

        let calendar = Calendar.current
        var summaries: [MonthlyRunningSummary] = []

        for offset in 0..<monthCount {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: anchorMonth),
                  let range = DateFormatterHelper.monthRange(for: month) else {
                continue
            }

            let year = calendar.component(.year, from: month)
            let monthNumber = calendar.component(.month, from: month)
            let localWorkouts = await workoutRepository.getWorkoutsInDateRangeAsync(
                startDate: range.start,
                endDate: range.end
            )

            let monthlyStats: [DailyStat]
            do {
                monthlyStats = try await monthlyStatsRepository.getMonthlyStats(year: year, month: monthNumber)
            } catch {
                Logger.debug("[TrainingCalendar] monthly summary stats failed for \(year)-\(monthNumber): \(error.localizedDescription)")
                monthlyStats = []
            }

            summaries.append(
                makeMonthlySummary(month: month, localWorkouts: localWorkouts, monthlyStats: monthlyStats)
            )
        }

        monthlySummaries = summaries
    }

    /// 合併本地訓練與月度統計
    /// - 優先級: 本地 workout > 月度統計
    /// - 月度統計只填補本地沒有的日期
    private func mergeWorkoutsWithMonthlyStats(
        localWorkouts: [WorkoutV2],
        monthlyStats: [DailyStat]
    ) -> [WorkoutV2] {
        guard !monthlyStats.isEmpty else {
            return localWorkouts
        }

        let calendar = Calendar.current

        // 獲取本地已有的日期集合
        let localDates = Set(localWorkouts.map { calendar.startOfDay(for: $0.startDate) })

        // 過濾月度統計中本地沒有的日期
        let missingDates = monthlyStats.filter { stat in
            guard let statDate = stat.dateValue else { return false }
            return !localDates.contains(calendar.startOfDay(for: statDate))
        }

        // 將月度統計轉為虛擬 WorkoutV2 對象（用於日曆顯示）
        let syntheticWorkouts = missingDates.compactMap { stat -> WorkoutV2? in
            guard let date = stat.dateValue else { return nil }

            // ⚠️ 創建虛擬 workout（標記 provider 為 "monthly_stats" 以便區分）
            return WorkoutV2(
                id: "monthly_\(stat.date)",
                provider: "monthly_stats",
                activityType: "running",
                startTimeUtc: "\(stat.date)T00:00:00Z",
                endTimeUtc: "\(stat.date)T00:00:00Z",
                durationSeconds: stat.avgPacePerKm.map { $0 * Int(stat.totalDistanceKm) } ?? 0,
                distanceMeters: stat.totalDistanceMeters,
                distanceDisplay: nil,
                distanceUnit: nil,
                deviceName: nil,
                basicMetrics: nil,
                advancedMetrics: nil,
                createdAt: nil,
                schemaVersion: nil,
                storagePath: nil,
                dailyPlanSummary: nil,
                aiSummary: nil,
                shareCardContent: nil
            )
        }

        // 合併並排序
        return (localWorkouts + syntheticWorkouts).sorted { $0.endDate > $1.endDate }
    }

    private func makeMonthlySummary(
        month: Date,
        localWorkouts: [WorkoutV2],
        monthlyStats: [DailyStat]
    ) -> MonthlyRunningSummary {
        let calendar = Calendar.current
        let localRunningWorkouts = localWorkouts.filter { $0.activityType == "running" }
        let localDates = Set(localRunningWorkouts.map { calendar.startOfDay(for: $0.startDate) })

        var totalDistanceKm = localRunningWorkouts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000.0) }
        var totalDurationSeconds = localRunningWorkouts.reduce(0.0) { $0 + $1.duration }
        var workoutCount = localRunningWorkouts.count

        for stat in monthlyStats {
            guard let statDate = stat.dateValue else { continue }
            guard !localDates.contains(calendar.startOfDay(for: statDate)) else { continue }
            guard stat.totalDistanceKm > 0 else { continue }

            totalDistanceKm += stat.totalDistanceKm
            workoutCount += stat.workoutCount
            if let pace = stat.avgPacePerKm {
                totalDurationSeconds += Double(pace) * stat.totalDistanceKm
            }
        }

        let averagePaceSeconds = totalDistanceKm > 0 ? totalDurationSeconds / totalDistanceKm : nil
        return MonthlyRunningSummary(
            month: month,
            totalDistanceKm: totalDistanceKm,
            averagePaceSecondsPerKm: averagePaceSeconds,
            workoutCount: workoutCount
        )
    }
}

struct MonthlyRunningSummary: Identifiable, Equatable {
    var id: String {
        let calendar = Calendar.current
        return "\(calendar.component(.year, from: month))-\(calendar.component(.month, from: month))"
    }

    let month: Date
    let totalDistanceKm: Double
    let averagePaceSecondsPerKm: Double?
    let workoutCount: Int
}

private enum TrainingCalendarMode: String {
    case calendar
    case monthlySummary
}

/// 訓練日曆視圖 - 顯示每月訓練記錄（從緩存讀取）
struct TrainingCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var viewModel = TrainingCalendarViewModel()

    @State private var selectedMonth = Date()
    @State private var workoutsByDate: [TimeInterval: DayWorkoutInfo] = [:]  // 日期 -> 訓練資訊
    @State private var selectedMode: TrainingCalendarMode = .calendar

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter.string(from: selectedMonth)
    }

    /// Get current month date range using DateFormatterHelper utility
    /// Ensures endOfMonth is set to 23:59:59 to include all records on the last day
    private var currentMonthRange: (start: Date, end: Date)? {
        return DateFormatterHelper.monthRange(for: selectedMonth)
    }

    /// 只計算跑步類型的月總里程
    private var totalMonthDistance: Double {
        guard let range = currentMonthRange else { return 0 }
        let calendar = Calendar.current

        // 從 ViewModel 獲取該月的跑步記錄
        let runningWorkouts = viewModel.workouts.filter { workout in
            // 注意：viewModel.workouts 已經是該月的數據（如果是通過 loadWorkoutsForMonth 加載的）
            // 但為了安全起見，再次過濾日期（因為初始加載可能是所有數據）
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= range.start && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
            let isRunning = workout.activityType == "running"
            return isInMonth && isRunning
        }

        // 只計算跑步的總距離（轉換為公里）
        return runningWorkouts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000.0) }
    }

    private var averagePace: String {
        guard let range = currentMonthRange else { return "--:--" }
        let calendar = Calendar.current

        // ✅ 只計算跑步類型的訓練記錄
        let runningWorkouts = viewModel.workouts.filter { workout in
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= range.start && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
            let isRunning = workout.activityType == "running"
            return isInMonth && isRunning
        }

        guard !runningWorkouts.isEmpty else { return "--:--" }

        // 計算跑步的總距離和總時長
        let totalDistance = runningWorkouts.reduce(0.0) { $0 + (($1.distance ?? 0) / 1000.0) }  // 轉換為公里
        let totalDuration = runningWorkouts.reduce(0.0) { $0 + $1.duration }

        guard totalDistance > 0 else { return "--:--" }

        // 計算平均配速 (分鐘/公里)
        let paceSeconds = totalDuration / totalDistance
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                modePicker

                // 月份選擇器
                if selectedMode == .calendar {
                    monthSelector

                    // 統計卡片
                    statsCard

                    // 日曆視圖
                    calendarGrid
                } else {
                    monthlySummaryView
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("training_plan.training_calendar", comment: "Training Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("common.close", comment: "Close")) {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadWorkoutsForMonth()
        }
        .onChange(of: selectedMode) { mode in
            guard mode == .monthlySummary else { return }
            loadMonthlySummariesIfNeeded()
        }
        .onChange(of: viewModel.workouts) { _ in
            processWorkoutsForDisplay()
        }
    }

    private var modePicker: some View {
        Picker(NSLocalizedString("training_calendar.view_mode", comment: "View mode"), selection: $selectedMode) {
            Text(NSLocalizedString("training_calendar.calendar_view", comment: "Calendar"))
                .tag(TrainingCalendarMode.calendar)
            Text(NSLocalizedString("training_calendar.monthly_summary", comment: "Monthly summary"))
                .tag(TrainingCalendarMode.monthlySummary)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("training_calendar.mode_picker")
    }

    // MARK: - 月份選擇器

    private var monthSelector: some View {
        HStack {
            Button(action: {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                loadWorkoutsForMonth()
            }) {
                Image(systemName: "chevron.left")
                    .font(AppFont.title3())
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthName)
                .font(AppFont.title2())
                .fontWeight(.semibold)

            Spacer()

            Button(action: {
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                if nextMonth <= Date() {
                    selectedMonth = nextMonth
                    loadWorkoutsForMonth()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(AppFont.title3())
                    .foregroundColor(canGoToNextMonth ? .blue : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoToNextMonth)
        }
    }

    private var canGoToNextMonth: Bool {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        return nextMonth <= Date()
    }

    // MARK: - 統計卡片

    private var statsCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("training_plan.monthly_total_distance", comment: "Monthly Total Distance"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", UnitManager.shared.convertedDistance(totalMonthDistance)))
                        .font(AppFont.title1())
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text(UnitManager.shared.currentUnitSystem.distanceSuffix)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(NSLocalizedString("training_plan.average_pace", comment: "Average Pace"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)

                Text(averagePace)
                    .font(AppFont.title1())
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
        )
    }

    // MARK: - 月統計

    private var monthlySummaryView: some View {
        let summaries = viewModel.monthlySummaries
        let featuredSummary = summaries.first
        let bestSummary = summaries.max { $0.totalDistanceKm < $1.totalDistanceKm }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("training_calendar.monthly_summary_title", comment: "Monthly running summary"))
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(NSLocalizedString("training_calendar.monthly_summary_description", comment: "Distance and pace by month"))
                        .font(AppFont.subheadline())
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.isLoadingMonthlySummaries {
                    ProgressView()
                }
            }

            if summaries.isEmpty && !viewModel.isLoadingMonthlySummaries {
                Text(NSLocalizedString("training_calendar.no_monthly_data", comment: "No monthly running data"))
                    .font(AppFont.subheadline())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            } else {
                VStack(spacing: 14) {
                    if let featuredSummary {
                        MonthlyRunningHeroCard(summary: featuredSummary, bestSummary: bestSummary)
                    }

                    MonthlyRunningTrendCard(summaries: summaries)

                    VStack(spacing: 8) {
                        ForEach(summaries) { summary in
                            MonthlyRunningSummaryRow(
                                summary: summary,
                                isBestMonth: summary.id == bestSummary?.id
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 日曆網格

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // 星期標題
            weekdayHeader

            // 日期網格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, workoutInfo: workoutsByDate[normalizeDate(date).timeIntervalSince1970])
                    } else {
                        EmptyDayCell()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var weekdayHeader: some View {
        let symbols = localizedWeekdaySymbolsStartingMonday()
        return HStack(spacing: 4) {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .font(AppFont.captionSmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }

    private func localizedWeekdaySymbolsStartingMonday() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.shortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else {
            return ["M", "T", "W", "T", "F", "S", "S"]
        }
        return Array(symbols[1...6]) + [symbols[0]]
    }

    // MARK: - 數據加載

    private func loadWorkoutsForMonth() {
        // 使用 Task 調用異步方法，添加 API 追蹤
        Task {
            await viewModel.loadWorkoutsForMonth(month: selectedMonth)
        }.tracked(from: "TrainingCalendarView: loadWorkoutsForMonth")
    }

    private func loadMonthlySummariesIfNeeded() {
        guard viewModel.monthlySummaries.isEmpty else { return }
        Task {
            await viewModel.loadRecentMonthlySummaries(anchorMonth: Date(), monthCount: 6)
        }.tracked(from: "TrainingCalendarView: loadMonthlySummaries")
    }
    
    private func processWorkoutsForDisplay() {
        guard let range = currentMonthRange else { return }
        let calendar = Calendar.current

        // 這些數據已經是該月的了，但我們還是過濾一下確保安全
        let allWorkouts = viewModel.workouts

        // 過濾當月的訓練記錄（排除 rest 類型）
        let monthWorkouts = allWorkouts.filter { workout in
            let workoutDate = workout.startDate
            let isInMonth = workoutDate >= range.start && workoutDate <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
            // 排除 "rest" 類型，這不是實際的運動記錄
            let isNotRest = workout.activityType.lowercased() != "rest"
            return isInMonth && isNotRest
        }

        // 按日期分組並計算總距離和主要運動類型
        var grouped: [TimeInterval: DayWorkoutInfo] = [:]
        for workout in monthWorkouts {
            let key = normalizeDate(workout.startDate).timeIntervalSince1970
            let distance = (workout.distance ?? 0) / 1000.0  // 轉換為公里
            let duration = workout.duration

            if var existing = grouped[key] {
                existing.totalDistance += distance
                existing.totalDuration += duration
                existing.workoutCount += 1
                // 更新主要類型（選擇距離最長的）
                if distance > (existing.primaryDistance ?? 0) {
                    existing.primaryType = workout.activityType
                    existing.primaryDistance = distance
                }
                grouped[key] = existing
            } else {
                grouped[key] = DayWorkoutInfo(
                    totalDistance: distance,
                    totalDuration: duration,
                    primaryType: workout.activityType,
                    primaryDistance: distance,
                    workoutCount: 1
                )
            }
        }

        workoutsByDate = grouped

        print("📅 日曆數據處理完成：\(selectedMonth) 共 \(monthWorkouts.count) 筆記錄")
    }

    // MARK: - Helper Functions

    private func normalizeDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date)
    }

    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        var days: [Date?] = []

        // 獲取第一天是星期幾，轉換為 Mon=0, Tue=1, ..., Sun=6
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1=Sun, 2=Mon, ..., 7=Sat
        let offset = (firstWeekday + 5) % 7

        // 添加前置空白
        for _ in 0..<offset {
            days.append(nil)
        }

        // 添加所有日期
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - 訓練資訊結構

struct DayWorkoutInfo {
    var totalDistance: Double
    var totalDuration: TimeInterval
    var primaryType: String  // 主要運動類型
    var primaryDistance: Double?
    var workoutCount: Int
}

// MARK: - Monthly Summary Row

private struct MonthlyRunningSummaryRow: View {
    let summary: MonthlyRunningSummary
    let isBestMonth: Bool

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter.string(from: summary.month)
    }

    private var distanceText: String {
        let converted = UnitManager.shared.convertedDistance(summary.totalDistanceKm)
        let unit = UnitManager.shared.currentUnitSystem.distanceSuffix
        return "\(String(format: "%.1f", converted)) \(unit)"
    }

    private var paceText: String {
        guard let secondsPerKm = summary.averagePaceSecondsPerKm, secondsPerKm.isFinite else {
            return "--:--"
        }
        let totalSeconds = Int(secondsPerKm.rounded())
        return String(format: "%d'%02d\"", totalSeconds / 60, totalSeconds % 60)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(monthAbbreviation)
                    .font(AppFont.systemScaled(size: 13, weight: .bold))
                    .foregroundColor(isBestMonth ? .white : .green)

                Text(yearText)
                    .font(AppFont.systemScaled(size: 10, weight: .medium))
                    .foregroundColor(isBestMonth ? .white.opacity(0.78) : .secondary)
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isBestMonth ? Color.green : Color.green.opacity(0.12))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(monthTitle)
                    .font(AppFont.systemScaled(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Text(String(format: NSLocalizedString("training_calendar.run_count_format", comment: "Run count"), summary.workoutCount))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    if isBestMonth {
                        Text(NSLocalizedString("training_calendar.best_month", comment: "Best month"))
                            .font(AppFont.systemScaled(size: 11, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(distanceText)
                    .font(AppFont.systemScaled(size: 17, weight: .bold))
                    .foregroundColor(.primary)

                Text(paceText)
                    .font(AppFont.systemScaled(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("training_calendar.monthly_summary_row.\(summary.id)")
    }

    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: summary.month)
    }

    private var yearText: String {
        String(Calendar.current.component(.year, from: summary.month))
    }
}

private struct MonthlyRunningHeroCard: View {
    let summary: MonthlyRunningSummary
    let bestSummary: MonthlyRunningSummary?

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: summary.month)
    }

    private var distanceValue: String {
        String(format: "%.1f", UnitManager.shared.convertedDistance(summary.totalDistanceKm))
    }

    private var distanceUnit: String {
        UnitManager.shared.currentUnitSystem.distanceSuffix
    }

    private var paceText: String {
        guard let secondsPerKm = summary.averagePaceSecondsPerKm, secondsPerKm.isFinite else {
            return "--:--"
        }
        let totalSeconds = Int(secondsPerKm.rounded())
        return String(format: "%d'%02d\"", totalSeconds / 60, totalSeconds % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(monthTitle)
                        .font(AppFont.systemScaled(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Text(NSLocalizedString("training_calendar.hero_caption", comment: "Monthly running recap"))
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.68))
                }

                Spacer()

                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(distanceValue)
                    .font(AppFont.systemScaled(size: 52, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.74)

                Text(distanceUnit)
                    .font(AppFont.systemScaled(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.74))
            }

            HStack(spacing: 10) {
                heroMetric(
                    title: NSLocalizedString("training_calendar.average_pace_short", comment: "Average pace"),
                    value: paceText
                )
                heroMetric(
                    title: NSLocalizedString("training_calendar.runs_short", comment: "Runs"),
                    value: "\(summary.workoutCount)"
                )
                heroMetric(
                    title: NSLocalizedString("training_calendar.best_short", comment: "Best"),
                    value: bestSummary.map { String(format: "%.0f", UnitManager.shared.convertedDistance($0.totalDistanceKm)) } ?? "--"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.45, blue: 0.27), Color(red: 0.08, green: 0.28, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.green.opacity(0.2), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.systemScaled(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(AppFont.systemScaled(size: 17, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct MonthlyRunningTrendCard: View {
    let summaries: [MonthlyRunningSummary]
    private let chartHeight: CGFloat = 92

    private var chartSummaries: [MonthlyRunningSummary] {
        Array(summaries.reversed())
    }

    private var maxDistance: Double {
        max(chartSummaries.map(\.totalDistanceKm).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(NSLocalizedString("training_calendar.recent_trend", comment: "Recent trend"))
                    .font(AppFont.systemScaled(size: 16, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Text(NSLocalizedString("training_calendar.last_six_months", comment: "Last six months"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(chartSummaries) { summary in
                    VStack(spacing: 7) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green)
                                .frame(height: barHeight(for: summary))
                        }
                        .frame(height: chartHeight, alignment: .bottom)
                        .frame(maxWidth: .infinity)

                        Text(shortMonth(summary.month))
                            .font(AppFont.systemScaled(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func shortMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    private func barHeight(for summary: MonthlyRunningSummary) -> CGFloat {
        let ratio = max(0, min(1, summary.totalDistanceKm / maxDistance))
        return max(8, chartHeight * ratio)
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let workoutInfo: DayWorkoutInfo?
    @Environment(\.colorScheme) var colorScheme

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var workoutColor: Color {
        guard let info = workoutInfo else { return .clear }
        return ActivityTypeStyleHelper.color(for: info.primaryType)
    }

    private var workoutIcon: String {
        guard let info = workoutInfo else { return "figure.run" }
        return ActivityTypeStyleHelper.icon(for: info.primaryType)
    }

    private var backgroundColor: Color {
        if isToday {
            return .blue.opacity(0.15)
        } else if workoutInfo != nil {
            return workoutColor.opacity(0.12)
        } else {
            return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97)
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayNumber)
                .font(AppFont.systemScaled(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .blue : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let info = workoutInfo {
                if info.totalDistance > 0 {
                    Text(String(format: "%.1f", info.totalDistance))
                        .font(AppFont.systemScaled(size: 12, weight: .bold))
                        .foregroundColor(workoutColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                // 跑步 icon 旁邊掛 ×N — 語意：N 筆此類訓練
                HStack(spacing: 2) {
                    Image(systemName: workoutIcon)
                        .font(AppFont.systemScaled(size: 12))
                        .foregroundColor(workoutColor.opacity(0.8))
                    if info.workoutCount > 1 {
                        Text("×\(info.workoutCount)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(workoutColor.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

struct EmptyDayCell: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 70)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TrainingCalendarView()
    }
}
