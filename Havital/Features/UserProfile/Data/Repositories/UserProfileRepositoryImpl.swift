import Foundation

// MARK: - UserProfileRepositoryImpl
/// Implementation of UserProfileRepository protocol
/// Uses dual-track caching strategy: cache-first + background refresh
final class UserProfileRepositoryImpl: UserProfileRepository {

    // MARK: - Dependencies
    private let remoteDataSource: UserProfileRemoteDataSourceProtocol
    private let localDataSource: UserProfileLocalDataSourceProtocol
    private let targetRemoteDataSource: TargetRemoteDataSourceProtocol

    // MARK: - Initialization
    init(
        remoteDataSource: UserProfileRemoteDataSourceProtocol = UserProfileRemoteDataSource(),
        localDataSource: UserProfileLocalDataSourceProtocol = UserProfileLocalDataSource(),
        targetRemoteDataSource: TargetRemoteDataSourceProtocol = TargetRemoteDataSource()
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.targetRemoteDataSource = targetRemoteDataSource
    }

    // MARK: - User Profile

    func getUserProfile() async throws -> User {
        Logger.debug("[UserProfileRepo] getUserProfile")

        // Track A: Check local cache
        if let cached = localDataSource.getUserProfile(),
           !localDataSource.isUserProfileExpired() {
            Logger.debug("[UserProfileRepo] Cache hit")

            // Track B: Background refresh
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshInBackground()
            }

            return cached
        }

        // Cache miss or expired - fetch from API
        Logger.debug("[UserProfileRepo] Cache miss, fetching from API")
        return try await fetchAndCacheUserProfile()
    }

    func refreshUserProfile() async throws -> User {
        Logger.debug("[UserProfileRepo] Force refresh")
        return try await fetchAndCacheUserProfile()
    }

    func updateUserProfile(_ updates: [String: Any]) async throws -> User {
        Logger.debug("[UserProfileRepo] Updating profile with \(updates.count) fields")

        try await remoteDataSource.updateUserProfile(updates)

        // Invalidate cache and fetch fresh data
        localDataSource.clearUserProfile()
        return try await fetchAndCacheUserProfile()
    }

    func deleteAccount(userId: String) async throws {
        Logger.debug("[UserProfileRepo] Deleting account: \(userId)")

        try await remoteDataSource.deleteUser(userId: userId)

        // Clear all caches
        await clearCache()
    }

    // MARK: - Data Source

    func updateDataSource(_ dataSource: String) async throws {
        Logger.debug("[UserProfileRepo] Updating data source: \(dataSource)")

        try await remoteDataSource.updateDataSource(dataSource)

        // Invalidate profile cache since data_source is part of User
        localDataSource.clearUserProfile()
    }

    // MARK: - Heart Rate Zones

    func getHeartRateZones() async throws -> [HeartRateZone] {
        Logger.debug("[UserProfileRepo] Getting heart rate zones")

        // First check local cache
        if let cachedZones = localDataSource.getHeartRateZones(),
           !localDataSource.isHeartRateZonesExpired() {
            Logger.debug("[UserProfileRepo] HR zones cache hit")
            return cachedZones
        }

        // Get user profile to calculate zones
        let profile = try await getUserProfile()

        guard let maxHR = profile.maxHr, let restingHR = profile.relaxingHr else {
            throw UserProfileError.invalidHeartRate(message: "Missing heart rate data in profile")
        }

        // Calculate zones using HRR formula (using new HeartRateZone entity)
        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)

        // Cache the zones
        localDataSource.saveHeartRateZones(zones)

        return zones
    }

    func updateHeartRateZones(maxHR: Int, restingHR: Int) async throws -> [HeartRateZone] {
        Logger.debug("[UserProfileRepo] Updating HR zones (max: \(maxHR), resting: \(restingHR))")

        // Update user profile with new HR values
        let updates: [String: Any] = [
            "max_heart_rate": maxHR,
            "resting_heart_rate": restingHR
        ]
        _ = try await updateUserProfile(updates)

        // Calculate and cache new zones using new HeartRateZone entity
        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)
        localDataSource.saveHeartRateZones(zones)

        return zones
    }

    func syncHeartRateData(from user: User) async {
        Logger.debug("[UserProfileRepo] Syncing HR data from user")

        guard let maxHR = user.maxHr, let restingHR = user.relaxingHr,
              maxHR > 0, restingHR > 0, maxHR > restingHR else {
            Logger.debug("[UserProfileRepo] Invalid HR data, skipping sync")
            return
        }

        // Calculate and cache zones using new HeartRateZone entity
        let zones = HeartRateZone.calculateZones(maxHR: maxHR, restingHR: restingHR)
        localDataSource.saveHeartRateZones(zones)
    }

    // MARK: - Targets

    func getTargets() async throws -> [Target] {
        Logger.debug("[UserProfileRepo] Getting targets")

        // For targets, we always fetch fresh data (frequently changing)
        let targets = try await targetRemoteDataSource.getTargets()
        return targets
    }

    func createTarget(_ target: Target) async throws {
        Logger.debug("[UserProfileRepo] Creating target: \(target.name)")

        _ = try await targetRemoteDataSource.createTarget(target)
    }

    // MARK: - Statistics

    func calculateStatistics() async -> UserStatistics? {
        Logger.debug("[UserProfileRepo] Calculating statistics")

        guard let profile = localDataSource.getUserProfile() else {
            return nil
        }

        // Get targets (ignore errors, use empty array)
        let targets = (try? await getTargets()) ?? []

        return UserStatistics(userData: profile, targets: targets)
    }

    // MARK: - Personal Best

    func updatePersonalBest(distanceKm: Double, completeTime: Int) async throws {
        Logger.debug("[UserProfileRepo] Updating personal best: \(distanceKm)km in \(completeTime)s")

        let performanceData: [String: Any] = [
            "distance_km": distanceKm,
            "complete_time": completeTime
        ]

        try await remoteDataSource.updatePersonalBest(performanceData)

        // Invalidate cache to get fresh data
        localDataSource.clearUserProfile()
    }

    func detectPersonalBestUpdates(
        oldData: [String: [PersonalBestRecordV2]]?,
        newData: [String: [PersonalBestRecordV2]]?
    ) async {
        Logger.debug("[UserProfileRepo] Detecting PB updates")

        // Check if this is first load (skip celebration)
        let isFirstLoad = oldData == nil || oldData?.isEmpty == true
        if isFirstLoad {
            Logger.debug("[UserProfileRepo] First load, skipping PB detection")
            return
        }

        guard let newData = newData else { return }
        var updates: [PersonalBestUpdate] = []

        // Compare each distance
        for (distance, newRecords) in newData {
            guard let newBest = newRecords.first else { continue }

            if let oldRecords = oldData?[distance],
               let oldBest = oldRecords.first {
                // Compare completion time (lower is better)
                if newBest.completeTime < oldBest.completeTime {
                    let improvement = oldBest.completeTime - newBest.completeTime
                    updates.append(PersonalBestUpdate(
                        distance: distance,
                        oldTime: oldBest.completeTime,
                        newTime: newBest.completeTime,
                        improvementSeconds: improvement,
                        workoutDate: newBest.workoutDate,
                        detectedAt: Date()
                    ))

                    Logger.firebase(
                        "PB update detected",
                        level: .info,
                        labels: ["module": "UserProfileRepo", "action": "detect_pb_update"],
                        jsonPayload: [
                            "distance": distance,
                            "improvement_seconds": improvement
                        ]
                    )
                }
            }
        }

        // Save the best update (longest distance priority)
        if let bestUpdate = updates.max(by: { $0.distancePriority < $1.distancePriority }) {
            savePersonalBestUpdate(bestUpdate)
        }
    }

    func getPendingCelebrationUpdate() -> PersonalBestUpdate? {
        let cache = PersonalBestCelebrationStorage.load()
        return (!cache.hasShownCelebration && cache.lastDetectedUpdate != nil)
            ? cache.lastDetectedUpdate
            : nil
    }

    func markCelebrationAsShown() {
        var cache = PersonalBestCelebrationStorage.load()
        cache.hasShownCelebration = true
        PersonalBestCelebrationStorage.save(cache)
        Logger.debug("[UserProfileRepo] Celebration marked as shown")
    }

    // MARK: - Cache Management

    func clearCache() async {
        Logger.debug("[UserProfileRepo] Clearing all caches")
        localDataSource.clearAll()
    }

    func isCacheExpired() -> Bool {
        return localDataSource.isUserProfileExpired()
    }

    // MARK: - Private Methods

    private func fetchAndCacheUserProfile() async throws -> User {
        let profile = try await remoteDataSource.getUserProfile()
        localDataSource.saveUserProfile(profile)
        return profile
    }

    private func refreshInBackground() async {
        do {
            let profile = try await remoteDataSource.getUserProfile()
            localDataSource.saveUserProfile(profile)
            Logger.debug("[UserProfileRepo] Background refresh success")
        } catch {
            Logger.debug("[UserProfileRepo] Background refresh failed (non-critical): \(error.localizedDescription)")
        }
    }

    private func savePersonalBestUpdate(_ update: PersonalBestUpdate) {
        var cache = PersonalBestCelebrationStorage.load()
        cache.lastDetectedUpdate = update
        cache.hasShownCelebration = false
        cache.lastCheckTimestamp = Date()
        PersonalBestCelebrationStorage.save(cache)

        NotificationCenter.default.post(
            name: .personalBestDidUpdate,
            object: update
        )
    }
}

// MARK: - DependencyContainer Extension
extension DependencyContainer {

    /// Register UserProfile module dependencies
    func registerUserProfileModule() {
        // DataSources
        let userRemoteDS = UserProfileRemoteDataSource(
            httpClient: resolve(),
            parser: resolve()
        )
        register(userRemoteDS, forProtocol: UserProfileRemoteDataSourceProtocol.self)

        let userLocalDS = UserProfileLocalDataSource()
        register(userLocalDS, forProtocol: UserProfileLocalDataSourceProtocol.self)

        let prefsRemoteDS = UserPreferencesRemoteDataSource(
            httpClient: resolve(),
            parser: resolve()
        )
        register(prefsRemoteDS, forProtocol: UserPreferencesRemoteDataSourceProtocol.self)

        let prefsLocalDS = UserPreferencesLocalDataSource()
        register(prefsLocalDS, forProtocol: UserPreferencesLocalDataSourceProtocol.self)

        let targetRemoteDS = TargetRemoteDataSource()
        register(targetRemoteDS, forProtocol: TargetRemoteDataSourceProtocol.self)

        // Repositories
        let userRepo = UserProfileRepositoryImpl(
            remoteDataSource: resolve() as UserProfileRemoteDataSourceProtocol,
            localDataSource: resolve() as UserProfileLocalDataSourceProtocol,
            targetRemoteDataSource: resolve() as TargetRemoteDataSourceProtocol
        )
        register(userRepo as UserProfileRepository, forProtocol: UserProfileRepository.self)

        let prefsRepo = UserPreferencesRepositoryImpl(
            remoteDataSource: resolve() as UserPreferencesRemoteDataSourceProtocol,
            localDataSource: resolve() as UserPreferencesLocalDataSourceProtocol
        )
        register(prefsRepo as UserPreferencesRepository, forProtocol: UserPreferencesRepository.self)

        Logger.debug("[DI] UserProfile module registered")
    }

    // MARK: - Use Case Factories

    func makeGetUserProfileUseCase() -> GetUserProfileUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return GetUserProfileUseCase(repository: resolve())
    }

    func makeUpdateUserProfileUseCase() -> UpdateUserProfileUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return UpdateUserProfileUseCase(repository: resolve())
    }

    func makeGetHeartRateZonesUseCase() -> GetHeartRateZonesUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return GetHeartRateZonesUseCase(repository: resolve())
    }

    func makeUpdateHeartRateZonesUseCase() -> UpdateHeartRateZonesUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return UpdateHeartRateZonesUseCase(repository: resolve())
    }

    func makeGetUserTargetsUseCase() -> GetUserTargetsUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return GetUserTargetsUseCase(repository: resolve())
    }

    func makeCreateTargetUseCase() -> CreateTargetUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return CreateTargetUseCase(repository: resolve())
    }

    func makeSyncUserPreferencesUseCase() -> SyncUserPreferencesUseCase {
        if !isRegistered(UserPreferencesRepository.self) {
            registerUserProfileModule()
        }
        return SyncUserPreferencesUseCase(preferencesRepository: resolve())
    }

    func makeCalculateUserStatsUseCase() -> CalculateUserStatsUseCase {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        return CalculateUserStatsUseCase(repository: resolve())
    }
}
