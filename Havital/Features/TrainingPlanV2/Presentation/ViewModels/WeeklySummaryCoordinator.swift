import Foundation
import Observation

// MARK: - WeeklySummaryCoordinator

/// Coordinator for weekly summary loading, generation, and display.
/// Cross-boundary state is accessed exclusively through injected closures — no direct parent reference.
@MainActor
@Observable
final class WeeklySummaryCoordinator {

    // MARK: - Observable State

    var weeklySummary: ViewState<WeeklySummaryV2> = .loading
    var weeklySummaries: [WeeklySummaryItem] = []
    var showWeeklySummary: Bool = false
    var isGeneratingSummary: Bool = false
    var isLoadingWeeklySummary: Bool = false
    var adjustmentSelections: [Int: Bool] = [:]

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
        isEnforcementEnabled: @escaping () -> Bool
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
    func loadWeeklySummary(weekOfPlan: Int) async {
        Logger.debug("[WeeklySummaryCoordinator] 載入第 \(weekOfPlan) 週摘要...")

        lastRequestedSummaryWeek = weekOfPlan
        weeklySummary = .loading

        do {
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

        lastRequestedSummaryWeek = week
        isGeneratingSummary = true
        isLoadingWeeklySummary = true
        setLoadingAnimation(true)

        if await shouldBlockByRizoQuota() {
            onRizoQuotaExceeded()
            stopLoadingAnimation()
            return
        }

        do {
            let summary = try await repository.generateWeeklySummary(weekOfPlan: week, forceUpdate: false)

            weeklySummary = .loaded(summary)
            initializeSelections(from: summary.nextWeekAdjustments.items)

            // 趁 loading sheet 還在時先更新 planStatusResponse
            await refreshPlanStatusResponse()

            // 關閉 loading sheet，等待 dismiss 動畫完成，再開啟 summary sheet
            stopLoadingAnimation()
            try await Task.sleep(nanoseconds: 600_000_000)

            showWeeklySummary = true

            Logger.info("[WeeklySummaryCoordinator] ✅ 週摘要產生成功，顯示 sheet")
        } catch {
            stopLoadingAnimation()
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                if isEnforcementEnabled() {
                    onPaywallTriggered(resolvePaywallTrigger())
                }
            case .rizoQuotaExceeded:
                onRizoQuotaExceeded()
            default:
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
    /// 用於查看已產生的歷史週回顧，不會重新產生
    func viewHistoricalSummary(week: Int) async {
        Logger.debug("[WeeklySummaryCoordinator] 查看第 \(week) 週的歷史回顧...")

        lastRequestedSummaryWeek = week
        do {
            let summary = try await repository.getWeeklySummary(weekOfPlan: week)
            self.weeklySummary = .loaded(summary)
            initializeSelections(from: summary.nextWeekAdjustments.items)
            self.showWeeklySummary = true
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
            showWeeklySummary = true
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
