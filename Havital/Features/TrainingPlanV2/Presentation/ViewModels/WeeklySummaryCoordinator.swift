import Foundation
import Observation

// MARK: - WeeklySummaryCoordinator

/// Coordinator for weekly summary loading, generation, and display.
/// Cross-boundary state is accessed exclusively through injected closures — no direct parent reference.
@MainActor
@Observable
final class WeeklySummaryCoordinator {

    // MARK: - Flow Phase

    enum SummaryFlowPhase {
        case loadingReview
        case showingSummary
        case loadingPlan
    }

    // MARK: - Observable State

    var weeklySummary: ViewState<WeeklySummaryV2> = .loading
    var weeklySummaries: [WeeklySummaryItem] = []
    var summaryFlowActive: Bool = false
    var summaryFlowPhase: SummaryFlowPhase = .loadingReview
    var isGeneratingSummary: Bool = false
    var isLoadingWeeklySummary: Bool = false
    var adjustmentSelections: [Int: Bool] = [:]

    // MARK: - AC-IOS-ANALYTICS-P1-11: session-level dedup for weekly_summary_view
    var hasTrackedWeeklySummaryView: Bool = false

    // MARK: - AC-IOS-ANALYTICS-P1-13: independent dedup for race_prediction_view
    var hasTrackedRacePredictionView: Bool = false

    /// The week the UI most recently asked this coordinator to show / generate a summary for.
    /// Used as the authoritative fallback when `weeklySummary` is not `.loaded`
    /// (error, empty, in-flight) so the sheet header never drifts to `currentWeek - 1`
    /// in the Sunday-generates-current-week-summary scenario.
    var lastRequestedSummaryWeek: Int?

    // MARK: - Dependencies

    @ObservationIgnored private let repository: TrainingPlanV2Repository
    @ObservationIgnored private let currentSelectedWeek: () -> Int
    @ObservationIgnored private let setLoadingAnimation: (Bool) -> Void
    @ObservationIgnored private let shouldBlockByRizoQuota: () async -> Bool
    @ObservationIgnored private let refreshPlanStatusResponse: () async -> Void
    @ObservationIgnored private let shouldSuppressError: (DomainError, String, (() -> Void)?) -> Bool
    @ObservationIgnored private let resolvePaywallTrigger: () -> PaywallTrigger
    @ObservationIgnored private let onSuccessToast: (String) -> Void
    @ObservationIgnored private let onPaywallTriggered: (PaywallTrigger) -> Void
    @ObservationIgnored private let onRizoQuotaExceeded: () -> Void
    @ObservationIgnored private let onNetworkError: (Error) -> Void
    @ObservationIgnored private let isEnforcementEnabled: () -> Bool
    /// S07 (AC-PAYWALL-23): called when weekly review is triggered without a subscription.
    @ObservationIgnored private let onWeeklyReviewInlineUpsellNeeded: (() -> Void)?

    // MARK: - Init

    init(
        repository: TrainingPlanV2Repository,
        currentSelectedWeek: @escaping () -> Int,
        setLoadingAnimation: @escaping (Bool) -> Void,
        shouldBlockByRizoQuota: @escaping () async -> Bool,
        refreshPlanStatusResponse: @escaping () async -> Void,
        shouldSuppressError: @escaping (DomainError, String, (() -> Void)?) -> Bool,
        resolvePaywallTrigger: @escaping () -> PaywallTrigger,
        onSuccessToast: @escaping (String) -> Void,
        onPaywallTriggered: @escaping (PaywallTrigger) -> Void,
        onRizoQuotaExceeded: @escaping () -> Void,
        onNetworkError: @escaping (Error) -> Void,
        isEnforcementEnabled: @escaping () -> Bool,
        onWeeklyReviewInlineUpsellNeeded: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.currentSelectedWeek = currentSelectedWeek
        self.setLoadingAnimation = setLoadingAnimation
        self.shouldBlockByRizoQuota = shouldBlockByRizoQuota
        self.refreshPlanStatusResponse = refreshPlanStatusResponse
        self.shouldSuppressError = shouldSuppressError
        self.resolvePaywallTrigger = resolvePaywallTrigger
        self.onSuccessToast = onSuccessToast
        self.onPaywallTriggered = onPaywallTriggered
        self.onRizoQuotaExceeded = onRizoQuotaExceeded
        self.onNetworkError = onNetworkError
        self.isEnforcementEnabled = isEnforcementEnabled
        self.onWeeklyReviewInlineUpsellNeeded = onWeeklyReviewInlineUpsellNeeded
    }

    // MARK: - AC-IOS-ANALYTICS mark methods

    /// Track weekly_summary_view once per sheet presentation (dedup by hasTrackedWeeklySummaryView).
    func markSummaryTracked(summaryId: String, weekOfTraining: Int) {
        guard !hasTrackedWeeklySummaryView else { return }
        hasTrackedWeeklySummaryView = true
        let analyticsService: AnalyticsService = DependencyContainer.shared.resolve()
        analyticsService.track(.weeklySummaryView(summaryId: summaryId, weekOfTraining: weekOfTraining))
    }

    /// Track race_prediction_view once per sheet presentation, independent from P1-11 dedup.
    /// Guard uses its own hasTrackedRacePredictionView so a late-arriving planOverview can still fire.
    func markRacePredictionTracked(predictedTime: String, distanceKm: Double) {
        guard !hasTrackedRacePredictionView else { return }
        hasTrackedRacePredictionView = true
        let analyticsService: AnalyticsService = DependencyContainer.shared.resolve()
        analyticsService.track(.racePredictionView(predictedTime: predictedTime, distanceKm: distanceKm))
    }

    // MARK: - Adjustment Selection State

    var selectedCount: Int {
        adjustmentSelections.values.filter { $0 }.count
    }

    var selectedIndices: [Int] {
        adjustmentSelections.filter { $0.value }.map { $0.key }.sorted()
    }

    func initializeSelections(from items: [AdjustmentItemV2]) {
        adjustmentSelections = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.offset, $0.element.apply) })
    }

    func toggleAdjustment(at index: Int) {
        adjustmentSelections[index] = !(adjustmentSelections[index] ?? true)
    }

    func resetSelectionsToDefaults() {
        guard case .loaded(let summary) = weeklySummary else { return }
        initializeSelections(from: summary.nextWeekAdjustments.items)
    }

    func applySelectedAdjustments(weekOfPlan: Int) async -> Bool {
        // AC-WKADJ-04：空陣列 = 全不套用。即使使用者把調整項全部取消勾選
        // （selectedIndices 為空），也必須送出 applied_indices=[] 讓後端撤銷既有採納，
        // 否則舊的休息週採納不會被清除、下週仍會觸發。
        // adjustmentSelections 由 initializeSelections 依建議項數建立；全部取消只是 value 全 false，
        // keys 仍在（非空）。僅在「根本沒有調整項」時 adjustmentSelections 才為空 → 略過送出。
        guard !adjustmentSelections.isEmpty else { return true }
        do {
            try await repository.applyAdjustmentItems(weekOfPlan: weekOfPlan, appliedIndices: selectedIndices)
            return true
        } catch {
            let domainError = error.toDomainError()
            Logger.error("[WeeklySummaryCoordinator] ❌ apply-items 失敗: \(domainError.localizedDescription)")
            onNetworkError(domainError)
            return false
        }
    }

    // MARK: - Public Methods

    /// 載入週摘要
    ///
    /// - Parameter allowGenerate: 那一週沒有回顧時，可不可以順手產一份。
    ///   `true`（預設，1.4 既有行為）走 `getWeeklySummary` 的 404 → POST fallback；
    ///   `false` 走**唯讀**的 `fetchWeeklySummary`，沒有就是 `.empty`。
    ///
    ///   **會有這個開關是因為「讀」不該變成「寫」**（T-0362）：後端的產生視窗
    ///   （`core/training_rules/plan_generation_window.py`）未開時，那個 fallback
    ///   送出的是必然回 400 的請求；而歷史週唯讀回看時它會在使用者沒要求的情況下
    ///   花掉一次 LLM 並寫進那一週。呼叫端知道視窗開不開，這裡不自己判。
    func loadWeeklySummary(weekOfPlan: Int, allowGenerate: Bool = true) async {
        Logger.debug("[WeeklySummaryCoordinator] 載入第 \(weekOfPlan) 週摘要（allowGenerate=\(allowGenerate)）...")

        lastRequestedSummaryWeek = weekOfPlan
        weeklySummary = .loading

        do {
            guard allowGenerate else {
                if let summary = try await repository.fetchWeeklySummary(weekOfPlan: weekOfPlan) {
                    weeklySummary = .loaded(summary)
                    initializeSelections(from: summary.nextWeekAdjustments.items)
                    Logger.debug("[WeeklySummaryCoordinator] ✅ 週摘要載入成功（唯讀）: \(summary.id)")
                } else {
                    Logger.debug("[WeeklySummaryCoordinator] 第 \(weekOfPlan) 週還沒有回顧（唯讀，不生成）")
                    weeklySummary = .empty
                }
                return
            }
            let summary = try await repository.getWeeklySummary(weekOfPlan: weekOfPlan)
            weeklySummary = .loaded(summary)
            initializeSelections(from: summary.nextWeekAdjustments.items)
            Logger.debug("[WeeklySummaryCoordinator] ✅ 週摘要載入成功: \(summary.id)")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "週摘要載入", { [weak self] in self?.weeklySummary = .empty }) { return }
            Logger.error("[WeeklySummaryCoordinator] ❌ 週摘要載入失敗: \(domainError.localizedDescription)")
            weeklySummary = .error(domainError)
        }
    }

    /// 產生週摘要
    func generateWeeklySummary() async {
        let selectedWeek = currentSelectedWeek()
        Logger.debug("[WeeklySummaryCoordinator] 產生第 \(selectedWeek) 週摘要...")

        // S07 gating: check subscription before executing (AC-PAYWALL-23/27)
        if isEnforcementEnabled(),
           !SubscriptionStateManager.shared.hasPremiumAccess {
            onWeeklyReviewInlineUpsellNeeded?()
            Logger.debug("[WeeklySummaryCoordinator] ⛔ 週回顧被 gate：顯示 weekly_review inline upsell card")
            return
        }

        lastRequestedSummaryWeek = selectedWeek
        weeklySummary = .loading

        if await shouldBlockByRizoQuota() {
            self.weeklySummary = .empty
            onRizoQuotaExceeded()
            return
        }

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: selectedWeek, forceUpdate: true)
            weeklySummary = .loaded(summary)
            initializeSelections(from: summary.nextWeekAdjustments.items)
            onSuccessToast("週回顧已產生")
            Logger.info("[WeeklySummaryCoordinator] ✅ 週摘要產生成功: \(summary.id)")
        } catch {
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                if isEnforcementEnabled() {
                    onPaywallTriggered(resolvePaywallTrigger())
                } else {
                    weeklySummary = .error(domainError)
                }
            case .rizoQuotaExceeded:
                onRizoQuotaExceeded()
            default:
                if shouldSuppressError(domainError, "週摘要產生", { [weak self] in self?.weeklySummary = .empty }) { return }
                Logger.error("[WeeklySummaryCoordinator] ❌ 週摘要產生失敗: \(domainError.localizedDescription)")
                weeklySummary = .error(domainError)
            }
        }
    }

    /// 產生週摘要並顯示 sheet（用於 needsWeeklySummary 流程）
    /// Week 2+ 必須先產生 summary，才能產生下週課表
    func createWeeklySummaryAndShow(week: Int) async {
        Logger.debug("[WeeklySummaryCoordinator] 產生第 \(week) 週摘要並顯示...")

        // S07 gating: check subscription before executing (AC-PAYWALL-23/27)
        if isEnforcementEnabled(),
           !SubscriptionStateManager.shared.hasPremiumAccess {
            onWeeklyReviewInlineUpsellNeeded?()
            Logger.debug("[WeeklySummaryCoordinator] ⛔ 週回顧 sheet 被 gate：顯示 weekly_review inline upsell card")
            return
        }

        lastRequestedSummaryWeek = week
        isGeneratingSummary = true
        isLoadingWeeklySummary = true
        summaryFlowPhase = .loadingReview
        summaryFlowActive = true

        if await shouldBlockByRizoQuota() {
            onRizoQuotaExceeded()
            summaryFlowActive = false
            stopLoadingAnimation()
            return
        }

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: week, forceUpdate: false)

            weeklySummary = .loaded(summary)
            initializeSelections(from: summary.nextWeekAdjustments.items)

            await refreshPlanStatusResponse()

            // 不 dismiss sheet，直接切換 phase（零閃爍）
            summaryFlowPhase = .showingSummary
            stopLoadingAnimation()

            Logger.info("[WeeklySummaryCoordinator] ✅ 週摘要產生成功，顯示 sheet")
        } catch {
            stopLoadingAnimation()
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                if isEnforcementEnabled() {
                    // Do NOT dismiss the loading sheet here. The View dismisses it and then
                    // presents the paywall in the sheet's onDismiss, so the paywall (which is
                    // hosted in a different view hierarchy via InterruptHost) is presented only
                    // after this sheet has fully torn down. Dismissing here and enqueuing the
                    // paywall in the same tick caused a cross-view race where the paywall could
                    // not be closed.
                    onPaywallTriggered(resolvePaywallTrigger())
                } else {
                    summaryFlowActive = false
                }
            case .rizoQuotaExceeded:
                summaryFlowActive = false
                onRizoQuotaExceeded()
            default:
                summaryFlowActive = false
                if shouldSuppressError(domainError, "週摘要產生", { [weak self] in self?.weeklySummary = .empty }) { return }
                Logger.error("[WeeklySummaryCoordinator] ❌ 週摘要產生失敗: \(domainError.localizedDescription)")
                onNetworkError(domainError)
            }
        }
    }

    /// 獲取所有週摘要列表（共用 V1 endpoint，用於判斷各週是否有課表/回顧）
    func fetchWeeklySummaries() async {
        Logger.debug("[WeeklySummaryCoordinator] fetchWeeklySummaries...")
        do {
            let items = try await repository.getWeeklySummaries()
            self.weeklySummaries = items
            Logger.info("[WeeklySummaryCoordinator] ✅ fetchWeeklySummaries: \(items.count) items")
        } catch {
            Logger.error("[WeeklySummaryCoordinator] ⚠️ fetchWeeklySummaries failed (non-critical): \(error)")
        }
    }

    /// 查看歷史週回顧（從 Toolbar Menu 觸發）
    ///
    /// **唯讀**：歷史週的回顧只讀存檔，任何路徑都不得觸發生成
    /// （2026-09-01 使用者裁決：「然後歷史週回顧也不該重新產生啊」）。
    ///
    /// 這支的註解一直寫著「不會重新產生」，但它走的是 `getWeeklySummary`
    /// ——那支在 404 時 fallback 到 `POST`（`fetchOrGenerateWeeklySummary`），
    /// 所以「只是打開一份歷史回顧」會在使用者沒要求的情況下對過去那一週補生成一份。
    /// 改走 T-0362 建立的唯讀 `fetchWeeklySummary`（同端點、同快取，只是不接
    /// 那個 fallback），讓實作對上它自己宣稱的語意。
    func viewHistoricalSummary(week: Int) async {
        Logger.debug("[WeeklySummaryCoordinator] 查看第 \(week) 週的歷史回顧（唯讀）...")

        lastRequestedSummaryWeek = week
        do {
            guard let summary = try await repository.fetchWeeklySummary(weekOfPlan: week) else {
                // 那一週沒有回顧就是沒有——不補生成，也不是錯誤。
                Logger.debug("[WeeklySummaryCoordinator] 第 \(week) 週沒有歷史回顧（唯讀，不生成）")
                self.weeklySummary = .empty
                self.summaryFlowPhase = .showingSummary
                self.summaryFlowActive = true
                return
            }
            self.weeklySummary = .loaded(summary)
            initializeSelections(from: summary.nextWeekAdjustments.items)
            self.summaryFlowPhase = .showingSummary
            self.summaryFlowActive = true
            Logger.info("[WeeklySummaryCoordinator] ✅ 歷史週回顧載入成功，顯示 sheet")
        } catch {
            let domainError = error.toDomainError()
            if shouldSuppressError(domainError, "歷史週回顧載入", { [weak self] in self?.weeklySummary = .empty }) { return }
            Logger.error("[WeeklySummaryCoordinator] ❌ 歷史週回顧載入失敗: \(domainError.localizedDescription)")
            onNetworkError(domainError)
        }
    }

    // MARK: - Debug Actions

    /// 在任何時間強制產生週回顧（Debug only）
    func debugGenerateForWeek(_ week: Int, onSuccess: @escaping (String) -> Void, onNetworkError: @escaping (Error) -> Void) async {
        Logger.debug("[WeeklySummaryCoordinator] 🐛 [DEBUG] Generating weekly summary for week \(week)")
        lastRequestedSummaryWeek = week
        isLoadingWeeklySummary = true
        setLoadingAnimation(true)

        do {
            let generated = try await repository.generateWeeklySummary(weekOfPlan: week, forceUpdate: true)
            setLoadingAnimation(false)
            isLoadingWeeklySummary = false
            weeklySummary = .loaded(generated)
            summaryFlowPhase = .showingSummary
            summaryFlowActive = true
            onSuccess("✅ [DEBUG] 週回顧已產生: week \(week)")
            Logger.info("[WeeklySummaryCoordinator] ✅ [DEBUG] Weekly summary generated: \(generated.id)")
        } catch {
            let domainError = error.toDomainError()
            setLoadingAnimation(false)
            isLoadingWeeklySummary = false
            if shouldSuppressError(domainError, "[DEBUG] 週摘要產生", { [weak self] in self?.weeklySummary = .empty }) { return }
            Logger.error("[WeeklySummaryCoordinator] ❌ [DEBUG] Failed to generate weekly summary: \(domainError.localizedDescription)")
            onNetworkError(domainError)
        }
    }

    // MARK: - Private Helpers

    private func stopLoadingAnimation() {
        setLoadingAnimation(false)
        isLoadingWeeklySummary = false
        isGeneratingSummary = false
    }
}
