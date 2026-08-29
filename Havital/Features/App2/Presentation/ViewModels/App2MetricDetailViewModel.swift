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
    @Published private(set) var detail: App2Sourced<App2VolumeDetail>?
    @Published private(set) var range: App2MetricRange = .weeks8
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    private let insight: App2Insight
    private let narrative: String?
    private let workoutDataSource: WorkoutStatsDataSourceProtocol
    private let healthDataSource: HealthDailyDataSourceProtocol
    private let profileRepository: UserProfileRepository?

    /// TSB 折線要看得出「疲勞累積」的形狀，60 天是設計 §51-6 x 軸跨度（6/23～本週）。
    private static let loadWindowDays = 60

    init(
        insight: App2Insight,
        narrative: String?,
        workoutDataSource: WorkoutStatsDataSourceProtocol? = nil,
        healthDataSource: HealthDailyDataSourceProtocol? = nil,
        profileRepository: UserProfileRepository? = nil
    ) {
        self.insight = insight
        self.narrative = narrative
        self.workoutDataSource = workoutDataSource ?? WorkoutRemoteDataSource()
        self.healthDataSource = healthDataSource ?? HealthDailyRemoteDataSource()
        if let profileRepository {
            self.profileRepository = profileRepository
        } else {
            let container = DependencyContainer.shared
            // 目標週跑量住在 profile（`current_week_distance`，＝訓練設定那顆旋鈕）。
            // 沒註冊就不強行註冊——那時只是少一條目標線，不該讓整頁掛掉。
            self.profileRepository = container.isRegistered(UserProfileRepository.self)
                ? (container.resolve() as UserProfileRepository)
                : nil
        }
    }

    deinit {
        cancelAllTasks()
    }

    func select(range newRange: App2MetricRange) {
        guard newRange != range else { return }
        range = newRange
        Task { [weak self] in await self?.revalidate() }
    }

    func revalidate() async {
        isLoading = !hasLoaded
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

        do {
            let stats = try await workoutDataSource.fetchWorkoutStats(
                days: 30,
                weeks: range.weeksParameter()
            )
            // 訓練負荷與目標線各自可缺席：**真失敗**只是少那一塊；取消（含 -999
            // 取消錯誤，Task.isCancelled 可能是 false）＝整輪作廢不發布（外審 E03）。
            let health: HealthDailyResponse?
            do {
                health = try await healthDataSource.fetchHealthDaily(limit: Self.loadWindowDays)
            } catch {
                guard !error.isCancellationError else { return }
                health = nil
            }
            let targetKm = await targetWeeklyKm()

            if Task.isCancelled { return }

            let bars = App2MetricDetailProjection.bars(stats.data.weeklySeries ?? [])
            detail = App2Sourced(
                App2VolumeDetail(
                    hero: Self.hero(insight: insight, narrative: narrative, targetKm: targetKm),
                    bars: bars,
                    targetKm: targetKm,
                    stats: App2MetricDetailProjection.volumeStats(
                        bars: bars,
                        ytdKm: stats.data.yearToDate?.distanceKm
                    ),
                    load: App2MetricDetailProjection.loadBlock(health?.healthData ?? [])
                ),
                origin: .live(endpoint: "GET /v2/workouts/stats + GET /v2/workouts/health_daily")
            )
            finishedRound = true
        } catch {
            guard !error.isCancellationError else { return }
            finishedRound = true
            Logger.debug("[App2VolumeDetailVM] stats 取得失敗: \(error)")
        }
    }

    /// 目標週跑量（`current_week_distance`）。讀不到就 nil —— 不畫目標線，也不編一個。
    private func targetWeeklyKm() async -> Double? {
        guard let profileRepository else { return nil }
        do {
            let user = try await profileRepository.getUserProfile()
            guard let km = user.currentWeekDistance, km > 0 else { return nil }
            return Double(km)
        } catch {
            if !error.isCancellationError {
                Logger.debug("[App2VolumeDetailVM] profile 取得失敗,不畫目標線: \(error)")
            }
            return nil
        }
    }

    static func hero(insight: App2Insight, narrative: String?, targetKm: Double?) -> App2MetricHero {
        App2MetricHero(
            title: L10n.App2.Metric.volumeHeroTitle.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: L10n.App2.Metric.volumeTarget.localized,
            compareValue: targetKm.map { App2MetricDetailProjection.kmLabel($0) },
            narrative: narrative
        )
    }
}

// MARK: - App2CapabilityDetailViewModel
/// §52 指標詳情 · 能力基準。
@MainActor
final class App2CapabilityDetailViewModel: ObservableObject, TaskManageable, App2Revalidating {

    @Published private(set) var isLoading = true
    @Published private(set) var detail: App2Sourced<App2CapabilityDetail>?
    @Published private(set) var range: App2MetricRange = .days60
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    private let insight: App2Insight
    private let narrative: String?
    private let vdotDataSource: VDOTDataSourceProtocol

    init(
        insight: App2Insight,
        narrative: String?,
        vdotDataSource: VDOTDataSourceProtocol? = nil
    ) {
        self.insight = insight
        self.narrative = narrative
        self.vdotDataSource = vdotDataSource ?? VDOTService.shared
    }

    deinit {
        cancelAllTasks()
    }

    func select(range newRange: App2MetricRange) {
        guard newRange != range else { return }
        range = newRange
        Task { [weak self] in await self?.revalidate() }
    }

    func revalidate() async {
        isLoading = !hasLoaded
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

        do {
            let response = try await vdotDataSource.getVDOTs(limit: range.vdotLimit)
            let series = App2MetricDetailProjection.vdotSeries(response.vdots)
            // `vdots` 一條序列同時裝「已經發生的」與「建計畫時生成的未來每日預估」
            // （2026-08-27 晚走查裁決（f））。hero 的現值與「30 天前」**只吃歷史段**
            // —— 之前取 `series.last` 等於把賽事日的預估值當成「目前跑力」顯示。
            let today = App2MetricDetailProjection.today()
            // 診斷欄的來源＝**不晚於今天**的最新一筆。未來預估點的診斷欄是空殼
            // （`daily_count = 0`），拿它當 latest 會把「證據 n = 0」印給用戶
            // （2026-08-29 D9 裁決；dev 實查 8/27 歷史筆 daily_count = 11）。
            let latest = response.vdots
                .filter { App2MetricDetailProjection.isoDate(epochSeconds: $0.datetime) <= today }
                .max { $0.datetime < $1.datetime }
                ?? response.vdots.max { $0.datetime < $1.datetime }
            let split = App2MetricDetailProjection.splitProjected(series, today: today)
            let previous = App2MetricDetailProjection.value(
                in: split.history,
                daysAgo: 30,
                from: today
            )

            detail = App2Sourced(
                App2CapabilityDetail(
                    hero: Self.hero(
                        insight: insight,
                        narrative: narrative,
                        current: split.history.last?.value,
                        previous: previous
                    ),
                    series: series,
                    projectedFromIndex: split.projectedFromIndex,
                    anchorDate: latest?.anchorDate,
                    diagnostics: App2MetricDetailProjection.diagnostics(latest: latest)
                ),
                origin: .live(endpoint: "GET /v2/workouts/vdots")
            )
            finishedRound = true
        } catch {
            guard !error.isCancellationError else { return }
            finishedRound = true
            Logger.debug("[App2CapabilityDetailVM] vdots 取得失敗: \(error)")
        }
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
            narrative: narrative
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
    @Published private(set) var detail: App2Sourced<App2RecoveryDetail>?
    private(set) var hasLoaded = false
    private(set) var lastLoadedAt: Date?

    nonisolated let taskRegistry = TaskRegistry()

    /// 設計 §53-2 的 x 軸是「4 週前／2 週前／今晨」。
    private static let windowDays = 28

    private let insight: App2Insight
    private let narrative: String?
    private let healthDataSource: HealthDailyDataSourceProtocol

    init(
        insight: App2Insight,
        narrative: String?,
        healthDataSource: HealthDailyDataSourceProtocol? = nil
    ) {
        self.insight = insight
        self.narrative = narrative
        self.healthDataSource = healthDataSource ?? HealthDailyRemoteDataSource()
    }

    deinit {
        cancelAllTasks()
    }

    func revalidate() async {
        isLoading = !hasLoaded
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

        do {
            let response = try await healthDataSource.fetchHealthDaily(limit: Self.windowDays)
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
            finishedRound = true
        } catch {
            guard !error.isCancellationError else { return }
            finishedRound = true
            Logger.debug("[App2RecoveryDetailVM] health_daily 取得失敗: \(error)")
        }
    }

    /// 「7 日基線」目前**沒有 producer**：恢復分數只有當下值，沒有序列端點
    /// （`DESIGN-app2-metric-drilldown-data-inventory.md` 總表已記為缺口）。
    /// 所以這一格恆為 nil → 畫「–」。**不拿 HRV 基線冒充分數基線**（量綱都不同）。
    static func hero(insight: App2Insight, narrative: String?) -> App2MetricHero {
        App2MetricHero(
            title: L10n.App2.Metric.recoveryHeroTitle.localized,
            valueText: insight.value,
            verdict: insight.verdict,
            direction: insight.direction,
            compareLabel: L10n.App2.Metric.recoveryBaseline.localized,
            compareValue: nil,
            narrative: narrative
        )
    }
}
