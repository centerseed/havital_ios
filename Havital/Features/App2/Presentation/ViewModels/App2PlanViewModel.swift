import Foundation

// MARK: - App2PlanViewModel
/// Presentation Layer — 2.0 課表頁（`DESIGN-app2-decision-chain-api.md` §3.3）。
///
/// 週目標量／每日安排來自 `GET /v2/plan/weekly/{plan_id}`；**已完成量不在該 payload 裡**
/// （§3.3 第 2 列），要另外從 `GET /v2/workouts` 的本週紀錄合併計算。
@MainActor
final class App2PlanViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var week: App2Sourced<App2PlanWeek>?
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

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
        isLoading = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
            lastLoadedAt = Date()
        }

        do {
            let status = try await planV2DataSource.getPlanStatus()
            guard let planId = status.currentWeekPlanId else {
                Logger.debug("[App2PlanVM] 本週尚無課表 (next_action=\(status.nextAction)),退樣本")
                guard week == nil else { return }   // SWR：重驗失敗時保留舊資料
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
            guard week == nil else { return }       // SWR：重驗失敗時保留舊資料
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
            let dayType = isRest ? DayType.rest : Self.dayType(day.primary)
            return App2PlanDay(
                id: day.dayIndex,
                weekdayLabel: Self.weekdayLabel(dayIndex: day.dayIndex),
                // 課型顯示字走既有的 `DayType.localizedName`（三語已齊），
                // 不再把後端的 `run_type` 識別字（`easy`／`lsd`）直接印到畫面上。
                tag: dayType?.localizedName
                    ?? (isRest ? L10n.App2.Plan.rest.localized : (day.category ?? day.dayTarget)),
                dayType: dayType,
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

    /// `day_index` **1 = 週一 … 7 = 週日**。
    ///
    /// 原本這裡當成 0-based（`(dayIndex + 1) % 7`），星期與「今天」整整差一天。
    /// 2026-08-25 對 dev 的真實 payload 確認：`day_index: 2` 的 `reason` 寫的是
    /// 「週二安排長距離慢跑」，所以 1 = 週一。
    static func weekdayLabel(dayIndex: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        // shortWeekdaySymbols[0] 是週日；day_index 7（週日）→ 0，1…6 → 1…6。
        let index = dayIndex % 7
        return symbols.indices.contains(index) ? symbols[index] : "—"
    }

    /// 今天的 `day_index`（1 = 週一 … 7 = 週日）。
    static func todayDayIndex() -> Int {
        // Calendar.weekday: 1 = 週日 … 7 = 週六。
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    static func plannedDistanceLabel(_ primary: PrimaryActivityDTO?) -> String? {
        guard case .run(let run) = primary, let km = run.distanceKm, km > 0 else { return nil }
        return String(format: "%.1f km", km)
    }

    /// `run_type` → 既有的 `DayType`。肌力／交叉訓練沒有跑步課型，各自映到對應的 case。
    static func dayType(_ primary: PrimaryActivityDTO?) -> DayType? {
        switch primary {
        case .run(let run):
            return DayType(rawValue: run.runType.lowercased())
        case .strength:
            return .strength
        case .cross:
            return .crossTraining
        case .none:
            return .rest
        @unknown default:
            return nil
        }
    }

    /// 「課表」那一行的結構化內容（設計 frame-00 今日課表卡、frame-01 每日卡）。
    ///
    /// 全部從 payload 的結構欄位組出來，沒有一個字是編的：
    /// - 有間歇段 → `6 × 200m · 5:25/km · 組間 90 秒`
    /// - 一般跑   → `9.0 km · 7:55/km`
    /// 兩者都拿不到 → nil（畫面就不顯示這一行，不用 placeholder 充數）。
    static func contentLine(_ primary: PrimaryActivityDTO?) -> String? {
        guard case .run(let run) = primary else { return nil }

        if let interval = run.segments?.first(where: { $0.kind == "interval" }),
           let repeats = interval.repeats, repeats > 0 {
            var parts: [String] = []
            if let metres = interval.work?.distanceM ?? interval.distanceM {
                parts.append("\(repeats) × \(metres)m")
            } else if let minutes = interval.work?.durationMinutes {
                parts.append("\(repeats) × \(minutes) min")
            } else {
                parts.append("× \(repeats)")
            }
            if let pace = interval.work?.pace ?? interval.pace {
                parts.append("\(pace)/km")
            }
            if let seconds = interval.recovery?.durationSeconds {
                parts.append(String(format: L10n.App2.Home.recoverySeconds.localized, seconds))
            } else if let metres = interval.recovery?.distanceM {
                parts.append(String(format: L10n.App2.Home.recoveryMetres.localized, metres))
            }
            return parts.joined(separator: " · ")
        }

        var parts: [String] = []
        if let km = run.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let minutes = run.durationMinutes {
            parts.append("\(minutes) min")
        }
        if let pace = run.climateAdjustedPace ?? run.pace {
            parts.append("\(pace)/km")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 強度徽章。只有 payload 真的帶 `target_intensity` 才顯示 —— 沒有就不顯示，
    /// 不從課型自己推一個出來。
    static func intensityLabel(_ primary: PrimaryActivityDTO?) -> String? {
        guard case .run(let run) = primary, let raw = run.targetIntensity else { return nil }
        switch raw.lowercased() {
        case "low":    return L10n.App2.Plan.intensityLow.localized
        case "medium": return L10n.App2.Plan.intensityMedium.localized
        case "high":   return L10n.App2.Plan.intensityHigh.localized
        default:       return nil
        }
    }

    private static func temperatureLabel(_ climate: ClimateDayDTO?) -> String? {
        guard let climate else { return nil }
        return String(format: "%.0f°C", climate.feelsLikeTempC)
    }
}
