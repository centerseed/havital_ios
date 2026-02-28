import Foundation
import SwiftUI
import FirebaseAuth

// MARK: - UserProfileFeatureViewModel
/// Clean Architecture ViewModel for UserProfile feature
/// Replaces UserManager.shared and UserPreferencesManager.shared
@MainActor
class UserProfileFeatureViewModel: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - Published State

    /// User profile state
    @Published var profileState: ViewState<User> = .loading

    /// User preferences state
    @Published var preferencesState: ViewState<UserPreferences> = .loading

    /// Heart rate zones
    @Published var heartRateZones: [HeartRateZone] = []

    /// User targets
    @Published var targets: [Target] = []

    /// User statistics
    @Published var statistics: UserStatistics?

    /// Current VDOT value for pace zone display
    @Published var currentVDOT: Double = 0

    /// Loading states
    @Published var isLoadingZones = false
    @Published var isLoadingTargets = false

    /// Authentication state
    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?

    // MARK: - Convenience Properties

    /// Current user profile (convenience accessor)
    var currentUser: User? {
        if case .loaded(let user) = profileState {
            return user
        }
        return nil
    }

    /// Backward compatibility alias for currentUser
    var userData: User? {
        currentUser
    }

    /// Current preferences (convenience accessor)
    var preferences: UserPreferences? {
        if case .loaded(let prefs) = preferencesState {
            return prefs
        }
        return nil
    }

    /// Current data source
    var currentDataSource: DataSourceType {
        get { preferencesRepository.dataSourcePreference }
        set { Task { @MainActor in await updateDataSource(newValue) } }
    }

    /// Timezone preference (for display)
    var timezonePreference: String? {
        preferencesRepository.timezonePreference
    }

    /// Update data source preference (local only)
    func updateDataSource(_ dataSource: DataSourceType) async {
        await preferencesRepository.updateDataSource(dataSource)
    }

    /// Update data source and sync to backend
    /// Use this for onboarding and settings where backend sync is required
    func updateAndSyncDataSource(_ dataSource: DataSourceType) async throws {
        Logger.debug("[UserProfileVM] Updating and syncing data source: \(dataSource.displayName)")

        // 1. Update local preferences
        await preferencesRepository.updateDataSource(dataSource)

        // 2. Sync to backend
        try await userRepository.updateDataSource(dataSource.rawValue)

        Logger.debug("[UserProfileVM] Data source synced successfully")
    }

    /// Update timezone preference
    func updateTimezone(_ timezone: String) async throws {
        try await preferencesRepository.updatePreferences(language: nil, timezone: timezone)
    }

    /// Update language preference
    func updateLanguage(_ language: SupportedLanguage) async {
        await preferencesRepository.updateLanguagePreference(language)
    }

    // MARK: - Heart Rate Prompt Settings

    /// Do not show heart rate prompt
    var doNotShowHeartRatePrompt: Bool {
        get { preferencesRepository.doNotShowHeartRatePrompt }
        set { Task { @MainActor in await preferencesRepository.updateHeartRatePromptSettings(doNotShow: newValue, nextRemindDate: heartRatePromptNextRemindDate) } }
    }

    /// Next remind date for heart rate prompt
    var heartRatePromptNextRemindDate: Date? {
        get { preferencesRepository.heartRatePromptNextRemindDate }
        set { Task { @MainActor in await preferencesRepository.updateHeartRatePromptSettings(doNotShow: doNotShowHeartRatePrompt, nextRemindDate: newValue) } }
    }

    // MARK: - Heart Rate Data

    /// Max heart rate
    var maxHeartRate: Int? {
        preferencesRepository.maxHeartRate
    }

    /// Resting heart rate
    var restingHeartRate: Int? {
        preferencesRepository.restingHeartRate
    }

    /// Update heart rate data
    func updateHeartRateData(maxHR: Int, restingHR: Int) {
        preferencesRepository.updateHeartRateData(maxHR: maxHR, restingHR: restingHR)
    }

    /// Check if user has complete profile
    var hasCompleteProfile: Bool {
        guard let user = currentUser else { return false }
        return user.displayName != nil && user.email != nil
    }

    /// Check if onboarding is needed
    var needsOnboarding: Bool {
        return !hasCompleteProfile || heartRateZones.isEmpty
    }

    // MARK: - Loading/Error State (Backward Compatibility)

    /// Is profile loading
    var isLoading: Bool {
        if case .loading = profileState {
            return true
        }
        return false
    }

    /// Profile error (if any)
    var error: Error? {
        if case .error(let domainError) = profileState {
            return domainError
        }
        return nil
    }

    // MARK: - Dependencies

    private let getUserProfileUseCase: GetUserProfileUseCase
    private let updateUserProfileUseCase: UpdateUserProfileUseCase
    private let getHeartRateZonesUseCase: GetHeartRateZonesUseCase
    private let updateHeartRateZonesUseCase: UpdateHeartRateZonesUseCase
    private let getUserTargetsUseCase: GetUserTargetsUseCase
    private let createTargetUseCase: CreateTargetUseCase
    private let syncUserPreferencesUseCase: SyncUserPreferencesUseCase
    private let calculateUserStatsUseCase: CalculateUserStatsUseCase
    private let preferencesRepository: UserPreferencesRepository
    private let userRepository: UserProfileRepository
    private let authService: AuthenticationServiceProtocol

    // MARK: - Task Management
    let taskRegistry = TaskRegistry()

    // MARK: - Initialization

    init(
        getUserProfileUseCase: GetUserProfileUseCase,
        updateUserProfileUseCase: UpdateUserProfileUseCase,
        getHeartRateZonesUseCase: GetHeartRateZonesUseCase,
        updateHeartRateZonesUseCase: UpdateHeartRateZonesUseCase,
        getUserTargetsUseCase: GetUserTargetsUseCase,
        createTargetUseCase: CreateTargetUseCase,
        syncUserPreferencesUseCase: SyncUserPreferencesUseCase,
        calculateUserStatsUseCase: CalculateUserStatsUseCase,
        preferencesRepository: UserPreferencesRepository,
        userRepository: UserProfileRepository,
        authService: AuthenticationServiceProtocol = AuthenticationService.shared
    ) {
        self.getUserProfileUseCase = getUserProfileUseCase
        self.updateUserProfileUseCase = updateUserProfileUseCase
        self.getHeartRateZonesUseCase = getHeartRateZonesUseCase
        self.updateHeartRateZonesUseCase = updateHeartRateZonesUseCase
        self.getUserTargetsUseCase = getUserTargetsUseCase
        self.createTargetUseCase = createTargetUseCase
        self.syncUserPreferencesUseCase = syncUserPreferencesUseCase
        self.calculateUserStatsUseCase = calculateUserStatsUseCase
        self.preferencesRepository = preferencesRepository
        self.userRepository = userRepository
        self.authService = authService

        checkAuthenticationStatus()
    }

    /// Convenience initializer using DependencyContainer
    convenience init() {
        let container = DependencyContainer.shared

        if !container.isRegistered(UserProfileRepository.self) {
            container.registerUserProfileModule()
        }

        self.init(
            getUserProfileUseCase: container.makeGetUserProfileUseCase(),
            updateUserProfileUseCase: container.makeUpdateUserProfileUseCase(),
            getHeartRateZonesUseCase: container.makeGetHeartRateZonesUseCase(),
            updateHeartRateZonesUseCase: container.makeUpdateHeartRateZonesUseCase(),
            getUserTargetsUseCase: container.makeGetUserTargetsUseCase(),
            createTargetUseCase: container.makeCreateTargetUseCase(),
            syncUserPreferencesUseCase: container.makeSyncUserPreferencesUseCase(),
            calculateUserStatsUseCase: container.makeCalculateUserStatsUseCase(),
            preferencesRepository: container.resolve(),
            userRepository: container.resolve()
        )
    }

    // MARK: - Public Methods

    /// Initialize and load all data
    func initialize() async {
        Logger.debug("[UserProfileVM] Initializing...")

        checkAuthenticationStatus()

        if isAuthenticated {
            await loadAllData()
        }
    }

    /// Load all user data
    func loadAllData() async {
        await loadUserProfile()
        await loadHeartRateZones()
        await loadTargets()
        calculateStatistics()
        loadVDOT()
    }

    /// Load current VDOT value from VDOTManager
    func loadVDOT() {
        currentVDOT = VDOTManager.shared.currentVDOT
    }

    /// Load user profile
    /// - Parameter forceRefresh: Force refresh from API
    func loadUserProfile(forceRefresh: Bool = false) async {
        Logger.debug("[UserProfileVM] Loading user profile (force: \(forceRefresh))")

        profileState = .loading

        do {
            let input = GetUserProfileUseCase.Input(forceRefresh: forceRefresh)
            let output = try await getUserProfileUseCase.execute(input: input)

            profileState = .loaded(output.profile)

            // Sync preferences from user data
            await syncUserPreferencesUseCase.execute(input: .init(user: output.profile))

            // Detect personal best updates if refreshing
            if forceRefresh, let oldUser = currentUser {
                await userRepository.detectPersonalBestUpdates(
                    oldData: oldUser.personalBestV2?["race_run"],
                    newData: output.profile.personalBestV2?["race_run"]
                )
            }

            Logger.debug("[UserProfileVM] Profile loaded: \(output.profile.displayName ?? "Unknown")")

        } catch {
            // Ignore cancellation errors - don't show ErrorView
            if isTaskCancelled(error) {
                Logger.debug("[UserProfileVM] Profile load task cancelled, ignoring")
                return
            }
            Logger.error("[UserProfileVM] Failed to load profile: \(error)")
            profileState = .error(mapToDomainError(error))
        }
    }

    /// Refresh user profile (force)
    func refreshUserProfile() async {
        await loadUserProfile(forceRefresh: true)
    }

    /// Backward compatibility alias for loadUserProfile
    /// - Note: Deprecated, use loadUserProfile() instead
    func fetchUserProfile() {
        Task { @MainActor in
            await loadUserProfile()
        }
    }

    /// Update user profile
    /// - Parameter updates: Dictionary of fields to update
    func updateUserProfile(_ updates: [String: Any]) async -> Bool {
        Logger.debug("[UserProfileVM] Updating profile with \(updates.count) fields")

        do {
            let input = UpdateUserProfileUseCase.Input(updates: updates)
            let output = try await updateUserProfileUseCase.execute(input: input)

            profileState = .loaded(output.updatedProfile)
            calculateStatistics()

            return true

        } catch {
            // Ignore cancellation errors
            if isTaskCancelled(error) {
                Logger.debug("[UserProfileVM] Profile update task cancelled, ignoring")
                return false
            }
            Logger.error("[UserProfileVM] Failed to update profile: \(error)")
            return false
        }
    }

    /// Update weekly distance
    /// - Parameter distance: New weekly distance in km
    func updateWeeklyDistance(_ distance: Int) async -> Bool {
        return await updateUserProfile(["current_week_distance": distance])
    }

    /// Backward compatibility alias for updateWeeklyDistance
    /// - Parameter distance: New weekly distance in km
    func updateWeeklyDistance(distance: Int) async {
        _ = await updateWeeklyDistance(distance)
    }

    // MARK: - Heart Rate Zones

    /// Load heart rate zones
    func loadHeartRateZones() async {
        Logger.debug("[UserProfileVM] Loading heart rate zones")

        isLoadingZones = true

        do {
            let output = try await getHeartRateZonesUseCase.execute()
            heartRateZones = output.zones
            Logger.debug("[UserProfileVM] Loaded \(output.zones.count) zones")

        } catch {
            // Ignore cancellation errors
            if isTaskCancelled(error) {
                Logger.debug("[UserProfileVM] HR zones load task cancelled, ignoring")
                isLoadingZones = false
                return
            }
            Logger.debug("[UserProfileVM] HR zones not available: \(error.localizedDescription)")
            heartRateZones = []
        }

        isLoadingZones = false
    }

    /// Update heart rate parameters
    /// - Parameters:
    ///   - maxHR: Maximum heart rate
    ///   - restingHR: Resting heart rate
    func updateHeartRateZones(maxHR: Int, restingHR: Int) async -> Bool {
        Logger.debug("[UserProfileVM] Updating HR zones (max: \(maxHR), resting: \(restingHR))")

        do {
            let input = UpdateHeartRateZonesUseCase.Input(maxHR: maxHR, restingHR: restingHR)
            let output = try await updateHeartRateZonesUseCase.execute(input: input)

            heartRateZones = output.zones
            return true

        } catch {
            // Ignore cancellation errors
            if isTaskCancelled(error) {
                Logger.debug("[UserProfileVM] HR zones update task cancelled, ignoring")
                return false
            }
            Logger.error("[UserProfileVM] Failed to update HR zones: \(error)")
            return false
        }
    }

    // MARK: - Targets

    /// Load user targets
    func loadTargets() async {
        Logger.debug("[UserProfileVM] Loading targets")

        isLoadingTargets = true

        do {
            let output = try await getUserTargetsUseCase.execute()
            targets = output.targets
            Logger.debug("[UserProfileVM] Loaded \(output.targets.count) targets")

        } catch {
            // Ignore cancellation errors
            if isTaskCancelled(error) {
                Logger.debug("[UserProfileVM] Targets load task cancelled, ignoring")
                isLoadingTargets = false
                return
            }
            Logger.debug("[UserProfileVM] Failed to load targets: \(error.localizedDescription)")
            targets = []
        }

        isLoadingTargets = false
        calculateStatistics()
    }

    /// Create a new target
    /// - Parameter target: Target to create
    func createTarget(_ target: Target) async -> Bool {
        Logger.debug("[UserProfileVM] Creating target: \(target.name)")

        do {
            let input = CreateTargetUseCase.Input(target: target)
            try await createTargetUseCase.execute(input: input)

            // Reload targets
            await loadTargets()
            return true

        } catch {
            // Ignore cancellation errors
            if isTaskCancelled(error) {
                Logger.debug("[UserProfileVM] Target creation task cancelled, ignoring")
                return false
            }
            Logger.error("[UserProfileVM] Failed to create target: \(error)")
            return false
        }
    }

    // MARK: - Statistics

    /// Calculate and update statistics
    func calculateStatistics() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let output = await self.calculateUserStatsUseCase.execute() {
                self.statistics = output.statistics
            }
        }
    }

    // MARK: - Account Management

    /// Delete user account
    /// - Important: Resets onboarding status BEFORE deletion to ensure fresh onboarding on next login
    func deleteAccount() async throws {
        guard let userId = currentUserId else {
            throw UserProfileError.notAuthenticated
        }

        Logger.debug("[UserProfileVM] Deleting account: \(userId)")

        // ✅ STEP 1: Reset onboarding status in backend BEFORE deleting account
        // This ensures if the user logs in again with the same account (soft delete scenario),
        // they will go through onboarding again
        do {
            let onboardingRepo = DependencyContainer.shared.resolve() as OnboardingRepository
            try await onboardingRepo.resetOnboarding()
            Logger.debug("[UserProfileVM] Onboarding status reset successfully")
        } catch {
            Logger.error("[UserProfileVM] Failed to reset onboarding (non-critical): \(error.localizedDescription)")
            // Continue with deletion even if reset fails
        }

        // ✅ STEP 2: Delete account from backend
        try await userRepository.deleteAccount(userId: userId)

        // ✅ STEP 3: Publish user logout event to clear ALL caches (TrainingPlan, Workout, MonthlyStats, etc.)
        // This ensures no local data remains when the user logs in again
        CacheEventBus.shared.publish(.userLogout)

        // ✅ STEP 4: Sign out (clears UserDefaults, Firebase session, etc.)
        try await authService.signOut()

        // Clear state
        profileState = .loading
        preferencesState = .loading
        heartRateZones = []
        targets = []
        statistics = nil
        isAuthenticated = false
        currentUserId = nil
    }

    /// Sign out
    func signOut() async throws {
        Logger.debug("[UserProfileVM] Signing out")

        try await authService.signOut()
        await userRepository.clearCache()

        // Publish userLogout event so AuthenticationViewModel updates isAuthenticated
        // This is required for Demo mode where Firebase listener doesn't fire on signOut
        CacheEventBus.shared.publish(.userLogout)

        // Clear state
        profileState = .loading
        preferencesState = .loading
        heartRateZones = []
        targets = []
        statistics = nil
        isAuthenticated = false
        currentUserId = nil
    }

    // MARK: - Personal Best

    /// Get pending celebration update
    func getPendingCelebrationUpdate() -> PersonalBestUpdate? {
        return userRepository.getPendingCelebrationUpdate()
    }

    /// Mark celebration as shown
    func markCelebrationAsShown() {
        userRepository.markCelebrationAsShown()
    }

    // MARK: - Helper Methods

    private func checkAuthenticationStatus() {
        // Use injected authService instead of direct Auth.auth() dependence
        // This supports Demo Login mode where Auth.auth().currentUser might be nil but authService.isAuthenticated is true
        if authService.isAuthenticated {
            isAuthenticated = true
            // Prefer Firebase UID, fallback to AppUser email (for Demo mode)
            currentUserId = Auth.auth().currentUser?.uid ?? authService.appUser?.email
        } else {
            isAuthenticated = false
            currentUserId = nil
        }
    }

    private func mapToDomainError(_ error: Error) -> DomainError {
        if let profileError = error as? UserProfileError {
            return profileError.toDomainError()
        }
        return .unknown(error.localizedDescription)
    }

    /// Check if error is task cancellation (should be ignored for UI state)
    /// Uses the standardized isCancellationError extension for consistency
    private func isTaskCancelled(_ error: Error) -> Bool {
        return error.isCancellationError
    }

    // MARK: - Formatting Helpers

    func weekdayName(for index: Int) -> String {
        return ViewModelUtils.weekdayName(for: index)
    }

    func weekdayShortName(for index: Int) -> String {
        return ViewModelUtils.weekdayShortName(for: index)
    }

    func formatHeartRate(_ rate: Int?) -> String {
        guard let rate = rate else { return "-- bpm" }
        return "\(rate) bpm"
    }

    func formatHeartRate(_ rate: Int) -> String {
        return "\(rate) bpm"
    }

    func paceZoneColor(for zone: PaceCalculator.PaceZone) -> Color {
        switch zone {
        case .recovery: return .blue
        case .easy: return .green
        case .tempo: return .yellow
        case .marathon: return .orange
        case .threshold: return .orange
        case .anaerobic: return .purple
        case .interval: return .red
        }
    }

    func paceZoneType(_ zone: PaceCalculator.PaceZone) -> String {
        switch zone {
        case .recovery: return "recovery"
        case .easy: return "easy"
        case .tempo: return "tempo"
        case .marathon: return "marathon"
        case .threshold: return "threshold"
        case .anaerobic: return "anaerobic"
        case .interval: return "interval"
        }
    }

    func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    deinit {
        cancelAllTasks()
    }
}

// MARK: - DependencyContainer Factory
extension DependencyContainer {

    /// Create UserProfileFeatureViewModel with all dependencies
    @MainActor
    func makeUserProfileFeatureViewModel() -> UserProfileFeatureViewModel {
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }

        return UserProfileFeatureViewModel(
            getUserProfileUseCase: makeGetUserProfileUseCase(),
            updateUserProfileUseCase: makeUpdateUserProfileUseCase(),
            getHeartRateZonesUseCase: makeGetHeartRateZonesUseCase(),
            updateHeartRateZonesUseCase: makeUpdateHeartRateZonesUseCase(),
            getUserTargetsUseCase: makeGetUserTargetsUseCase(),
            createTargetUseCase: makeCreateTargetUseCase(),
            syncUserPreferencesUseCase: makeSyncUserPreferencesUseCase(),
            calculateUserStatsUseCase: makeCalculateUserStatsUseCase(),
            preferencesRepository: resolve(),
            userRepository: resolve(),
            authService: AuthenticationService.shared
        )
    }
}
