import Foundation

// MARK: - TrainingPlanV2RepositoryImpl
/// Implementation of TrainingPlanV2Repository protocol
/// Implements dual-track caching strategy for optimal performance:
/// - Track A: Immediate cache return (fast user experience)
/// - Track B: Background refresh (keep data fresh)
final class TrainingPlanV2RepositoryImpl: TrainingPlanV2Repository {

    // MARK: - Dependencies

    private let remoteDataSource: TrainingPlanV2RemoteDataSourceProtocol
    private let localDataSource: TrainingPlanV2LocalDataSourceProtocol

    // MARK: - Initialization

    init(
        remoteDataSource: TrainingPlanV2RemoteDataSourceProtocol,
        localDataSource: TrainingPlanV2LocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - Plan Status

    func getPlanStatus() async throws -> PlanStatusV2Response {
        Logger.debug("[TrainingPlanV2Repo] Getting plan status")

        do {
            let response = try await remoteDataSource.getPlanStatus()
            Logger.info("[TrainingPlanV2Repo] ✅ Plan status: week \(response.currentWeek)/\(response.totalWeeks), nextAction=\(response.nextAction)")
            return response
        } catch {
            logErrorToCloud(module: "PlanStatus", operation: "fetch", error: error)
            // 將錯誤轉換為 DomainError
            throw error.toDomainError()
        }
    }

    // MARK: - Target Types & Methodologies

    func getTargetTypes() async throws -> [TargetTypeV2] {
        Logger.debug("[TrainingPlanV2Repo] Fetching target types")

        // No caching for target types - they're rarely changed and small payload
        let targetTypes = try await remoteDataSource.getTargetTypes()

        Logger.info("[TrainingPlanV2Repo] Fetched \(targetTypes.count) target types")
        return targetTypes
    }

    func getMethodologies(targetType: String?) async throws -> [MethodologyV2] {
        Logger.debug("[TrainingPlanV2Repo] 🎯 Fetching methodologies for: '\(targetType ?? "nil")'")

        // No caching for methodologies - they're rarely changed and small payload
        Logger.debug("[TrainingPlanV2Repo] 📡 Calling remoteDataSource.getMethodologies with targetType=\(targetType ?? "nil")")
        let methodologies = try await remoteDataSource.getMethodologies(targetType: targetType)

        Logger.info("[TrainingPlanV2Repo] ✅ Fetched \(methodologies.count) methodologies: \(methodologies.map { $0.id })")
        return methodologies
    }

    // MARK: - Plan Overview

    func createOverviewForRace(targetId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Creating overview for race: \(targetId)")

        let dto = try await remoteDataSource.createOverviewForRace(
            targetId: targetId,
            startFromStage: startFromStage,
            methodologyId: methodologyId
        )

        let entity = PlanOverviewV2Mapper.toEntity(from: dto)

        // Cache the result
        localDataSource.saveOverview(entity)

        Logger.info("[TrainingPlanV2Repo] Overview created and cached: \(entity.id)")
        return entity
    }

    func createOverviewForNonRace(
        targetType: String,
        trainingWeeks: Int,
        availableDays: Int?,
        methodologyId: String?,
        startFromStage: String?,
        intendedRaceDistanceKm: Int?
    ) async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Creating overview for \(targetType)")

        let dto = try await remoteDataSource.createOverviewForNonRace(
            targetType: targetType,
            trainingWeeks: trainingWeeks,
            availableDays: availableDays,
            methodologyId: methodologyId,
            startFromStage: startFromStage,
            intendedRaceDistanceKm: intendedRaceDistanceKm
        )

        let entity = PlanOverviewV2Mapper.toEntity(from: dto)

        // Cache the result
        localDataSource.saveOverview(entity)

        Logger.info("[TrainingPlanV2Repo] Overview created and cached: \(entity.id)")
        return entity
    }

    func getOverview() async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] getOverview")

        // Track A: Check local cache
        if let cached = localDataSource.getOverview(),
           !localDataSource.isOverviewExpired() {
            Logger.debug("[TrainingPlanV2Repo] Cache hit")
            // Note: Track B (background refresh) is handled by ViewModel layer
            return cached
        }

        // Cache miss - fetch from API
        Logger.debug("[TrainingPlanV2Repo] Cache miss, fetching from API")
        return try await fetchAndCacheOverview()
    }

    func refreshOverview() async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Force refresh overview")
        return try await fetchAndCacheOverview()
    }

    func updateOverview(overviewId: String, startFromStage: String?, methodologyId: String?) async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Updating overview: \(overviewId)")

        let dto = try await remoteDataSource.updateOverview(
            overviewId: overviewId,
            startFromStage: startFromStage,
            methodologyId: methodologyId
        )

        let entity = PlanOverviewV2Mapper.toEntity(from: dto)

        // Clear old cache and save new data
        localDataSource.clearOverview()
        localDataSource.saveOverview(entity)

        Logger.info("[TrainingPlanV2Repo] Overview updated: \(entity.id)")
        return entity
    }

    // MARK: - Weekly Plan

    func generateWeeklyPlan(
        weekOfTraining: Int,
        forceGenerate: Bool?,
        promptVersion: String?,
        methodology: String?
    ) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] Generating weekly plan for week \(weekOfTraining)")

        do {
            let dto = try await remoteDataSource.generateWeeklyPlan(
                weekOfTraining: weekOfTraining,
                forceGenerate: forceGenerate,
                promptVersion: promptVersion,
                methodology: methodology
            )

            let entity = WeeklyPlanV2Mapper.toEntity(from: dto)

            // Cache the result
            localDataSource.saveWeeklyPlan(entity, week: weekOfTraining)

            Logger.info("[TrainingPlanV2Repo] Weekly plan generated and cached: week \(weekOfTraining)")
            return entity
        } catch {
            logErrorToCloud(module: "WeeklyPlan", operation: "generate", error: error, context: ["week": weekOfTraining])
            throw error.toDomainError()
        }
    }

    func getWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] getWeeklyPlan for week \(weekOfTraining), overviewId: \(overviewId)")

        // Track A: Check local cache
        if let cached = localDataSource.getWeeklyPlan(week: weekOfTraining),
           !localDataSource.isWeeklyPlanExpired(week: weekOfTraining) {
            Logger.debug("[TrainingPlanV2Repo] Cache hit for week \(weekOfTraining)")
            return cached
        }

        // Cache miss 或過期 — 用 overviewId 組出正確的 planId 呼叫 GET API
        let planId = "\(overviewId)_\(weekOfTraining)"
        Logger.debug("[TrainingPlanV2Repo] Fetching from API with planId: \(planId)")
        return try await fetchAndCacheWeeklyPlan(planId: planId, week: weekOfTraining)
    }

    func fetchWeeklyPlan(planId: String) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] Fetching weekly plan by planId: \(planId)")
        let dto = try await remoteDataSource.getWeeklyPlan(planId: planId)
        let entity = WeeklyPlanV2Mapper.toEntity(from: dto)
        let week = entity.effectiveWeek
        if week > 0 {
            localDataSource.saveWeeklyPlan(entity, week: week)
        }
        Logger.info("[TrainingPlanV2Repo] Weekly plan fetched and cached: \(planId)")
        return entity
    }

    func updateWeeklyPlan(planId: String, updates: UpdateWeeklyPlanRequest) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] Updating weekly plan: \(planId)")
        let dto = try await remoteDataSource.updateWeeklyPlan(planId: planId, updates: updates)
        let entity = WeeklyPlanV2Mapper.toEntity(from: dto)
        let week = entity.effectiveWeek
        if week > 0 {
            localDataSource.saveWeeklyPlan(entity, week: week)
        }
        Logger.info("[TrainingPlanV2Repo] Weekly plan updated and cached: \(planId)")
        return entity
    }

    func refreshWeeklyPlan(weekOfTraining: Int, overviewId: String) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] Force refresh weekly plan for week \(weekOfTraining)")

        let planId = "\(overviewId)_\(weekOfTraining)"
        return try await fetchAndCacheWeeklyPlan(planId: planId, week: weekOfTraining)
    }

    func deleteWeeklyPlan(planId: String) async throws {
        Logger.debug("[TrainingPlanV2Repo] 🗑️ [DEBUG] Deleting weekly plan: \(planId)")
        try await remoteDataSource.deleteWeeklyPlan(planId: planId)
        Logger.info("[TrainingPlanV2Repo] ✅ [DEBUG] Weekly plan deleted: \(planId)")
    }

    // MARK: - Weekly Summary

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        Logger.debug("[TrainingPlanV2Repo] Generating weekly summary for week \(weekOfPlan)")

        do {
            let dto = try await remoteDataSource.generateWeeklySummary(
                weekOfPlan: weekOfPlan,
                forceUpdate: forceUpdate
            )

            let entity = WeeklySummaryV2Mapper.toEntity(from: dto)

            // Cache the result
            localDataSource.saveWeeklySummary(entity, week: weekOfPlan)

            Logger.info("[TrainingPlanV2Repo] Weekly summary generated and cached: week \(weekOfPlan)")
            return entity
        } catch {
            logErrorToCloud(module: "WeeklySummary", operation: "generate", error: error, context: ["week": weekOfPlan])
            throw error.toDomainError()
        }
    }

    func getWeeklySummaries() async throws -> [WeeklySummaryItem] {
        Logger.debug("[TrainingPlanV2Repo] getWeeklySummaries")
        do {
            return try await remoteDataSource.getWeeklySummaries()
        } catch {
            logErrorToCloud(module: "WeeklySummary", operation: "list", error: error)
            throw error.toDomainError()
        }
    }

    func getWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        Logger.debug("[TrainingPlanV2Repo] getWeeklySummary for week \(weekOfPlan)")

        // Track A: Check local cache
        if let cached = localDataSource.getWeeklySummary(week: weekOfPlan),
           !localDataSource.isWeeklySummaryExpired(week: weekOfPlan) {
            Logger.debug("[TrainingPlanV2Repo] Cache hit for week \(weekOfPlan)")

            // Track B: Background refresh
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshWeeklySummaryInBackground(week: weekOfPlan)
            }

            return cached
        }

        // Cache miss - 先 GET，404 才 fallback 到 POST
        Logger.debug("[TrainingPlanV2Repo] Cache miss for week \(weekOfPlan), fetching or generating summary")
        return try await fetchOrGenerateWeeklySummary(week: weekOfPlan)
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        Logger.debug("[TrainingPlanV2Repo] Force refresh weekly summary for week \(weekOfPlan)")
        return try await generateWeeklySummary(weekOfPlan: weekOfPlan, forceUpdate: true)
    }

    func deleteWeeklySummary(summaryId: String) async throws {
        Logger.debug("[TrainingPlanV2Repo] 🗑️ [DEBUG] Deleting weekly summary: \(summaryId)")
        try await remoteDataSource.deleteWeeklySummary(summaryId: summaryId)
        Logger.info("[TrainingPlanV2Repo] ✅ [DEBUG] Weekly summary deleted: \(summaryId)")
    }

    // MARK: - Cache Management

    func clearCache() async {
        Logger.debug("[TrainingPlanV2Repo] Clearing all caches")
        localDataSource.clearAll()
    }

    func clearOverviewCache() async {
        Logger.debug("[TrainingPlanV2Repo] Clearing overview cache")
        localDataSource.clearOverview()
    }

    func clearWeeklyPlanCache(weekOfTraining: Int?) async {
        if let week = weekOfTraining {
            Logger.debug("[TrainingPlanV2Repo] Clearing weekly plan cache for week \(week)")
            localDataSource.clearWeeklyPlan(week: week)
        } else {
            Logger.debug("[TrainingPlanV2Repo] Clearing all weekly plan caches")
            localDataSource.clearAllWeeklyPlans()
        }
    }

    func clearWeeklySummaryCache(weekOfPlan: Int?) async {
        if let week = weekOfPlan {
            Logger.debug("[TrainingPlanV2Repo] Clearing weekly summary cache for week \(week)")
            localDataSource.clearWeeklySummary(week: week)
        } else {
            Logger.debug("[TrainingPlanV2Repo] Clearing all weekly summary caches")
            localDataSource.clearAllWeeklySummaries()
        }
    }

    func preloadData() async {
        Logger.debug("[TrainingPlanV2Repo] Preloading data")

        // Preload overview in background
        Task.detached(priority: .background) { [weak self] in
            do {
                _ = try await self?.getOverview()
                Logger.debug("[TrainingPlanV2Repo] Preload completed")
            } catch {
                Logger.debug("[TrainingPlanV2Repo] Preload failed: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    private func logErrorToCloud(
        module: String,
        operation: String,
        error: Error,
        context: [String: Any] = [:]
    ) {
        guard !error.isCancellationError else { return }

        var payload: [String: Any] = [
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "module": module,
            "operation": operation
        ]
        payload.merge(context) { _, new in new }

        Logger.firebase(
            "[\(module)] \(operation) failed: \(error.localizedDescription)",
            level: .error,
            labels: [
                "cloud_logging": "true",
                "module": module,
                "operation": operation
            ],
            jsonPayload: payload
        )
    }

    private func fetchAndCacheOverview() async throws -> PlanOverviewV2 {
        do {
            let dto = try await remoteDataSource.getOverview()
            let entity = PlanOverviewV2Mapper.toEntity(from: dto)
            localDataSource.saveOverview(entity)
            return entity
        } catch {
            logErrorToCloud(module: "PlanOverview", operation: "fetch", error: error)
            // 將 HTTPError 轉換為 DomainError
            throw error.toDomainError()
        }
    }

    private func refreshOverviewInBackground() async {
        do {
            _ = try await fetchAndCacheOverview()
            Logger.debug("[TrainingPlanV2Repo] Background refresh completed for overview")
        } catch {
            Logger.debug("[TrainingPlanV2Repo] Background refresh failed for overview: \(error)")
        }
    }

    private func fetchAndCacheWeeklyPlan(planId: String, week: Int) async throws -> WeeklyPlanV2 {
        do {
            let dto = try await remoteDataSource.getWeeklyPlan(planId: planId)
            let entity = WeeklyPlanV2Mapper.toEntity(from: dto)
            localDataSource.saveWeeklyPlan(entity, week: week)
            return entity
        } catch {
            logErrorToCloud(module: "WeeklyPlan", operation: "fetch", error: error, context: ["planId": planId, "week": week])
            // 將 HTTPError 轉換為 DomainError，確保 ViewModel 能正確處理 404
            throw error.toDomainError()
        }
    }

    private func refreshWeeklyPlanInBackground(week: Int) async {
        do {
            guard let cached = localDataSource.getWeeklyPlan(week: week) else {
                Logger.debug("[TrainingPlanV2Repo] No cached plan for week \(week), skipping background refresh")
                return
            }
            _ = try await fetchAndCacheWeeklyPlan(planId: cached.effectivePlanId, week: week)
            Logger.debug("[TrainingPlanV2Repo] Background refresh completed for week \(week) plan")
        } catch {
            Logger.debug("[TrainingPlanV2Repo] Background refresh failed for week \(week) plan: \(error)")
        }
    }

    private func refreshWeeklySummaryInBackground(week: Int) async {
        do {
            let dto = try await remoteDataSource.getWeeklySummary(weekOfPlan: week)
            let entity = WeeklySummaryV2Mapper.toEntity(from: dto)
            localDataSource.saveWeeklySummary(entity, week: week)
            Logger.debug("[TrainingPlanV2Repo] Background refresh completed for week \(week) summary")
        } catch {
            Logger.debug("[TrainingPlanV2Repo] Background refresh failed for week \(week) summary: \(error)")
        }
    }

    private func fetchOrGenerateWeeklySummary(week: Int) async throws -> WeeklySummaryV2 {
        do {
            let dto = try await remoteDataSource.getWeeklySummary(weekOfPlan: week)
            let entity = WeeklySummaryV2Mapper.toEntity(from: dto)
            localDataSource.saveWeeklySummary(entity, week: week)
            return entity
        } catch {
            if case .notFound = error.toDomainError() {
                return try await generateWeeklySummary(weekOfPlan: week, forceUpdate: nil)
            }
            logErrorToCloud(module: "WeeklySummary", operation: "fetch_or_generate", error: error, context: ["week": week])
            throw error.toDomainError()
        }
    }
}

// MARK: - Dependency Injection
extension DependencyContainer {

    /// 註冊 TrainingPlanV2 模組依賴
    /// 包含 DataSources、Repositories 的註冊
    func registerTrainingPlanV2Module() {
        // Step 1: Register DataSources
        let localDS = TrainingPlanV2LocalDataSource()
        register(localDS, forProtocol: TrainingPlanV2LocalDataSourceProtocol.self)

        let remoteDS = TrainingPlanV2RemoteDataSource()
        register(remoteDS, forProtocol: TrainingPlanV2RemoteDataSourceProtocol.self)

        // Step 2: Create and Register Repository
        let repository = TrainingPlanV2RepositoryImpl(
            remoteDataSource: resolve() as TrainingPlanV2RemoteDataSourceProtocol,
            localDataSource: resolve() as TrainingPlanV2LocalDataSourceProtocol
        )
        register(repository as TrainingPlanV2Repository, forProtocol: TrainingPlanV2Repository.self)

        Logger.debug("[DI] TrainingPlanV2 module dependencies registered")
    }
}
