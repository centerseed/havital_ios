import Foundation

// MARK: - TrainingPlan Repository Implementation
/// 實作 TrainingPlanRepository 協議
/// 使用雙軌緩存策略：立即顯示緩存 + 背景更新
final class TrainingPlanRepositoryImpl: TrainingPlanRepository {

    // MARK: - Dependencies
    private let remoteDataSource: TrainingPlanRemoteDataSource
    private let localDataSource: TrainingPlanLocalDataSource

    // MARK: - Initialization
    init(
        remoteDataSource: TrainingPlanRemoteDataSource = TrainingPlanRemoteDataSource(),
        localDataSource: TrainingPlanLocalDataSource = TrainingPlanLocalDataSource()
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - Weekly Plan

    func getWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        Logger.debug("[Repository] getWeeklyPlan: \(planId)")

        // Track A: 檢查本地緩存
        if let cached = localDataSource.getWeeklyPlan(planId: planId),
           !localDataSource.isWeeklyPlanExpired(planId: planId) {
            Logger.debug("[Repository] Cache hit: \(planId)")

            // Track B: 背景刷新
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshWeeklyPlanInBackground(planId: planId)
            }

            return cached
        }

        // 無緩存或已過期，從 API 獲取
        Logger.debug("[Repository] Cache miss, fetching from API: \(planId)")
        return try await fetchAndCacheWeeklyPlan(planId: planId)
    }

    func refreshWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        Logger.debug("[Repository] Force refresh: \(planId)")
        return try await fetchAndCacheWeeklyPlan(planId: planId)
    }

    func createWeeklyPlan(week: Int?, startFromStage: String?, isBeginner: Bool) async throws -> WeeklyPlan {
        Logger.debug("[Repository] Creating weekly plan for week: \(week ?? -1)")

        let plan = try await remoteDataSource.createWeeklyPlan(
            week: week,
            startFromStage: startFromStage,
            isBeginner: isBeginner
        )

        // 緩存新建的計畫
        let planId = plan.id
        localDataSource.saveWeeklyPlan(plan, planId: planId)

        // 同時使 plan status 失效
        localDataSource.removePlanStatus()

        return plan
    }

    func modifyWeeklyPlan(planId: String, updatedPlan: WeeklyPlan) async throws -> WeeklyPlan {
        Logger.debug("[Repository] Modifying weekly plan: \(planId)")

        // 🔍 DEBUG: 詳細打印即將發送到後端的計畫內容
        Logger.debug("[Repository] 📤 發送修改請求到後端:")
        Logger.debug("[Repository] Plan ID: \(planId)")
        Logger.debug("[Repository] Total days: \(updatedPlan.days.count)")

        for (index, day) in updatedPlan.days.enumerated() {
            Logger.debug("[Repository] Day \(index + 1): type=\(day.trainingType), target=\(day.dayTarget ?? "none")")

            if let details = day.trainingDetails {
                Logger.debug("[Repository]   trainingDetails: distance=\(details.distanceKm ?? 0)km, pace=\(details.pace ?? "N/A")")

                if let work = details.work {
                    Logger.debug("[Repository]     work: dist=\(work.distanceKm ?? 0)km, time=\(work.timeMinutes ?? 0)min, timeSeconds=\(work.timeSeconds ?? 0)s, pace=\(work.pace ?? "N/A")")
                }

                if let recovery = details.recovery {
                    Logger.debug("[Repository]     recovery: dist=\(recovery.distanceKm ?? 0)km, time=\(recovery.timeMinutes ?? 0)min, timeSeconds=\(recovery.timeSeconds ?? 0)s, pace=\(recovery.pace ?? "N/A"), desc=\(recovery.description ?? "N/A")")
                }

                if let repeats = details.repeats {
                    Logger.debug("[Repository]     repeats: \(repeats)")
                }
            }
        }

        let modifiedPlan = try await remoteDataSource.modifyWeeklyPlan(
            planId: planId,
            updatedPlan: updatedPlan
        )

        // 更新緩存
        localDataSource.saveWeeklyPlan(modifiedPlan, planId: planId)

        return modifiedPlan
    }

    // MARK: - Training Overview

    func getOverview() async throws -> TrainingPlanOverview {
        Logger.debug("[Repository] getOverview")

        // Track A: 檢查本地緩存
        if let cached = localDataSource.getOverview(),
           !localDataSource.isOverviewExpired() {
            Logger.debug("[Repository] Overview cache hit")

            // Track B: 背景刷新
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshOverviewInBackground()
            }

            return cached
        }

        // 無緩存或已過期
        Logger.debug("[Repository] Overview cache miss, fetching from API")
        return try await fetchAndCacheOverview()
    }

    func refreshOverview() async throws -> TrainingPlanOverview {
        Logger.debug("[Repository] Force refresh overview")
        return try await fetchAndCacheOverview()
    }

    func createOverview(startFromStage: String?, isBeginner: Bool) async throws -> TrainingPlanOverview {
        Logger.debug("[Repository] Creating overview")

        let overview = try await remoteDataSource.createOverview(
            startFromStage: startFromStage,
            isBeginner: isBeginner
        )

        localDataSource.saveOverview(overview)
        return overview
    }

    func updateOverview(overviewId: String) async throws -> TrainingPlanOverview {
        Logger.debug("[Repository] Updating overview: \(overviewId)")

        let overview = try await remoteDataSource.updateOverview(overviewId: overviewId)
        localDataSource.saveOverview(overview)
        return overview
    }

    // MARK: - Plan Status

    func getPlanStatus() async throws -> PlanStatusResponse {
        Logger.debug("[Repository] getPlanStatus")

        // Track A: 檢查本地緩存
        if let cached = localDataSource.getPlanStatus(),
           !localDataSource.isPlanStatusExpired() {
            Logger.debug("[Repository] Plan status cache hit")

            // Track B: 背景刷新
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshPlanStatusInBackground()
            }

            return cached
        }

        // 無緩存或已過期
        Logger.debug("[Repository] Plan status cache miss, fetching from API")
        return try await fetchAndCachePlanStatus()
    }

    func refreshPlanStatus() async throws -> PlanStatusResponse {
        Logger.debug("[Repository] Force refresh plan status")
        return try await fetchAndCachePlanStatus()
    }

    // MARK: - Modifications

    func getModifications() async throws -> [Modification] {
        // 修改項目不緩存，每次都從 API 獲取
        return try await remoteDataSource.getModifications()
    }

    func getModificationsDescription() async throws -> String {
        return try await remoteDataSource.getModificationsDescription()
    }

    func createModification(_ modification: NewModification) async throws -> Modification {
        return try await remoteDataSource.createModification(modification)
    }

    func updateModifications(_ modifications: [Modification]) async throws -> [Modification] {
        return try await remoteDataSource.updateModifications(modifications)
    }

    func clearModifications() async throws {
        try await remoteDataSource.clearModifications()
    }

    // MARK: - Weekly Summary



    // MARK: - Cache Management

    func clearCache() async {
        localDataSource.clearAll()
        Logger.debug("[Repository] Cache cleared")
    }

    func preloadData() async {
        // 預載入 overview 和 plan status
        Logger.debug("[Repository] Preloading data...")

        async let overviewTask: () = { [weak self] in
            _ = try? await self?.getOverview()
        }()

        async let statusTask: () = { [weak self] in
            _ = try? await self?.getPlanStatus()
        }()

        await overviewTask
        await statusTask

        Logger.debug("[Repository] Preload complete")
    }

    // MARK: - Private Methods

    private func fetchAndCacheWeeklyPlan(planId: String) async throws -> WeeklyPlan {
        do {
            let plan = try await remoteDataSource.getWeeklyPlan(planId: planId)
            localDataSource.saveWeeklyPlan(plan, planId: planId)
            return plan
        } catch let error as HTTPError {
            if case .notFound = error {
                throw TrainingPlanError.weeklyPlanNotFound(planId: planId)
            }
            throw error
        }
    }

    private func fetchAndCacheOverview() async throws -> TrainingPlanOverview {
        do {
            let overview = try await remoteDataSource.getOverview()
            localDataSource.saveOverview(overview)
            return overview
        } catch let error as HTTPError {
            if case .notFound = error {
                throw TrainingPlanError.overviewNotFound
            }
            throw error
        }
    }

    private func fetchAndCachePlanStatus() async throws -> PlanStatusResponse {
        let status = try await remoteDataSource.getPlanStatus()
        localDataSource.savePlanStatus(status)
        return status
    }

    // MARK: - Background Refresh Methods

    private func refreshWeeklyPlanInBackground(planId: String) async {
        do {
            let plan = try await remoteDataSource.getWeeklyPlan(planId: planId)
            localDataSource.saveWeeklyPlan(plan, planId: planId)
            Logger.debug("[Repository] Background refresh success: \(planId)")
        } catch {
            // 背景刷新失敗不影響已顯示的緩存
            Logger.debug("[Repository] Background refresh failed (non-critical): \(error.localizedDescription)")
        }
    }

    private func refreshOverviewInBackground() async {
        do {
            let overview = try await remoteDataSource.getOverview()
            localDataSource.saveOverview(overview)
            Logger.debug("[Repository] Background overview refresh success")
        } catch {
            Logger.debug("[Repository] Background overview refresh failed: \(error.localizedDescription)")
        }
    }

    private func refreshPlanStatusInBackground() async {
        do {
            let status = try await remoteDataSource.getPlanStatus()
            localDataSource.savePlanStatus(status)
            Logger.debug("[Repository] Background plan status refresh success")
        } catch {
            Logger.debug("[Repository] Background plan status refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Weekly Summary

    func createWeeklySummary(weekNumber: Int?, forceUpdate: Bool) async throws -> WeeklyTrainingSummary {
        Logger.debug("[Repository] Creating weekly summary for week: \(weekNumber ?? -1), forceUpdate: \(forceUpdate)")

        let summary = try await remoteDataSource.createWeeklySummary(
            weekNumber: weekNumber,
            forceUpdate: forceUpdate
        )

        // 緩存週回顧（可選，根據需求決定是否緩存）
        // localDataSource.saveWeeklySummary(summary)

        Logger.debug("[Repository] Weekly summary created: \(summary.id)")
        return summary
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        Logger.debug("[Repository] Fetching weekly summaries")

        let summaries = try await remoteDataSource.getWeeklySummaries()

        Logger.debug("[Repository] Fetched \(summaries.count) weekly summaries")
        return summaries
    }

    func getWeeklySummary(weekNumber: Int) async throws -> WeeklyTrainingSummary {
        Logger.debug("[Repository] Fetching weekly summary for week: \(weekNumber)")

        let summary = try await remoteDataSource.getWeeklySummary(weekNumber: weekNumber)

        Logger.debug("[Repository] Weekly summary fetched: \(summary.id)")
        return summary
    }

    func updateAdjustments(summaryId: String, items: [AdjustmentItem]) async throws -> [AdjustmentItem] {
        Logger.debug("[Repository] Updating \(items.count) adjustments for summary: \(summaryId)")

        let updatedItems = try await remoteDataSource.updateAdjustments(
            summaryId: summaryId,
            items: items
        )

        Logger.debug("[Repository] Adjustments updated: \(updatedItems.count)")
        return updatedItems
    }
}

// MARK: - DependencyContainer Registration
extension DependencyContainer {

    /// 註冊 TrainingPlan 模組依賴
    func registerTrainingPlanModule() {
        // DataSources
        register(TrainingPlanRemoteDataSource(), for: TrainingPlanRemoteDataSource.self)
        register(TrainingPlanLocalDataSource(), for: TrainingPlanLocalDataSource.self)

        // Repository
        let repository = TrainingPlanRepositoryImpl(
            remoteDataSource: resolve(),
            localDataSource: resolve()
        )
        register(repository as TrainingPlanRepository, forProtocol: TrainingPlanRepository.self)

        Logger.debug("[DI] TrainingPlan module registered")
    }
}
