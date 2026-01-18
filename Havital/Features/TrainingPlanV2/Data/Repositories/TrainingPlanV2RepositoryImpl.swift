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

    // MARK: - Plan Overview

    func createOverviewForRace(targetId: String, startFromStage: String?) async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Creating overview for race: \(targetId)")

        let dto = try await remoteDataSource.createOverviewForRace(
            targetId: targetId,
            startFromStage: startFromStage
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
        startFromStage: String?
    ) async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Creating overview for \(targetType)")

        let dto = try await remoteDataSource.createOverviewForNonRace(
            targetType: targetType,
            trainingWeeks: trainingWeeks,
            availableDays: availableDays,
            methodologyId: methodologyId,
            startFromStage: startFromStage
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

            // Track B: Background refresh
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshOverviewInBackground()
            }

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

    func updateOverview(overviewId: String, startFromStage: String?) async throws -> PlanOverviewV2 {
        Logger.debug("[TrainingPlanV2Repo] Updating overview: \(overviewId)")

        let dto = try await remoteDataSource.updateOverview(
            overviewId: overviewId,
            startFromStage: startFromStage
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
    }

    func getWeeklyPlan(weekOfTraining: Int) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] getWeeklyPlan for week \(weekOfTraining)")

        // Track A: Check local cache
        if let cached = localDataSource.getWeeklyPlan(week: weekOfTraining),
           !localDataSource.isWeeklyPlanExpired(week: weekOfTraining) {
            Logger.debug("[TrainingPlanV2Repo] Cache hit for week \(weekOfTraining)")

            // Track B: Background refresh
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshWeeklyPlanInBackground(week: weekOfTraining)
            }

            return cached
        }

        // Cache miss - generate plan
        Logger.debug("[TrainingPlanV2Repo] Cache miss for week \(weekOfTraining), generating plan")
        return try await generateWeeklyPlan(
            weekOfTraining: weekOfTraining,
            forceGenerate: nil,
            promptVersion: nil,
            methodology: nil
        )
    }

    func refreshWeeklyPlan(weekOfTraining: Int) async throws -> WeeklyPlanV2 {
        Logger.debug("[TrainingPlanV2Repo] Force refresh weekly plan for week \(weekOfTraining)")
        return try await generateWeeklyPlan(
            weekOfTraining: weekOfTraining,
            forceGenerate: true,
            promptVersion: nil,
            methodology: nil
        )
    }

    // MARK: - Weekly Summary

    func generateWeeklySummary(weekOfPlan: Int, forceUpdate: Bool?) async throws -> WeeklySummaryV2 {
        Logger.debug("[TrainingPlanV2Repo] Generating weekly summary for week \(weekOfPlan)")

        let dto = try await remoteDataSource.generateWeeklySummary(
            weekOfPlan: weekOfPlan,
            forceUpdate: forceUpdate
        )

        let entity = WeeklySummaryV2Mapper.toEntity(from: dto)

        // Cache the result
        localDataSource.saveWeeklySummary(entity, week: weekOfPlan)

        Logger.info("[TrainingPlanV2Repo] Weekly summary generated and cached: week \(weekOfPlan)")
        return entity
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

        // Cache miss - generate summary
        Logger.debug("[TrainingPlanV2Repo] Cache miss for week \(weekOfPlan), generating summary")
        return try await generateWeeklySummary(weekOfPlan: weekOfPlan, forceUpdate: nil)
    }

    func refreshWeeklySummary(weekOfPlan: Int) async throws -> WeeklySummaryV2 {
        Logger.debug("[TrainingPlanV2Repo] Force refresh weekly summary for week \(weekOfPlan)")
        return try await generateWeeklySummary(weekOfPlan: weekOfPlan, forceUpdate: true)
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

    private func fetchAndCacheOverview() async throws -> PlanOverviewV2 {
        let dto = try await remoteDataSource.getOverview()
        let entity = PlanOverviewV2Mapper.toEntity(from: dto)
        localDataSource.saveOverview(entity)
        return entity
    }

    private func refreshOverviewInBackground() async {
        do {
            _ = try await fetchAndCacheOverview()
            Logger.debug("[TrainingPlanV2Repo] Background refresh completed for overview")
        } catch {
            Logger.debug("[TrainingPlanV2Repo] Background refresh failed for overview: \(error)")
        }
    }

    private func refreshWeeklyPlanInBackground(week: Int) async {
        do {
            let dto = try await remoteDataSource.generateWeeklyPlan(
                weekOfTraining: week,
                forceGenerate: false,
                promptVersion: nil,
                methodology: nil
            )
            let entity = WeeklyPlanV2Mapper.toEntity(from: dto)
            localDataSource.saveWeeklyPlan(entity, week: week)
            Logger.debug("[TrainingPlanV2Repo] Background refresh completed for week \(week) plan")
        } catch {
            Logger.debug("[TrainingPlanV2Repo] Background refresh failed for week \(week) plan: \(error)")
        }
    }

    private func refreshWeeklySummaryInBackground(week: Int) async {
        do {
            let dto = try await remoteDataSource.generateWeeklySummary(
                weekOfPlan: week,
                forceUpdate: false
            )
            let entity = WeeklySummaryV2Mapper.toEntity(from: dto)
            localDataSource.saveWeeklySummary(entity, week: week)
            Logger.debug("[TrainingPlanV2Repo] Background refresh completed for week \(week) summary")
        } catch {
            Logger.debug("[TrainingPlanV2Repo] Background refresh failed for week \(week) summary: \(error)")
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
