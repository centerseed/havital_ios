import Foundation

// MARK: - App2PlanViewModel
/// Presentation Layer — 2.0 課表頁（`DESIGN-app2-decision-chain-api.md` §3.3）。
///
/// 週目標量／每日安排來自 `GET /v2/plan/weekly/{plan_id}`；**已完成量不在該 payload 裡**
/// （§3.3 第 2 列），要另外從 `GET /v2/workouts` 的本週紀錄合併計算。
@MainActor
final class App2PlanViewModel: ObservableObject, TaskManageable {

    @Published private(set) var isLoading = true
    @Published private(set) var week: App2Sourced<App2PlanWeek>?

    nonisolated let taskRegistry = TaskRegistry()

    private let planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol
    private let workoutRepository: WorkoutRepository

    init(
        planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol? = nil,
        workoutRepository: WorkoutRepository? = nil
    ) {
        let container = DependencyContainer.shared
        self.planV2DataSource = planV2DataSource ?? TrainingPlanV2RemoteDataSource()

        if let workoutRepository {
            self.workoutRepository = workoutRepository
        } else {
            if !container.isRegistered(WorkoutRepository.self) {
                container.registerWorkoutModule()
            }
            self.workoutRepository = container.resolve() as WorkoutRepository
        }
    }

    deinit {
        cancelAllTasks()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await planV2DataSource.getPlanStatus()
            guard let planId = status.currentWeekPlanId else {
                Logger.debug("[App2PlanVM] 本週尚無課表 (next_action=\(status.nextAction)),退樣本")
                week = App2Sourced(
                    App2StubFixtures.planWeek,
                    origin: .stub(pendingSection: App2StubFixtures.Section.offline)
                )
                return
            }

            let dto = try await planV2DataSource.getWeeklyPlan(planId: planId)
            let completed = await completedDistanceKmThisWeek()

            week = App2Sourced(
                map(dto: dto, planStatus: status, completedKm: completed),
                origin: .live(endpoint: "GET /v2/plan/weekly/{plan_id} + GET /v2/workouts")
            )
        } catch {
            Logger.debug("[App2PlanVM] 週課表取得失敗,退樣本: \(error)")
            week = App2Sourced(
                App2StubFixtures.planWeek,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
    }

    // MARK: - Mapping

    private func map(
        dto: WeeklyPlanV2DTO,
        planStatus: PlanStatusV2Response,
        completedKm: Double?
    ) -> App2PlanWeek {
        let weekNumber = dto.weekOfTraining ?? dto.weekOfPlan ?? planStatus.currentWeek
        let climateByDayIndex = Dictionary(
            (dto.climate ?? []).map { ($0.dayIndex, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let todayIndex = Self.todayDayIndex()

        let days: [App2PlanDay] = dto.days.map { day in
            // 沒有 primary activity ＝ 休息日。
            let isRest = day.primary == nil
            return App2PlanDay(
                id: day.dayIndex,
                weekdayLabel: Self.weekdayLabel(dayIndex: day.dayIndex),
                tag: isRest
                    ? L10n.App2.Plan.rest.localized
                    : (Self.runTypeLabel(day.primary) ?? day.category ?? day.dayTarget),
                summary: day.dayTarget,
                planned: Self.plannedDistanceLabel(day.primary),
                // 實際值要按日期對齊 workouts；骨架階段僅在週總量層合併（見 completedKm）。
                actual: nil,
                temp: Self.temperatureLabel(climateByDayIndex[day.dayIndex]),
                isToday: day.dayIndex == todayIndex
            )
        }

        return App2PlanWeek(
            weekLabel: String(weekNumber),
            totalWeeks: dto.totalWeeks ?? planStatus.totalWeeks,
            targetDistanceKm: dto.totalDistance,
            completedDistanceKm: completedKm,
            purpose: dto.coachNote ?? dto.purpose,
            intensityLowMinutes: dto.intensityTotalMinutes.map { Int($0.low.rounded()) },
            intensityMediumMinutes: dto.intensityTotalMinutes.map { Int($0.medium.rounded()) },
            intensityHighMinutes: dto.intensityTotalMinutes.map { Int($0.high.rounded()) },
            days: days
        )
    }

    private func completedDistanceKmThisWeek() async -> Double? {
        let calendar = Calendar.current
        let now = Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let workouts = await workoutRepository.getWorkoutsInDateRangeAsync(
            startDate: interval.start,
            endDate: now
        )
        guard !workouts.isEmpty else { return nil }
        let meters = workouts
            .filter { $0.activityType.lowercased().contains("run") }
            .compactMap(\.distanceMeters)
            .reduce(0, +)
        return meters / 1000
    }

    // MARK: - Formatting

    /// `day_index` 0 = 週一（與週課表 doc 的週一起算一致）。
    private static func weekdayLabel(dayIndex: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        // shortWeekdaySymbols[0] 是週日；day_index 0 是週一 → 位移 1。
        let index = (dayIndex + 1) % 7
        return symbols.indices.contains(index) ? symbols[index] : "—"
    }

    private static func todayDayIndex() -> Int {
        // Calendar.weekday: 1 = 週日 … 7 = 週六；day_index 0 = 週一。
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private static func plannedDistanceLabel(_ primary: PrimaryActivityDTO?) -> String? {
        guard case .run(let run) = primary, let km = run.distanceKm, km > 0 else { return nil }
        return String(format: "%.1f km", km)
    }

    /// 課型標籤取 `run_type`；肌力／交叉訓練沒有跑步課型，回 nil 讓 caller 退到 `category`。
    private static func runTypeLabel(_ primary: PrimaryActivityDTO?) -> String? {
        guard case .run(let run) = primary else { return nil }
        return run.runType.isEmpty ? nil : run.runType
    }

    private static func temperatureLabel(_ climate: ClimateDayDTO?) -> String? {
        guard let climate else { return nil }
        return String(format: "%.0f°C", climate.feelsLikeTempC)
    }
}
