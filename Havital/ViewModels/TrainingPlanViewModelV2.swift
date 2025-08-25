import Foundation
import SwiftUI
import HealthKit

// MARK: - 重構後的訓練計劃 ViewModel (遵循統一架構模式)
/// 使用 TrainingPlanManager 和 BaseDataViewModel 的標準化實現
@MainActor
class TrainingPlanViewModelV2: BaseDataViewModel<WeeklyPlan, TrainingPlanManager> {
    
    // MARK: - Training Plan Specific Properties
    @Published var currentWeeklyPlan: WeeklyPlan? { 
        didSet { 
            // 當計劃更新時，同步更新 data 數組以保持一致性
            data = currentWeeklyPlan != nil ? [currentWeeklyPlan!] : []
        }
    }
    @Published var trainingOverview: TrainingPlanOverview?
    @Published var selectedWeek: Int = 1 {
        didSet {
            if selectedWeek != oldValue {
                Task {
                    await switchToWeek(selectedWeek)
                }
            }
        }
    }
    @Published var currentWeek: Int = 1
    @Published var weekDateInfo: WeekDateInfo?
    @Published var modifications: [Modification] = []
    
    // MARK: - Status Properties
    @Published var noWeeklyPlanAvailable: Bool = false
    @Published var showNewWeekPrompt: Bool = false
    @Published var showFinalWeekPrompt: Bool = false
    
    // MARK: - Workout Integration
    @Published var currentWeekDistance: Double = 0.0
    @Published var currentWeekIntensity: TrainingIntensityManager.IntensityMinutes = .zero
    @Published var isLoadingIntensity = false
    @Published var isLoadingDistance = false
    @Published var isLoadingWorkouts = false
    @Published var workoutsByDayV2: [Int: [WorkoutV2]] = [:]
    
    // MARK: - Weekly Summary Integration  
    @Published var weeklySummary: WeeklyTrainingSummary?
    @Published var isLoadingWeeklySummary = false
    @Published var weeklySummaryError: Error?
    @Published var showWeeklySummary = false
    
    // MARK: - UI State
    @Published var expandedDayIndices = Set<Int>()
    @Published var modDescription: String = ""
    
    // MARK: - Dependencies
    private let intensityManager = TrainingIntensityManager.shared
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared
    private let weeklySummaryService = WeeklySummaryService.shared
    
    // MARK: - Initialization
    override init(manager: TrainingPlanManager = TrainingPlanManager.shared) {
        super.init(manager: manager)
        
        // 綁定 manager 的屬性到 ViewModel
        bindManagerProperties()
    }
    
    // MARK: - Setup & Initialization
    
    override func initialize() async {
        await manager.initialize()
        
        // 同步管理器狀態
        syncManagerState()
        
        // 如果有訓練計劃數據，載入相關數據
        if hasWeeklyPlan {
            await loadWorkoutData()
            await loadModifications()
        }
    }
    
    // MARK: - Training Plan Management
    
    /// 載入數據 - 避免重複 loading 狀態
    override func loadData() async {
        // 先檢查是否有緩存數據
        let hasCachedData = manager.getCacheSize() > 0 && !manager.isExpired()
        
        if !hasCachedData {
            // 只有在沒有緩存數據時才顯示 loading
            await super.loadData()
        } else {
            // 有緩存時直接載入，不顯示 loading
            await manager.loadData()
            syncManagerState()
        }
        
        // 如果有訓練計劃數據，載入相關數據
        if hasWeeklyPlan {
            await loadWorkoutData()
        }
    }
    
    func switchToWeek(_ week: Int) async {
        guard week != selectedWeek else { return }
        
        selectedWeek = week
        await manager.switchToWeek(week)
        
        // 同步狀態並載入相關數據
        syncManagerState()
        if hasWeeklyPlan {
            await loadWorkoutData()
        }
    }
    
    func generateNewWeekPlan() async -> Bool {
        let success = await manager.generateNewWeekPlan()
        
        if success {
            syncManagerState()
            await loadWorkoutData()
        }
        
        return success
    }
    
    func refreshTrainingPlan() async {
        await manager.refreshData()
        syncManagerState()
        await loadWorkoutData()
    }
    
    // MARK: - Modifications Management
    
    func loadModifications() async {
        await manager.loadModifications()
        modifications = manager.modifications
    }
    
    func saveModification() async -> Bool {
        guard !modDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        let success = await manager.saveSimpleModification(modDescription)
        
        if success {
            modDescription = ""
            modifications = manager.modifications
        }
        
        return success
    }
    
    // MARK: - Workout Data Integration
    
    private func loadWorkoutData() async {
        await executeWithErrorHandling {
            self.isLoadingWorkouts = true
            self.isLoadingDistance = true
            self.isLoadingIntensity = true
            
            // 並行載入不同類型的運動數據
            async let workoutsTask = self.loadWorkoutsByDay()
            async let distanceTask = self.loadCurrentWeekDistance()
            async let intensityTask = self.loadCurrentWeekIntensity()
            
            await workoutsTask
            await distanceTask  
            await intensityTask
            
            self.isLoadingWorkouts = false
            self.isLoadingDistance = false
            self.isLoadingIntensity = false
        }
    }
    
    private func loadWorkoutsByDay() async {
        // 使用 UnifiedWorkoutManager 獲取運動數據
        guard let dateInfo = weekDateInfo else { return }
        
        let workouts = unifiedWorkoutManager.getWorkoutsInDateRange(
            startDate: dateInfo.startDate,
            endDate: dateInfo.endDate
        )
        
        // 按日期分組
        var workoutsByDay: [Int: [WorkoutV2]] = [:]
        for workout in workouts {
            let dayOfWeek = Calendar.current.component(.weekday, from: workout.startDate)
            workoutsByDay[dayOfWeek, default: []].append(workout)
        }
        
        self.workoutsByDayV2 = workoutsByDay
    }
    
    private func loadCurrentWeekDistance() async {
        guard let dateInfo = weekDateInfo else { return }
        
        let workouts = unifiedWorkoutManager.getWorkoutsInDateRange(
            startDate: dateInfo.startDate,
            endDate: dateInfo.endDate
        )
        
        // 只計算跑步活動的距離
        let runningWorkouts = workouts.filter { $0.activityType == "running" }
        currentWeekDistance = runningWorkouts.compactMap { $0.distance }.reduce(0, +)
        
        print("🏃 計算當週跑量: 總記錄 \(workouts.count) 筆, 跑步記錄 \(runningWorkouts.count) 筆, 總跑量 \(currentWeekDistance) km")
    }
    
    private func loadCurrentWeekIntensity() async {
        guard let dateInfo = weekDateInfo else { return }
        
        do {
            // 從後端 API 獲取該週的運動數據，並聚合強度信息
            let workouts = unifiedWorkoutManager.getWorkoutsInDateRange(startDate: dateInfo.startDate, endDate: dateInfo.endDate)
            
            // 從每個運動的詳細數據中獲取強度信息（如果有的話）
            var totalLowIntensity: Double = 0
            var totalMediumIntensity: Double = 0
            var totalHighIntensity: Double = 0
            
            // 方案1: 如果 WorkoutV2 有 intensityMinutes 數據，直接使用
            for workout in workouts {
                // 這裡假設未來 WorkoutV2 會包含強度數據，或者我們需要調用詳細的運動 API
                // 暫時使用本地計算作為後備方案
                if let workoutDetail = await fetchWorkoutDetailWithIntensity(workoutId: workout.id) {
                    totalLowIntensity += workoutDetail.intensityMinutes?.low ?? 0
                    totalMediumIntensity += workoutDetail.intensityMinutes?.medium ?? 0
                    totalHighIntensity += workoutDetail.intensityMinutes?.high ?? 0
                } else {
                    // 後備方案：基於運動類型的簡化計算
                    let durationMinutes = Double(workout.durationSeconds) / 60.0
                    switch workout.activityType.lowercased() {
                    case "walking", "hiking":
                        totalLowIntensity += durationMinutes
                    case "running", "cycling":
                        totalMediumIntensity += durationMinutes  
                    case "interval", "hiit":
                        totalHighIntensity += durationMinutes
                    default:
                        totalMediumIntensity += durationMinutes
                    }
                }
            }
            
            currentWeekIntensity = TrainingIntensityManager.IntensityMinutes(
                low: totalLowIntensity,
                medium: totalMediumIntensity,
                high: totalHighIntensity
            )
            
        } catch {
            Logger.firebase(
                "載入週強度失敗: \(error.localizedDescription)",
                level: .error,
                labels: ["module": "TrainingPlanViewModelV2", "action": "load_intensity"]
            )
        }
    }
    
    /// 獲取包含強度數據的運動詳細信息
    private func fetchWorkoutDetailWithIntensity(workoutId: String) async -> WorkoutSummary? {
        // 這裡應該調用運動詳細信息 API，如果它包含強度數據
        // 可以調用類似 WorkoutDetailService 的 API 來獲取完整的運動摘要
        // 目前先返回 nil，使用後備計算方案
        return nil
    }
    
    // MARK: - Weekly Summary Management
    
    func loadWeeklySummary() async {
        await executeWithErrorHandling {
            self.isLoadingWeeklySummary = true
            self.weeklySummaryError = nil
            
            do {
                let summary = try await self.weeklySummaryService.getWeeklySummary(weekNumber: self.selectedWeek)
                self.weeklySummary = summary
            } catch {
                self.weeklySummaryError = error
            }
            
            self.isLoadingWeeklySummary = false
        }
    }
    
    func toggleWeeklySummaryVisibility() {
        showWeeklySummary.toggle()
        
        if showWeeklySummary && weeklySummary == nil {
            Task {
                await loadWeeklySummary()
            }
        }
    }
    
    // MARK: - UI Helpers
    
    func toggleDayExpansion(_ dayIndex: Int) {
        if expandedDayIndices.contains(dayIndex) {
            expandedDayIndices.remove(dayIndex)
        } else {
            expandedDayIndices.insert(dayIndex)
        }
    }
    
    func isDayExpanded(_ dayIndex: Int) -> Bool {
        return expandedDayIndices.contains(dayIndex)
    }
    
    var availableWeeks: [Int] {
        return manager.availableWeeks
    }
    
    // MARK: - Notification Setup Override
    
    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        
        // 監聽運動記錄更新
        let workoutUpdateObserver = NotificationCenter.default.addObserver(
            forName: .workoutsDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadWorkoutData()
            }
        }
        notificationObservers.append(workoutUpdateObserver)
        
        // 監聽訓練計劃更新
        let planUpdateObserver = NotificationCenter.default.addObserver(
            forName: .trainingPlanDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncManagerState()
        }
        notificationObservers.append(planUpdateObserver)
    }
    
    // MARK: - Private Helper Methods
    
    private func bindManagerProperties() {
        // 使用 Combine 來綁定 manager 的屬性變化（如果需要）
        // 或者使用定期同步的方式
    }
    
    private func syncManagerState() {
        currentWeeklyPlan = manager.currentWeeklyPlan
        trainingOverview = manager.trainingOverview
        currentWeek = manager.currentWeek
        weekDateInfo = manager.weekDateInfo
        modifications = manager.modifications
        noWeeklyPlanAvailable = manager.noWeeklyPlanAvailable
        showNewWeekPrompt = manager.showNewWeekPrompt
        showFinalWeekPrompt = manager.showFinalWeekPrompt
        
        // 同步基礎屬性
        isLoading = manager.isLoading
        lastSyncTime = manager.lastSyncTime
        syncError = manager.syncError
    }
}

// MARK: - Computed Properties
extension TrainingPlanViewModelV2 {
    
    var hasWeeklyPlan: Bool {
        return currentWeeklyPlan != nil
    }
    
    var currentWeekString: String {
        guard let dateInfo = weekDateInfo else { return "第 \(currentWeek) 週" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return "第 \(currentWeek) 週 (\(formatter.string(from: dateInfo.startDate)) - \(formatter.string(from: dateInfo.endDate)))"
    }
    
    var totalModificationsCount: Int {
        return modifications.count
    }
    
    var hasWorkouts: Bool {
        return !workoutsByDayV2.isEmpty
    }
}

// MARK: - Legacy Compatibility (漸進式遷移支援)
extension TrainingPlanViewModelV2 {
    
    /// 為了與現有 UI 代碼兼容，提供舊的方法名稱
    func loadWeeklyPlan() async {
        await loadData()
    }
    
    /// 提供錯誤處理的兼容性
    var error: Error? {
        get {
            if let syncError = syncError {
                return NSError(domain: "TrainingPlanError", code: -1, userInfo: [NSLocalizedDescriptionKey: syncError])
            }
            return nil
        }
        set {
            syncError = newValue?.localizedDescription
        }
    }
}