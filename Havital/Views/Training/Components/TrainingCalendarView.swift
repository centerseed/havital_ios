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

    /// 記住最後載入的月份，供同步事件後重載。
    private var lastLoadedMonth: Date?

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
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch reason {
                case .userLogout:
                    Logger.debug("[TrainingCalendarViewModel] 收到 userLogout 事件，清除月度統計緩存")
                    await self.monthlyStatsRepository.clearCache()
                    self.workouts = []
                case .dataChanged(.workouts):
                    // 新訓練同步進來 → 失效近月快取並重載當前顯示月份，避免日曆漏掉新訓練。
                    Logger.debug("[TrainingCalendarViewModel] 收到 dataChanged.workouts，失效近月快取並重載")
                    await self.monthlyStatsRepository.invalidateRecentMonths(count: 3)
                    if let month = self.lastLoadedMonth {
                        await self.loadWorkoutsForMonth(month: month)
                    }
                default:
                    break
                }
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
        lastLoadedMonth = month
        let calendar = Calendar.current

        // 用統一的 monthRange helper：end 是最後一天 23:59:59（且尊重使用者時區），
        // 與 totalMonthDistance 用的 currentMonthRange 一致。
        guard let range = DateFormatterHelper.monthRange(for: month) else {
            isLoading = false
            return
        }
        let startOfMonth = range.start
        let endOfMonth = range.end
        let year = calendar.component(.year, from: month)
        let monthNumber = calendar.component(.month, from: month)

        // ── Track A：先用「已快取的本地 workouts」立刻渲染 ───────────────────────────
        // getWorkoutsInDateRangeAsync 純讀 LocalDataSource（無網路）→ 重訪某月可秒填格子。
        // 有快取就「不轉圈」；只有該月完全沒本地快取時才顯示 loading。
        // （修：原本無條件 isLoading=true 並 await ensureMonthLoaded 的網路刷新後才更新
        //   workouts，導致每次切月、連重訪都卡網路 round-trip。改成 SWR：快取先上、刷新丟背景。）
        let cachedLocal = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: startOfMonth,
            endDate: endOfMonth
        )
        if cachedLocal.isEmpty {
            isLoading = true
        } else {
            self.workouts = cachedLocal
        }

        // ── Track B：背景刷新（ensureMonthLoaded 對近月仍會抓新同步的訓練；但不再擋 UI）──
        await workoutRepository.ensureMonthLoaded(year: year, month: monthNumber)
        let freshLocal = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: startOfMonth,
            endDate: endOfMonth
        )

        // MonthlyStatsRepository 自帶快取：已緩存該月 → 直接回不打 API。
        var monthlyStats: [DailyStat] = []
        do {
            monthlyStats = try await tracked("TrainingCalendarView: loadMonthlyStats") {
                try await monthlyStatsRepository.getMonthlyStats(year: year, month: monthNumber)
            }
        } catch {
            monthlyStats = []
        }

        // 期間使用者可能已切到別月 → 只在仍停在同一月時才覆蓋，避免 stale 蓋掉新選月。
        guard let last = lastLoadedMonth,
              calendar.component(.year, from: last) == year,
              calendar.component(.month, from: last) == monthNumber else {
            return
        }

        // 本地優先，月度統計補充空白日期。
        self.workouts = mergeWorkoutsWithMonthlyStats(
            localWorkouts: freshLocal,
            monthlyStats: monthlyStats
        )
        self.isLoading = false
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
                monthlyStats = try await tracked("TrainingCalendarView: loadMonthlyStats") {
                    try await monthlyStatsRepository.getMonthlyStats(year: year, month: monthNumber)
                }
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

    /// 本月有運動的天數（含各類型）
    private var monthlyActiveDays: Int { workoutsByDate.count }
    /// 本月運動總筆數（含各類型）
    private var monthlyWorkoutCount: Int {
        workoutsByDate.values.reduce(0) { $0 + $1.workoutCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                modePicker

                // 月份選擇器
                if selectedMode == .calendar {
                    monthSelector

                    // 品牌淡藍 hero（可炫耀：總距離 + 出勤 + 次數 + 配速 + Paceriz 品牌）
                    shareableHeroCard

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
        .preferredColorScheme(.light)
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

    // MARK: - 品牌 hero 卡（淡藍品牌風，可炫耀 + 截圖即分享）

    private var shareableHeroCard: some View {
        let unit = UnitManager.shared.currentUnitSystem.distanceSuffix
        let distanceValue = String(format: "%.1f", UnitManager.shared.convertedDistance(totalMonthDistance))
        return VStack(alignment: .leading, spacing: 10) {
            // 品牌列：Paceriz logo chip + 月份
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white)   // 白底讓藍色 shoe logo 在藍 hero 上看得見
                        .frame(width: 26, height: 26)
                    Image("paceriz_logo")
                        .resizable().scaledToFit().frame(width: 18, height: 18)
                }
                Text("PACERIZ")
                    .font(AppFont.systemScaled(size: 12, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.white)
                Spacer()
                // 月份不再放這（上方選擇器已顯示，避免重複）
            }

            // 大數字：本月總距離（縮小，讓出空間給月曆）
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(distanceValue)
                    .font(AppFont.systemScaled(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.78)
                Text(unit)
                    .font(AppFont.systemScaled(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Text(NSLocalizedString("training_plan.monthly_total_distance", comment: "Monthly Total Distance"))
                    .font(AppFont.caption())
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.leading, 4)
            }

            // 指標 chips：出勤天數 / 跑步次數 / 平均配速
            HStack(spacing: 8) {
                heroMetric(title: NSLocalizedString("training_calendar.active_days_short", comment: "Active days"),
                           value: "\(monthlyActiveDays)")
                heroMetric(title: NSLocalizedString("training_calendar.runs_short", comment: "Runs"),
                           value: "\(monthlyWorkoutCount)")
                heroMetric(title: NSLocalizedString("training_calendar.average_pace_short", comment: "Average pace"),
                           value: averagePace)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PacerizColor.blue, PacerizColor.blueDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: PacerizColor.blue.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFont.systemScaled(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(value)
                .font(AppFont.systemScaled(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7).padding(.horizontal, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.18)))
    }

    // MARK: - 月統計

    private var monthlySummaryView: some View {
        let summaries = viewModel.monthlySummaries
        let featuredSummary = summaries.first

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
                        MonthlyRunningHeroCard(summary: featuredSummary)
                    }

                    MonthlyRunningTrendCard(summaries: summaries)

                    VStack(spacing: 8) {
                        ForEach(summaries) { summary in
                            MonthlyRunningSummaryRow(summary: summary)
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
                // 用 slot index 當 id（不要用 \.self）：daysInMonth 開頭有多個 nil 空白格，
                // 用 \.self 會讓多個 nil 共用同一個 id → ForEach diff 壞掉，導致月底最後幾天的
                // 格子拿不到資料（缺的天數 ≈ 開頭空白數-1，所以總是月底那幾天空白）。
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
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
        let calendar = displayCalendar

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

        // 依「日 → 顯示訓練類型」聚合（跑步用 run_type、非跑步用 activityType）。
        // 色源 = w.trainingType（= advancedMetrics.training_type，Task 0 實證）；取不到 → "easy"（D5）。
        let grouped = DayWorkoutAggregator.aggregate(workouts: monthWorkouts, calendar: calendar) { w in
            DayWorkoutAggregator.Input(
                startDate: w.startDate,
                activityType: w.activityType,
                displayTrainingType: w.trainingType,
                distanceMeters: w.distance ?? 0,
                duration: w.duration
            )
        }

        workoutsByDate = grouped

        print("📅 日曆數據處理完成：\(selectedMonth) 共 \(monthWorkouts.count) 筆記錄")
    }

    // MARK: - Helper Functions

    /// 與 DateFormatterHelper.monthRange 同一套時區的 calendar。
    /// 修正：原本格子/分組 key 用 Calendar.current（裝置時區），但 monthRange（總距離/出勤計算）
    /// 用「使用者時區偏好」。兩者不一致時，月底跨日的訓練會被算進 hero（出勤 25）卻對不到格子（只畫 22 天）。
    /// 統一成同一時區後，格子 key、daysInMonth、範圍過濾三者一致。
    private var displayCalendar: Calendar {
        var calendar = Calendar.current
        if let userTimezone = UserPreferencesManager.shared.timezonePreference,
           let tz = TimeZone(identifier: userTimezone) {
            calendar.timeZone = tz
        }
        return calendar
    }

    private func normalizeDate(_ date: Date) -> Date {
        return displayCalendar.startOfDay(for: date)
    }

    private var daysInMonth: [Date?] {
        let calendar = displayCalendar
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

struct DayTypeBreakdown: Identifiable {
    let id = UUID()
    let activityType: String     // 給 icon（running/cycling/strength…）
    let displayType: String      // 給 bucket：跑步=run_type、非跑步=activityType
    let distanceKm: Double
    let count: Int
    var isRunning: Bool {
        let t = activityType.lowercased()
        return t == "running" || t == "run"
    }
    var bucket: CalendarTypeBucket { calendarBucket(for: displayType) }
}

struct DayWorkoutInfo {
    var totalDistance: Double      // 當日跨類型總距離（km）
    var totalDuration: TimeInterval
    var primaryType: String        // 距離最長的類型
    var primaryDistance: Double?
    var workoutCount: Int          // 當日總筆數（跨類型）
    var runningDistanceKm: Double  // 當日跑步距離（heatmap 分級 + 距離數字用，與 hero 月距離口徑一致）
    var breakdown: [DayTypeBreakdown]  // 各類型 (距離, 筆數)，跑步優先排序
}

/// 純聚合：把完成運動依「日 → 顯示訓練類型」累計成 DayWorkoutInfo。可單測。
/// 顯示訓練類型：跑步用 run_type（取不到→"easy"，spec D5）；非跑步用 activityType。
enum DayWorkoutAggregator {
    /// 抽象輸入，讓單測不必建完整 WorkoutV2。
    struct Input {
        let startDate: Date
        let activityType: String
        let displayTrainingType: String?
        let distanceMeters: Double
        let duration: TimeInterval
    }

    static func aggregate<W>(
        workouts: [W],
        calendar: Calendar,
        map: (W) -> Input
    ) -> [TimeInterval: DayWorkoutInfo] {
        // day -> displayType -> (dist, count, activity)
        var perDayType: [TimeInterval: [String: (dist: Double, count: Int, activity: String)]] = [:]
        var perDayDuration: [TimeInterval: TimeInterval] = [:]

        for w in workouts {
            let i = map(w)
            let activity = i.activityType.lowercased()
            guard activity != "rest" else { continue }
            let isRun = activity == "running" || activity == "run"
            let runType = i.displayTrainingType?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            // 顯示訓練類型 = 分組 key
            let key: String = isRun ? (runType.isEmpty ? "easy" : runType) : activity
            let dayKey = calendar.startOfDay(for: i.startDate).timeIntervalSince1970
            var typeMap = perDayType[dayKey] ?? [:]
            let cur = typeMap[key] ?? (0, 0, activity)
            typeMap[key] = (cur.dist + i.distanceMeters / 1000.0, cur.count + 1, activity)
            perDayType[dayKey] = typeMap
            perDayDuration[dayKey, default: 0] += i.duration
        }

        var grouped: [TimeInterval: DayWorkoutInfo] = [:]
        for (dayKey, typeMap) in perDayType {
            // breakdown：跑步永遠排第一，其餘按距離降序
            let breakdown = typeMap
                .map { (key, v) in
                    DayTypeBreakdown(activityType: v.activity, displayType: key,
                                     distanceKm: v.dist, count: v.count)
                }
                .sorted { a, b in
                    if a.isRunning != b.isRunning { return a.isRunning }
                    return a.distanceKm > b.distanceKm
                }
            guard let primary = breakdown.max(by: { $0.distanceKm < $1.distanceKm }) else { continue }
            grouped[dayKey] = DayWorkoutInfo(
                totalDistance: breakdown.reduce(0) { $0 + $1.distanceKm },
                totalDuration: perDayDuration[dayKey] ?? 0,
                primaryType: primary.activityType,
                primaryDistance: primary.distanceKm,
                workoutCount: breakdown.reduce(0) { $0 + $1.count },
                runningDistanceKm: breakdown.first(where: { $0.isRunning })?.distanceKm ?? 0,
                breakdown: breakdown
            )
        }
        return grouped
    }

    /// 薄重載：測試直接傳 [Input]。
    static func aggregate(workouts: [Input], calendar: Calendar) -> [TimeInterval: DayWorkoutInfo] {
        aggregate(workouts: workouts, calendar: calendar) { $0 }
    }
}

// MARK: - Monthly Summary Row

private struct MonthlyRunningSummaryRow: View {
    let summary: MonthlyRunningSummary
    private let accentColor = PacerizTokens.color.brand.primary

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
                    .foregroundColor(accentColor)

                Text(yearText)
                    .font(AppFont.systemScaled(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.12))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(monthTitle)
                    .font(AppFont.systemScaled(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Text(String(format: NSLocalizedString("training_calendar.run_count_format", comment: "Run count"), summary.workoutCount))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
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
    private let accentColor = PacerizTokens.color.brand.primary

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

    private var averageDistancePerRunText: String {
        guard summary.workoutCount > 0 else { return "--" }
        let averageKm = summary.totalDistanceKm / Double(summary.workoutCount)
        let converted = UnitManager.shared.convertedDistance(averageKm)
        let unit = UnitManager.shared.currentUnitSystem.distanceSuffix
        return "\(String(format: "%.1f", converted)) \(unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(monthTitle)
                        .font(AppFont.systemScaled(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))

                    Text(NSLocalizedString("training_calendar.hero_caption", comment: "Monthly running recap"))
                        .font(AppFont.caption())
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("training_plan.monthly_total_distance", comment: "Monthly Total Distance"))
                    .font(AppFont.caption())
                    .foregroundColor(.white.opacity(0.72))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(distanceValue)
                        .font(AppFont.systemScaled(size: 46, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.78)

                    Text(distanceUnit)
                        .font(AppFont.systemScaled(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))
                }
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
                    title: NSLocalizedString("training_calendar.avg_distance_short", comment: "Average distance per run"),
                    value: averageDistancePerRunText
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PacerizColor.blue, PacerizColor.blueDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: PacerizColor.blue.opacity(0.25), radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .combine)
    }

    private func heroMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.systemScaled(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
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
                .fill(Color.white.opacity(0.14))
        )
    }
}

private struct MonthlyRunningTrendCard: View {
    let summaries: [MonthlyRunningSummary]
    private let chartHeight: CGFloat = 92
    private let accentColor = PacerizTokens.color.brand.primary

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
                                .fill(accentColor)
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

    private var emptyFill: Color { colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.97) }

    // 有訓練的日子用極淡品牌藍底（只區分「有/無訓練」，不編碼跑量 → 不需要圖例）；空白日近乎透明。
    private var backgroundColor: Color {
        workoutInfo == nil ? emptyFill : PacerizColor.blue.opacity(0.06)
    }

    private func distanceText(_ km: Double) -> String {
        let v = UnitManager.shared.convertedDistance(km)
        // 格子窄：≥10 去小數（22 而非 22.0）省寬度，避免長距離被截斷
        return v >= 10 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 0) {
                dayNumberView
                Spacer(minLength: 0)
            }

            // 直接列出當日各運動：[類型 icon] [距離]（icon 形狀本身就說明是哪種運動，免圖例）
            if let info = workoutInfo {
                ForEach(info.breakdown.prefix(2)) { b in
                    workoutRow(b)
                }
                if info.breakdown.count > 2 {
                    Text("+\(info.breakdown.count - 2)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 70)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // 一筆「運動 icon + 距離 (+×N)」—— 直接、不需解碼
    @ViewBuilder
    private func workoutRow(_ b: DayTypeBreakdown) -> some View {
        HStack(spacing: 1.5) {
            Image(systemName: isCalendarIntervalType(b.displayType)
                    ? "stopwatch.fill"                          // 間歇家族：碼錶，與閾值/節奏的跑者 icon 區分
                    : ActivityTypeStyleHelper.icon(for: b.activityType))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(b.bucket.deepColor)            // 依訓練類型深色（取代 activityType 4 色）
                .frame(width: 11, alignment: .center)
            if b.distanceKm > 0.01 {
                Text(distanceText(b.distanceKm))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(b.bucket.deepColor)        // 數字也上深色（D3 可讀），原為 .primary
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            Spacer(minLength: 0)
        }
    }

    // 日期數字：今天 = 白字 + 品牌藍圓底（系統日曆式「今天」訊號）
    // 用固定字級 + fixedSize，避免動態字級把數字撐爆固定框 → 顯示成「…」。
    private var dayNumberView: some View {
        Text(dayNumber)
            .font(.system(size: 12, weight: isToday ? .bold : .semibold))
            .foregroundColor(isToday ? .white : (workoutInfo == nil ? .secondary : .primary))
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 18, minHeight: 18)
            .background(
                Group { if isToday { Circle().fill(PacerizColor.blue) } }
            )
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
