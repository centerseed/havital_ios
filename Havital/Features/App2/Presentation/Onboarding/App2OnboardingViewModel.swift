import SwiftUI
import Combine

// MARK: - App2OnboardingViewModel
/// 2.0 onboarding 的**流程殼**（設計 frame-30 ~ frame-39）。
///
/// **不是第二套 onboarding 邏輯。** 查過的既有實作全部照用：
///
/// | 事情 | 誰做 |
/// |---|---|
/// | 目標型態／方法論／賽事／PB／訓練日的載入與提交 | `OnboardingFeatureViewModel`（本檔的 `flow`） |
/// | 跨步驟共享狀態、`POST /v2/plan/overview`、`POST /v2/plan/weekly`、完成旗標 | `OnboardingCoordinator.shared` ＋ `CompleteOnboardingUseCase` |
/// | 心率存檔、資料來源綁定 | `UserProfileFeatureViewModel`（與 1.x 心率頁／資料來源頁同一支） |
/// | 賽事搜尋 | `RaceEventListView`（既有，以 sheet 呈現） |
///
/// 這一層只擁有**畫面順序**與**只存在於 2.0 版面的暫存狀態**（滾輪值、成績新舊、
/// 跑量確認模式）。`OnboardingCoordinator.navigationPath` 是 1.x 那條路徑的狀態，
/// 2.0 走自己的 `path`；共享的是資料欄位，不是導航。
@MainActor
final class App2OnboardingViewModel: ObservableObject {

    // MARK: - Step

    enum Step: Hashable {
        case goalType       // frame-31
        case raceSetup      // frame-32（只有 race_run 分支）
        case heartRate      // frame-33
        case deviceLink     // frame-34
        case recentResult   // frame-35
        case methodology    // frame-36
        case trainingDays   // frame-37
        case mileage        // frame-38
        case completion     // frame-39

        var segment: App2OnboardingSegment {
            switch self {
            case .goalType, .raceSetup, .heartRate, .deviceLink: return .goal
            case .recentResult, .methodology, .trainingDays, .mileage: return .training
            case .completion: return .plan
            }
        }
    }

    // MARK: - 共享既有實作

    /// 既有的 onboarding ViewModel —— 所有提交都走它。
    let flow: OnboardingFeatureViewModel
    /// 既有的個人檔案 ViewModel —— 心率與資料來源走它（與 1.x 同一支）。
    let profile: UserProfileFeatureViewModel

    private let coordinator = OnboardingCoordinator.shared

    // MARK: - 導航

    @Published var path: [Step] = []
    /// re-onboarding（設定頁「重新設定目標賽事」）：跳過開場頁，根視圖就是目標型態。
    let isReonboarding: Bool

    // MARK: - 2.0 版面自己的暫存狀態

    @Published var maxHeartRate: Int = 190
    @Published var restingHeartRate: Int = 60

    /// frame-35「一年內／一年前」。
    @Published var resultIsWithinYear: Bool = true
    @Published var estimatedVDOT: Double?

    /// frame-38「差不多／我想調整」。
    @Published var mileageIsConfirmed: Bool = true
    /// 是否真的有同步紀錄推得的平均（沒有就不顯示來源徽章，也不謊稱來自 Garmin）。
    var hasSyncedMileage: Bool { flow.historicalWeeklyAverage != nil }

    /// frame-39「現在的你」——走既有的 readiness 出口，沒有就整欄不顯示。
    @Published var currentEstimatedFinish: String?

    // MARK: - UI 狀態

    @Published var isBusy = false
    @Published var isGeneratingPlan = false
    @Published var isStartingFirstWeek = false
    @Published var errorMessage: String?

    private var vdotTask: Task<Void, Never>?
    private let readinessViewModel = TrainingReadinessViewModel()

    // MARK: - 非賽事分支的訓練週數
    //
    // 設計包只畫了賽事分支，`beginner`／`maintenance` 沒有「選幾週」那一頁。
    // 這裡沿用 1.x `TrainingWeeksSetupView` 的推薦值（同檔 `recommendedWeeks`），
    // 不自己另訂一組；使用者之後可在訓練設定改。
    private static let recommendedWeeksByTargetType: [String: Int] = [
        "beginner": 8,
        "maintenance": 12
    ]
    private static let beginnerDefaultRaceDistanceKm = 5

    // MARK: - Init

    init(isReonboarding: Bool) {
        self.isReonboarding = isReonboarding
        self.flow = DependencyContainer.shared.makeOnboardingFeatureViewModel()
        self.profile = UserProfileFeatureViewModel()
    }

    // MARK: - 導航衍生值

    /// 目前分支會經過的頁（用來算三段進度，也決定 race 分支要不要 frame-32）。
    var pages: [Step] {
        var result: [Step] = [.goalType]
        if isRaceBranch { result.append(.raceSetup) }
        result += [.heartRate, .deviceLink, .recentResult, .methodology, .trainingDays, .mileage, .completion]
        return result
    }

    var isRaceBranch: Bool {
        (coordinator.selectedTargetTypeId ?? flow.selectedTargetTypeV2?.id) == "race_run"
    }

    /// 該頁在它所屬那一段裡走到第幾格（0…1）。
    func progress(for step: Step) -> Double {
        let inSegment = pages.filter { $0.segment == step.segment }
        guard let index = inSegment.firstIndex(of: step), !inSegment.isEmpty else { return 0 }
        return Double(index + 1) / Double(inSegment.count)
    }

    func push(_ step: Step) {
        path.append(step)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    // MARK: - 進場載入

    func loadInitial() async {
        await flow.loadTargetTypes()
        loadHeartRateDefaults()
        async let pbs: Void = flow.loadPersonalBests()
        async let days: Void = flow.loadTrainingDayPreferences()
        async let races: Void = flow.loadCuratedRaces()
        _ = await (pbs, days, races)
    }

    // MARK: - frame-31 目標型態

    func selectGoalType(_ targetType: TargetTypeV2) {
        flow.selectedGoalType = .v2(targetType)
        flow.selectedTargetTypeV2 = targetType
    }

    var selectedTargetType: TargetTypeV2? { flow.selectedTargetTypeV2 }

    /// 與 1.x `GoalTypeSelectionView.handleNextStep()` 同一組副作用，只是導到 2.0 的下一頁。
    func confirmGoalType() async {
        guard let targetType = flow.selectedTargetTypeV2 else { return }
        isBusy = true
        defer { isBusy = false }

        coordinator.selectedTargetTypeId = targetType.id
        coordinator.trackGoalTypeSelected(targetType: targetType.id)
        coordinator.isBeginner = targetType.isBeginnerTarget
        flow.isBeginner = targetType.isBeginnerTarget
        flow.resetMethodologyState()

        if targetType.isRaceRunTarget {
            coordinator.trainingWeeks = nil
            coordinator.intendedRaceDistanceKm = nil
            push(.raceSetup)
            return
        }

        // 非賽事分支：設計沒有「選幾週」那一頁，套 1.x 的推薦週數。
        flow.trackTargetSetForNonRace(targetType: targetType)
        coordinator.trainingWeeks = Self.recommendedWeeksByTargetType[targetType.id] ?? 12
        coordinator.intendedRaceDistanceKm = targetType.isBeginnerTarget
            ? Self.beginnerDefaultRaceDistanceKm
            : nil
        await flow.loadMethodologiesForTargetType(targetType.id)
        push(.heartRate)
    }

    // MARK: - frame-32 目標賽事

    /// 從支援賽事橫捲卡選一場（走既有的 `selectRaceEvent`，含 analytics）。
    func selectRaceEvent(_ event: RaceEvent, distance: RaceDistance) {
        flow.selectRaceEvent(event, distance: distance)
    }

    var selectedRaceEventId: String? { flow.selectedRaceEvent?.raceId }

    var canContinueFromRaceSetup: Bool {
        !flow.raceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (flow.targetHours * 3600 + flow.targetMinutes * 60 + raceTargetSeconds) > 0
    }

    /// 目標完賽秒數的「秒」欄。既有 VM 只有時／分兩欄（`targetHours`／`targetMinutes`），
    /// 設計 frame-32 有三欄，所以秒住在這裡，提交時併回既有欄位。
    @Published var raceTargetSeconds: Int = 0

    func confirmRaceSetup() async {
        isBusy = true
        defer { isBusy = false }

        // 秒併進分（既有 Target 只吃 targetTime 總秒數，`createRaceTarget` 由時＋分組出來，
        // 這裡把秒補進去，避免第二條建立路徑）。
        if raceTargetSeconds > 0 {
            let total = flow.targetHours * 3600 + flow.targetMinutes * 60 + raceTargetSeconds
            flow.targetHours = total / 3600
            flow.targetMinutes = (total % 3600) / 60
            raceTargetSeconds = total % 60
        }

        guard await flow.createRaceTarget() else {
            errorMessage = flow.error
            return
        }

        coordinator.selectedTargetId = flow.selectedTargetKey
        coordinator.targetDistance = Double(flow.selectedDistance) ?? 42.195
        coordinator.weeksRemaining = flow.trainingWeeks
        flow.targetDistance = coordinator.targetDistance

        await flow.loadMethodologiesForTargetType("race_run")
        push(.heartRate)
    }

    // MARK: - frame-33 心率

    private func loadHeartRateDefaults() {
        if let stored = profile.maxHeartRate {
            maxHeartRate = stored
        } else {
            let age = UserDefaults.standard.object(forKey: "age") as? Int ?? 30
            maxHeartRate = App2OnboardingProjection.estimatedMaxHR(age: age)
        }
        restingHeartRate = profile.restingHeartRate ?? 60
    }

    var heartRateBands: [App2OnboardingProjection.HeartRateBand] {
        App2OnboardingProjection.heartRateBands(maxHR: maxHeartRate, restingHR: restingHeartRate)
    }

    /// 與 1.x `HeartRateZoneInfoView.saveHeartRateZones()` 同一組欄位
    /// （`max_hr` / `relaxing_hr`）與同一個 notifier。
    func confirmHeartRate() async {
        guard maxHeartRate > restingHeartRate else {
            errorMessage = NSLocalizedString("hr_zone.max_greater_than_resting", comment: "")
            return
        }
        isBusy = true
        defer { isBusy = false }

        profile.updateHeartRateData(maxHR: maxHeartRate, restingHR: restingHeartRate)
        let didUpdate = await profile.updateUserProfile([
            "max_hr": maxHeartRate,
            "relaxing_hr": restingHeartRate
        ])
        guard didUpdate else {
            errorMessage = NSLocalizedString("hr_zone.save_failed_generic", comment: "")
            return
        }
        HeartRateProfileRefreshNotifier.notifySaved(isOnboardingMode: true)
        push(.deviceLink)
    }

    // MARK: - frame-34 連結裝置

    /// 與 1.x `DataSourceSelectionView.handleAppleHealthSelection()` 同一條。
    func connectAppleHealth() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await HealthKitManager.shared.requestAuthorization()
            try await profile.updateAndSyncDataSource(.appleHealth)
            coordinator.trackDataSourceConnected(provider: "apple_health")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 與 1.x `handleGarminSelection()` 同一條（OAuth 由 `GarminManager` 開）。
    func connectGarmin() async {
        isBusy = true
        defer { isBusy = false }
        await profile.updateDataSource(.garmin)
        await GarminManager.shared.startConnection()
    }

    func disconnectGarmin() async {
        isBusy = true
        defer { isBusy = false }
        await GarminManager.shared.disconnect()
    }

    func continueFromDeviceLink() {
        push(.recentResult)
    }

    /// 與 1.x `handleSkipForNow()` 同一條：存 `.unbound` 再往下走。
    func skipDeviceLink() async {
        isBusy = true
        defer { isBusy = false }
        coordinator.trackDataSourceSkipped()
        do {
            try await profile.updateAndSyncDataSource(.unbound)
        } catch {
            Logger.warn("[App2Onboarding] 略過資料來源時寫入失敗: \(error.localizedDescription)")
        }
        push(.recentResult)
    }

    // MARK: - frame-35 近期成績

    /// 使用者一改距離或時間就重算 VDOT（本機，見 `App2OnboardingProjection` 的退場說明）。
    func recomputeEstimates() {
        vdotTask?.cancel()
        let distance = Double(flow.selectedPBDistance) ?? 5
        let seconds = flow.personalBestHours * 3600 + flow.personalBestMinutes * 60 + flow.personalBestSeconds
        estimatedVDOT = App2OnboardingProjection.estimatedRaceVDOT(distanceKm: distance, totalSeconds: seconds)
    }

    var recentResultPace: String { flow.currentPace }

    var canContinueFromRecentResult: Bool {
        (flow.personalBestHours * 3600 + flow.personalBestMinutes * 60 + flow.personalBestSeconds) > 0
    }

    func confirmRecentResult() async {
        isBusy = true
        defer { isBusy = false }
        flow.hasPersonalBest = true
        guard await flow.updatePersonalBest() else {
            errorMessage = flow.error
            return
        }
        push(.methodology)
    }

    func skipRecentResult() async {
        isBusy = true
        defer { isBusy = false }
        flow.hasPersonalBest = false
        _ = await flow.updatePersonalBest()   // 只寫 hasPersonalBest 旗標，不送成績
        push(.methodology)
    }

    // MARK: - frame-36 訓練方法

    /// 推薦項＝該目標型態的 `defaultMethodology`（既有欄位），沒有就取清單第一個。
    var recommendedMethodologyId: String? {
        flow.selectedTargetTypeV2?.defaultMethodology ?? flow.availableMethodologies.first?.id
    }

    func selectMethodology(_ methodology: MethodologyV2) {
        flow.selectedMethodology = methodology
    }

    func confirmMethodology() async {
        isBusy = true
        defer { isBusy = false }
        coordinator.selectedMethodologyId = flow.selectedMethodology?.id ?? recommendedMethodologyId
        await flow.loadHistoricalWeeklyDistance()
        push(.trainingDays)
    }

    // MARK: - frame-37 訓練日

    func toggleWeekday(_ weekday: Int) {
        if flow.selectedWeekdays.contains(weekday) {
            flow.selectedWeekdays.remove(weekday)
        } else {
            flow.selectedWeekdays.insert(weekday)
        }
        // 長跑日必須落在已選日之內 —— 走既有 VM 的那一條規則。
        flow.normalizeLongRunDaySelection()
    }

    var canContinueFromTrainingDays: Bool { !flow.selectedWeekdays.isEmpty }

    func confirmTrainingDays() async {
        isBusy = true
        defer { isBusy = false }
        guard await flow.saveTrainingDaysPreferencesOnly() else {
            errorMessage = flow.error
            return
        }
        coordinator.availableDays = flow.selectedWeekdays.count
        coordinator.trackScheduleSet(availableDays: flow.selectedWeekdays.count)
        push(.mileage)
    }

    // MARK: - frame-38 跑量確認

    var mileagePreview: App2OnboardingProjection.MileagePreview {
        App2OnboardingProjection.mileagePreview(
            startKm: flow.weeklyDistance,
            totalWeeks: totalWeeksForPreview
        )
    }

    private var totalWeeksForPreview: Int {
        if isRaceBranch { return max(flow.trainingWeeks, 1) }
        return coordinator.trainingWeeks ?? 12
    }

    /// 「來自你的 X 跑步紀錄」的來源名 —— 沒有同步紀錄就回 nil，不編一個來源。
    var mileageSourceName: String? {
        guard hasSyncedMileage else { return nil }
        switch profile.currentDataSource {
        case .garmin:      return "Garmin"
        case .appleHealth: return "Apple Health"
        case .strava:      return "Strava"
        case .unbound:     return nil
        }
    }

    /// 設計 frame-38：CTA 產生 overview，然後進完成頁。
    func generatePlan() async {
        guard let targetType = flow.selectedTargetTypeV2 else {
            errorMessage = NSLocalizedString("onboarding.race_target_required", comment: "")
            return
        }

        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        coordinator.trackPlanGenerating()

        guard await flow.saveWeeklyDistance() else {
            errorMessage = flow.error
            return
        }

        let overview = await flow.createPlanOverviewV2(
            targetType: targetType,
            trainingWeeks: coordinator.trainingWeeks,
            targetId: coordinator.selectedTargetId,
            startFromStage: nil,
            methodologyId: coordinator.selectedMethodologyId,
            intendedRaceDistanceKm: coordinator.intendedRaceDistanceKm
        )

        guard let overview else {
            errorMessage = flow.error
            return
        }

        coordinator.trainingPlanOverviewV2 = overview
        await loadCurrentFitnessEstimate()
        push(.completion)
    }

    // MARK: - frame-39 完成

    var overview: PlanOverviewV2? { coordinator.trainingPlanOverviewV2 }

    /// 「現在的你」走既有的 readiness 出口（`GET /plan/readiness` 的
    /// `race_fitness.estimated_race_time`，與首頁目標卡同一個值）。
    /// 全新帳號通常還沒有這個值 —— 那一欄就整格不顯示，**不本機推一個預估頂替**。
    private func loadCurrentFitnessEstimate() async {
        await readinessViewModel.loadData()
        currentEstimatedFinish = readinessViewModel.estimatedRaceTime
    }

    /// 設計 frame-39 CTA：產生第一週課表 → 進首頁。
    /// 走既有的 `OnboardingCoordinator.completeOnboarding()`（→ `CompleteOnboardingUseCase`），
    /// 它負責 `POST /v2/plan/weekly`、完成旗標與 `onboardingCompleted` 事件。
    func startFirstWeek() async {
        isStartingFirstWeek = true
        defer { isStartingFirstWeek = false }
        await coordinator.completeOnboarding()
        if let error = coordinator.error {
            errorMessage = error
            coordinator.error = nil
        }
    }
}
