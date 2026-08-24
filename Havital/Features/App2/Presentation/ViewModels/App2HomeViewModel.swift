import Combine
import Foundation

// MARK: - App2HomeViewModel
/// Presentation Layer — 2.0 首頁（`DESIGN-app2-decision-chain-api.md` §3.1／§3.1a）。
///
/// 每個區塊各自載入、各自失敗、各自標來源：一條端點掛掉不該讓整個首頁空白。
/// 拿不到真資料的區塊退到 `App2StubFixtures` 並把 origin 標成 stub，畫面掛徽章。
@MainActor
final class App2HomeViewModel: ObservableObject, TaskManageable {

    // MARK: - Published

    @Published private(set) var isLoading = true
    @Published private(set) var goalCard: App2Sourced<App2GoalCard>?
    @Published private(set) var trainingStatus: App2Sourced<App2TrainingStatus>?
    @Published private(set) var insights: App2Sourced<[App2Insight]>?
    @Published private(set) var todaySession: App2Sourced<App2TodaySession>?

    /// §4.1 端點未落地 —— 恆為樣本，不隨載入結果改變。
    let intentCard = App2Sourced(
        App2StubFixtures.intentCard,
        origin: .stub(pendingSection: App2StubFixtures.Section.intent)
    )

    /// §7-16 軌跡圖序列 —— 同樣沒有 HTTP 出口。
    var trajectoryPoints: [App2TrajectoryChart.Point] {
        App2StubFixtures.trajectoryPoints(
            currentWeek: trainingStatus?.value.currentWeek ?? 5,
            totalWeeks: trainingStatus?.value.totalWeeks ?? 22
        )
    }

    let trajectoryOrigin = App2DataOrigin.stub(pendingSection: App2StubFixtures.Section.trajectory)

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let dailyStateRepository: DailyStateRepository
    private let targetRepository: TargetRepository
    private let planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol
    private let app2DataSource: App2RemoteDataSourceProtocol
    private let readinessViewModel: TrainingReadinessViewModel

    // MARK: - Init

    init(
        dailyStateRepository: DailyStateRepository? = nil,
        targetRepository: TargetRepository? = nil,
        planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol? = nil,
        app2DataSource: App2RemoteDataSourceProtocol? = nil,
        readinessViewModel: TrainingReadinessViewModel? = nil
    ) {
        let container = DependencyContainer.shared

        if let dailyStateRepository {
            self.dailyStateRepository = dailyStateRepository
        } else {
            if !container.isRegistered(DailyStateRepository.self) {
                container.registerDailyStateModule()
            }
            self.dailyStateRepository = container.resolve() as DailyStateRepository
        }

        if let targetRepository {
            self.targetRepository = targetRepository
        } else {
            if !container.isRegistered(TargetRepository.self) {
                container.registerTargetModule()
            }
            self.targetRepository = container.resolve() as TargetRepository
        }

        self.planV2DataSource = planV2DataSource ?? TrainingPlanV2RemoteDataSource()
        self.app2DataSource = app2DataSource ?? App2RemoteDataSource()
        self.readinessViewModel = readinessViewModel ?? TrainingReadinessViewModel()
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        // 各區塊獨立：一條失敗不阻斷其他。
        async let status: Void = loadTrainingStatus()
        async let goal: Void = loadGoalCard()
        async let metrics: Void = loadInsights()
        _ = await (status, goal, metrics)
        isLoading = false
    }

    // MARK: - §3.1a 訓練狀況卡

    private func loadTrainingStatus() async {
        var planStatus: PlanStatusV2Response?
        do {
            planStatus = try await planV2DataSource.getPlanStatus()
        } catch {
            Logger.debug("[App2HomeVM] plan status 取得失敗: \(error)")
        }

        do {
            let card = try await dailyStateRepository.fetchTodayState()
            trainingStatus = App2Sourced(
                App2TrainingStatus(
                    headline: card.displayHeadline,
                    narrative: card.narrativeText,
                    // 軌道落點目前沒有 producer（§7-2 同一批評級語意），先置中。
                    trackPosition: 0.5,
                    currentWeek: planStatus?.currentWeek,
                    totalWeeks: planStatus?.totalWeeks
                ),
                origin: .live(endpoint: "GET /v2/state/today")
            )
            todaySession = todaySessionFromCard(card)
        } catch {
            Logger.debug("[App2HomeVM] state/today 取得失敗,退樣本: \(error)")
            trainingStatus = App2Sourced(
                App2StubFixtures.trainingStatus,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
            todaySession = App2Sourced(
                App2StubFixtures.todaySession,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
    }

    /// 今日課表卡：`StateCard.action_line` 已是「12K easy · 6:45」這種一行摘要。
    private func todaySessionFromCard(_ card: DailyStateCard) -> App2Sourced<App2TodaySession> {
        guard let actionLine = card.actionLine, !actionLine.isEmpty else {
            return App2Sourced(
                App2StubFixtures.todaySession,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEMd")
        return App2Sourced(
            App2TodaySession(
                dayLabel: formatter.string(from: Date()),
                title: actionLine,
                intensityLabel: nil,
                summary: card.mileageProgression
            ),
            origin: .live(endpoint: "GET /v2/state/today")
        )
    }

    // MARK: - §3.1 目標賽事卡

    private func loadGoalCard() async {
        await readinessViewModel.loadData()
        let estimated = readinessViewModel.estimatedRaceTime

        var planStatus: PlanStatusV2Response?
        do {
            planStatus = try await planV2DataSource.getPlanStatus()
        } catch {
            Logger.debug("[App2HomeVM] plan status（goal card）取得失敗: \(error)")
        }

        // `getMainTarget()` 只讀本機快取。1.x 的 tab 由別處先打過 `/user/targets`，
        // 2.0 的 App2RootView 沒有那條路徑，所以冷啟後快取是空的、卡片永遠退樣本。
        // 這裡先走檔頭表列的既有出口 `getTargets()`（dual-track，會填快取），不新增第二條路。
        do {
            _ = try await targetRepository.getTargets()
        } catch {
            Logger.debug("[App2HomeVM] targets 取得失敗,改讀既有快取: \(error)")
        }

        guard let main = await targetRepository.getMainTarget() else {
            Logger.debug("[App2HomeVM] 無主要賽事目標,退樣本")
            goalCard = App2Sourced(
                App2StubFixtures.goalCard,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
            return
        }

        goalCard = App2Sourced(
            App2GoalCard(
                raceName: main.name,
                raceDate: Self.localDateString(fromEpochSeconds: main.raceDate, timezone: main.timezone),
                distanceLabel: Self.distanceLabel(km: main.distanceKm),
                // 階段標籤住在 plan overview（TrainingStage），§3.9a 註明出口待實作時確認。
                stageLabel: nil,
                targetTime: main.targetTime > 0 ? Self.formatSeconds(main.targetTime) : nil,
                estimatedFinish: estimated,
                currentWeek: planStatus?.currentWeek,
                totalWeeks: planStatus?.totalWeeks ?? (main.trainingWeeks > 0 ? main.trainingWeeks : nil)
            ),
            origin: .live(endpoint: "GET /user/targets + GET /v2/plan/status + GET /plan/readiness")
        )
    }

    // MARK: - §3.1a 指標網格

    private func loadInsights() async {
        do {
            let dto = try await app2DataSource.fetchAthleteStateMetrics()
            let rows = dto.metrics ?? [:]
            guard !rows.isEmpty else { throw DomainError.unknown("empty metrics") }

            // 網格拿掉「一致性」後為 5 格（2026-08-24 裁決）。順序固定，避免每次載入跳位。
            let order = [
                "capability_baseline",
                "recovery_index",
                "aerobic_endurance",
                "speed_endurance",
                "heat_sensitivity"
            ]
            let stubByID = Dictionary(uniqueKeysWithValues: App2StubFixtures.insights.map { ($0.id, $0) })

            let items: [App2Insight] = order.compactMap { key in
                guard let row = rows[key] else { return nil }
                let value = row.pointEstimate.map { String(format: "%.0f", $0) }
                return App2Insight(
                    id: key,
                    // label 與 verdict 都是評級／文案層，端點依規格不產生（ME-INV-05 → §7-2）。
                    label: stubByID[key]?.label ?? key,
                    value: value,
                    // 方向同樣需要序列對照，envelope 只存當下值。
                    direction: .unknown,
                    verdict: nil
                )
            }
            guard !items.isEmpty else { throw DomainError.unknown("no known metric keys") }
            insights = App2Sourced(items, origin: .live(endpoint: "GET /v2/athlete-state/metrics"))
        } catch {
            Logger.debug("[App2HomeVM] athlete-state metrics 取得失敗,退樣本: \(error)")
            insights = App2Sourced(
                App2StubFixtures.insights,
                origin: .stub(pendingSection: App2StubFixtures.Section.offline)
            )
        }
    }

    // MARK: - Formatting

    /// 賽事日期以賽事時區顯示。數字 timestamp 是 UTC，`YYYY-MM-DD` 是當地日期。
    private static func localDateString(fromEpochSeconds seconds: Int, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    private static func formatSeconds(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private static func distanceLabel(km: Int) -> String {
        switch km {
        case 42: return "42.195 km"
        case 21: return "21.1 km"
        default: return "\(km) km"
        }
    }
}
