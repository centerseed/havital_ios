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

    // MARK: - 更換訓練方法（2026-08-27 晚走查裁決（e））

    /// 可選的方法論。**只有取得 overview 之後才有值**（要用它的 `target_type` 過濾）。
    @Published private(set) var methodologies: [MethodologyV2] = []
    @Published private(set) var isChangingMethodology = false
    /// 換成功了 —— 畫面上出一行小字說「週課表下週依新方法產生」。
    @Published private(set) var didChangeMethodology = false
    /// 換失敗的訊息。**失敗不改變現值**（畫面上的方法名仍是舊的）。
    @Published var methodologyError: String?

    /// 更換方法論要打在哪一份 overview 上。取不到就沒有這一列。
    private(set) var overviewId: String?
    private(set) var targetType: String?

    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?
    /// 這一輪的子載入是否吃到取消（-999 取消錯誤不設 `Task.isCancelled`）。
    /// 有＝整輪作廢：不發布、不標載過（外審第七輪 E03）。
    private var roundSawCancellation = false
    /// revalidate 的同輪互斥：兩輪並發會在 await 點交錯共用取消旗標與完成標記。
    private var isRevalidating = false
    /// 這一輪重驗的起點（判卡死用，見 revalidate 開頭）。
    private var revalidateBegan: Date?

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    /// **課表資料只有這一個入口**（2026-08-26 架構收斂）。
    private let planRepository: TrainingPlanV2Repository
    private let targetRepository: TargetRepository
    private let userProfileRepository: UserProfileRepository
    private let readinessViewModel: TrainingReadinessViewModel
    /// 近幾週的實際週跑量。既有出口是 `WeeklySummaryService`（singleton），
    /// 包成 closure 讓測試塞值 —— 不新增第二條 HTTP 路徑。
    private let weeklyVolumesLoader: (() async -> [WeeklySummaryItem])?

    // MARK: - Init

    init(
        planRepository: TrainingPlanV2Repository? = nil,
        targetRepository: TargetRepository? = nil,
        userProfileRepository: UserProfileRepository? = nil,
        readinessViewModel: TrainingReadinessViewModel? = nil,
        weeklyVolumesLoader: (() async -> [WeeklySummaryItem])? = nil
    ) {
        let container = DependencyContainer.shared

        if let planRepository {
            self.planRepository = planRepository
        } else {
            if !container.isRegistered(TrainingPlanV2Repository.self) {
                container.registerTrainingPlanV2Module()
            }
            self.planRepository = container.resolve() as TrainingPlanV2Repository
        }

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
        self.weeklyVolumesLoader = weeklyVolumesLoader
    }

    /// 週跑量歷史。取消要記進 `roundSawCancellation`（外審第八輪 E03），
    /// 所以預設實作是實例方法而不是 init 裡的 escaping 預設 closure。
    private func loadWeeklyVolumes() async -> [WeeklySummaryItem] {
        if let weeklyVolumesLoader { return await weeklyVolumesLoader() }
        do {
            // `/summary/weekly/` 這條在 dev 上回空陣列；帶跑量的是 `/summary/weekly/all`
            // （2026-08-25 對創辦人 dev 帳號實測），所以用既有 service 的這一支。
            return try await WeeklySummaryService.shared.fetchAllWeeklyVolumes(limit: 8)
        } catch {
            if error.isCancellationError {
                roundSawCancellation = true
            } else {
                Logger.debug("[App2PlanOverviewVM] 週跑量歷史取得失敗: \(error)")
            }
            return []
        }
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func revalidate() async {
        // 鎖是防重入，不是允許一輪卡住就永遠吞掉下拉刷新（T-0355，2026-08-31：
        // 推播已到、18:47–19:07 App 對後端零請求，重開 app 才恢復）。超過門檻
        // 視為前一輪卡死，讓位開新輪；卡死輪殘餘的 defer 只會提前放鎖，影響
        // 背景 SWR 的重入時機，資料發布仍在 MainActor 上序列化。
        if App2RevalidatePolicy.shouldBlock(isRevalidating: isRevalidating, began: revalidateBegan) {
            return
        }
        isRevalidating = true
        revalidateBegan = Date()
        defer { isRevalidating = false }

        isLoading = !hasLoaded
        roundSawCancellation = false
        var finishedRound = false
        defer {
            isLoading = false
            // 成功或**真失敗**才算載過；取消不標——task 取消與 -999 取消錯誤
            // （提早 return，finishedRound 維持 false）都算取消（2026-08-29 外審 D04/E03）。
            if finishedRound, !Task.isCancelled {
                hasLoaded = true
                lastLoadedAt = Date()
            }
        }

        // 週次是這一頁的骨幹：沒有 plan status 就沒有「第 N / M 週」，也綁不了 overview。
        let planStatus: PlanStatusV2Response?
        do {
            planStatus = try await planRepository.getPlanStatus(forceRefresh: true)
        } catch {
            // 取消（task 取消或 -999 取消錯誤）不算這一輪：不發布也不標載過。
            guard !error.isCancellationError else { return }
            planStatus = nil
        }

        async let stagesTask = loadStages(planStatus: planStatus)
        async let mainTargetTask = loadMainTarget()
        async let estimateTask = loadEstimatedFinish()
        async let weeklyTask = loadWeeklyVolumes()
        async let rhythmTask = loadRhythmPreferences()

        let (stageBundle, mainTarget, estimate, weeklyItems, preferences) =
            await (stagesTask, mainTargetTask, estimateTask, weeklyTask, rhythmTask)

        // planStatus 與各子載入都以 `try?`／可缺席語意收攏——取消也會被折成 nil。
        // 被取消的那一輪不得發布殘缺 overview（AGENTS.md 陷阱 5；2026-08-29 外審）。
        if Task.isCancelled || roundSawCancellation { return }
        finishedRound = true

        stagesUnbound = stageBundle.isUnbound

        overview = App2Sourced(
            Self.project(
                planStatus: planStatus,
                mainTarget: mainTarget,
                stages: stageBundle.stages,
                milestones: stageBundle.milestones,
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
        var stages: [TrainingStageV2] = []
        /// 里程碑與期程同住一份 overview，同一次取，不另打端點。
        var milestones: [MilestoneV2] = []
        var methodologyName: String?
        var isUnbound = false
    }

    private func loadStages(planStatus: PlanStatusV2Response?) async -> StageBundle {
        guard let planStatus else { return StageBundle() }
        do {
            let overview = try await planRepository.refreshOverview()
            // 更換方法論打在**目前這一份 overview** 上。
            //
            // **不同源時這個 id 仍然有效**：`isUnbound` 只代表本週課表比 overview 舊
            // （換過方法論或改過目標之後必然如此），不代表拿到了別人的計畫。
            // 這裡曾經在不同源時把 id 清掉，結果是換完方法論那一刻「更換訓練方法」
            // 整列消失、換不回來（2026-08-27 模擬器實測）。
            overviewId = overview.id
            targetType = overview.targetType
            guard App2HomeViewModel.isOverview(overview.id, boundTo: planStatus) else {
                Logger.debug("[App2PlanOverviewVM] overview 與本週課表不同源,期程不顯示")
                // **方法論名仍然要帶出來。** 不同源擋掉的是「第 N 週落在哪一段」
                // 這種綁週次的東西（stages／milestones）；訓練方法不綁週次，它就是
                // 這份 overview 現在用的方法，也正是「更換訓練方法」寫回去的那一份
                // （上面 `overviewId` 在不同源時同樣保留，理由相同）。
                // 之前一起清掉的後果：「更換訓練方法」列的值變空、sheet 裡目前那一項
                // 沒有勾（2026-08-28 走查 F10／D13-iOS）。
                return StageBundle(
                    methodologyName: overview.methodologyOverview?.name,
                    isUnbound: true
                )
            }
            return StageBundle(
                stages: overview.trainingStages,
                milestones: overview.milestones,
                methodologyName: overview.methodologyOverview?.name
            )
        } catch {
            if error.isCancellationError {
                roundSawCancellation = true
            } else {
                Logger.debug("[App2PlanOverviewVM] overview 取得失敗: \(error)")
            }
            return StageBundle()
        }
    }

    // MARK: - 更換訓練方法

    /// 可換的方法論清單（`GET /v2/methodologies`，依 `target_type` 過濾）。
    /// **1.4 在訓練總覽就能換，App2 漏接＝功能缺口**（2026-08-27 晚走查裁決（e））。
    func loadMethodologies() async {
        guard methodologies.isEmpty else { return }
        do {
            methodologies = try await planRepository.getMethodologies(targetType: targetType)
        } catch {
            if error.isCancellationError {
                roundSawCancellation = true
            } else {
                Logger.debug("[App2PlanOverviewVM] 方法論清單取得失敗: \(error)")
                methodologyError = error.toDomainError().localizedDescription
            }
        }
    }

    /// 換方法論。成功＝**重載 overview**（後端換完會重生），畫面上的方法名跟著變；
    /// 失敗不改變現值，只出錯誤訊息。
    ///
    /// 寫入路徑走既有的 `TrainingPlanV2Repository.updateOverview` —— 與 1.4 的
    /// `MethodologyCoordinator.changeMethodology` 同一條，不另開第二份。
    @discardableResult
    func changeMethodology(to methodologyId: String) async -> Bool {
        guard let overviewId, !isChangingMethodology else { return false }
        isChangingMethodology = true
        didChangeMethodology = false
        methodologyError = nil
        defer { isChangingMethodology = false }

        do {
            _ = try await planRepository.updateOverview(
                overviewId: overviewId,
                startFromStage: nil,
                methodologyId: methodologyId
            )
        } catch {
            let domainError = error.toDomainError()
            Logger.debug("[App2PlanOverviewVM] 更換方法論失敗: \(domainError)")
            methodologyError = domainError.localizedDescription
            return false
        }

        await forceRefresh()
        didChangeMethodology = true
        return true
    }

    func dismissMethodologyNotice() {
        didChangeMethodology = false
    }

    private func loadMainTarget() async -> Target? {
        // 冷啟時本機快取是空的（同 `App2HomeViewModel.loadGoalCard` 的註解），
        // 先走 dual-track 的 `getTargets()` 把快取填起來，不新增第二條路。
        do {
            _ = try await targetRepository.getTargets()
        } catch {
            if error.isCancellationError {
                roundSawCancellation = true
            } else {
                Logger.debug("[App2PlanOverviewVM] targets 取得失敗,改讀既有快取: \(error)")
            }
        }
        return await targetRepository.getMainTarget()
    }

    private func loadEstimatedFinish() async -> String? {
        // `loadData()` 是 cache-first：讀到舊快取就立刻返回、背景刷新落在投影
        // 組完**之後**——換了主賽事再進這一頁，「現在的你」永遠是上一場的預估
        // （2026-08-27 使用者實機回報：換半馬後預估沒跟著換）。這一頁要的是
        // 當下的預估，直接向 API 取。
        await readinessViewModel.refreshData()
        return readinessViewModel.estimatedRaceTime
    }

    private func loadRhythmPreferences() async -> (days: [Int]?, longRun: Int?) {
        do {
            let user = try await userProfileRepository.getUserProfile()
            return (user.preferWeekDays, user.preferWeekDaysLongrun?.first)
        } catch {
            if error.isCancellationError {
                roundSawCancellation = true
            } else {
                Logger.debug("[App2PlanOverviewVM] 訓練日偏好取得失敗: \(error)")
            }
            return (nil, nil)
        }
    }

    #if DEBUG
    /// 測試／預覽用：直接填投影結果，不打網路。
    func applyForTesting(
        overview: App2Sourced<App2PlanOverview>?,
        stagesUnbound: Bool = false,
        overviewId: String? = nil,
        methodologies: [MethodologyV2] = []
    ) {
        self.overview = overview
        self.stagesUnbound = stagesUnbound
        self.overviewId = overviewId
        self.methodologies = methodologies
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - 投影（純函式，可單獨測）

    static func project(
        planStatus: PlanStatusV2Response?,
        mainTarget: Target?,
        stages: [TrainingStageV2],
        milestones: [MilestoneV2] = [],
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
            milestones: Self.milestones(milestones),
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
    static func stages(_ dtos: [TrainingStageV2], currentWeek: Int?) -> [App2PlanStage] {
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

    /// `milestones[]` → 畫面上的里程碑列（2026-08-27 晚走查裁決（c））。
    ///
    /// 順序照週次；**標題空白的那一筆整筆丟掉** —— 沒有標題就沒有可讀的內容，
    /// 印一列空白比不印更糟。`description` 空白只是少一行小字，那一筆仍然留著。
    /// 文字本身後端已在地化，App 端不改寫也不補預設句。
    /// 同一週的多筆維持 payload 原順序（`Array.sorted` 不保證穩定，所以帶原索引比）。
    static func milestones(_ dtos: [MilestoneV2]) -> [App2PlanMilestone] {
        dtos
            .enumerated()
            .compactMap { index, dto -> (Int, App2PlanMilestone)? in
                let title = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                let description = dto.description.trimmingCharacters(in: .whitespacesAndNewlines)
                return (index, App2PlanMilestone(
                    week: dto.week,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    isKey: dto.isKeyMilestone
                ))
            }
            .sorted { lhs, rhs in
                lhs.1.week == rhs.1.week ? lhs.0 < rhs.0 : lhs.1.week < rhs.1.week
            }
            .map { $0.1 }
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
        let currentWeekStart = App2WeekCalendar.currentWeekStart(reference: now)
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

    /// 距離賽事還有幾**整**週（floor），與 Android `App2RaceProjections.weeksUntil` 同一算法：
    /// 賽事落在 7 天內（含當週）＝0 週（2026-08-29 D1 裁決）。已過期回 nil —— 不顯示負週數。
    static func weeksUntil(epochSeconds: Int, now: Date = Date()) -> Int? {
        let calendar = Calendar.current
        let raceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(epochSeconds)))
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0
        guard days >= 0 else { return nil }
        return days / 7
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
