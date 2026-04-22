//
//  OnboardingFeatureViewModel.swift
//  Havital
//
//  Onboarding Feature ViewModel
//  Presentation Layer - Handles all onboarding step operations using Clean Architecture
//
//  This ViewModel orchestrates the entire onboarding flow by composing
//  existing repositories (UserProfile, Target, TrainingPlan).
//

import SwiftUI
import Combine

// MARK: - Onboarding Feature ViewModel
/// Unified ViewModel for the entire onboarding flow
/// Uses Clean Architecture principles with Repository dependencies
@MainActor
final class OnboardingFeatureViewModel: ObservableObject {

    // MARK: - Dependencies

    private let userProfileRepository: UserProfileRepository
    private let targetRepository: TargetRepository
    private let trainingPlanRepository: TrainingPlanRepository
    private let trainingPlanV2Repository: TrainingPlanV2Repository
    private let raceRepository: RaceRepository
    private let versionRouter: TrainingVersionRouting

    private var analyticsService: AnalyticsService {
        DependencyContainer.shared.resolve()
    }

    // MARK: - Shared State (across all steps)

    /// Target race distance in km
    @Published var targetDistance: Double = 21.0975

    /// Whether this is a beginner 5K plan
    @Published var isBeginner: Bool = false

    // MARK: - Personal Best State

    @Published var personalBestHours: Int = 0
    @Published var personalBestMinutes: Int = 0
    @Published var personalBestSeconds: Int = 0
    @Published var selectedPBDistance: String = "5"
    @Published var hasPersonalBest: Bool = false
    @Published var availablePersonalBests: [String: [PersonalBestRecordV2]] = [:]
    @Published var selectedPersonalBestKey: String?

    /// Computed pace based on personal best time and distance
    var currentPace: String {
        guard hasPersonalBest else { return "" }
        let totalSeconds = personalBestHours * 3600 + personalBestMinutes * 60 + personalBestSeconds
        guard totalSeconds > 0 else { return "" }

        let distanceKm = Double(selectedPBDistance) ?? 5.0
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }

    // MARK: - Weekly Distance State

    @Published var weeklyDistance: Double = 10.0
    @Published var isLoadingWeeklyHistory: Bool = false

    // MARK: - Goal Type State

    @Published var selectedGoalType: GoalType?

    // MARK: - V2 Goal Type State

    @Published var availableTargetTypes: [TargetTypeV2] = []
    @Published var selectedTargetTypeV2: TargetTypeV2?
    @Published var isLoadingTargetTypes: Bool = false

    // MARK: - Methodology State

    /// 當前目標類型的可用方法論列表
    @Published var availableMethodologies: [MethodologyV2] = []

    /// 使用者選擇的方法論
    @Published var selectedMethodology: MethodologyV2?

    /// 載入方法論的狀態
    @Published var isLoadingMethodologies: Bool = false

    /// 方法論載入錯誤
    @Published var methodologyError: String?

    // MARK: - Training Days State

    @Published var selectedWeekdays: Set<Int> = []
    @Published var selectedLongRunDay: Int = 6

    // MARK: - Training Overview State

    @Published var trainingOverview: TrainingPlanOverview?
    @Published var trainingOverviewV2: PlanOverviewV2?

    // MARK: - UI State

    @Published var isLoading: Bool = false
    @Published var isLoadingPreferences: Bool = false  // Separate state for loading preferences (no fullScreenCover)
    @Published var error: String?

    // MARK: - Available Distances for Personal Best

    let availablePBDistances: [String: String] = [
        "3": NSLocalizedString("distance.3k", comment: "3K"),
        "5": NSLocalizedString("distance.5k", comment: "5K"),
        "10": NSLocalizedString("distance.10k", comment: "10K"),
        "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
        "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
    ]

    // MARK: - Race Setup State (merged from OnboardingViewModel)

    /// 賽事名稱（手動輸入）
    @Published var raceName: String = ""

    /// 賽事日期
    @Published var raceDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    /// 選擇的距離（字串，用於 Picker 匹配）
    @Published var selectedDistance: String = "42.195"

    /// 目標完賽時數
    @Published var targetHours: Int = 4

    /// 目標完賽分鐘數
    @Published var targetMinutes: Int = 0

    /// 起始階段選擇相關狀態
    @Published var selectedStartStage: TrainingStagePhase? = nil
    @Published var shouldShowStageSelection: Bool = false

    /// 未來目標選擇相關狀態
    @Published var availableTargets: [Target] = []
    @Published var selectedTargetKey: String?
    @Published var isLoadingTargets: Bool = false

    // MARK: - Race API State

    /// 從 API 載入的精選賽事列表
    @Published var raceEvents: [RaceEvent] = []

    /// 賽事 API 是否可用
    @Published var isRaceAPIAvailable: Bool = true

    /// 賽事列表載入中
    @Published var isLoadingRaces: Bool = false

    /// 用戶選擇的賽事
    @Published var selectedRaceEvent: RaceEvent? = nil

    /// 用戶選擇的賽事距離
    @Published var selectedRaceDistance: RaceDistance? = nil

    /// 選擇的地區
    @Published var selectedRegion: String = "tw"

    // MARK: - Computed Properties (Race Setup)

    /// 可選距離字典（用於 RaceSetup）
    var availableDistances: [String: String] {
        [
            "5": NSLocalizedString("distance.5k", comment: "5K"),
            "10": NSLocalizedString("distance.10k", comment: "10K"),
            "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
            "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
        ]
    }

    /// 使用「週邊界」演算法計算訓練週數（與後端一致）
    var trainingWeeks: Int {
        return TrainingWeeksCalculator.calculateTrainingWeeks(
            startDate: Date(),
            raceDate: raceDate
        )
    }

    /// 保留舊的計算方式用於對比（僅供參考）
    var actualWeeksRemaining: Double {
        let (_, weeks) = TrainingWeeksCalculator.calculateActualDateDifference(
            startDate: Date(),
            raceDate: raceDate
        )
        return weeks
    }

    /// 目標配速
    var targetPace: String {
        let totalSeconds = targetHours * 3600 + targetMinutes * 60
        let distanceKm = Double(selectedDistance) ?? 42.195
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }

    // MARK: - Initialization

    init(
        userProfileRepository: UserProfileRepository,
        targetRepository: TargetRepository,
        trainingPlanRepository: TrainingPlanRepository,
        trainingPlanV2Repository: TrainingPlanV2Repository,
        raceRepository: RaceRepository,
        versionRouter: TrainingVersionRouting
    ) {
        self.userProfileRepository = userProfileRepository
        self.targetRepository = targetRepository
        self.trainingPlanRepository = trainingPlanRepository
        self.trainingPlanV2Repository = trainingPlanV2Repository
        self.raceRepository = raceRepository
        self.versionRouter = versionRouter

        Logger.debug("[OnboardingFeatureVM] Initialized with repositories (including V2 + Race + VersionRouter)")
    }

    /// Convenience initializer for DI
    convenience init() {
        let container = DependencyContainer.shared
        container.registerTrainingVersionRouter()
        self.init(
            userProfileRepository: container.resolve(),
            targetRepository: container.resolve(),
            trainingPlanRepository: container.resolve(),
            trainingPlanV2Repository: container.resolve(),
            raceRepository: container.resolve(),
            versionRouter: container.resolve() as TrainingVersionRouting
        )
    }

    // MARK: - Personal Best Methods

    /// Load existing personal bests from user profile
    func loadPersonalBests() async {
        Logger.debug("[OnboardingFeatureVM] Loading personal bests")

        do {
            let user = try await userProfileRepository.getUserProfile()

            if let personalBestV2 = user.personalBestV2,
               let raceRunData = personalBestV2["race_run"],
               !raceRunData.isEmpty {
                self.availablePersonalBests = raceRunData
                self.hasPersonalBest = true
                prefillClosestPersonalBestIfAvailable()
                Logger.debug("[OnboardingFeatureVM] Loaded \(raceRunData.count) PB distances")
            } else {
                clearPersonalBestSelection()
                hasPersonalBest = false
                availablePersonalBests = [:]
                Logger.debug("[OnboardingFeatureVM] No PB found, defaulting hasPersonalBest to false")
            }
        } catch {
            clearPersonalBestSelection()
            hasPersonalBest = false
            availablePersonalBests = [:]
            Logger.debug("[OnboardingFeatureVM] Failed to load PBs: \(error.localizedDescription)")
            // Don't show error - new users may not have PBs
        }
    }

    /// Select an existing personal best
    func selectPersonalBest(distanceKey: String) {
        guard let records = availablePersonalBests[distanceKey],
              let bestRecord = records.first else { return }

        let normalizedDistance = normalizeDistanceKey(distanceKey)
        selectedPBDistance = normalizedDistance
        selectedPersonalBestKey = distanceKey

        let totalSeconds = bestRecord.completeTime
        personalBestHours = totalSeconds / 3600
        personalBestMinutes = (totalSeconds % 3600) / 60
        personalBestSeconds = totalSeconds % 60

        Logger.debug("[OnboardingFeatureVM] Selected PB: \(distanceKey)km, time: \(bestRecord.formattedTime())")
    }

    /// Update personal best data
    func updatePersonalBest() async -> Bool {
        isLoading = true
        error = nil

        do {
            if hasPersonalBest {
                let totalSeconds = personalBestHours * 3600 + personalBestMinutes * 60 + personalBestSeconds
                guard totalSeconds > 0 else {
                    error = NSLocalizedString("onboarding.enter_valid_time", comment: "Enter Valid Time")
                    isLoading = false
                    return false
                }

                let normalizedDistance = normalizeDistance(selectedPBDistance)
                try await userProfileRepository.updatePersonalBest(
                    distanceKm: normalizedDistance,
                    completeTime: totalSeconds
                )

                Logger.debug("[OnboardingFeatureVM] Personal best updated successfully")
            } else {
                Logger.debug("[OnboardingFeatureVM] User has no PB, skipping update")
            }

            // Save hasPersonalBest state for later navigation logic
            UserDefaults.standard.set(hasPersonalBest, forKey: "onboarding_hasPersonalBest")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Weekly Distance Methods

    /// Load historical weekly distance from summaries
    /// Updates weeklyDistance if history exists, otherwise keeps the default value
    func loadHistoricalWeeklyDistance() async {
        isLoadingWeeklyHistory = true

        do {
            // Use WeeklySummaryService for now (peripheral service, not user data)
            let summaries = try await WeeklySummaryService.shared.fetchAllWeeklyVolumes(limit: 8)

            if !summaries.isEmpty {
                let recentWeeks = summaries.suffix(4)
                let distances = recentWeeks.compactMap { $0.distanceKm }.filter { $0 > 0 }

                if !distances.isEmpty {
                    let average = distances.reduce(0, +) / Double(distances.count)
                    weeklyDistance = min(max(average, 5.0), 30.0)
                    Logger.debug("[OnboardingFeatureVM] Updated weekly distance from history: \(weeklyDistance)km")
                } else {
                    Logger.debug("[OnboardingFeatureVM] No valid historical data found, keeping default 10km")
                }
            } else {
                Logger.debug("[OnboardingFeatureVM] No historical summaries found, keeping default 10km")
            }
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load weekly history: \(error.localizedDescription), keeping default 10km")
        }

        isLoadingWeeklyHistory = false
    }

    /// Save weekly distance to user profile
    func saveWeeklyDistance() async -> Bool {
        isLoading = true
        error = nil

        do {
            let weeklyDistanceInt = Int(weeklyDistance.rounded())
            let updates: [String: Any] = ["current_week_distance": weeklyDistanceInt]

            _ = try await userProfileRepository.updateUserProfile(updates)
            Logger.debug("[OnboardingFeatureVM] Weekly distance saved: \(weeklyDistanceInt)km")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Determine next step after weekly distance based on user data
    func determineNextStepAfterWeeklyDistance() -> OnboardingCoordinator.Step {
        // V2 Flow: Always go to Goal Type first to let user choose their training target
        // Goal Type will then navigate to appropriate next step based on selection
        return .goalType
    }

    // MARK: - Goal Type Methods

    /// Called from GoalTypeSelectionView for non-race paths where no additional race info is collected.
    func trackTargetSetForNonRace(targetType: TargetTypeV2) {
        analyticsService.track(.onboardingTargetSet(
            targetType: targetType.id,
            raceId: nil,
            distanceKm: nil
        ))
    }

    /// Load V2 target types from API
    func loadTargetTypes() async {
        Logger.debug("[OnboardingFeatureVM] Starting to load V2 target types...")
        isLoadingTargetTypes = true
        error = nil

        do {
            let targetTypes = try await trainingPlanV2Repository.getTargetTypes()
            await MainActor.run {
                self.availableTargetTypes = targetTypes
                if targetTypes.isEmpty {
                    Logger.warn("[OnboardingFeatureVM] ⚠️ API returned 0 target types - will show V1 fallback options")
                } else {
                    Logger.info("[OnboardingFeatureVM] ✅ Loaded \(targetTypes.count) V2 target types: \(targetTypes.map { $0.id }.joined(separator: ", "))")
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                Logger.error("[OnboardingFeatureVM] ❌ Failed to load target types: \(error.localizedDescription)")
                Logger.error("[OnboardingFeatureVM] Will fall back to V1 legacy options")
            }
        }

        await MainActor.run {
            self.isLoadingTargetTypes = false
        }
    }

    // MARK: - Methodology Methods

    /// 載入指定目標類型的方法論列表
    func loadMethodologiesForTargetType(_ targetType: String) async {
        Logger.debug("[OnboardingFeatureVM] Loading methodologies for: \(targetType)")
        isLoadingMethodologies = true
        methodologyError = nil

        do {
            let methodologies = try await trainingPlanV2Repository.getMethodologies(targetType: targetType)

            await MainActor.run {
                self.availableMethodologies = methodologies

                // 如果只有一個方法論，自動選擇
                if methodologies.count == 1 {
                    self.selectedMethodology = methodologies[0]
                    Logger.debug("[OnboardingFeatureVM] Auto-selected single methodology: \(methodologies[0].id)")
                }
                // 如果有預設方法論，優先選擇
                else if let targetTypeV2 = self.selectedTargetTypeV2,
                        let defaultMethod = methodologies.first(where: { $0.id == targetTypeV2.defaultMethodology }) {
                    self.selectedMethodology = defaultMethod
                    Logger.debug("[OnboardingFeatureVM] Pre-selected default methodology: \(defaultMethod.id)")
                }

                Logger.info("[OnboardingFeatureVM] Loaded \(methodologies.count) methodologies")
            }
        } catch {
            await MainActor.run {
                self.methodologyError = error.localizedDescription
                Logger.error("[OnboardingFeatureVM] Failed to load methodologies: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            self.isLoadingMethodologies = false
        }
    }

    /// 重置方法論相關狀態
    func resetMethodologyState() {
        availableMethodologies = []
        selectedMethodology = nil
        isLoadingMethodologies = false
        methodologyError = nil
    }

    /// Create V2 training plan overview
    /// - Parameters:
    ///   - targetType: 目標類型（beginner, maintenance, race_run）
    ///   - trainingWeeks: 訓練週數（非賽事模式必填）
    ///   - targetId: 目標 ID（賽事模式必填）
    ///   - startFromStage: 起始階段（可選）
    /// - Returns: 創建的 PlanOverviewV2，失敗時返回 nil
    func createPlanOverviewV2(
        targetType: TargetTypeV2,
        trainingWeeks: Int?,
        targetId: String?,
        startFromStage: String? = nil,
        methodologyId: String? = nil,
        intendedRaceDistanceKm: Int? = nil
    ) async -> PlanOverviewV2? {
        isLoading = true
        error = nil

        let resolvedMethodologyId = methodologyId ?? selectedMethodology?.id

        do {
            let overview: PlanOverviewV2

            if targetType.isRaceRunTarget {
                // 賽事模式：需要 targetId
                guard let targetId = targetId else {
                    error = NSLocalizedString("onboarding.race_target_required", comment: "Race target required")
                    isLoading = false
                    return nil
                }

                overview = try await trainingPlanV2Repository.createOverviewForRace(
                    targetId: targetId,
                    startFromStage: startFromStage,
                    methodologyId: resolvedMethodologyId
                )
            } else {
                // 非賽事模式：需要 trainingWeeks
                guard let trainingWeeks = trainingWeeks else {
                    error = NSLocalizedString("onboarding.training_weeks_required", comment: "Training weeks required")
                    isLoading = false
                    return nil
                }

                overview = try await trainingPlanV2Repository.createOverviewForNonRace(
                    targetType: targetType.id,
                    trainingWeeks: trainingWeeks,
                    availableDays: selectedWeekdays.count > 0 ? selectedWeekdays.count : nil,
                    methodologyId: resolvedMethodologyId,
                    startFromStage: startFromStage,
                    intendedRaceDistanceKm: intendedRaceDistanceKm
                )
            }

            // 存儲到 ViewModel
            self.trainingOverviewV2 = overview

            Logger.info("[OnboardingFeatureVM] ✅ V2 plan overview created: \(overview.id) for targetType: \(targetType.id)")
            isLoading = false
            return overview
        } catch {
            Logger.error("[OnboardingFeatureVM] ❌ Failed to create V2 overview: \(error.localizedDescription)")

            // Recovery path:
            // Some backend deployments may have succeeded in creating the overview
            // but returned a payload that fails DTO extraction on POST.
            // Retry fetching active overview before surfacing error to UI.
            do {
                let recoveredOverview = try await recoverOverviewAfterCreateFailure()
                self.trainingOverviewV2 = recoveredOverview
                Logger.warn("[OnboardingFeatureVM] ⚠️ POST create failed but recovered active overview via retry GET: \(recoveredOverview.id)")
                isLoading = false
                return recoveredOverview
            } catch {
                let previewOverview = await buildLocalPreviewOverview(
                    targetType: targetType,
                    trainingWeeks: trainingWeeks,
                    targetId: targetId,
                    startFromStage: startFromStage,
                    methodologyId: resolvedMethodologyId,
                    intendedRaceDistanceKm: intendedRaceDistanceKm
                )

                self.trainingOverviewV2 = previewOverview
                Logger.warn("[OnboardingFeatureVM] ⚠️ Recovery via GET /v2/plan/overview failed. Falling back to local preview overview: \(previewOverview.id)")
                isLoading = false
                return previewOverview
            }
        }
    }

    /// Create beginner 5K goal (V1 compatibility)
    func createBeginner5kGoal() async -> Bool {
        isLoading = true
        error = nil

        do {
            let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date()) ?? Date()
            let target = Target(
                id: UUID().uuidString,
                type: "race_run",
                name: NSLocalizedString("onboarding.beginner_5k_goal", comment: "Can run 5km"),
                distanceKm: 5,
                targetTime: 40 * 60,
                targetPace: "8:00",
                raceDate: Int(raceDate.timeIntervalSince1970),
                isMainRace: true,
                trainingWeeks: 4
            )

            _ = try await targetRepository.createTarget(target)
            isBeginner = true
            Logger.debug("[OnboardingFeatureVM] Beginner 5K goal created")

            analyticsService.track(.onboardingTargetSet(
                targetType: "beginner",
                raceId: nil,
                distanceKm: 5.0
            ))

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Training Days Methods

    /// Load user's training day preferences
    func loadTrainingDayPreferences() async {
        // ✅ Use separate loading state to avoid triggering fullScreenCover
        // This loading is fast (reads from cache) and doesn't need a full-screen loading animation
        isLoadingPreferences = true

        do {
            let user = try await userProfileRepository.getUserProfile()

            if let weekdayPreferences = user.preferWeekDays, !weekdayPreferences.isEmpty {
                selectedWeekdays = Set(weekdayPreferences)
                Logger.debug("[OnboardingFeatureVM] Loaded training days: \(weekdayPreferences)")
            }

            if let longrunDays = user.preferWeekDaysLongrun,
               let longrunDay = longrunDays.first {
                selectedLongRunDay = longrunDay
                Logger.debug("[OnboardingFeatureVM] Loaded long run day: \(longrunDay)")
            } else if !selectedWeekdays.isEmpty {
                selectedLongRunDay = selectedWeekdays.contains(6) ? 6 : (selectedWeekdays.sorted().first ?? 6)
            }
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load training days: \(error.localizedDescription)")
        }

        isLoadingPreferences = false
    }

    /// Save training day preferences and generate overview
    func saveTrainingDaysAndGenerateOverview(startFromStage: String?) async -> Bool {
        guard !selectedWeekdays.isEmpty else {
            error = NSLocalizedString("onboarding.select_at_least_one_day", comment: "Select at least one day")
            return false
        }

        guard selectedWeekdays.contains(selectedLongRunDay) else {
            error = NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day")
            return false
        }

        isLoading = true
        error = nil

        do {
            // Update user preferences
            let preferences: [String: Any] = [
                "prefer_week_days": Array(selectedWeekdays),
                "prefer_week_days_longrun": [selectedLongRunDay]
            ]
            _ = try await userProfileRepository.updateUserProfile(preferences)

            // Generate training plan overview
            let overview = try await trainingPlanRepository.createOverview(
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            trainingOverview = overview
            Logger.debug("[OnboardingFeatureVM] Training overview created: \(overview.id)")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// Save training day preferences only (V2 flow - Overview created in CompleteOnboardingUseCase)
    func saveTrainingDaysPreferencesOnly() async -> Bool {
        guard !selectedWeekdays.isEmpty else {
            error = NSLocalizedString("onboarding.select_at_least_one_day", comment: "Select at least one day")
            return false
        }

        guard selectedWeekdays.contains(selectedLongRunDay) else {
            error = NSLocalizedString("onboarding.long_run_day_must_be_training_day", comment: "Long run day must be training day")
            return false
        }

        isLoading = true
        error = nil

        do {
            // Update user preferences only
            let preferences: [String: Any] = [
                "prefer_week_days": Array(selectedWeekdays),
                "prefer_week_days_longrun": [selectedLongRunDay]
            ]
            _ = try await userProfileRepository.updateUserProfile(preferences)

            Logger.debug("[OnboardingFeatureVM] V2: Training days preferences saved (no Overview yet)")

            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Target Management Methods

    /// Update an existing target
    func updateTarget(id: String, target: Target) async throws {
        Logger.debug("[OnboardingFeatureVM] Updating target: \(id)")
        _ = try await targetRepository.updateTarget(id: id, target: target)
    }

    /// Get all targets
    func getTargets() async throws -> [Target] {
        Logger.debug("[OnboardingFeatureVM] Getting all targets")
        return try await targetRepository.getTargets()
    }

    /// Delete a target
    func deleteTarget(id: String) async throws {
        Logger.debug("[OnboardingFeatureVM] Deleting target: \(id)")
        try await targetRepository.deleteTarget(id: id)
    }

    /// Create a new target
    func createTarget(_ target: Target) async throws {
        Logger.debug("[OnboardingFeatureVM] Creating target: \(target.name)")
        _ = try await targetRepository.createTarget(target)
    }

    // MARK: - Training Overview Methods

    /// Load training overview（依據版本路由器分流到 V1 / V2 Repository）
    ///
    /// V2 primary 防線：V2 用戶走 `trainingPlanV2Repository.getOverview()`；
    /// V1 用戶維持原本 `trainingPlanRepository.getOverview()`。
    /// Decorator 為 double safety，這裡的分流才是主要防線。
    func loadTrainingOverview() async {
        isLoading = true
        error = nil

        if await versionRouter.isV2User() {
            do {
                let overviewV2 = try await trainingPlanV2Repository.getOverview()
                trainingOverviewV2 = overviewV2
                Logger.firebase(
                    "onboarding_load_overview_v2",
                    level: .info,
                    labels: [
                        "cloud_logging": "true",
                        "module": "OnboardingVM",
                        "operation": "load_overview_v2"
                    ],
                    jsonPayload: [
                        "uid": AuthenticationService.shared.user?.uid ?? "",
                        "overview_id": overviewV2.id,
                        "tracking": "OnboardingFeatureVM: loadTrainingOverviewV2"
                    ]
                )
                Logger.debug("[OnboardingFeatureVM] V2 training overview loaded: \(overviewV2.id)")
            } catch {
                self.error = error.toDomainError().userFriendlyMessage
                Logger.warn("[OnboardingFeatureVM] V2 loadTrainingOverview failed: \(error.localizedDescription)")
            }
        } else {
            do {
                let overview = try await trainingPlanRepository.getOverview()
                trainingOverview = overview
                Logger.debug("[OnboardingFeatureVM: loadTrainingOverviewV1] Training overview loaded: \(overview.id)")
            } catch {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Load target pace from main race
    ///
    /// V2 用戶：優先從 `trainingOverviewV2.targetPace` 讀（overview 已嵌入 pace），
    /// 沒有則 fallback "6:00"（PlanOverviewV2 沒有 `mainRaceId` 欄位，對應的是 `targetId`）。
    /// V1 用戶：維持原本從 `trainingOverview.mainRaceId` 拉 target。
    func loadTargetPace() async -> String {
        if await versionRouter.isV2User() {
            if let overview = trainingOverviewV2, let pace = overview.targetPace, !pace.isEmpty {
                return pace
            }
            return "6:00"
        }

        guard let overview = trainingOverview, !overview.mainRaceId.isEmpty else {
            return "6:00"
        }

        do {
            let mainRace = try await targetRepository.getTarget(id: overview.mainRaceId)
            return mainRace.targetPace
        } catch {
            Logger.debug("[OnboardingFeatureVM] Failed to load target pace: \(error.localizedDescription)")
            return "6:00"
        }
    }

    /// Complete onboarding by creating weekly plan（依據版本路由器分流）
    ///
    /// V2 用戶：呼叫 `trainingPlanV2Repository.generateWeeklyPlan(weekOfTraining: 1, ...)`，
    /// methodology 視 `isBeginner` 決定：beginner → "beginner"，否則 "paceriz"。
    /// V1 用戶：維持原本 `trainingPlanRepository.createWeeklyPlan(...)`。
    func completeOnboarding(startFromStage: String?) async -> Bool {
        isLoading = true
        error = nil

        if await versionRouter.isV2User() {
            do {
                _ = try await trainingPlanV2Repository.generateWeeklyPlan(
                    weekOfTraining: 1,
                    forceGenerate: false,
                    promptVersion: "v2",
                    methodology: isBeginner ? "beginner" : "paceriz"
                )

                Logger.firebase(
                    "onboarding_complete_v2",
                    level: .info,
                    labels: [
                        "cloud_logging": "true",
                        "module": "OnboardingVM",
                        "operation": "complete_onboarding_v2"
                    ],
                    jsonPayload: [
                        "uid": AuthenticationService.shared.user?.uid ?? "",
                        "is_beginner": isBeginner,
                        "tracking": "OnboardingFeatureVM: completeOnboardingV2"
                    ]
                )
                Logger.debug("[OnboardingFeatureVM] V2 weekly plan generated, onboarding complete")
                isLoading = false
                return true
            } catch {
                self.error = error.toDomainError().userFriendlyMessage
                Logger.warn("[OnboardingFeatureVM] V2 completeOnboarding failed: \(error.localizedDescription)")
                isLoading = false
                return false
            }
        }

        do {
            _ = try await trainingPlanRepository.createWeeklyPlan(
                week: nil,
                startFromStage: startFromStage,
                isBeginner: isBeginner
            )

            Logger.debug("[OnboardingFeatureVM: completeOnboardingV1] Weekly plan created, onboarding complete")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Race Setup Methods (merged from OnboardingViewModel)

    /// 從後端載入用戶的所有未來目標（只載入主要賽事 isMainRace=true）
    func loadAvailableTargets() async {
        isLoadingTargets = true

        do {
            let allTargets = try await targetRepository.getTargets()

            let now = Date()
            let futureMainTargets = allTargets.filter { target in
                let targetDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
                return targetDate > now && target.isMainRace
            }

            self.availableTargets = futureMainTargets
            Logger.debug("[OnboardingFeatureVM] 成功載入 \(futureMainTargets.count) 個未來主要目標")
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            Logger.warn("[OnboardingFeatureVM] 載入目標失敗: \(error.localizedDescription)")
            // 不顯示錯誤，因為新用戶可能沒有目標
        }

        isLoadingTargets = false
    }

    /// 建立或更新主要賽事目標
    func createRaceTarget() async -> Bool {
        isLoading = true
        self.error = nil

        do {
            if let selectedTargetId = selectedTargetKey, hasSelectedTargetBeenModified() {
                // 更新已選擇的目標
                let updatedTarget = Target(
                    id: selectedTargetId,
                    type: "race_run",
                    name: raceName.isEmpty ? NSLocalizedString("onboarding.my_training_goal", comment: "My Training Goal") : raceName,
                    distanceKm: Int(Double(selectedDistance) ?? 42.195),
                    targetTime: targetHours * 3600 + targetMinutes * 60,
                    targetPace: targetPace,
                    raceDate: Int(raceDate.timeIntervalSince1970),
                    isMainRace: true,
                    trainingWeeks: trainingWeeks
                )
                _ = try await targetRepository.updateTarget(id: selectedTargetId, target: updatedTarget)
                Logger.debug("[OnboardingFeatureVM] 目標已更新: \(updatedTarget.name)")
            } else if selectedTargetKey == nil {
                // 創建新的主要目標
                let target = Target(
                    id: UUID().uuidString,
                    type: "race_run",
                    name: raceName.isEmpty ? NSLocalizedString("onboarding.my_training_goal", comment: "My Training Goal") : raceName,
                    distanceKm: Int(Double(selectedDistance) ?? 42.195),
                    targetTime: targetHours * 3600 + targetMinutes * 60,
                    targetPace: targetPace,
                    raceDate: Int(raceDate.timeIntervalSince1970),
                    isMainRace: true,
                    trainingWeeks: trainingWeeks
                )
                let createdTarget = try await targetRepository.createTarget(target)
                selectedTargetKey = createdTarget.id
                Logger.debug("[OnboardingFeatureVM] 新目標創建成功: \(createdTarget.name), id: \(createdTarget.id)")
            } else {
                // 選擇了目標但沒有改動，直接跳過
                Logger.debug("[OnboardingFeatureVM] 使用先前的目標賽事，不需要創建或更新")
            }

            let distanceKm = Double(selectedDistance) ?? 42.195
            analyticsService.track(.onboardingTargetSet(
                targetType: "race_run",
                raceId: selectedTargetKey,
                distanceKm: distanceKm
            ))

            isLoading = false
            return true
        } catch is CancellationError {
            isLoading = false
            return false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// 當用戶選擇已有的目標時，填入表單
    func selectTarget(_ target: Target) {
        selectedRaceEvent = nil
        selectedRaceDistance = nil
        selectedTargetKey = target.id
        raceName = target.name
        raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        selectedDistance = normalizeDistanceForPicker(target.distanceKm)

        let totalSeconds = target.targetTime
        targetHours = totalSeconds / 3600
        targetMinutes = (totalSeconds % 3600) / 60

        Logger.debug("[OnboardingFeatureVM] 選擇已有目標: \(target.name), 距離: \(target.distanceKm)km -> \(selectedDistance)")
    }

    // MARK: - Race API Methods

    /// 從 API 載入精選賽事
    func loadCuratedRaces() async {
        isLoadingRaces = true
        do {
            raceEvents = try await raceRepository.getRaces(
                region: selectedRegion,
                distanceMin: nil,
                distanceMax: nil,
                dateFrom: nil,
                dateTo: nil,
                query: nil,
                curatedOnly: true,
                limit: 50,
                offset: nil
            )
            isRaceAPIAvailable = !raceEvents.isEmpty
        } catch {
            isRaceAPIAvailable = false
            Logger.warn("[Onboarding] Race API unavailable: \(error.localizedDescription)")
        }
        isLoadingRaces = false
    }

    /// 用戶從賽事資料庫選擇賽事，自動填入目標設定
    func selectRaceEvent(_ event: RaceEvent, distance: RaceDistance) {
        // 清除先前選擇的既有 target，確保 createRaceTarget() 走 CREATE 分支
        // 而非因為 selectedTargetKey 殘留而跳過 API 呼叫
        selectedTargetKey = nil
        selectedRaceEvent = event
        selectedRaceDistance = distance
        // 自動填入賽事資訊到手動表單
        raceName = event.name
        raceDate = event.eventDate
        selectedDistance = normalizeDistanceForPicker(Int(distance.distanceKm))
    }

    /// 清除賽事資料庫選擇，回到手動輸入模式。
    /// 保留已帶入的欄位，讓使用者能直接微調而不是重填。
    func clearSelectedRace() {
        selectedRaceEvent = nil
        selectedRaceDistance = nil
    }

    // MARK: - Private Helpers

    private func normalizeDistanceKey(_ key: String) -> String {
        switch key {
        case "21": return "21.0975"
        case "42": return "42.195"
        default: return key
        }
    }

    private func normalizeDistance(_ distanceStr: String) -> Double {
        let distance = Double(distanceStr) ?? 0.0
        if distance == 21 { return 21.0975 }
        if distance == 42 { return 42.195 }
        return distance
    }

    private func normalizeDistanceForPicker(_ distanceKm: Int) -> String {
        switch distanceKm {
        case 5: return "5"
        case 10: return "10"
        case 21: return "21.0975"
        case 42: return "42.195"
        default: return String(distanceKm)
        }
    }

    private func clearPersonalBestSelection() {
        selectedPersonalBestKey = nil
        personalBestHours = 0
        personalBestMinutes = 0
        personalBestSeconds = 0
    }

    private func prefillClosestPersonalBestIfAvailable() {
        if let selectedKey = selectedPersonalBestKey,
           availablePersonalBests[selectedKey]?.isEmpty == false {
            selectPersonalBest(distanceKey: selectedKey)
            return
        }

        if let existingSelectionKey = availablePersonalBests.keys.first(where: { normalizeDistanceKey($0) == selectedPBDistance }),
           availablePersonalBests[existingSelectionKey]?.isEmpty == false {
            selectPersonalBest(distanceKey: existingSelectionKey)
            return
        }

        if let targetSelectionKey = availablePersonalBests.keys.first(where: {
            guard let distance = Double($0) else { return false }
            return abs(distance - targetDistance) < 0.0001
        }),
           availablePersonalBests[targetSelectionKey]?.isEmpty == false {
            selectPersonalBest(distanceKey: targetSelectionKey)
            return
        }

        let longestKey = availablePersonalBests.keys
            .compactMap { key -> (String, Double)? in
                guard let distance = Double(key) else { return nil }
                return (key, distance)
            }
            .max { $0.1 < $1.1 }?
            .0

        if let longestKey {
            selectPersonalBest(distanceKey: longestKey)
        }
    }

    private func recoverOverviewAfterCreateFailure() async throws -> PlanOverviewV2 {
        let retryDelays: [UInt64] = [
            500_000_000,
            1_000_000_000,
            2_000_000_000,
            4_000_000_000
        ]

        var lastError: Error?

        for (index, delay) in retryDelays.enumerated() {
            if index > 0 {
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                Logger.warn("[OnboardingFeatureVM] Recovery attempt \(index + 1)/\(retryDelays.count) via GET /v2/plan/overview")
                return try await trainingPlanV2Repository.refreshOverview()
            } catch {
                lastError = error
                Logger.warn("[OnboardingFeatureVM] Recovery attempt \(index + 1) failed: \(error.localizedDescription)")
            }
        }

        throw lastError ?? DomainError.unknown("Failed to recover plan overview")
    }

    private func buildLocalPreviewOverview(
        targetType: TargetTypeV2,
        trainingWeeks: Int?,
        targetId: String?,
        startFromStage: String?,
        methodologyId: String?,
        intendedRaceDistanceKm: Int?
    ) async -> PlanOverviewV2 {
        let resolvedMethodology = selectedMethodology
            ?? availableMethodologies.first(where: { $0.id == methodologyId })
            ?? availableMethodologies.first(where: { $0.id == targetType.defaultMethodology })

        let methodologyOverview = resolvedMethodology.map {
            MethodologyOverviewV2(
                name: $0.name,
                philosophy: $0.description,
                intensityStyle: "balanced",
                intensityDescription: $0.description
            )
        }

        var resolvedTargetName: String?
        var resolvedRaceDate: Int?
        var resolvedDistanceKm: Double?
        var resolvedTargetPace: String?
        var resolvedTargetTime: Int?
        var resolvedTotalWeeks = trainingWeeks ?? 0

        if targetType.isRaceRunTarget, let targetId {
            if let target = try? await targetRepository.getTarget(id: targetId) {
                resolvedTargetName = target.name
                resolvedRaceDate = target.raceDate
                resolvedDistanceKm = Double(target.distanceKm)
                resolvedTargetPace = target.targetPace
                resolvedTargetTime = target.targetTime
                if resolvedTotalWeeks <= 0 {
                    resolvedTotalWeeks = target.trainingWeeks
                }
            }
        }

        if resolvedTotalWeeks <= 0 {
            resolvedTotalWeeks = max(trainingWeeks ?? 0, 1)
        }

        if resolvedDistanceKm == nil, let intendedRaceDistanceKm {
            resolvedDistanceKm = Double(intendedRaceDistanceKm)
        }

        return PlanOverviewV2(
            id: "local_preview_\(UUID().uuidString)",
            targetId: targetId,
            targetType: targetType.id,
            targetDescription: targetType.isRaceRunTarget ? nil : targetType.description,
            methodologyId: methodologyId ?? resolvedMethodology?.id ?? targetType.defaultMethodology,
            totalWeeks: resolvedTotalWeeks,
            startFromStage: startFromStage,
            raceDate: resolvedRaceDate,
            distanceKm: resolvedDistanceKm,
            distanceKmDisplay: nil,
            distanceUnit: nil,
            targetPace: resolvedTargetPace,
            targetTime: resolvedTargetTime,
            isMainRace: targetType.isRaceRunTarget ? true : nil,
            targetName: resolvedTargetName,
            methodologyOverview: methodologyOverview,
            targetEvaluate: nil,
            approachSummary: nil,
            trainingStages: [],
            milestones: [],
            createdAt: Date(),
            methodologyVersion: nil,
            milestoneBasis: nil
        )
    }

    private func hasSelectedTargetBeenModified() -> Bool {
        guard let selectedTargetId = selectedTargetKey else { return false }
        guard let selectedTarget = availableTargets.first(where: { $0.id == selectedTargetId }) else {
            // 找不到原始 target 無法比較，視為已修改以觸發 UPDATE 而非靜默跳過
            return true
        }

        let nameChanged = raceName != selectedTarget.name
        let distanceChanged = Int(Double(selectedDistance) ?? 42.195) != selectedTarget.distanceKm
        let timeChanged = (targetHours * 3600 + targetMinutes * 60) != selectedTarget.targetTime
        let dateChanged = Int(raceDate.timeIntervalSince1970) != selectedTarget.raceDate

        return nameChanged || distanceChanged || timeChanged || dateChanged
    }
}

// MARK: - RacePickerDataSource Conformance

/// Pure declaration — all required members already exist on OnboardingFeatureViewModel.
/// preselectedRaceId returns nil because onboarding has no pre-existing race_id to highlight.
extension OnboardingFeatureViewModel: RacePickerDataSource {
    var preselectedRaceId: String? { nil }
}

// MARK: - DependencyContainer Extension
extension DependencyContainer {

    /// Create OnboardingFeatureViewModel with dependencies resolved from container
    @MainActor
    func makeOnboardingFeatureViewModel() -> OnboardingFeatureViewModel {
        // Ensure modules are registered
        if !isRegistered(UserProfileRepository.self) {
            registerUserProfileModule()
        }
        if !isRegistered(TargetRepository.self) {
            registerTargetModule()
        }
        if !isRegistered(TrainingPlanRepository.self) {
            registerTrainingPlanModule()
        }
        if !isRegistered(TrainingPlanV2Repository.self) {
            registerTrainingPlanV2Dependencies()
        }
        if !isRegistered(RaceRepository.self) {
            registerRaceModule()
        }
        registerTrainingVersionRouter()

        return OnboardingFeatureViewModel(
            userProfileRepository: resolve(),
            targetRepository: resolve(),
            trainingPlanRepository: resolve(),
            trainingPlanV2Repository: resolve(),
            raceRepository: resolve(),
            versionRouter: resolve() as TrainingVersionRouting
        )
    }
}
