import Combine
import Foundation
import Observation

// MARK: - TrainingPlanV2 ViewModel
/// Orchestrates WeeklyPlanLoader, WeeklyPlanGenerator, WeeklySummaryCoordinator, MethodologyCoordinator.
/// Owns parent-level state only: toasts, paywall, loading animation, error banners.
@MainActor
@Observable
final class TrainingPlanV2ViewModel: TaskManageable {

    // MARK: - Dependencies
    private let repository: TrainingPlanV2Repository
    private let workoutRepository: WorkoutRepository
    private let versionRouter: TrainingVersionRouter
    private let achievementRepository: AchievementRepository
    @ObservationIgnored private var displayBadgeCancellables = Set<AnyCancellable>()

    // MARK: - TaskManageable
    @ObservationIgnored nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Child Coordinators & Loader
    private(set) var loader: WeeklyPlanLoader!
    private(set) var methodology: MethodologyCoordinator!
    var summary: WeeklySummaryCoordinator!
    private(set) var generator: WeeklyPlanGenerator!

    // MARK: - Orchestration State
    var displayBadge: AchievementBadge?
    var networkError: Error?
    var successToast: String?
    var isLoadingAnimation = false
    var paywallTrigger: PaywallTrigger?
    var showRizoQuotaExceededBanner: Bool = false

    // MARK: - AC-IOS-ANALYTICS-P1-09: session-level dedup for weekly_plan_view
    var trackedWeeklyPlanKey: String? = nil

    // MARK: - AC-IOS-ANALYTICS-P1-12: session-level dedup for plan_overview_view
    var hasTrackedPlanOverviewView: Bool = false

    // S07 inline upsell state (AC-PAYWALL-22/23/26)
    // true = show WeeklyPlanInlineUpsellCard in place of the plan content
    var showWeeklyPlanInlineUpsell: Bool = false
    /// Whether the inline card was triggered by a re-generation (true) or first Week 2 (false).
    var weeklyPlanUpsellIsRegenerate: Bool = false
    // true = show WeeklyReviewInlineUpsellCard in place of weekly review
    var showWeeklyReviewInlineUpsell: Bool = false

    // MARK: - Computed Properties

    var isLoading: Bool {
        loader.planStatus == .loading
    }

    var totalWeeks: Int {
        loader.planOverview?.totalWeeks ?? 0
    }

    var upcomingWeeks: [WeekPreview] {
        guard let preview = loader.weeklyPreview else { return [] }
        return Array(
            preview.weeks
                .filter { $0.week >= loader.currentWeek }
                .sorted { $0.week < $1.week }
                .prefix(4)
        )
    }

    // MARK: - Initialization

    init(
        repository: TrainingPlanV2Repository,
        workoutRepository: WorkoutRepository,
        versionRouter: TrainingVersionRouter,
        achievementRepository: AchievementRepository
    ) {
        self.repository = repository
        self.workoutRepository = workoutRepository
        self.versionRouter = versionRouter
        self.achievementRepository = achievementRepository

        loader = WeeklyPlanLoader(
            repository: repository,
            workoutRepository: workoutRepository,
            shouldSuppressError: { [weak self] error, ctx, dataCorruption in
                self?.shouldSuppressError(error, context: ctx, onDataCorruption: dataCorruption) ?? false
            },
            onNetworkError: { [weak self] error in self?.networkError = error }
        )

        self.methodology = MethodologyCoordinator(
            repository: repository,
            currentTargetType: { [weak self] in self?.loader.planOverview?.targetType },
            currentOverviewId: { [weak self] in self?.loader.planOverview?.id },
            onMethodologyChanged: { [weak self] updatedOverview in
                guard let self else { return }
                self.loader.planOverview = updatedOverview
                self.successToast = NSLocalizedString("training.methodology_changed", comment: "方法論已更換")
                await self.repository.clearCache()
                await self.loader.loadPlanStatus()
            },
            onPaywallNeeded: { [weak self] in self?.triggerPaywallIfEnforced() },
            onNetworkError: { [weak self] error in self?.networkError = error }
        )

        self.summary = WeeklySummaryCoordinator(
            repository: repository,
            currentSelectedWeek: { [weak self] in self?.loader.selectedWeek ?? 1 },
            setLoadingAnimation: { [weak self] value in self?.isLoadingAnimation = value },
            shouldBlockByRizoQuota: { [weak self] in await self?.shouldBlockByRizoQuota() ?? false },
            refreshPlanStatusResponse: { [weak self] in await self?.loader.refreshPlanStatusResponse() },
            shouldSuppressError: { [weak self] domainError, context, onDataCorruption in
                self?.shouldSuppressError(domainError, context: context, onDataCorruption: onDataCorruption) ?? false
            },
            resolvePaywallTrigger: { [weak self] in self?.resolvePaywallTrigger() ?? .apiGated },
            onSuccessToast: { [weak self] message in self?.successToast = message },
            onPaywallTriggered: { [weak self] trigger in self?.paywallTrigger = trigger },
            onRizoQuotaExceeded: { [weak self] in self?.showRizoQuotaExceededBanner = true },
            onNetworkError: { [weak self] error in self?.networkError = error },
            isEnforcementEnabled: { SubscriptionStateManager.shared.isEnforcementEnabled },
            onWeeklyReviewInlineUpsellNeeded: { [weak self] in self?.showWeeklyReviewInlineUpsell = true }
        )

        self.generator = WeeklyPlanGenerator(
            repository: repository,
            loader: loader,
            summary: summary,
            setLoadingAnimation: { [weak self] value in self?.isLoadingAnimation = value },
            shouldBlockByRizoQuota: { [weak self] in await self?.shouldBlockByRizoQuota() ?? false },
            triggerPaywallIfEnforced: { [weak self] in self?.triggerPaywallIfEnforced() },
            shouldSuppressError: { [weak self] error, ctx, onCorrupt in
                self?.shouldSuppressError(error, context: ctx, onDataCorruption: onCorrupt) ?? false
            },
            onSuccessToast: { [weak self] message in self?.successToast = message },
            onRizoQuotaExceeded: { [weak self] in self?.showRizoQuotaExceededBanner = true },
            onNetworkError: { [weak self] error in self?.networkError = error },
            onWeeklyPlanInlineUpsellNeeded: { [weak self] isRegenerate in
                self?.weeklyPlanUpsellIsRegenerate = isRegenerate
                self?.showWeeklyPlanInlineUpsell = true
            }
        )

        setupDisplayBadgeObservation()
    }

    /// 便利初始化器（使用 DI Container）
    convenience init() {
        let container = DependencyContainer.shared

        if !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        if !container.isRegistered(WorkoutRepository.self) {
            container.registerWorkoutModule()
        }

        if !container.isRegistered(AchievementRepository.self) {
            container.registerAchievementModule()
        }

        let repository: TrainingPlanV2Repository = container.resolve()
        let workoutRepository: WorkoutRepository = container.resolve()
        let versionRouter: TrainingVersionRouter = container.resolve()
        let achievementRepository: AchievementRepository = container.resolve()

        self.init(
            repository: repository,
            workoutRepository: workoutRepository,
            versionRouter: versionRouter,
            achievementRepository: achievementRepository
        )
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Forwarded Initialization

    func initialize() async {
        await loader.initialize()
    }

    func loadCurrentWeekPlan() async {
        await loader.loadCurrentWeekPlan()
    }

    func loadPlanStatus() async {
        await loader.loadPlanStatus()
    }

    func refreshWeeklyPlan() async {
        await loader.refreshWeeklyPlan()
    }

    // MARK: - Helper Methods

    func getWorkouts(for dayIndex: Int) -> [WorkoutV2] {
        loader.workoutsByDay[dayIndex] ?? []
    }

    func getDate(for dayIndex: Int) -> Date? {
        guard let overview = loader.planOverview else { return nil }

        guard let createdAt = overview.createdAt else {
            Logger.error("[TrainingPlanV2VM] ❌ getDate: Overview createdAt 為 nil")
            return nil
        }

        let formatter = ISO8601DateFormatter()
        let createdAtString = formatter.string(from: createdAt)

        guard let weekInfo = WeekDateService.weekDateInfo(
            createdAt: createdAtString,
            weekNumber: loader.selectedWeek
        ) else {
            return nil
        }

        return weekInfo.daysMap[dayIndex]
    }

    func isToday(dayIndex: Int) -> Bool {
        guard let date = getDate(for: dayIndex) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    func clearError() {
        networkError = nil
    }

    func clearSuccessToast() {
        successToast = nil
    }

    // MARK: - AC-IOS-ANALYTICS-P1-09: weekly_plan_view dedup

    /// Track weekly_plan_view for the given plan/week combination.
    /// Deduplicates by key ("\(planId)-\(weekOfTraining)") — fires at most once per key per session.
    /// View calls this; ViewModel owns the dedup state and analytics dispatch.
    func markWeeklyPlanTracked(planId: String, weekOfTraining: Int) {
        let key = "\(planId)-\(weekOfTraining)"
        guard trackedWeeklyPlanKey != key else { return }
        trackedWeeklyPlanKey = key
        let analyticsService: AnalyticsService = DependencyContainer.shared.resolve()
        analyticsService.track(.weeklyPlanView(planId: planId, weekOfTraining: weekOfTraining))
    }

    // MARK: - AC-IOS-ANALYTICS-P1-12: plan_overview_view dedup

    /// Track plan_overview_view once per sheet presentation.
    /// No-op if already tracked (hasTrackedPlanOverviewView == true).
    func markPlanOverviewTracked(overviewId: String, targetType: String) {
        guard !hasTrackedPlanOverviewView else { return }
        hasTrackedPlanOverviewView = true
        let analyticsService: AnalyticsService = DependencyContainer.shared.resolve()
        analyticsService.track(.planOverviewView(overviewId: overviewId, targetType: targetType))
    }

    // MARK: - Showcase Badge (課表首頁展示徽章)

    /// 已解鎖徽章清單（picker 用），最近解鎖在前。
    var unlockedBadges: [AchievementBadge] {
        achievementRepository.getUnlockedBadges()
    }

    /// 目前自選的展示徽章 ID；nil = 自動挑選（最近解鎖）。
    var showcaseBadgeId: String? {
        achievementRepository.getPinnedBadgeId()
    }

    /// 設定展示徽章（nil = 恢復預設自動挑選）。
    /// pin 變更會透過 pinnedBadgeIdDidChange 自動更新 displayBadge。
    func setShowcaseBadge(_ badgeId: String?) {
        achievementRepository.setPinnedBadgeId(badgeId)
    }

    // MARK: - Private Helpers

    private func setupDisplayBadgeObservation() {
        // Initial load: fetch summary then snapshot displayBadge
        Task { [weak self] in
            guard let self else { return }
            _ = try? await achievementRepository.fetchSummary(forceRefresh: false)
            await MainActor.run {
                self.displayBadge = self.achievementRepository.getDisplayBadge()
            }
        }

        // Live updates: react to pin changes
        achievementRepository.pinnedBadgeIdDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.displayBadge = self?.achievementRepository.getDisplayBadge()
            }
            .store(in: &displayBadgeCancellables)
    }

    private func shouldSuppressError(_ domainError: DomainError, context: String, onDataCorruption: (() -> Void)? = nil) -> Bool {
        if case .dataCorruption = domainError {
            onDataCorruption?()
            successToast = NSLocalizedString("error.data_corruption", comment: "Data corruption")
            Logger.error("[TrainingPlanV2VM] ⚠️ \(context) decode/schema mismatch: \(domainError.localizedDescription)")
            return true
        }
        if !domainError.shouldShowErrorView {
            Logger.debug("[TrainingPlanV2VM] \(context) 被取消或訂閱攔截，忽略")
            return true
        }
        return false
    }

    private func shouldBlockByRizoQuota() async -> Bool {
        if let usage = SubscriptionStateManager.shared.currentStatus?.rizoUsage, usage.isExhausted {
            Logger.debug("[TrainingPlanV2VM] Rizo quota exhausted from cached status")
            return true
        }
        do {
            let repo: SubscriptionRepository = DependencyContainer.shared.resolve()
            let refreshed = try await repo.refreshStatus()
            if let usage = refreshed.rizoUsage, usage.isExhausted {
                Logger.debug("[TrainingPlanV2VM] Rizo quota exhausted from refreshed status")
                return true
            }
        } catch {
            Logger.error("[TrainingPlanV2VM] Failed to refresh subscription status: \(error.localizedDescription)")
        }
        return false
    }

    private func resolvePaywallTrigger() -> PaywallTrigger {
        guard let lastStatus = SubscriptionStateManager.shared.currentStatus else { return .apiGated }
        switch lastStatus.status {
        case .trial:    return .trialExpired
        case .cancelled: return .resubscribe
        default:         return .apiGated
        }
    }

    private func triggerPaywallIfEnforced() {
        guard SubscriptionStateManager.shared.isEnforcementEnabled else { return }
        paywallTrigger = resolvePaywallTrigger()
    }

    // MARK: - Debug Actions

    func debugGenerateWeeklySummary() async {
        guard let week = TrainingPlanV2View.previousWeeklySummaryWeek(currentWeek: loader.currentWeek) else {
            successToast = NSLocalizedString("training.weekly_summary_not_available_first_week", comment: "No completed week is available for weekly review yet")
            return
        }
        await summary.debugGenerateForWeek(
            week,
            onSuccess: { [weak self] msg in self?.successToast = msg },
            onNetworkError: { [weak self] err in self?.networkError = err }
        )
    }

    func debugDeleteCurrentWeekPlan() async {
        guard let plan = loader.weeklyPlan else {
            networkError = NSError(domain: "TrainingPlanV2", code: -1, userInfo: [NSLocalizedDescriptionKey: "無週課表可刪除"])
            return
        }
        let planId = plan.effectivePlanId
        do {
            try await repository.deleteWeeklyPlan(planId: planId)
            await repository.clearWeeklyPlanCache(weekOfTraining: loader.currentWeek)
            loader.weeklyPlan = nil
            loader.planStatus = .noWeeklyPlan
            successToast = "✅ [DEBUG] 週課表已刪除"
        } catch {
            networkError = error
        }
    }

    func debugDeleteCurrentWeeklySummary() async {
        do {
            let s = try await repository.getWeeklySummary(weekOfPlan: loader.currentWeek)
            try await repository.deleteWeeklySummary(summaryId: s.id)
            await repository.clearWeeklySummaryCache(weekOfPlan: loader.currentWeek)
            summary.weeklySummary = .empty
            successToast = "✅ [DEBUG] 週回顧已刪除"
        } catch {
            networkError = error
        }
    }
}

// MARK: - DependencyContainer Factory

extension DependencyContainer {
    @MainActor
    func makeTrainingPlanV2ViewModel() -> TrainingPlanV2ViewModel {
        return TrainingPlanV2ViewModel()
    }
}
