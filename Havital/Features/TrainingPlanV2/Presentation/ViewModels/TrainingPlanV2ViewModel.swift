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

    // MARK: - TaskManageable
    @ObservationIgnored nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Child Coordinators & Loader
    private(set) var loader: WeeklyPlanLoader!
    private(set) var methodology: MethodologyCoordinator!
    var summary: WeeklySummaryCoordinator!
    private(set) var generator: WeeklyPlanGenerator!

    // MARK: - Orchestration State
    var networkError: Error?
    var successToast: String?
    var isLoadingAnimation = false
    var paywallTrigger: PaywallTrigger?
    var showRizoQuotaExceededBanner: Bool = false

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
        versionRouter: TrainingVersionRouter
    ) {
        self.repository = repository
        self.workoutRepository = workoutRepository
        self.versionRouter = versionRouter

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
            isEnforcementEnabled: { SubscriptionStateManager.shared.isEnforcementEnabled }
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
            onNetworkError: { [weak self] error in self?.networkError = error }
        )
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

        let repository: TrainingPlanV2Repository = container.resolve()
        let workoutRepository: WorkoutRepository = container.resolve()
        let versionRouter: TrainingVersionRouter = container.resolve()

        self.init(
            repository: repository,
            workoutRepository: workoutRepository,
            versionRouter: versionRouter
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

    // MARK: - Private Helpers

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
        let week = max(1, loader.currentWeek - 1)
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
