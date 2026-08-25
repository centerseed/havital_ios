import Foundation

// MARK: - App2PlanOverviewViewModel
/// Presentation Layer — 2.0 訓練計畫總覽（設計 **frame-20**）。
///
/// **不是第二份計畫總覽邏輯。** 1.x 已經有 `TrainingOverviewV2View` ＋ `PhaseRoadmapView`
/// 在畫同一份 `training_stages`，但那是 1.x 的視覺與導航樹；2.0 只換版面，資料仍走
/// 同一組既有出口（`TrainingPlanV2RemoteDataSource` / `TargetRepository` /
/// `UserProfileRepository` / readiness），沒有新的 HTTP 路徑。
///
/// **週次／期別／賽事一律同源。** 週次來自 `GET /v2/plan/status`，期程來自它
/// `current_week_plan_id` 前綴所綁定的那一份 overview（`GET /v2/plan/overview` 拿回來
/// 先過 `App2HomeViewModel.isOverview(_:boundTo:)` 比對，**不是「最新的 overview」**）。
/// 綁不上就整段期程不顯示、畫面說明原因 —— 這條規則與首頁目標卡的期別膠囊是同一支。
///
/// 其餘欄位各自走既有出口：
///
/// | 畫面欄位 | 來源 |
/// |---|---|
/// | 目標賽事名／日期／距離／目標成績 | `TargetRepository`（`GET /user/targets`） |
/// | 「現在的你」完賽預估 | `TrainingReadinessViewModel.estimatedRaceTime`（`GET /plan/readiness/{date}`） |
/// | 「約 N km / 週」 | `WeeklySummaryService.fetchAllWeeklyVolumes`（`GET /summary/weekly/all`） |
/// | 每週跑步天數／長跑日 | `UserProfileRepository` 的 `prefer_week_days` / `prefer_week_days_longrun` |
/// | 訓練方法名 | overview 的 `methodology_overview.name`（後端已在地化） |
@MainActor
final class App2PlanOverviewViewModel: ObservableObject, TaskManageable, App2Revalidating {

    // MARK: - Published

    @Published private(set) var isLoading = true
    @Published private(set) var overview: App2Sourced<App2PlanOverview>?
    /// overview 拿到了但與本週課表不同源 —— 期程整段不顯示，畫面上要說明原因。
    /// 讀取失敗不算（那時不宣稱「不同源」，只是沒有期程）。
    @Published private(set) var stagesUnbound = false

    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol
    private let targetRepository: TargetRepository
    private let userProfileRepository: UserProfileRepository
    private let readinessViewModel: TrainingReadinessViewModel
    /// 近幾週的實際週跑量。既有出口是 `WeeklySummaryService`（singleton），
    /// 包成 closure 讓測試塞值 —— 不新增第二條 HTTP 路徑。
    private let weeklyVolumesLoader: () async -> [WeeklySummaryItem]

    // MARK: - Init

    init(
        planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol? = nil,
        targetRepository: TargetRepository? = nil,
        userProfileRepository: UserProfileRepository? = nil,
        readinessViewModel: TrainingReadinessViewModel? = nil,
        weeklyVolumesLoader: (() async -> [WeeklySummaryItem])? = nil
    ) {
        let container = DependencyContainer.shared

        self.planV2DataSource = planV2DataSource ?? TrainingPlanV2RemoteDataSource()

        if let targetRepository {
            self.targetRepository = targetRepository
        } else {
            if !container.isRegistered(TargetRepository.self) {
                container.registerTargetModule()
            }
            self.targetRepository = container.resolve() as TargetRepository
        }

        if let userProfileRepository {
            self.userProfileRepository = userProfileRepository
        } else {
            if !container.isRegistered(UserProfileRepository.self) {
                container.registerUserProfileModule()
            }
            self.userProfileRepository = container.resolve() as UserProfileRepository
        }

        self.readinessViewModel = readinessViewModel ?? TrainingReadinessViewModel()
        self.weeklyVolumesLoader = weeklyVolumesLoader ?? {
            do {
                // `/summary/weekly/` 這條在 dev 上回空陣列；帶跑量的是 `/summary/weekly/all`
                // （2026-08-25 對創辦人 dev 帳號實測），所以用既有 service 的這一支。
                return try await WeeklySummaryService.shared.fetchAllWeeklyVolumes(limit: 8)
            } catch {
                Logger.debug("[App2PlanOverviewVM] 週跑量歷史取得失敗: \(error)")
                return []
            }
        }
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func revalidate() async {
        isLoading = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
            lastLoadedAt = Date()
        }

        // 週次是這一頁的骨幹：沒有 plan status 就沒有「第 N / M 週」，也綁不了 overview。
        let planStatus = try? await planV2DataSource.getPlanStatus()

        async let stagesTask = loadStages(planStatus: planStatus)
        async let mainTargetTask = loadMainTarget()
        async let estimateTask = loadEstimatedFinish()
        async let weeklyTask = weeklyVolumesLoader()
        async let rhythmTask = loadRhythmPreferences()

        let (stageBundle, mainTarget, estimate, weeklyItems, preferences) =
            await (stagesTask, mainTargetTask, estimateTask, weeklyTask, rhythmTask)

        stagesUnbound = stageBundle.isUnbound

        overview = App2Sourced(
            Self.project(
                planStatus: planStatus,
                mainTarget: mainTarget,
                stages: stageBundle.stages,
                methodologyName: stageBundle.methodologyName,
                estimatedFinish: estimate,
                weeklyVolumes: weeklyItems,
                preferWeekDays: preferences.days,
                longRunWeekday: preferences.longRun
            ),
            origin: .live(
                endpoint: "GET /v2/plan/status + GET /v2/plan/overview + GET /user/targets"
                    + " + GET /plan/readiness/{date} + GET /summary/weekly/all + GET /user"
            )
        )
    }

    /// 期程 ＋ 訓練方法名 —— 兩者住在同一份 overview，一次取。
    private struct StageBundle {
        var stages: [TrainingStageDTO] = []
        var methodologyName: String?
        var isUnbound = false
    }

    private func loadStages(planStatus: PlanStatusV2Response?) async -> StageBundle {
        guard let planStatus else { return StageBundle() }
        do {
            let dto = try await planV2DataSource.getOverview()
            guard App2HomeViewModel.isOverview(dto.id, boundTo: planStatus) else {
                Logger.debug("[App2PlanOverviewVM] overview 與本週課表不同源,期程不顯示")
                return StageBundle(isUnbound: true)
            }
            return StageBundle(
                stages: dto.trainingStages ?? [],
                methodologyName: dto.methodologyOverview?.name
            )
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2PlanOverviewVM] overview 取得失敗: \(error)")
            }
            return StageBundle()
        }
    }

    private func loadMainTarget() async -> Target? {
        // 冷啟時本機快取是空的（同 `App2HomeViewModel.loadGoalCard` 的註解），
        // 先走 dual-track 的 `getTargets()` 把快取填起來，不新增第二條路。
        do {
            _ = try await targetRepository.getTargets()
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2PlanOverviewVM] targets 取得失敗,改讀既有快取: \(error)")
            }
        }
        return await targetRepository.getMainTarget()
    }

    private func loadEstimatedFinish() async -> String? {
        await readinessViewModel.loadData()
        return readinessViewModel.estimatedRaceTime
    }

    private func loadRhythmPreferences() async -> (days: [Int]?, longRun: Int?) {
        do {
            let user = try await userProfileRepository.getUserProfile()
            return (user.preferWeekDays, user.preferWeekDaysLongrun?.first)
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2PlanOverviewVM] 訓練日偏好取得失敗: \(error)")
            }
            return (nil, nil)
        }
    }

    #if DEBUG
    /// 測試／預覽用：直接填投影結果，不打網路。
    func applyForTesting(overview: App2Sourced<App2PlanOverview>?, stagesUnbound: Bool = false) {
        self.overview = overview
        self.stagesUnbound = stagesUnbound
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - 投影（純函式，可單獨測）

    static func project(
        planStatus: PlanStatusV2Response?,
        mainTarget: Target?,
        stages: [TrainingStageDTO],
        methodologyName: String?,
        estimatedFinish: String?,
        weeklyVolumes: [WeeklySummaryItem],
        preferWeekDays: [Int]?,
        longRunWeekday: Int?,
        now: Date = Date()
    ) -> App2PlanOverview {
        let currentWeek = planStatus?.currentWeek
        // 總週數以 plan status 為準；沒有才退目標賽事自己的訓練週數。
        let totalWeeks = planStatus?.totalWeeks
            ?? mainTarget.flatMap { $0.trainingWeeks > 0 ? $0.trainingWeeks : nil }

        let projectedStages = Self.stages(stages, currentWeek: currentWeek)

        return App2PlanOverview(
            raceName: mainTarget?.name,
            raceDateLabel: mainTarget.map {
                Self.localDateString(fromEpochSeconds: $0.raceDate, timezone: $0.timezone)
            },
            distanceLabel: mainTarget.map {
                App2OnboardingFormat.distanceLabel(km: Double($0.distanceKm))
            },
            weeksUntilRace: mainTarget.flatMap {
                Self.weeksUntil(epochSeconds: $0.raceDate, now: now)
            },
            currentEstimatedFinish: estimatedFinish,
            currentWeeklyKm: Self.averageWeeklyKm(weeklyVolumes, now: now),
            targetTime: mainTarget.flatMap {
                $0.targetTime > 0 ? App2OnboardingFormat.duration($0.targetTime) : nil
            },
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            currentStageName: projectedStages.first(where: { $0.state == .active })?.name,
            stages: projectedStages,
            rhythm: App2PlanRhythm(
                runDaysPerWeek: preferWeekDays.flatMap { $0.isEmpty ? nil : $0.count },
                longRunDayLabel: longRunWeekday.flatMap {
                    let label = App2OnboardingFormat.weekdayFull($0)
                    return label.isEmpty ? nil : label
                },
                methodologyName: methodologyName
            )
        )
    }

    /// `training_stages[]` → 畫面上的期程列。
    ///
    /// 狀態只看週次落點：當前週在區間內＝進行中，整段在當前週之前＝已完成，其餘＝待進行。
    /// **沒有當前週就沒有狀態可判** —— 那時每一段都是「待進行」，不猜第一段正在跑。
    static func stages(_ dtos: [TrainingStageDTO], currentWeek: Int?) -> [App2PlanStage] {
        dtos.map { dto in
            let state: App2PlanStage.State
            var weeksElapsed: Int?
            if let currentWeek {
                if currentWeek > dto.weekEnd {
                    state = .done
                } else if currentWeek >= dto.weekStart {
                    state = .active
                    weeksElapsed = currentWeek - dto.weekStart + 1
                } else {
                    state = .upcoming
                }
            } else {
                state = .upcoming
            }

            let focus = dto.trainingFocus.trimmingCharacters(in: .whitespacesAndNewlines)
            return App2PlanStage(
                id: dto.stageId,
                name: dto.stageName,
                focus: focus.isEmpty ? nil : focus,
                weekStart: dto.weekStart,
                weekEnd: dto.weekEnd,
                state: state,
                weeksElapsed: weeksElapsed
            )
        }
    }

    /// 「約 N km / 週」＝**最近 4 個已結束的週**的實際跑量平均。
    ///
    /// 兩個決定寫在這裡，不散在呼叫端：
    /// - **當週不算**：週三看到的「本週 5 km」不是這個人的週量水準，會把平均拉垮。
    /// - **0 的週照算**：那幾週真的沒跑，濾掉會把平均灌高。全部都是 0 或沒資料 → nil，
    ///   畫面整格不顯示，不印 `0 km / 週`。
    ///
    /// payload（`/summary/weekly/all`）是新到舊，但這裡不靠它的順序 —— 用
    /// `week_start_timestamp` 自己排，順序換了也不會靜靜地取到最舊的四週。
    static func averageWeeklyKm(_ items: [WeeklySummaryItem], now: Date = Date()) -> Double? {
        let currentWeekStart = App2PlanViewModel.currentWeekStart(reference: now)
        let completed = items
            .filter { item in
                guard let timestamp = item.weekStartTimestamp else { return true }
                return Date(timeIntervalSince1970: timestamp) < currentWeekStart
            }
            .sorted { ($0.weekStartTimestamp ?? 0) > ($1.weekStartTimestamp ?? 0) }
            .prefix(4)
            .map { $0.distanceKm ?? 0 }

        guard !completed.isEmpty, completed.contains(where: { $0 > 0 }) else { return nil }
        return completed.reduce(0, +) / Double(completed.count)
    }

    /// 距離賽事還有幾週（無條件進位）。已過期回 nil —— 不顯示負週數。
    static func weeksUntil(epochSeconds: Int, now: Date = Date()) -> Int? {
        let raceDate = Date(timeIntervalSince1970: TimeInterval(epochSeconds))
        let days = Calendar.current.dateComponents([.day], from: now, to: raceDate).day ?? 0
        guard days >= 0 else { return nil }
        return max(1, Int(ceil(Double(days) / 7.0)))
    }

    /// 賽事日期以賽事時區顯示（數字 timestamp 是 UTC，`YYYY-MM-DD` 是當地日期）。
    static func localDateString(fromEpochSeconds seconds: Int, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}
