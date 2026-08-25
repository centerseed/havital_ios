import Combine
import Foundation

// MARK: - App2HomeViewModel
/// Presentation Layer — 2.0 首頁（`DESIGN-app2-decision-chain-api.md` §3.1／§3.1a）。
///
/// 每個區塊各自載入、各自失敗、各自標來源：一條端點掛掉不該讓整個首頁空白。
///
/// **同一個事實只讀一次。** `current_week`／`total_weeks`／`current_week_plan_id`
/// 全部來自同一次 `GET /v2/plan/status`，由 `revalidate()` 取一次後傳給各區塊。
/// 之前三個區塊各打各的，三個回應可以彼此不一致 —— 2026-08-25 用戶截圖上「目標卡
/// 1/17、狀況卡 6/18、今日課表說尚未產生」就是同一屏三份答案。
@MainActor
final class App2HomeViewModel: ObservableObject, TaskManageable, App2Revalidating {

    // MARK: - Published

    @Published private(set) var isLoading = true
    /// 這一頁載成功過至少一次。SWR 用：載過就不再出 loading 骨架。
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?
    @Published private(set) var goalCard: App2Sourced<App2GoalCard>?
    @Published private(set) var trainingStatus: App2Sourced<App2TrainingStatus>?
    @Published private(set) var insights: App2Sourced<[App2Insight]>?
    /// 今日課表卡。nil = 這一輪還沒載完；其餘四態見 `App2TodaySessionState`。
    @Published private(set) var todayState: App2TodaySessionState?
    /// 今日課表卡點下去要開的訓練詳情（設計 frame-02）。
    /// **與卡片同一份 payload**，詳情頁不再打任何端點；休息日為 nil（不進詳情）。
    @Published private(set) var todayDetail: App2SessionDetail?
    @Published private(set) var weekReview: App2WeekReviewState?
    /// 內嵌 Rizo 卡的教練推話。**由 `/v2/state/today` 的句子組出來**，
    /// 組不出來就是 nil ——那時 Rizo 區退成純入口，不顯示假對話。
    @Published private(set) var rizoOpeningLine: String?
    /// 交棒情境（`card.rizoScenario`）。開對話時帶給既有的 `StateRizoChatViewModel`。
    @Published private(set) var rizoScenario: String?

    /// §7-16 軌跡圖序列 —— 沒有 HTTP 出口，永遠是樣本。
    ///
    /// **週數用真的**：樣本只准填曲線形狀，不准連週數一起編。拿不到真週數時
    /// 用一段中性的長度畫形狀（圖上沒有任何週數字），不外溢成畫面上的「第 N / M 週」。
    var trajectoryPoints: [App2TrajectoryChart.Point] {
        App2StubFixtures.trajectoryPoints(
            currentWeek: trainingStatus?.value.currentWeek ?? Self.neutralTrajectoryCurrentWeek,
            totalWeeks: trainingStatus?.value.totalWeeks ?? Self.neutralTrajectoryTotalWeeks
        )
    }

    /// 真週數缺席時的中性圖形長度。**不是週數**：圖上不畫任何週數字，
    /// 圖例的「第 N / M 週」另外走 `trainingStatus.currentWeek/totalWeeks`（缺就不顯示）。
    private static let neutralTrajectoryCurrentWeek = 6
    private static let neutralTrajectoryTotalWeeks = 16

    let trajectoryOrigin = App2DataOrigin.stub(pendingSection: App2StubFixtures.Section.trajectory)

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Dependencies

    private let dailyStateRepository: DailyStateRepository
    private let targetRepository: TargetRepository
    private let planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol
    private let readinessViewModel: TrainingReadinessViewModel

    // MARK: - Init

    init(
        dailyStateRepository: DailyStateRepository? = nil,
        targetRepository: TargetRepository? = nil,
        planV2DataSource: TrainingPlanV2RemoteDataSourceProtocol? = nil,
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
        self.readinessViewModel = readinessViewModel ?? TrainingReadinessViewModel()
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func revalidate() async {
        // 只有「從未載過」才出 loading —— 重驗時畫面保留上一次的資料，不閃白。
        isLoading = !hasLoaded

        // 全頁共用的一次 plan status。三張卡都從這一份取週數與本週課表 id。
        let planStatus = await fetchPlanStatus()

        // 其餘區塊獨立：一條失敗不阻斷其他。
        async let state: Void = loadDailyState(planStatus: planStatus.value)
        async let goal: Void = loadGoalCard(planStatus: planStatus.value)
        async let today: Void = loadTodaySession(planStatus: planStatus)
        async let review: Void = loadWeekReview(planStatus: planStatus.value)
        _ = await (state, goal, today, review)

        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }

    /// 一次 plan status 的結果。`.failed` 與「拿到了但沒有本週課表」是兩件事，
    /// 今日課表卡要分得出來才不會把讀取失敗說成「尚未產生」。
    enum PlanStatusOutcome {
        case loaded(PlanStatusV2Response)
        case failed
        /// 這一輪被取消：不要動畫面上的既有資料。
        case cancelled

        var value: PlanStatusV2Response? {
            if case .loaded(let status) = self { return status }
            return nil
        }
    }

    private func fetchPlanStatus() async -> PlanStatusOutcome {
        do {
            return .loaded(try await planV2DataSource.getPlanStatus())
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）：下拉刷新的 task 被 SwiftUI 收掉時
            // in-flight 請求會回 -999。
            if error.isCancellationError { return .cancelled }
            Logger.debug("[App2HomeVM] plan status 取得失敗: \(error)")
            return .failed
        }
    }

    // MARK: - §3.1a 訓練狀況卡 ＋ 指標膠囊列 ＋ Rizo 推話
    //
    // 三者同一個來源：`GET /v2/state/today`。
    //
    // **指標列不再打 `/v2/athlete-state/metrics`。** 那條端點依規格只交 envelope、
    // 不評級也不渲染句子（ME-INV-05），所以綁它的膠囊永遠沒有 verdict 也沒有箭頭
    // ——2026-08-25 在 dev 上實測就是整排灰 icon ＋ 小點。`state/today` 的
    // `insights[]` 才是已評級、已在地化的那一份（`label`／`arrow`／`verdict`／
    // `change`／`dot`／`status`），設計文件 §3.1a 指到前者是判定錯誤，票面已記。

    private func loadDailyState(planStatus: PlanStatusV2Response?) async {
        do {
            let card = try await dailyStateRepository.fetchTodayState()

            trainingStatus = App2Sourced(
                Self.trainingStatus(
                    card: card,
                    currentWeek: planStatus?.currentWeek,
                    totalWeeks: planStatus?.totalWeeks
                ),
                origin: .live(endpoint: "GET /v2/state/today")
            )

            let rows = Self.insights(rows: card.insights)
            if rows.isEmpty {
                // 端點沒帶 insights（舊版後端）→ 這一列先退樣本並掛徽章。
                Logger.debug("[App2HomeVM] state/today 沒有 insights,指標列退樣本")
                insights = App2Sourced(
                    App2StubFixtures.insights,
                    origin: .stub(pendingSection: App2StubFixtures.Section.insightVerdict)
                )
            } else {
                insights = App2Sourced(rows, origin: .live(endpoint: "GET /v2/state/today"))
            }

            rizoOpeningLine = Self.rizoOpeningLine(card: card)
            rizoScenario = card.rizoScenario
        } catch {
            // 取消不是失敗（`AGENTS.md` 陷阱 2）。下拉刷新的 task 被 SwiftUI 收掉時
            // 每一條 in-flight 請求都會回 -999；當成失敗會把畫面上的真資料換成樣本。
            guard !error.isCancellationError else { return }
            Logger.debug("[App2HomeVM] state/today 取得失敗,退樣本: \(error)")
            if trainingStatus == nil {
                trainingStatus = App2Sourced(
                    // **樣本只填敘事，週數一律用真的。** 樣本檔已經不帶週數欄位，
                    // 這裡再明寫一次來源，避免日後有人把週數塞回樣本。
                    Self.offlineTrainingStatus(
                        currentWeek: planStatus?.currentWeek,
                        totalWeeks: planStatus?.totalWeeks
                    ),
                    origin: .stub(pendingSection: App2StubFixtures.Section.offline)
                )
            }
            if insights == nil {
                insights = App2Sourced(
                    App2StubFixtures.insights,
                    origin: .stub(pendingSection: App2StubFixtures.Section.offline)
                )
            }
        }
    }

    // MARK: - §3.1 今日課表卡
    //
    // 資料來源是**本週課表的今日項目**（`GET /v2/plan/status` → `GET /v2/plan/weekly/{id}`
    // 的 `days[day_index == 今天]`），不是 `/v2/state/today` 的 `action_line`
    // ——後者是一行已渲染的字（`8K easy`），拆不出課型／強度／內容三個欄位，
    // 也不會在地化。
    //
    // 「本週課表尚未產生」只有在 `current_week_plan_id` 真的是 nil 時才准講。

    private func loadTodaySession(planStatus: PlanStatusOutcome) async {
        switch planStatus {
        case .cancelled:
            return  // 保留上一次的今日課表，不清成空狀態。
        case .failed:
            if todayState == nil { todayState = .unavailable }
            return
        case .loaded(let status):
            guard let planId = status.currentWeekPlanId else {
                Logger.debug("[App2HomeVM] 本週課表尚未產生 (next_action=\(status.nextAction))")
                todayState = .notGenerated
                return
            }
            do {
                let plan = try await planV2DataSource.getWeeklyPlan(planId: planId)
                let todayIndex = App2PlanViewModel.todayDayIndex()
                guard let session = Self.todaySession(
                    days: plan.days,
                    todayIndex: todayIndex,
                    dayLabel: Self.todayLabel()
                ) else {
                    todayState = .noSessionToday
                    todayDetail = nil
                    return
                }
                todayState = .session(session)
                todayDetail = plan.days
                    .first { $0.dayIndex == todayIndex }
                    .flatMap {
                        App2SessionDetailProjection.detail(
                            day: $0,
                            weekStart: App2PlanViewModel.currentWeekStart()
                        )
                    }
            } catch {
                guard !error.isCancellationError else { return }
                Logger.debug("[App2HomeVM] 今日課表取得失敗（plan_id=\(planId)）: \(error)")
                todayState = .unavailable
            }
        }
    }

    // MARK: - 週回顧 CTA
    //
    // 設計 dc.html:5112：週日＝「產生本週回顧」，週一～六＝「產生上週回顧」。
    // 目標週的回顧已經在了就改成「查看回顧」。

    private func loadWeekReview(planStatus: PlanStatusV2Response?) async {
        guard let planStatus else { return }
        let isSunday = Self.isSunday()

        if !isSunday {
            // 上週回顧的存在與否，`/v2/plan/status` 已經直接給了，不必多打一條。
            weekReview = Self.weekReviewState(
                planStatus: planStatus,
                isSunday: false,
                summaryId: planStatus.previousWeekSummaryId
            )
            return
        }

        // 週日看的是「本週」，plan status 沒有「本週回顧 id」這一欄 → 問既有的週摘要出口。
        // `next_action == create_summary` 已經明說本週還沒產生，那就不用問了。
        if planStatus.nextAction == "create_summary" {
            weekReview = Self.weekReviewState(planStatus: planStatus, isSunday: true, summaryId: nil)
            return
        }
        var summaryId: String?
        do {
            summaryId = try await planV2DataSource.getWeeklySummary(weekOfPlan: planStatus.currentWeek).id
        } catch {
            guard !error.isCancellationError else { return }
            Logger.debug("[App2HomeVM] 本週回顧查詢失敗,視為尚未產生: \(error)")
        }
        weekReview = Self.weekReviewState(planStatus: planStatus, isSunday: true, summaryId: summaryId)
    }

    #if DEBUG
    /// 測試／預覽用：直接填入各區塊狀態，不打網路。
    /// （沿用 repo 既有的 `DailyStateCardViewModel.loadForTest()` 慣例。）
    func applyForTesting(
        goalCard: App2Sourced<App2GoalCard>? = nil,
        trainingStatus: App2Sourced<App2TrainingStatus>? = nil,
        insights: App2Sourced<[App2Insight]>? = nil,
        todayState: App2TodaySessionState? = nil,
        weekReview: App2WeekReviewState? = nil,
        rizoOpeningLine: String? = nil
    ) {
        self.goalCard = goalCard
        self.trainingStatus = trainingStatus
        self.insights = insights
        self.todayState = todayState
        self.weekReview = weekReview
        self.rizoOpeningLine = rizoOpeningLine
        isLoading = false
        hasLoaded = true
        lastLoadedAt = Date()
    }
    #endif

    // MARK: - 投影（純函式，可單獨測）
    //
    // 「payload → 畫面欄位」全部抽成 static：載入路徑要網路，投影不用。

    /// 訓練狀況卡（§3.1a）。
    /// `trackPosition` 目前沒有 producer（§7-2 同一批評級語意），恆置中。
    static func trainingStatus(
        card: DailyStateCard,
        currentWeek: Int?,
        totalWeeks: Int?
    ) -> App2TrainingStatus {
        App2TrainingStatus(
            headline: card.displayHeadline,
            narrative: card.narrativeText,
            trackPosition: 0.5,
            currentWeek: currentWeek,
            totalWeeks: totalWeeks
        )
    }

    /// `state/today` 掛掉時的訓練狀況卡：敘事退樣本，**週數仍然是真的**。
    static func offlineTrainingStatus(currentWeek: Int?, totalWeeks: Int?) -> App2TrainingStatus {
        let stub = App2StubFixtures.trainingStatus
        return App2TrainingStatus(
            headline: stub.headline,
            narrative: stub.narrative,
            trackPosition: stub.trackPosition,
            currentWeek: currentWeek,
            totalWeeks: totalWeeks
        )
    }

    /// 今日課表卡（§3.1）。今天不在 `days` 裡就回 nil —— 呼叫端據此走 `.noSessionToday`。
    static func todaySession(
        days: [DayDetailDTO],
        todayIndex: Int,
        dayLabel: String
    ) -> App2TodaySession? {
        guard let day = days.first(where: { $0.dayIndex == todayIndex }) else { return nil }
        let dayType = day.primary == nil ? DayType.rest : App2PlanViewModel.dayType(day.primary)
        let segments = Self.segments(day: day)
        let durationMinutes: Int? = {
            if case .run(let run) = day.primary { return run.durationMinutes }
            return nil
        }()
        return App2TodaySession(
            dayLabel: dayLabel,
            title: dayType?.localizedName ?? (day.category ?? L10n.App2.Plan.rest.localized),
            intensityLabel: App2PlanViewModel.intensityLabel(day.primary),
            summary: App2PlanViewModel.contentLine(day.primary),
            segments: segments,
            structureBars: Self.structureBars(day: day),
            strengthLabel: Self.strengthLabel(day: day),
            dayIndex: day.dayIndex,
            dayType: dayType,
            showsFuelingNote: App2SessionDetailProjection.showsFuelingNote(
                dayType: dayType,
                durationMinutes: durationMinutes
            )
        )
    }

    /// 指標膠囊列（§3.1a）。**順序、名稱、評級全部照後端給的來**，
    /// app 端不排序也不改名 —— 那是評級層的決定，不是呈現層的。
    static func insights(rows: [DailyStateInsight]) -> [App2Insight] {
        rows.map { row in
            App2Insight(
                id: row.key,
                label: row.label,
                value: row.valueText,
                direction: App2Insight.Direction(rawValue: row.arrow.rawValue) ?? .unknown,
                verdict: row.verdict,
                change: row.change,
                isNotComputed: row.isNotComputed
            )
        }
    }

    /// Rizo 卡的開場句。**用既有的狀態句組，不生成新文案。**
    /// `collapsed_reason`（融合了建議＋理由＋數字）最貼近設計的推話；沒有就退
    /// `narrative_text`；兩者都沒有 → nil，畫面把 Rizo 區退成純入口。
    static func rizoOpeningLine(card: DailyStateCard) -> String? {
        let candidates = [card.collapsedReason, card.narrativeText]
        return candidates.compactMap { $0 }.first { !$0.isEmpty }
    }

    /// 週回顧 CTA 狀態。**回 nil ＝整張卡不顯示。**
    ///
    /// 出現條件只有一條：**目標週是一個「可回顧的訓練週」**。
    /// - 平日：目標週＝上一個訓練週（`current_week - 1`）。課表從第 1 週才開始的帳號
    ///   沒有上一週可回顧 —— 2026-08-25 demo 帳號正是這個狀態，畫面卻掛著
    ///   「產生上週回顧」，那是一張按下去無事可做的卡。
    /// - 週日：目標週＝本週，前提是本週真的有課表（`current_week_plan_id` 非 nil）。
    ///
    /// `summaryId` 有值＝目標週的回顧已存在 → 改成「查看回顧」。
    static func weekReviewState(
        planStatus: PlanStatusV2Response,
        isSunday: Bool,
        summaryId: String?
    ) -> App2WeekReviewState? {
        let targetWeekHasPlan = isSunday
            ? planStatus.currentWeekPlanId != nil
            : planStatus.currentWeek > 1
        guard targetWeekHasPlan else { return nil }

        if let summaryId, !summaryId.isEmpty {
            return .available(summaryId: summaryId, isCurrentWeek: isSunday)
        }
        return .notGenerated(isCurrentWeek: isSunday)
    }

    static func isSunday(date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }

    // MARK: - 今日課表卡的分段與結構

    /// 分段列（設計 dc.html 今日課表卡的「全程勻速」／「熱身＋節奏段＋緩和」那一排）。
    ///
    /// 依 payload 的實際順序走一遍：`warmup` → `primary.segments[]` → `cooldown`。
    /// 間歇段展開成「衝刺 ＋ 恢復」兩行，其餘段落各一行。組不出值的那一行**不出現**，
    /// 不用 placeholder 補。
    ///
    /// **單段課也有一列。** 8/25 版設計的四張今日課表卡裡，輕鬆跑與長距離都是一列
    /// （「全程勻速 8.0 km · 6:50」／「穩定耐力 24 km · 6:30」），與節奏跑的三列
    /// 同一組視覺；舊版把單列濾掉是因為當時卡片沒有這一排，只有右側的結構圖。
    static func segments(day: DayDetailDTO) -> [App2SessionSegment] {
        var result: [App2SessionSegment] = []
        func append(_ name: String, _ detail: String?, isWork: Bool) {
            guard let detail else { return }
            result.append(.init(id: result.count, name: name, detail: detail, isWork: isWork))
        }

        append(
            NSLocalizedString("training.segment.warmup", comment: ""),
            day.warmup.flatMap(effortLabel(segment:)),
            isWork: false
        )

        if case .run(let run) = day.primary {
            let runSegments = run.segments ?? []
            if runSegments.isEmpty {
                // 單段課（輕鬆跑／長跑）也有結構，只是只有一段主課。
                append(L10n.App2.Home.segmentMain.localized,
                       App2PlanViewModel.contentLine(day.primary), isWork: true)
            }
            for segment in runSegments {
                if segment.kind == "interval" {
                    if let work = segment.work, let detail = effortLabel(effort: work) {
                        let repeats = segment.repeats ?? 0
                        append(NSLocalizedString("training.segment.sprint", comment: ""),
                               repeats > 1 ? "\(repeats) × \(detail)" : detail, isWork: true)
                    }
                    append(L10n.App2.Home.segmentRecovery.localized,
                           segment.recovery.flatMap(effortLabel(effort:)), isWork: false)
                } else {
                    append(L10n.App2.Home.segmentMain.localized,
                           effortLabel(segment: segment), isWork: true)
                }
            }
        }

        if case .cross(let cross) = day.primary {
            // 交叉訓練沒有配速，但仍然是一段課 —— 用時長當那一列的量。
            append(
                L10n.App2.Home.segmentMain.localized,
                String(format: L10n.App2.Home.minutes.localized, cross.durationMinutes),
                isWork: true
            )
        }

        append(
            NSLocalizedString("training.segment.cooldown", comment: ""),
            day.cooldown.flatMap(effortLabel(segment:)),
            isWork: false
        )

        return result
    }

    /// 配速結構示意（設計 frame-02「預計配速」同一視覺家族）。
    ///
    /// **每一種課型都要畫得出來**（2026-08-25 用戶裁決）：單段輕鬆跑＝一整塊綠色
    /// 穩定段（塊上標配速），有暖身／緩和就前後加淺色塊，間歇課維持橘色趟柱。
    ///
    /// **橘柱＝衝刺（interval 的 work）那幾趟，只有它算「趟」。** 熱身、主課的
    /// 穩定段、組間恢復、緩和都不計趟 —— 把穩定段也算進去會讓
    /// 「6 × 200m」的課寫成「趟數 × 7 趟」（2026-08-25 用戶在截圖上抓到）。
    static func structureBars(day: DayDetailDTO) -> [App2SessionStructureBar] {
        var bars: [App2SessionStructureBar] = []
        func append(
            _ kind: App2SessionStructureBar.Kind,
            height: Double,
            width: Double,
            pace: String? = nil,
            noteLabel: String? = nil,
            noteDetail: String? = nil
        ) {
            bars.append(.init(
                id: bars.count, kind: kind, height: height, widthWeight: width, paceLabel: pace,
                noteLabel: noteLabel, noteDetail: noteDetail
            ))
        }

        if day.warmup != nil { append(.support, height: 0.35, width: 1) }

        if case .run(let run) = day.primary {
            let runSegments = run.segments ?? []
            if runSegments.isEmpty {
                // 單段課（輕鬆跑／長跑）：一整塊穩定段，配速標在塊上。
                // 標註列的量直接用卡片「課表」那一行的同一支（`contentLine`），
                // 不另組一份字串 —— 兩處出現同一個量卻長得不一樣就是矛盾。
                append(
                    .steady, height: 0.6, width: 4,
                    pace: run.climateAdjustedPace ?? run.pace,
                    noteLabel: L10n.App2.Home.structureNoteSteady.localized,
                    noteDetail: App2PlanViewModel.contentLine(day.primary)
                )
            }
            for segment in runSegments {
                if segment.kind == "interval", let repeats = segment.repeats, repeats > 0 {
                    // 太多趟就不畫滿，畫面上那格只有幾十 pt 寬。
                    let drawn = min(repeats, 10)
                    let detail = segment.work.flatMap(effortLabel(effort:))
                    for index in 0..<drawn {
                        append(
                            .interval, height: 1.0, width: 1,
                            // 標註列只掛第一根柱，後面的柱共用同一條說明（下面 chart 會去重）。
                            noteLabel: index == 0 ? L10n.App2.Home.structureNoteInterval.localized : nil,
                            noteDetail: index == 0
                                ? detail.map { repeats > 1 ? "\(repeats) × \($0)" : $0 }
                                : nil
                        )
                        if index < drawn - 1 { append(.support, height: 0.3, width: 0.6) }
                    }
                } else {
                    append(
                        .steady, height: 0.6, width: 3,
                        pace: segment.work?.pace ?? segment.pace,
                        noteLabel: L10n.App2.Home.structureNoteSteady.localized,
                        noteDetail: effortLabel(segment: segment)
                    )
                }
            }
        } else if day.primary != nil {
            // 肌力／交叉訓練沒有配速，但仍然有「一段課」的結構。
            append(.steady, height: 0.6, width: 4)
        }

        if day.cooldown != nil { append(.support, height: 0.35, width: 1) }

        return bars
    }

    /// `力量 · 3 個動作`。今天沒有肌力補充項目就回 nil。
    static func strengthLabel(day: DayDetailDTO) -> String? {
        let exercises = (day.supplementary ?? []).reduce(into: 0) { total, activity in
            if case .strength(let strength) = activity { total += strength.exercises.count }
        }
        guard exercises > 0 else { return nil }
        return String(format: L10n.App2.Home.strengthRow.localized, exercises)
    }

    /// `400m @ 4:30`／`10 分鐘`。組不出來就回 nil（那一行不顯示）。
    static func effortLabel(effort: SegmentEffortDTO) -> String? {
        var parts: [String] = []
        if let metres = effort.distanceM {
            parts.append("\(metres)m")
        } else if let km = effort.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let minutes = effort.durationMinutes {
            parts.append(String(format: L10n.App2.Home.minutes.localized, minutes))
        } else if let seconds = effort.durationSeconds {
            parts.append(String(format: L10n.App2.Home.recoverySeconds.localized, seconds))
        }
        if let pace = effort.pace ?? effort.basePace {
            parts.append("@ \(pace)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func effortLabel(segment: RunSegmentDTO) -> String? {
        var parts: [String] = []
        if let km = segment.distanceKm, km > 0 {
            parts.append(String(format: "%.1f km", km))
        } else if let metres = segment.distanceM {
            parts.append("\(metres)m")
        } else if let minutes = segment.durationMinutes {
            parts.append(String(format: L10n.App2.Home.minutes.localized, minutes))
        }
        if let pace = segment.climateAdjustedPace ?? segment.pace ?? segment.basePace {
            parts.append("@ \(pace)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// `週二 · 8/25` —— 裝置當地日期，不是後端字串。
    private static func todayLabel() -> String {
        let weekday = DateFormatter()
        weekday.locale = Locale.current
        weekday.setLocalizedDateFormatFromTemplate("EEEE")
        let date = DateFormatter()
        date.locale = Locale.current
        date.setLocalizedDateFormatFromTemplate("Md")
        return "\(weekday.string(from: Date())) · \(date.string(from: Date()))"
    }

    // MARK: - §3.1 目標賽事卡

    private func loadGoalCard(planStatus: PlanStatusV2Response?) async {
        await readinessViewModel.loadData()
        let estimated = readinessViewModel.estimatedRaceTime

        // `getMainTarget()` 只讀本機快取。1.x 的 tab 由別處先打過 `/user/targets`，
        // 2.0 的 App2RootView 沒有那條路徑，所以冷啟後快取是空的、卡片永遠退樣本。
        // 這裡先走檔頭表列的既有出口 `getTargets()`（dual-track，會填快取），不新增第二條路。
        do {
            _ = try await targetRepository.getTargets()
        } catch {
            if error.isCancellationError, goalCard != nil { return }
            Logger.debug("[App2HomeVM] targets 取得失敗,改讀既有快取: \(error)")
        }

        // 沒有主要賽事目標 → 卡片留空（畫面顯示「尚未設定目標賽事」），
        // **不拿設計稿的示範賽事充數**。
        guard let main = await targetRepository.getMainTarget() else {
            Logger.debug("[App2HomeVM] 無主要賽事目標,顯示空狀態")
            goalCard = nil
            return
        }

        let stage = await stageLabel(planStatus: planStatus)

        goalCard = App2Sourced(
            App2GoalCard(
                raceName: main.name,
                raceDate: Self.localDateString(fromEpochSeconds: main.raceDate, timezone: main.timezone),
                distanceLabel: Self.distanceLabel(km: main.distanceKm),
                // 階段標籤（設計 frame-00 右上的藍膠囊）住在 plan overview 的
                // `training_stages[]`，用 plan status 的當前週落在哪一段來挑。
                stageLabel: stage,
                targetTime: main.targetTime > 0 ? Self.formatSeconds(main.targetTime) : nil,
                estimatedFinish: estimated,
                currentWeek: planStatus?.currentWeek,
                totalWeeks: planStatus?.totalWeeks ?? (main.trainingWeeks > 0 ? main.trainingWeeks : nil)
            ),
            origin: .live(
                endpoint: "GET /user/targets + GET /v2/plan/status + GET /plan/readiness"
                    + " + GET /v2/plan/overview"
            )
        )
    }

    /// 期別膠囊的字（`基礎期`）。
    ///
    /// **綁的是 plan status 指向的那份 overview，不是「最新的 overview」。**
    /// `current_week_plan_id` 的前綴就是 overview id（dev 實測：plan `e1289e60f251_1`
    /// ↔ overview `e1289e60f251`）；`GET /v2/plan/overview` 只交當前那一份，所以拿回來
    /// 先比對 id，對不上就不顯示 —— 寧可少一個膠囊，也不要標一個別的計畫的期別。
    private func stageLabel(planStatus: PlanStatusV2Response?) async -> String? {
        guard let planStatus else { return nil }
        let currentWeek = planStatus.currentWeek
        do {
            let overview = try await planV2DataSource.getOverview()
            guard Self.isOverview(overview.id, boundTo: planStatus) else {
                Logger.debug("[App2HomeVM] overview 與本週課表不同源,不顯示期別")
                return nil
            }
            return Self.stageName(stages: overview.trainingStages, currentWeek: currentWeek)
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2HomeVM] overview 取得失敗,期別留白: \(error)")
            }
            return nil
        }
    }

    /// 這份 overview 是不是 plan status 指向的那一份。
    ///
    /// `current_week_plan_id` 的前綴就是 overview id（dev 實測：plan `e1289e60f251_1`
    /// ↔ overview `e1289e60f251`）。`GET /v2/plan/overview` 只交當前那一份，拿回來要先比對
    /// —— 對不上就什麼都不顯示，不要把另一份計畫的期別／期程畫成這一份的。
    ///
    /// **本週課表還沒產生時（`current_week_plan_id == nil`）綁不了**，一律回 false：
    /// 那時沒有任何東西能證明手上這份 overview 就是要跑的那份。
    ///
    /// 首頁的期別膠囊與訓練計畫總覽頁的期程列表共用這一支，不各寫一份。
    static func isOverview(_ overviewId: String, boundTo planStatus: PlanStatusV2Response) -> Bool {
        guard let planId = planStatus.currentWeekPlanId,
              let boundOverviewId = planId.split(separator: "_").first.map(String.init) else {
            return false
        }
        return overviewId == boundOverviewId
    }

    /// 當前週落在哪一段 `training_stages`。落不進任何一段就沒有期別（不猜最近的那段）。
    static func stageName(stages: [TrainingStageDTO]?, currentWeek: Int) -> String? {
        stages?.first { currentWeek >= $0.weekStart && currentWeek <= $0.weekEnd }?.stageName
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

    /// 距離標籤走既有的 `race_filter.*`（三語已齊，賽事清單頁在用同一組），
    /// 不把 `distance_km` 或 `type` 這種識別字直接印到畫面上。
    private static func distanceLabel(km: Int) -> String {
        switch km {
        case 42: return NSLocalizedString("race_filter.full_marathon", comment: "")
        case 21: return NSLocalizedString("race_filter.half_marathon", comment: "")
        case 10: return NSLocalizedString("race_filter.10k", comment: "")
        case 5:  return NSLocalizedString("race_filter.5k", comment: "")
        default: return "\(km) km"
        }
    }
}
