import Foundation
import Observation

// MARK: - WeeklyPlanGenerator

/// Coordinator for all week-generation user actions.
/// Pure action coordinator: reads loader / summary state, writes back through closures.
/// Owns no observable state — the parent TrainingPlanV2ViewModel remains the single source of truth
/// for isLoadingAnimation, toasts, paywall, and error banners.
@MainActor
@Observable
final class WeeklyPlanGenerator {

    // MARK: - Dependencies

    @ObservationIgnored private let repository: TrainingPlanV2Repository
    @ObservationIgnored private let loader: WeeklyPlanLoader
    @ObservationIgnored private let summary: WeeklySummaryCoordinator

    // MARK: - Closure Injection (parent-owned state / helpers)

    @ObservationIgnored private let setLoadingAnimation: (Bool) -> Void
    @ObservationIgnored private let shouldBlockByRizoQuota: () async -> Bool
    @ObservationIgnored private let triggerPaywallIfEnforced: () -> Void
    @ObservationIgnored private let shouldSuppressError: (DomainError, String, (() -> Void)?) -> Bool
    @ObservationIgnored private let onSuccessToast: (String) -> Void
    @ObservationIgnored private let onRizoQuotaExceeded: () -> Void
    @ObservationIgnored private let onNetworkError: (Error) -> Void

    // MARK: - Init

    init(
        repository: TrainingPlanV2Repository,
        loader: WeeklyPlanLoader,
        summary: WeeklySummaryCoordinator,
        setLoadingAnimation: @escaping (Bool) -> Void,
        shouldBlockByRizoQuota: @escaping () async -> Bool,
        triggerPaywallIfEnforced: @escaping () -> Void,
        shouldSuppressError: @escaping (DomainError, String, (() -> Void)?) -> Bool,
        onSuccessToast: @escaping (String) -> Void,
        onRizoQuotaExceeded: @escaping () -> Void,
        onNetworkError: @escaping (Error) -> Void
    ) {
        self.repository = repository
        self.loader = loader
        self.summary = summary
        self.setLoadingAnimation = setLoadingAnimation
        self.shouldBlockByRizoQuota = shouldBlockByRizoQuota
        self.triggerPaywallIfEnforced = triggerPaywallIfEnforced
        self.shouldSuppressError = shouldSuppressError
        self.onSuccessToast = onSuccessToast
        self.onRizoQuotaExceeded = onRizoQuotaExceeded
        self.onNetworkError = onNetworkError
    }

    // MARK: - Generate Current Week Plan

    /// 使用者觸發產生當前選中週的課表
    func generateCurrentWeekPlan() async {
        Logger.debug("[WeeklyPlanGenerator] 使用者觸發產生第 \(loader.selectedWeek) 週課表...")

        guard await prepareForGeneration() else { return }

        do {
            let planLoadStart = Date()
            let plan = try await repository.generateWeeklyPlan(
                weekOfTraining: loader.selectedWeek,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )

            // 補足 10 秒最短顯示時間
            let elapsed = Date().timeIntervalSince(planLoadStart)
            let remaining = max(0.0, 10.0 - elapsed)
            if remaining > 0 {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            setLoadingAnimation(false)
            loader.currentWeek = loader.selectedWeek
            loader.weeklyPlan = plan
            loader.planStatus = .ready(plan)
            onSuccessToast("第 \(loader.selectedWeek) 週課表已產生")

            await loader.loadWorkoutsForCurrentWeek()

            Logger.debug("[WeeklyPlanGenerator] ✅ 週課表產生成功: week=\(loader.selectedWeek)")
        } catch {
            handleGenerationError(error)
        }
    }

    // MARK: - Generate Next Week Plan

    func generateNextWeekPlan() async {
        guard let nextWeekInfo = loader.planStatusResponse?.nextWeekInfo else {
            Logger.error("[WeeklyPlanGenerator] ❌ 無法產生下週課表：缺少 nextWeekInfo")
            return
        }

        if nextWeekInfo.requiresCurrentWeekSummary == true {
            Logger.debug("[WeeklyPlanGenerator] 需要先產生週回顧，再從回顧 sheet 產生下週課表")
            await summary.createWeeklySummaryAndShow(week: loader.currentWeek)
            return
        }

        Logger.debug("[WeeklyPlanGenerator] 本週回顧已完成，直接產生第 \(nextWeekInfo.weekNumber) 週課表")
        await generateWeeklyPlanDirectly(weekNumber: nextWeekInfo.weekNumber)
    }

    // MARK: - Resolve Week After Summary

    /// 產生週回顧後，決定要產生哪一週的課表
    func resolveWeekToGenerateAfterSummary(summaryWeek: Int) async -> Int {
        await loader.refreshPlanStatusResponse()
        if let backendWeek = loader.planStatusResponse?.nextWeekInfo?.weekNumber, backendWeek > 0 {
            return backendWeek
        }
        return max(1, summaryWeek + 1)
    }

    // MARK: - Generate Weekly Plan Directly

    /// 直接產生指定週次的課表（不經過 summary 流程）
    /// - Parameter managedLoadingExternally: true 時 loading sheet 由呼叫方（summaryFlow）管理，
    ///   此函式不呼叫 setLoadingAnimation。
    func generateWeeklyPlanDirectly(weekNumber: Int, managedLoadingExternally: Bool = false) async {
        Logger.debug("[WeeklyPlanGenerator] 開始產生第 \(weekNumber) 週課表...")

        if !managedLoadingExternally {
            guard await prepareForGeneration() else { return }
        } else {
            if await shouldBlockByRizoQuota() {
                onRizoQuotaExceeded()
                return
            }
        }

        do {
            let planLoadStart = Date()
            let plan = try await repository.generateWeeklyPlan(
                weekOfTraining: weekNumber,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )

            // 補足 10 秒最短顯示時間
            let elapsed = Date().timeIntervalSince(planLoadStart)
            let remaining = max(0.0, 10.0 - elapsed)
            if remaining > 0 {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            if !managedLoadingExternally { setLoadingAnimation(false) }
            loader.currentWeek = weekNumber
            loader.selectedWeek = weekNumber
            loader.weeklyPlan = plan
            loader.planStatus = .ready(plan)
            onSuccessToast("第 \(weekNumber) 週課表已產生")

            async let statusRefresh: Void = loader.refreshPlanStatusResponse()
            async let workoutsRefresh: Void = loader.loadWorkoutsForCurrentWeek()
            _ = await (statusRefresh, workoutsRefresh)

            Logger.debug("[WeeklyPlanGenerator] ✅ 週課表產生成功: week=\(weekNumber)")
        } catch {
            handleGenerationError(error, skipLoadingReset: managedLoadingExternally)
        }
    }

    // MARK: - Update Overview

    /// 更新訓練計畫概覽（修改目標或起始階段後重新產生）
    func updateOverview(startFromStage: String? = nil) async {
        Logger.debug("[WeeklyPlanGenerator] 更新訓練計畫概覽... startFromStage=\(startFromStage ?? "nil")")

        guard let overviewId = loader.planOverview?.id else {
            Logger.error("[WeeklyPlanGenerator] ❌ 無法更新：overview ID 為 nil")
            onNetworkError(NSError(domain: "", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "無法更新訓練計劃"
            ]))
            return
        }

        setLoadingAnimation(true)
        summary.isLoadingWeeklySummary = false

        do {
            let updatedOverview = try await repository.updateOverview(
                overviewId: overviewId,
                startFromStage: startFromStage,
                methodologyId: nil
            )

            loader.planOverview = updatedOverview
            setLoadingAnimation(false)
            onSuccessToast(NSLocalizedString("training.plan_regenerated", comment: "訓練計劃已根據最新目標重新產生"))

            await repository.clearCache()
            await loader.loadPlanStatus()

            Logger.info("[WeeklyPlanGenerator] ✅ 訓練計劃概覽已更新")
        } catch {
            let domainError = error.toDomainError()
            setLoadingAnimation(false)
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                triggerPaywallIfEnforced()
            default:
                if shouldSuppressError(domainError, "更新訓練計劃概覽", nil) { return }
                Logger.error("[WeeklyPlanGenerator] ❌ 更新訓練計劃概覽失敗: \(domainError.localizedDescription)")
                onNetworkError(domainError)
            }
        }
    }

    // MARK: - Private Helpers

    /// 產生課表前的前置檢查：重置 summary 動畫、啟動 loading、檢查 Rizo 配額。
    /// Returns false if blocked by quota (caller should return early).
    private func prepareForGeneration() async -> Bool {
        summary.isLoadingWeeklySummary = false
        setLoadingAnimation(true)

        if await shouldBlockByRizoQuota() {
            onRizoQuotaExceeded()
            setLoadingAnimation(false)
            return false
        }
        return true
    }

    /// 處理課表產生失敗：依錯誤類型路由到 paywall / quota / error state。
    /// - Parameter skipLoadingReset: 當 loading 由外部（summaryFlow）管理時傳 true，跳過 setLoadingAnimation(false)。
    private func handleGenerationError(_ error: Error, skipLoadingReset: Bool = false) {
        let domainError = error.toDomainError()
        if !skipLoadingReset { setLoadingAnimation(false) }
        switch domainError {
        case .subscriptionRequired, .trialExpired, .forbidden:
            triggerPaywallIfEnforced()
        case .rizoQuotaExceeded:
            onRizoQuotaExceeded()
        default:
            if shouldSuppressError(domainError, "週課表產生", { self.loader.planStatus = .noWeeklyPlan }) { return }
            Logger.error("[WeeklyPlanGenerator] ❌ 週課表產生失敗: \(domainError.localizedDescription)")
            loader.planStatus = .error(domainError)
        }
    }
}
