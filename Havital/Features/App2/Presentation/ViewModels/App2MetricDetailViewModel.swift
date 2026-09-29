import Combine
import Foundation

// MARK: - App2MetricRange
/// 範圍 tabs（§51-3 訓練量、§52-2 能力基準）。§53 恢復沒有 tabs（稿如此）。
enum App2MetricRange: String, Identifiable, CaseIterable {
    /// §51：近 8 週／近 26 週／今年。
    case weeks8, weeks26, year
    /// §52：近 60 天／近 6 個月／全部。
    case days60, months6, all

    var id: String { rawValue }

    static let volume: [App2MetricRange] = [.weeks8, .weeks26, .year]
    static let capability: [App2MetricRange] = [.days60, .months6, .all]

    var label: String {
        switch self {
        case .weeks8:  return L10n.App2.Metric.rangeWeeks8.localized
        case .weeks26: return L10n.App2.Metric.rangeWeeks26.localized
        case .year:    return L10n.App2.Metric.rangeYear.localized
        case .days60:  return L10n.App2.Metric.rangeDays60.localized
        case .months6: return L10n.App2.Metric.rangeMonths6.localized
        case .all:     return L10n.App2.Metric.rangeAll.localized
        }
    }

    /// `/v2/workouts/stats?weeks=` 的參數。「今年」＝今天落在第幾個當地週。
    func weeksParameter(now: Date = Date(), calendar: Calendar = .current) -> Int {
        switch self {
        case .weeks8:  return 8
        case .weeks26: return 26
        case .year:
            let week = calendar.component(.weekOfYear, from: now)
            return min(max(week, 1), 53)
        default:       return 8
        }
    }

    /// `/v2/workouts/vdots?limit=` 的參數（一天一筆）。
    var vdotLimit: Int {
        switch self {
        case .days60:  return 60
        case .months6: return 185
        case .all:     return 730
        default:       return 60
        }
    }
}

// MARK: - App2VolumeDetailViewModel
/// §51 指標詳情 · 訓練量。
///
/// **hero 的大數字與判語不由這一支算**：它們是首頁那一列的 `insight`，由呼叫端
/// 原樣傳進來（同一個量在兩個畫面上必須是同一個字）。這裡只補歷史序列、現算欄
/// 與訓練負荷。
@MainActor
final class App2VolumeDetailViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var readFailed = false
    @Published private(set) var detail: App2Sourced<App2VolumeDetail>?
    @Published private(set) var range: App2MetricRange = .weeks8
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    private let insight: App2Insight
    private let narrative: String?
    /// 卡片的使用者當地業務日：30 天負荷比序列的窗右端（同 T-0617 兩格的作法）。
    private let asof: String?
    private let workoutDataSource: WorkoutStatsDataSourceProtocol
    private let seriesDataSource: AthleteStateSeriesDataSourceProtocol
    private let planRepository: TrainingPlanV2Repository?
    private let cache: App2MetricDetailCache

    init(
        insight: App2Insight,
        narrative: String?,
        asof: String? = nil,
        workoutDataSource: WorkoutStatsDataSourceProtocol? = nil,
        seriesDataSource: AthleteStateSeriesDataSourceProtocol? = nil,
        planRepository: TrainingPlanV2Repository? = nil,
        cache: App2MetricDetailCache = .shared
    ) {
        self.insight = insight
        self.narrative = narrative
        self.asof = asof
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()
        self.seriesDataSource = seriesDataSource ?? AthleteStateSeriesRemoteDataSource()
        self.cache = cache
        if let planRepository {
            self.planRepository = planRepository
        } else {
            let container = DependencyContainer.shared
            // 課表是目標線的唯一真相。沒註冊就不強行註冊——那時只是少一條目標線，
            // 不該讓整頁掛掉。
            self.planRepository = container.isRegistered(TrainingPlanV2Repository.self)
                ? (container.resolve() as TrainingPlanV2Repository)
                : nil
        }
        // VM 隨 push 重建：有 session 快取就先出畫面（SWR），過期與否交給
        // loadIfNeeded 的 staleAfter 判斷（T-0357）。
        if let entry = cache.volume[range] {
            publish(entry.payload)
            hasLoaded = true
            lastLoadedAt = entry.loadedAt
            isLoading = false
        }
    }

    deinit {
        cancelAllTasks()
    }

    /// 切 range 起的重載 task 由 VM 持有：快速連點時先取消上一發，
    /// 舊 range 的慢回應才不會蓋掉新 range 的畫面（外審第十輪 D04/E08）。
    private(set) var rangeReloadTask: Task<Void, Never>?

    /// 這一輪重驗的代號。**首載那一輪由 view 的 `.task` 起，VM 手上沒有外層把手**
    /// ——所以「哪一輪能寫」不能只靠取消：每輪開頭固定 `round` 與 `requestedRange`，
    /// 回來時代號或當前 range 已變就整輪作廢，不 store 也不 publish
    /// （2026-09-01 外審 D04：切 range 期間舊 range 的回應會被寫進新 range 的 key）。
    private var revalidateGeneration = 0

    /// 現任輪的 task（**含首載那一輪**）：切 range 或離場時取消它。
    private(set) var revalidateRoundTask: Task<Void, Never>?

    func select(range newRange: App2MetricRange) {
        guard newRange != range else { return }
        range = newRange
        // 新 range 有快取先上畫面，revalidate 照跑（切 range 一律重驗）。
        if let entry = cache.volume[newRange] {
            publish(entry.payload)
        }
        // 舊 range 的 in-flight 輪（含首載）當場作廢——**同步**遞增代號，不能等新輪
        // 開跑才遞增：這中間舊輪的 defer 仍會通過代號檢查、把現任輪的 spinner 清掉
        // （2026-09-01 外審第二輪 D04）。
        invalidateCurrentRound()
        rangeReloadTask?.cancel()
        rangeReloadTask = Task { [weak self] in await self?.revalidate() }
    }

    /// 離開畫面時由 view 的 `onDisappear` 呼叫：取消 in-flight 的重驗輪（含首載），
    /// task 才不會抓著 VM 撐過畫面生命週期（外審第十一輪 D04）。
    func cancelInFlightReload() {
        invalidateCurrentRound()
        rangeReloadTask?.cancel()
        rangeReloadTask = nil
    }

    func revalidate() async {
        invalidateCurrentRound()
        let round = revalidateGeneration
        // range 在**發請求前**就定下來，之後只用這一份；用「當下的 range」寫快取
        // 正是 D04 的缺陷本體。
        let requestedRange = range
        let roundTask = Task { [weak self] in
            guard let self else { return }
            await self.revalidateRound(round, range: requestedRange)
        }
        revalidateRoundTask = roundTask
        // 呼叫端（view 的 `.task`）被取消時把取消轉發進本輪，取消語意不變。
        await withTaskCancellationHandler {
            await roundTask.value
        } onCancel: {
            roundTask.cancel()
        }
        if revalidateGeneration == round {
            revalidateRoundTask = nil
        }
    }

    private func revalidateRound(_ round: Int, range requestedRange: App2MetricRange) async {
        // 發請求前記下快取的失效世代（見 `App2MetricDetailCache.invalidationEpoch`）。
        let epoch = cache.invalidationEpoch
        isLoading = !hasLoaded
        var finishedRound = false
        var succeeded = false
        defer {
            // 只有現任輪能收尾——被取代的舊輪連 isLoading 都不得清（外審 D04）。
            if revalidateGeneration == round {
                isLoading = false
                // 成功或**真失敗**才算載過；取消不標——task 取消與 -999 取消錯誤
                // （提早 return，finishedRound 維持 false）都算取消（2026-08-29 外審 D04/E03）。
                if finishedRound, !Task.isCancelled {
                    hasLoaded = true
                    if succeeded { lastLoadedAt = Date() }
                }
            }
        }

        do {
            // 三個請求互相獨立，並行打（T-0357）。
            async let statsAsync = workoutDataSource.fetchWorkoutStats(
                days: 30,
                weeks: requestedRange.weeksParameter()
            )
            async let seriesAsync = fetchSeriesOptional()
            async let targetAsync = targetWeeklyKm()

            let stats = try await statsAsync
            let seriesOutcome = await seriesAsync
            let targetKm = await targetAsync

            // 負荷比線與目標線各自可缺席：**真失敗**只是少那一塊；
            // 取消（含 -999 取消錯誤，Task.isCancelled 可能是 false）＝整輪作廢不發布
            //（外審 E03）。
            if case .cancelled = seriesOutcome { return }
            if Task.isCancelled { return }
            guard isCurrentRound(round, requestedRange) else { return }

            let previous = cache.volume[requestedRange]
            let partialFailure = seriesOutcome.hasFailed
            let payload = App2MetricDetailCache.VolumePayload(
                stats: stats,
                targetKm: targetKm,
                series: seriesOutcome.hasFailed ? previous?.payload.series : seriesOutcome.response
            )
            cache.storeIfCurrent(epoch: epoch) {
                $0.storeVolume(payload, range: requestedRange,
                               loadedAt: partialFailure ? previous?.loadedAt ?? .distantPast : Date())
            }
            publish(payload)
            finishedRound = true
            succeeded = !partialFailure
            readFailed = partialFailure
        } catch {
            guard !error.isCancellationError, !Task.isCancelled else { return }
            guard isCurrentRound(round, requestedRange) else { return }
            finishedRound = true
            readFailed = true
            Logger.debug("[App2VolumeDetailVM] stats 取得失敗: \(error)")
        }
    }

    /// 這一輪還算不算數：代號沒被新輪頂掉，且它打的 range 還是畫面上的 range。
    /// 兩個條件都要——`select(range:)` 先改 `range` 再起新輪，兩者之間有一個
    /// 窗口 generation 尚未遞增，只查代號會漏掉那一段。
    private func isCurrentRound(_ round: Int, _ requestedRange: App2MetricRange) -> Bool {
        revalidateGeneration == round && requestedRange == range
    }

    /// 同步作廢現任輪：取消它，並**當場**遞增代號。
    /// 只在新輪開跑時才遞增擋不住空窗期——`select(range:)` 取消舊輪到新輪真的
    /// 執行之間，舊輪的 defer 仍會通過代號檢查、清掉現任輪的 loading 態
    /// （2026-09-01 外審第二輪 D04）。
    private func invalidateCurrentRound() {
        revalidateRoundTask?.cancel()
        revalidateRoundTask = nil
        revalidateGeneration += 1
    }

    private enum SeriesOutcome {
        case ok(AthleteStateSeriesResponse?)
        case cancelled
        case failed

        var hasFailed: Bool {
            if case .failed = self { return true }
            return false
        }

        var response: AthleteStateSeriesResponse? {
            if case .ok(let response) = self { return response }
            return nil
        }
    }

    /// 近 30 天負荷比序列。窗與有氧／速度兩頁同一支算（`App2LevelDetailViewModel.window`）
    /// —— 三頁都是「卡片業務日往回 30 天」，不該有第二份日期算術。
    private func fetchSeriesOptional() async -> SeriesOutcome {
        let window = App2LevelDetailViewModel.window(asof: asof)
        do {
            return .ok(try await seriesDataSource.fetchMetricSeries(
                startDay: window.start, endDay: window.end
            ))
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2VolumeDetailVM] metrics/series 取得失敗,不畫負荷比線: \(error)")
            }
            return error.isCancellationError ? .cancelled : .failed
        }
    }

    /// 投影是純函式：快取命中（init／切 range）與網路回來走同一條，hero 永遠吃
    /// 當下的 insight，不會被快取凍住。
    private func publish(_ payload: App2MetricDetailCache.VolumePayload) {
        let bars = App2MetricDetailProjection.bars(payload.stats.data.weeklySeries ?? [])
        detail = App2Sourced(
            App2VolumeDetail(
                hero: Self.hero(insight: insight, narrative: narrative),
                bars: bars,
                targetKm: payload.targetKm,
                stats: App2MetricDetailProjection.volumeStats(
                    bars: bars,
                    ytdKm: payload.stats.data.yearToDate?.distanceKm
                ),
                acwr: payload.series.flatMap(App2MetricDetailProjection.acwrBlock)
            ),
            origin: .live(endpoint:
                "GET /v2/workouts/stats + GET /v2/athlete-state/metrics/series")
        )
    }

    /// 目標週跑量來自本週課表，與課表頁的週目標共用同一份 plan。
    /// 沒有本週課表就 nil —— 不畫目標線，也不退回 profile 值。
    private func targetWeeklyKm() async -> Double? {
        guard let planRepository else { return nil }
        do {
            let status = try await planRepository.getPlanStatus(forceRefresh: true)
            guard let planId = status.currentWeekPlanId else { return nil }
            let plan = try await planRepository.fetchWeeklyPlan(planId: planId)
            guard plan.totalDistance > 0 else { return nil }
            return plan.totalDistance
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2VolumeDetailVM] 本週課表取得失敗,不畫目標線: \(error)")
            }
            return nil
        }
    }

    /// hero 大數字是後端的負荷比（`value_text`，最近一週 ÷ 前四週平均），判語是後端的
    /// `verdict`；上一完整週公里數已在下面的柱狀圖上（2026-09-29 使用者裁決撤回「上週 km」hero）。
    ///
    /// **右側對照整格不畫**（T-0618）：比值旁邊擺公里數會被讀成同一把尺。
    /// 副標是後端組好的 `change`（上一完整週公里數）＋課表敘事，app 不重拼、不另算。
    static func hero(insight: App2Insight, narrative: String?) -> App2MetricHero {
        let lines = [insight.change, narrative].compactMap { line -> String? in
            guard let line, !line.isEmpty else { return nil }
            return line
        }
        return App2MetricHero(
            title: L10n.App2.Metric.volumeHeroTitle.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: nil,
            compareValue: nil,
            narrative: lines.isEmpty ? nil : lines.joined(separator: "\n")
        )
    }
}

// MARK: - App2CapabilityDetailViewModel
/// §52 指標詳情 · 能力基準。
@MainActor
final class App2CapabilityDetailViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var readFailed = false
    @Published private(set) var detail: App2Sourced<App2CapabilityDetail>?
    @Published private(set) var range: App2MetricRange = .days60
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    private let insight: App2Insight
    private let narrative: String?
    private let vdotDataSource: VDOTDataSourceProtocol
    private let seriesDataSource: AthleteStateSeriesDataSourceProtocol
    private let asof: String?
    private let cache: App2MetricDetailCache
    /// 30 天前那天的能力基準（decision-chain 序列的 `center.value`）。nil ＝ 還沒讀到或那天沒有點。
    private var baseline30DaysAgo: Double?
    private var lastPublishedResponse: VDOTResponse?

    init(
        insight: App2Insight,
        narrative: String?,
        asof: String? = nil,
        vdotDataSource: VDOTDataSourceProtocol? = nil,
        seriesDataSource: AthleteStateSeriesDataSourceProtocol? = nil,
        cache: App2MetricDetailCache = .shared
    ) {
        self.insight = insight
        self.narrative = narrative
        self.asof = asof
        self.vdotDataSource = vdotDataSource ?? VDOTService.shared
        self.seriesDataSource = seriesDataSource ?? AthleteStateSeriesRemoteDataSource()
        self.cache = cache
        // 同訓練量 VM：session 快取先出畫面（T-0357）。
        if let entry = cache.capability[range] {
            publish(entry.payload)
            hasLoaded = true
            lastLoadedAt = entry.loadedAt
            isLoading = false
        }
    }

    deinit {
        cancelAllTasks()
    }

    /// 同訓練量 VM：切 range 的重載 task 由 VM 持有，後選取消前選。
    private(set) var rangeReloadTask: Task<Void, Never>?

    /// 同訓練量 VM 的 generation 護欄（2026-09-01 外審 D04）：首載那一輪由 view 的
    /// `.task` 起，只有代號＋requestedRange 相符的回應才能寫快取與發布。
    private var revalidateGeneration = 0

    /// 現任輪的 task（含首載那一輪）。
    private(set) var revalidateRoundTask: Task<Void, Never>?

    func select(range newRange: App2MetricRange) {
        guard newRange != range else { return }
        range = newRange
        // 新 range 有快取先上畫面，revalidate 照跑（切 range 一律重驗）。
        if let entry = cache.capability[newRange] {
            publish(entry.payload)
        }
        invalidateCurrentRound()
        rangeReloadTask?.cancel()
        rangeReloadTask = Task { [weak self] in await self?.revalidate() }
    }

    /// 同訓練量 VM：離開畫面時取消 in-flight 的重驗輪（含首載，外審第十一輪 D04）。
    func cancelInFlightReload() {
        invalidateCurrentRound()
        rangeReloadTask?.cancel()
        rangeReloadTask = nil
    }

    func revalidate() async {
        invalidateCurrentRound()
        let round = revalidateGeneration
        let requestedRange = range
        let roundTask = Task { [weak self] in
            guard let self else { return }
            await self.revalidateRound(round, range: requestedRange)
        }
        revalidateRoundTask = roundTask
        await withTaskCancellationHandler {
            await roundTask.value
        } onCancel: {
            roundTask.cancel()
        }
        if revalidateGeneration == round {
            revalidateRoundTask = nil
        }
    }

    private func revalidateRound(_ round: Int, range requestedRange: App2MetricRange) async {
        // 發請求前記下快取的失效世代（見 `App2MetricDetailCache.invalidationEpoch`）。
        let epoch = cache.invalidationEpoch
        isLoading = !hasLoaded
        var finishedRound = false
        var succeeded = false
        defer {
            // 只有現任輪能收尾（外審 D04）。
            if revalidateGeneration == round {
                isLoading = false
                // 成功或**真失敗**才算載過；取消不標——task 取消與 -999 取消錯誤
                // （提早 return，finishedRound 維持 false）都算取消（2026-08-29 外審 D04/E03）。
                if finishedRound, !Task.isCancelled {
                    hasLoaded = true
                    if succeeded { lastLoadedAt = Date() }
                }
            }
        }

        do {
            let response = try await vdotDataSource.getVDOTs(limit: requestedRange.vdotLimit)
            if Task.isCancelled { return }
            guard isCurrentRound(round, requestedRange) else { return }
            cache.storeIfCurrent(epoch: epoch) { $0.storeCapability(response, range: requestedRange) }
            publish(response)
            await refreshBaseline(round, requestedRange)
            finishedRound = true
            succeeded = true
            readFailed = false
        } catch {
            guard !error.isCancellationError, !Task.isCancelled else { return }
            guard isCurrentRound(round, requestedRange) else { return }
            finishedRound = true
            readFailed = true
            Logger.debug("[App2CapabilityDetailVM] vdots 取得失敗: \(error)")
        }
    }

    /// 同訓練量 VM：代號沒被頂掉，且打的 range 還是畫面上的 range。
    private func isCurrentRound(_ round: Int, _ requestedRange: App2MetricRange) -> Bool {
        revalidateGeneration == round && requestedRange == range
    }

    /// 「30 天前」讀 decision-chain 序列（`metrics/series` 的 `capability_baseline`）那一天的點，
    /// 不再用 `/v2/workouts/vdots`（那是 readiness 流）。讀不到只是少那一格，不擋頁。
    private func refreshBaseline(_ round: Int, _ requestedRange: App2MetricRange) async {
        let end = asof ?? App2MetricDetailProjection.today()
        guard let day = App2MetricDetailProjection.dateString(byAdding: -30, to: end) else { return }
        do {
            let response = try await seriesDataSource.fetchMetricSeries(startDay: day, endDay: day)
            if Task.isCancelled { return }
            guard isCurrentRound(round, requestedRange) else { return }
            baseline30DaysAgo = App2MetricDetailProjection.baselineValue(response, on: day)
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2CapabilityDetailVM] capability_baseline 序列取得失敗,不畫 30 天前: \(error)")
            }
            return
        }
        if let lastPublishedResponse { publish(lastPublishedResponse) }
    }

    /// 同步作廢現任輪：取消它，並**當場**遞增代號。
    /// 只在新輪開跑時才遞增擋不住空窗期——`select(range:)` 取消舊輪到新輪真的
    /// 執行之間，舊輪的 defer 仍會通過代號檢查、清掉現任輪的 loading 態
    /// （2026-09-01 外審第二輪 D04）。
    private func invalidateCurrentRound() {
        revalidateRoundTask?.cancel()
        revalidateRoundTask = nil
        revalidateGeneration += 1
    }

    /// 投影是純函式：快取命中與網路回來走同一條，hero 吃當下的 insight（T-0357）。
    private func publish(_ response: VDOTResponse) {
        lastPublishedResponse = response
        let series = App2MetricDetailProjection.vdotSeries(response.vdots)
        // `vdots` 一條序列同時裝「已經發生的」與「建計畫時生成的未來每日預估」
        // （2026-08-27 晚走查裁決（f））。診斷欄只吃歷史段；hero 的現值是首頁那一列的
        // `value_text`、「30 天前」讀 decision-chain 序列，兩者都不碰這條序列的未來預估。
        let today = App2MetricDetailProjection.today()
        // 診斷欄的來源＝**不晚於今天**的最新一筆。未來預估點的診斷欄是空殼
        // （`daily_count = 0`），拿它當 latest 會把「證據 n = 0」印給用戶
        // （2026-08-29 D9 裁決；dev 實查 8/27 歷史筆 daily_count = 11）。
        let latest = response.vdots
            .filter { App2MetricDetailProjection.isoDate(epochSeconds: $0.datetime) <= today }
            .max { $0.datetime < $1.datetime }
            ?? response.vdots.max { $0.datetime < $1.datetime }
        let split = App2MetricDetailProjection.splitProjected(series, today: today)

        detail = App2Sourced(
            App2CapabilityDetail(
                hero: Self.hero(
                    insight: insight,
                    narrative: narrative,
                    current: insight.value.flatMap(Double.init),
                    previous: baseline30DaysAgo
                ),
                series: series,
                projectedFromIndex: split.projectedFromIndex,
                anchorDate: latest?.anchorDate,
                diagnostics: App2MetricDetailProjection.diagnostics(latest: latest)
            ),
            origin: .live(endpoint: "GET /v2/workouts/vdots")
        )
    }

    /// 右側對照＝「30 天前 / 39.0」。序列不到 30 天長就沒有這一格（畫「–」）。
    static func hero(
        insight: App2Insight,
        narrative: String?,
        current: Double?,
        previous: Double?
    ) -> App2MetricHero {
        var compare: String?
        if let previous {
            let text = String(format: "%.1f", previous)
            if let current {
                compare = String(
                    format: L10n.App2.Metric.capabilityCompareFormat.localized,
                    text,
                    App2MetricDetailProjection.signedLabel(current - previous)
                )
            } else {
                compare = text
            }
        }
        return App2MetricHero(
            title: L10n.App2.Metric.capabilityHeroTitle.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: L10n.App2.Metric.capabilityCompare.localized,
            compareValue: compare,
            narrative: narrative,
            trendText: App2MetricDetailProjection.trendLine(change: insight.change)
        )
    }
}

// MARK: - App2RecoveryDetailViewModel
/// §53 指標詳情 · 恢復。
///
/// **恢復分數本身不畫歷史線**（稿如此）：分數序列沒有讀口，那是已知缺口，
/// 這一頁的設計已經繞開 —— 畫的是 HRV × 靜息心率這兩條有序列的原始事實。
@MainActor
final class App2RecoveryDetailViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var readFailed = false
    @Published private(set) var detail: App2Sourced<App2RecoveryDetail>?
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    /// 設計 §53-2 的 x 軸是「4 週前／2 週前／今晨」。
    private static let windowDays = 28

    private let insight: App2Insight
    private let narrative: String?
    private let healthDataSource: HealthDailyDataSourceProtocol
    private let cache: App2MetricDetailCache

    init(
        insight: App2Insight,
        narrative: String?,
        healthDataSource: HealthDailyDataSourceProtocol? = nil,
        cache: App2MetricDetailCache = .shared
    ) {
        self.insight = insight
        self.narrative = narrative
        self.healthDataSource = healthDataSource ?? HealthDailyRemoteDataSource()
        self.cache = cache
        // 同訓練量 VM：session 快取先出畫面（T-0357）。
        if let entry = cache.recovery {
            publish(entry.payload)
            hasLoaded = true
            lastLoadedAt = entry.loadedAt
            isLoading = false
        }
    }

    deinit {
        cancelAllTasks()
    }

    /// 恢復頁沒有 range tabs，但重驗輪一樣可能重疊（首載 ＋ 背景重驗）：
    /// 同一條 generation 護欄，舊輪不得覆蓋新輪的畫面與快取（2026-09-01 外審 D04）。
    private var revalidateGeneration = 0

    /// 現任輪的 task（含首載那一輪）。
    private(set) var revalidateRoundTask: Task<Void, Never>?

    /// 離開畫面時取消 in-flight 的重驗輪。
    func cancelInFlightReload() {
        invalidateCurrentRound()
    }

    /// 同 range 版的同步作廢（2026-09-01 外審第二輪 D04）。
    private func invalidateCurrentRound() {
        revalidateRoundTask?.cancel()
        revalidateRoundTask = nil
        revalidateGeneration += 1
    }

    func revalidate() async {
        invalidateCurrentRound()
        let round = revalidateGeneration
        let roundTask = Task { [weak self] in
            guard let self else { return }
            await self.revalidateRound(round)
        }
        revalidateRoundTask = roundTask
        await withTaskCancellationHandler {
            await roundTask.value
        } onCancel: {
            roundTask.cancel()
        }
        if revalidateGeneration == round {
            revalidateRoundTask = nil
        }
    }

    private func revalidateRound(_ round: Int) async {
        // 發請求前記下快取的失效世代（見 `App2MetricDetailCache.invalidationEpoch`）。
        let epoch = cache.invalidationEpoch
        isLoading = !hasLoaded
        var finishedRound = false
        var succeeded = false
        defer {
            // 只有現任輪能收尾（外審 D04）。
            if revalidateGeneration == round {
                isLoading = false
                // 成功或**真失敗**才算載過；取消不標——task 取消與 -999 取消錯誤
                // （提早 return，finishedRound 維持 false）都算取消（2026-08-29 外審 D04/E03）。
                if finishedRound, !Task.isCancelled {
                    hasLoaded = true
                    if succeeded { lastLoadedAt = Date() }
                }
            }
        }

        do {
            let response = try await healthDataSource.fetchHealthDaily(limit: Self.windowDays)
            if Task.isCancelled { return }
            guard revalidateGeneration == round else { return }
            cache.storeIfCurrent(epoch: epoch) { $0.storeRecovery(response) }
            publish(response)
            finishedRound = true
            succeeded = true
            readFailed = false
        } catch {
            guard !error.isCancellationError, !Task.isCancelled else { return }
            guard revalidateGeneration == round else { return }
            finishedRound = true
            readFailed = true
            Logger.debug("[App2RecoveryDetailVM] health_daily 取得失敗: \(error)")
        }
    }

    /// 投影是純函式：快取命中與網路回來走同一條，hero 吃當下的 insight（T-0357）。
    private func publish(_ response: HealthDailyResponse) {
        let records = response.healthData
        let hrv = App2MetricDetailProjection.healthSeries(records) { $0.hrvLastNightAvg }
        let rhr = App2MetricDetailProjection.healthSeries(records) { $0.restingHeartRate.map(Double.init) }

        detail = App2Sourced(
            App2RecoveryDetail(
                hero: Self.hero(insight: insight, narrative: narrative),
                hrv: hrv,
                restingHR: rhr,
                stats: App2MetricDetailProjection.recoveryStats(hrv: hrv, restingHR: rhr)
            ),
            origin: .live(endpoint: "GET /v2/workouts/health_daily")
        )
    }

    /// 「7 日基線」目前**沒有 producer**：恢復分數只有當下值，沒有序列端點
    /// （`DESIGN-app2-metric-drilldown-data-inventory.md` 總表已記為缺口）。
    /// 所以整格不畫（不畫一個「–」）。**不拿 HRV 基線冒充分數基線**（量綱都不同）。
    static func hero(insight: App2Insight, narrative: String?) -> App2MetricHero {
        App2MetricHero(
            title: L10n.App2.Metric.recoveryHeroTitle.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: nil,
            compareValue: nil,
            narrative: narrative,
            trendText: App2MetricDetailProjection.trendLine(change: insight.change)
        )
    }
}

// MARK: - App2LevelDetailViewModel
/// 有氧續航／速度耐力詳情頁的 30 天線（SPEC-today-state §4.5，T-0617）。
///
/// **只有這一頁打序列**：首頁不因為這條多任何查詢，卡片本身也不帶序列。
/// 窗固定 30 天（先觀察 SQL 壓力再決定要不要放寬），右端是卡片的 `asof`
/// ——使用者當地業務日，不是裝置日期。
///
/// 讀不到就是空序列：頁面畫佔位，hero／分級尺／依據句照常在。線是這一頁的補充，
/// 不是它的前提。
@MainActor
final class App2LevelDetailViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var readFailed = false
    @Published private(set) var detail: App2Sourced<App2LevelDetail>?
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    /// 先固定 30 天（SPEC-today-state §4.5）。
    static let windowDays = 30

    private let itemKey: String
    private let asof: String?
    private let dataSource: AthleteStateSeriesDataSourceProtocol

    init(
        itemKey: String,
        asof: String?,
        dataSource: AthleteStateSeriesDataSourceProtocol? = nil
    ) {
        self.itemKey = itemKey
        self.asof = asof
        self.dataSource = dataSource ?? AthleteStateSeriesRemoteDataSource()
    }

    deinit {
        cancelAllTasks()
    }

    private var revalidateGeneration = 0
    private(set) var revalidateRoundTask: Task<Void, Never>?

    func cancelInFlightReload() {
        invalidateCurrentRound()
    }

    private func invalidateCurrentRound() {
        revalidateRoundTask?.cancel()
        revalidateRoundTask = nil
        revalidateGeneration += 1
    }

    func revalidate() async {
        invalidateCurrentRound()
        let round = revalidateGeneration
        let roundTask = Task { [weak self] in
            guard let self else { return }
            await self.revalidateRound(round)
        }
        revalidateRoundTask = roundTask
        await withTaskCancellationHandler {
            await roundTask.value
        } onCancel: {
            roundTask.cancel()
        }
        if revalidateGeneration == round {
            revalidateRoundTask = nil
        }
    }

    private func revalidateRound(_ round: Int) async {
        isLoading = !hasLoaded
        var finishedRound = false
        var succeeded = false
        defer {
            if revalidateGeneration == round {
                isLoading = false
                if finishedRound, !Task.isCancelled {
                    hasLoaded = true
                    if succeeded { lastLoadedAt = Date() }
                }
            }
        }

        let window = Self.window(asof: asof)
        do {
            let response = try await dataSource.fetchMetricSeries(
                startDay: window.start, endDay: window.end
            )
            if Task.isCancelled { return }
            guard revalidateGeneration == round else { return }
            let points = App2MetricDetailProjection.levelSeries(response, key: itemKey)
            detail = App2Sourced(
                App2LevelDetail(series: points),
                origin: .live(endpoint: "GET /v2/athlete-state/metrics/series")
            )
            finishedRound = true
            succeeded = true
            readFailed = false
        } catch {
            guard !error.isCancellationError, !Task.isCancelled else { return }
            guard revalidateGeneration == round else { return }
            finishedRound = true
            readFailed = true
            // 保留上次結果；失敗與空序列是兩種可觀察狀態。
            Logger.debug("[App2LevelDetailVM] metrics/series 取得失敗: \(error)")
        }
    }

    /// `asof − 29` … `asof`。卡片沒帶 `asof`（舊版後端）才退裝置當地日 ——
    /// 那是最後手段，跨時區會差一天。
    ///
    /// 日期算術用 `App2MetricDetailProjection` 既有的兩支（`today`／`dateString`），
    /// 不在這裡再開一份 `DateFormatter`。
    static func window(asof: String?, days: Int = windowDays) -> (start: String, end: String) {
        let end = asof ?? App2MetricDetailProjection.today()
        let start = App2MetricDetailProjection.dateString(byAdding: -(days - 1), to: end) ?? end
        return (start, end)
    }
}
