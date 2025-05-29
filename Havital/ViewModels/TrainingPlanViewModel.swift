import Combine
import HealthKit
import SwiftUI

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlan: WeeklyPlan?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentWeekDistance: Double = 0.0
    // 使用 Published 確保 UI 能即時更新
    @Published private(set) var _currentWeekIntensity: TrainingIntensityManager.IntensityMinutes = .zero
    @Published var isLoadingIntensity = false
    private let intensityManager = TrainingIntensityManager.shared
    
    // 使用計算屬性確保每次讀取都得到最新的值
    var currentWeekIntensity: TrainingIntensityManager.IntensityMinutes {
        // 最新的強度值應該是計算後的實際值
        return TrainingIntensityManager.IntensityMinutes(
            low: _currentWeekIntensity.low,
            medium: _currentWeekIntensity.medium,
            high: _currentWeekIntensity.high
        )
    }
    @Published var isLoadingDistance = false
    @Published var workoutsByDay: [Int: [HKWorkout]] = [:]
    @Published var isLoadingWorkouts = false
    @Published var trainingOverview: TrainingPlanOverview?
    @Published var selectedWeek: Int = 1
    @Published var currentWeek: Int = 1
    @Published var weekDateInfo: WeekDateInfo?
    /// 無對應週計畫時顯示
    @Published var noWeeklyPlanAvailable: Bool = false
    /// 當週尚無週計劃時顯示產生新週提示
    @Published var showNewWeekPrompt: Bool = false
    /// 當到新週但無計畫時提示
    @Published var showFinalWeekPrompt: Bool = false
    
    /// 可選過去週數範圍（不包含未來週）
    var availableWeeks: [Int] {
        if let currentWeek = calculateCurrentTrainingWeek() {
            return Array(1...currentWeek)
        }
        return []
    }
    
    // 週訓練回顧相關屬性
    @Published var weeklySummary: WeeklyTrainingSummary?
    @Published var isLoadingWeeklySummary = false
    @Published var weeklySummaryError: Error?
    @Published var showWeeklySummary = false
    @Published var lastFetchedWeekNumber: Int?
    
    // 週摘要列表
    @Published var weeklySummaries: [WeeklySummaryItem] = []
    @Published var isLoadingWeeklySummaries = false
    @Published var weeklySummariesError: Error?
    
    // 重用 TrainingRecordViewModel 的功能
    private let workoutService = WorkoutService.shared
    private let trainingRecordVM = TrainingRecordViewModel()
    private let weeklySummaryService = WeeklySummaryService.shared
    
    // 追蹤哪些日子被展開的狀態
    @Published var expandedDayIndices = Set<Int>()
    
    // 添加屬性來追蹤當前計劃的週數，用於檢測計劃變更
    private var currentPlanWeek: Int?
    
    // Modifications data
    @Published var modifications: [Modification] = []
    @Published var modDescription: String = ""
    
    // 添加 Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // 可注入的現在時間，預設為系統時間，便於測試
    var now: () -> Date = { Date() }
    
    // 在初始化時載入 overview 的 createdAt，若缺失則從 API 獲取並保存
    init() {
        // 從本地讀取概覽
        let savedOverview = TrainingPlanStorage.loadTrainingPlanOverview()
        if !savedOverview.createdAt.isEmpty {
            self.trainingOverview = savedOverview
            self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: savedOverview.createdAt) ?? 1
        }
        // 若本地無 createdAt，則非同步從 API 獲取並保存
        Task {
            if savedOverview.createdAt.isEmpty {
                do {
                    let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()
                    // 保存到本地
                    TrainingPlanStorage.saveTrainingPlanOverview(overview)
                    await MainActor.run {
                        self.trainingOverview = overview
                        self.currentWeek = TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: overview.createdAt) ?? 1
                    }
                } catch {
                    Logger.error("初始化獲取訓練計劃概覽失敗: \(error)")
                }
            }
            Task { await self.loadWeeklyPlan() }
        }
    }
    
    // MARK: - Plan display state
    enum PlanStatus {
        case loading
        case noPlan   // 尚未生成本週計畫
        case ready(WeeklyPlan)
        case completed
        case error(Error)
    }
    @Published var planStatus: PlanStatus = .loading
    
    // 獲取訓練回顧的方法
    func createWeeklySummary() async {
        await MainActor.run {
            isLoadingWeeklySummary = true
            weeklySummaryError = nil
        }
        
        do {
            // 獲取當前訓練週數
            guard let currentWeek = calculateCurrentTrainingWeek() else {
                throw NSError(
                    domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法計算當前訓練週數"])
            }
            
            // 從API獲取週訓練回顧數據
            // let summary = try await weeklySummaryService.createWeeklySummary(weekNumber: currentWeek)
            // 當前cloud將item.weekIndex -1來處理。未來cloud不會做這樣的偏移，之後要改成weekNumber: currentWeek - 1
            // app段不帶週數，或者帶當前週數-1代表產生前一週的summary
            let summary = try await weeklySummaryService.createWeeklySummary()
            
            // 保存到本地儲存
            WeeklySummaryStorage.shared.saveWeeklySummary(summary, weekNumber: currentWeek)
            
            await MainActor.run {
                self.weeklySummary = summary
                self.lastFetchedWeekNumber = currentWeek
                self.showWeeklySummary = true
                self.isLoadingWeeklySummary = false
            }
            
        } catch {
            Logger.error("載入週訓練回顧失敗: \(error)")
            
            await MainActor.run {
                self.weeklySummaryError = error
                self.isLoadingWeeklySummary = false
            }
            
            // 嘗試從本地儲存加載
            if let savedSummary = WeeklySummaryStorage.shared.loadWeeklySummary() {
                await MainActor.run {
                    self.weeklySummary = savedSummary
                    self.lastFetchedWeekNumber = WeeklySummaryStorage.shared
                        .getLastFetchedWeekNumber()
                    self.showWeeklySummary = true
                }
            }
        }
    }
    
    // 清除訓練回顧的方法
    func clearWeeklySummary() {
        WeeklySummaryStorage.shared.clearSavedWeeklySummary()
        
        Task { @MainActor in
            self.weeklySummary = nil
            self.lastFetchedWeekNumber = nil
            self.showWeeklySummary = false
        }
    }
    
    // 取得上兩週日期範圍的方法
    func getLastTwoWeeksRange() -> String {
        return WeekDateService.lastTwoWeeksRange()
    }
    
    /// 取得上週一到上週日的日期範圍字串（格式 MM/dd-MM/dd）
    func getLastWeekRangeString() -> String {
        return WeekDateService.lastWeekRange()
    }
    
    // 計算從訓練開始到當前的週數（改進版）
    func calculateCurrentTrainingWeek() -> Int? {
        return TrainingDateUtils.calculateCurrentTrainingWeek(createdAt: trainingOverview?.createdAt ?? "")
    }
    
    // 取得訓練週數並輸出日誌
    func logCurrentTrainingWeek() {
        if let week = calculateCurrentTrainingWeek() {
            Logger.debug("當前是第 \(week) 週訓練")
        } else {
            Logger.debug("無法計算訓練週數")
        }
    }
    
    // 從 TrainingRecordViewModel 重用的方法
    func isWorkoutUploaded(_ workout: HKWorkout) -> Bool {
        return workoutService.isWorkoutUploaded(workout)
    }
    
    func getWorkoutUploadTime(_ workout: HKWorkout) -> Date? {
        return workoutService.getWorkoutUploadTime(workout)
    }
    
    // 更新提示顯示狀態
    internal func updatePromptViews() {
        let cw = calculateCurrentTrainingWeek() ?? 0
        let total = trainingOverview?.totalWeeks ?? 0
        switch planStatus {
        case .noPlan:
            // 尚未生成本週計畫
            showNewWeekPrompt = (selectedWeek == cw)
            noWeeklyPlanAvailable = (selectedWeek < cw)
            showFinalWeekPrompt = false
        case .completed:
            // 完成最後一週後提示
            showFinalWeekPrompt = (selectedWeek == total)
            showNewWeekPrompt = false
            noWeeklyPlanAvailable = false
        default:
            // 其他狀態不顯示提示
            showNewWeekPrompt = false
            noWeeklyPlanAvailable = false
            showFinalWeekPrompt = false
        }
    }
    
    // Consolidated UI updater for weekly plan
    @MainActor private func updateWeeklyPlanUI(plan: WeeklyPlan?, planChanged: Bool = false, status: PlanStatus) {
        if let plan = plan {
            self.weeklyPlan = plan
            self.currentPlanWeek = plan.weekOfPlan
            if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: plan.weekOfPlan) {
                self.weekDateInfo = info
            }
            self.selectedWeek = plan.weekOfPlan
            if planChanged {
                self.workoutsByDay.removeAll()
                self.expandedDayIndices.removeAll()
            }
        }
        self.planStatus = status
        updatePromptViews()
    }
    
    func loadWeeklyPlan() async {
        // 僅在已有 trainingOverview.id 時才載入週計劃，避免無 overview 時報錯
        guard let overview = trainingOverview, !overview.id.isEmpty else { return }
        planStatus = .loading
        let cw = calculateCurrentTrainingWeek() ?? 0
        // 首先嘗試從本地加載數據
        if let savedPlan = TrainingPlanStorage.loadWeeklyPlan() {
            // 立即更新UI
            Logger.debug("overview.totalWeeks: \(overview.totalWeeks)")
            Logger.debug("cw: \(cw)")
            let status: PlanStatus = cw > overview.totalWeeks ? .completed : .ready(savedPlan)
            await updateWeeklyPlanUI(plan: savedPlan, status: status)
            
            // 異步從API獲取最新數據
            do {
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                Logger.info("Load weekly plan with planId: \(overviewId)_\(currentWeek).")
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                    planId: "\(overviewId)_\(self.currentWeek)")
                
                // 檢查計劃是否有變更
                let planChanged =
                savedPlan.id != newPlan.id || savedPlan.weekOfPlan != newPlan.weekOfPlan
                
                await updateWeeklyPlanUI(plan: newPlan, planChanged: planChanged, status: .ready(newPlan))
                
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404: 無週計劃
                await updateWeeklyPlanUI(plan: nil, status: .noPlan)
            } catch {
                // 其他錯誤: 使用本地數據並記錄
                Logger.error("API加載計劃失敗，使用本地數據: \(error)")
                await updateWeeklyPlanUI(plan: nil, status: .error(error))
            }
        } else {
            // 本地無數據，必須等待API
            do {
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                Logger.debug("overview.totalWeeks: \(overview.totalWeeks)")
                Logger.debug("cw: \(cw)")
                if (cw > overview.totalWeeks) {
                    await updateWeeklyPlanUI(plan: nil, status: .completed)
                } else {
                    let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                        planId: "\(overviewId)_\(self.currentWeek)")
                    
                    await updateWeeklyPlanUI(plan: newPlan, status: .ready(newPlan))
                }
                
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404: 無週計劃
                await updateWeeklyPlanUI(plan: nil, status: .noPlan)
            } catch {
                await updateWeeklyPlanUI(plan: nil, status: .error(error))
            }
        }
    }
    
    /// 依據指定週數產生對應週計劃
    func fetchWeekPlan(week: Int, healthKitManager: HealthKitManager) async {
        planStatus = .loading
        await MainActor.run {
            error = nil
        }
        do {
            // 僅使用 GET 查詢指定週計劃
            guard let overviewId = trainingOverview?.id else { throw NSError() }
            let plan = try await TrainingPlanService.shared.getWeeklyPlanById(
                planId: "\(overviewId)_\(week)")
            
            await updateWeeklyPlanUI(plan: plan, status: .ready(plan))
            
            // 載入該週的健康資料
            await loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            await loadCurrentWeekDistance(healthKitManager: healthKitManager)
            await loadCurrentWeekIntensity(healthKitManager: healthKitManager) // 新增強度加載
            await identifyTodayTraining()
            
        } catch let err as TrainingPlanService.WeeklyPlanError where err == .notFound {
            // 404 錯誤：依週數區分提示
            await updateWeeklyPlanUI(plan: nil, status: .noPlan)
        } catch {
            await updateWeeklyPlanUI(plan: nil, status: .error(error))
        }
    }
    
    // MARK: - New prompt display logic
    /// 是否已完成所有週的訓練
    var isFinalWeek: Bool {
        guard let plan = weeklyPlan else { return false }
        return currentWeek > plan.totalWeeks
    }
    
    /// 是否需要顯示「產生新週」提示
    var isNewWeekPromptNeeded: Bool {
        weeklyPlan == nil && selectedWeek == currentWeek
    }
    
    // 獲取當前週的日期範圍 (用於獲取訓練記錄)
    func getCurrentWeekDates() -> (Date, Date) {
        if let info = weekDateInfo {
            return (info.startDate, info.endDate)
        }
        
        // 默認情況：返回當前自然週的範圍
        let calendar = Calendar.current
        let today = Date()
        
        // 找到本週的週一
        let weekday = calendar.component(.weekday, from: today)
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
        
        // 週一日期
        let startDate = calendar.date(
            byAdding: .day, value: -adjustedWeekday + 1, to: calendar.startOfDay(for: today))!
        
        // 週日日期 (週一加6天)
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate)!
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!
        
        return (startDate, endOfDay)
    }
    
    // 獲取特定課表日的日期
    func getDateForDay(dayIndex: Int) -> Date? {
        return weekDateInfo?.daysMap[dayIndex]
    }
    
    // 判斷特定課表日是否為今天
    func isToday(dayIndex: Int, planWeek: Int) -> Bool {
        guard let date = getDateForDay(dayIndex: dayIndex) else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // 修正的 loadTrainingOverview 方法
    func loadTrainingOverview() async {
        // 首先從本地存儲加載
        let savedOverview = TrainingPlanStorage.loadTrainingPlanOverview()
        if !savedOverview.trainingPlanName.isEmpty {
            await MainActor.run {
                self.trainingOverview = savedOverview
            }
            
            // 輸出當前訓練週數
            logCurrentTrainingWeek()
        }
        
        // 然後嘗試從API獲取最新數據（登出後登入分支）
        do {
            let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()
            
            // 成功獲取後更新UI
            await MainActor.run {
                self.trainingOverview = overview
            }
            Logger.debug("成功載入訓練計劃概覽")
            Logger.debug("Plan Overview id \(overview.id)")
            TrainingPlanStorage.saveTrainingPlanOverview(overview)
            logCurrentTrainingWeek()
        } catch {
            Logger.error("載入訓練計劃概覽從API失敗: \(error)")
            // 已從本地加載，不需要額外處理
        }
    }
    
    // 用於 TrainingPlanView 中展示訓練計劃名稱
    var trainingPlanName: String {
        if let overview = trainingOverview, !overview.trainingPlanName.isEmpty {
            return overview.trainingPlanName
        }
        return "第\(weeklyPlan?.weekOfPlan ?? 0)週訓練計劃"
    }
    
    // 在產生新週計劃時更新概覽
    // 產生指定週數的課表
    func generateNextWeekPlan(targetWeek: Int) async {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CreateWeeklyPlan") { 
            // Expiration handler
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        // Defer ending the background task to ensure it's called
        defer {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        planStatus = .loading
        
        do {
            Logger.debug("開始產生第 \(targetWeek) 週課表...")
            _ = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: targetWeek)
            
            // 產生成功後重新載入課表
            do {
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                    planId: "\(overviewId)_\(self.currentWeek)")
                
                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan
                
                // 重新計算週日期信息
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                    self.weekDateInfo = info
                }
                
                await updateWeeklyPlanUI(plan: newPlan, status: .ready(newPlan))
                
                // 重新載入訓練計劃概覽，確保獲取最新資訊
                Logger.debug("重新載入訓練計劃概覽")
                await loadTrainingOverview()
                
                // 重新載入訓練記錄
                await loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager())
                
                Logger.debug("成功產生第 \(targetWeek) 週課表並更新 UI")
            } catch {
                Logger.error("重新載入課表失敗: \(error)")
                
                await updateWeeklyPlanUI(plan: nil, status: .error(error))
            }
        } catch {
            Logger.error("產生第 \(targetWeek) 週課表失敗: \(error)")
            planStatus = .error(error)
        }
    }
    
    // Flag to ensure initial data load only once
    private var hasLoadedInitialData = false
    
    /// 只在第一次執行：先載入概覽，再載入週計劃、VDOT、記錄、距離等
    func loadAllInitialData(healthKitManager: HealthKitManager) async {
        // 並行加載數據
        async let _ = loadCurrentWeekIntensity(healthKitManager: healthKitManager)
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true
        
        // 依序載入 overview，再載入 weeklyPlan
        await loadTrainingOverview()
        if weeklyPlan == nil {
            await loadWeeklyPlan()
        }
        
        await loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
        if let plan = weeklyPlan, plan.totalDistance > 0 {
            await loadCurrentWeekDistance(healthKitManager: healthKitManager)
        }
    }
    
    func refreshWeeklyPlan(healthKitManager: HealthKitManager) async {
        // 下拉刷新僅更新資料，不變更 planStatus
        
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            do {
                Logger.debug("開始更新計劃 (嘗試 \(currentRetry + 1)/\(maxRetries))")
                // 使用獨立 Task 呼叫 Service，避免 Button 或 View 取消影響
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                let weekId = "\(overviewId)_\(self.currentWeek)"
                Logger.info("Load weekly plan with planId: \(weekId).")
                
                let newPlan = try await Task.detached(priority: .userInitiated) {
                    try await TrainingPlanService.shared.getWeeklyPlanById(planId: weekId)
                }.value
                
                // 檢查計劃是否有變更
                let planWeekChanged =
                currentPlanWeek != nil && currentPlanWeek != newPlan.weekOfPlan
                
                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan
                
                // 重新計算週日期信息
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                    self.weekDateInfo = info
                }
                
                await updateWeeklyPlanUI(plan: newPlan, planChanged: planWeekChanged, status: .ready(newPlan))
                
                Logger.debug("完成更新計劃")
                
                // 重新載入訓練記錄
                await loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager())
                await identifyTodayTraining()
                
                if newPlan.totalDistance > 0 {
                    await loadCurrentWeekDistance(healthKitManager: healthKitManager)
                }
                
                break  // 成功後跳出重試迴圈
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404 時標記無週計劃並結束重試
                break
            } catch {
                currentRetry += 1
                if currentRetry >= maxRetries {
                    await updateWeeklyPlanUI(plan: nil, status: .error(error))
                    Logger.error("刷新訓練計劃失敗 (已重試 \(maxRetries) 次): \(error)")
                } else {
                    Logger.error("刷新訓練計劃失敗，準備重試: \(error)")
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))  // 等待1秒後重試
                }
            }
        }
    }
    
    // 修正的載入當前週訓練記錄方法
    func loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager) async {
        await MainActor.run {
            isLoadingWorkouts = true
        }
        
        do {
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            try await healthKitManager.requestAuthorization()
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(
                start: weekStart, end: weekEnd)
            
            // 按日期分組
            let groupedWorkouts = groupWorkoutsByDay(workouts)
            
            Logger.debug("分組後的訓練記錄:")
            for (day, dayWorkouts) in groupedWorkouts {
                Logger.debug(
                    "星期\(["一", "二", "三", "四", "五", "六", "日"][day-1]): \(dayWorkouts.count) 條記錄")
            }
            
            // 檢查今天的運動記錄
            let calendar = Calendar.current
            let today = Date()
            let todayWeekday = calendar.component(.weekday, from: today)
            let todayIndex = todayWeekday == 1 ? 7 : todayWeekday - 1  // 轉換為1-7代表週一到週日
            
            if let todayWorkouts = groupedWorkouts[todayIndex], !todayWorkouts.isEmpty {
                Logger.debug(
                    "今天(星期\(["一", "二", "三", "四", "五", "六", "日"][todayIndex-1]))有 \(todayWorkouts.count) 條訓練記錄"
                )
            } else {
                Logger.debug("今天沒有訓練記錄")
            }
            
            // 更新 UI
            await MainActor.run {
                self.workoutsByDay = groupedWorkouts
                self.isLoadingWorkouts = false
            }
            
            if let plan = weeklyPlan, plan.totalDistance > 0 {
                await loadCurrentWeekDistance(healthKitManager: healthKitManager)
            }
            
        } catch {
            Logger.error("載入訓練記錄時出錯: \(error)")
            
            await MainActor.run {
                self.isLoadingWorkouts = false
            }
        }
    }
    
    // 改進的按日期分組方法
    private func groupWorkoutsByDay(_ workouts: [HKWorkout]) -> [Int: [HKWorkout]] {
        let calendar = Calendar.current
        var grouped: [Int: [HKWorkout]] = [:]
        
        // 定義跑步相關的活動類型
        let runningActivityTypes: [HKWorkoutActivityType] = [
            .running,
            .walking,
            .hiking,
            .trackAndField,
            .crossTraining,
        ]
        
        for workout in workouts {
            // 只處理跑步相關的鍛煉
            guard runningActivityTypes.contains(workout.workoutActivityType) else {
                continue
            }
            
            let weekday = calendar.component(.weekday, from: workout.startDate)
            // 轉換 weekday 為 1-7（週一到週日）
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
            
            if grouped[adjustedWeekday] == nil {
                grouped[adjustedWeekday] = []
            }
            grouped[adjustedWeekday]?.append(workout)
        }
        
        // 對每天的運動記錄按日期排序（最新的在前面）
        for (day, dayWorkouts) in grouped {
            grouped[day] = dayWorkouts.sorted { $0.startDate > $1.startDate }
        }
        
        return grouped
    }
    
    // 識別並自動展開當天的訓練
    func identifyTodayTraining() async {
        if let plan = weeklyPlan {
            await MainActor.run {
                for day in plan.days
                where isToday(dayIndex: day.dayIndexInt, planWeek: plan.weekOfPlan) {
                    expandedDayIndices.insert(day.dayIndexInt)
                    break
                }
            }
        }
    }
    
    // 載入本週訓練強度分鐘數
    func loadCurrentWeekIntensity(healthKitManager: HealthKitManager) async {
        Logger.debug("載入本週訓練強度...")
        await MainActor.run {
            isLoadingIntensity = true
        }
        
        do {
            let (weekStart, _) = getCurrentWeekDates()
            Logger.debug("計算 \(formatDate(weekStart)) 開始的週訓練強度...")
            
            // 使用 TrainingIntensityManager 計算訓練強度
            let intensity = await intensityManager.calculateWeeklyIntensity(
                weekStartDate: weekStart,
                healthKitManager: healthKitManager
            )
            
            Logger.debug("訓練強度計算完成 - 低: \(intensity.low), 中: \(intensity.medium), 高: \(intensity.high)")
            
            // 確保在主線程上更新 UI
            await MainActor.run {
                // 使用實際計算出的強度值
                self._currentWeekIntensity = intensity
                
                // 強制引發 UI 刷新
                self.objectWillChange.send()
                self.isLoadingIntensity = false
                
                // 記錄完成的強度值
                Logger.debug("已更新強度值 - 低: \(intensity.low), 中: \(intensity.medium), 高: \(intensity.high)")
            }
            
        } catch {
            Logger.error("加載本週訓練強度時出錯: \(error)")
            
            // 確保在發生錯誤時也重置載入狀態
            await MainActor.run {
                self.isLoadingIntensity = false
            }
        }
        
        await MainActor.run {
            isLoadingIntensity = false
        }
    }
    
    func loadCurrentWeekDistance(healthKitManager: HealthKitManager) async {
        Logger.debug("載入週跑量中...")
        await MainActor.run {
            isLoadingDistance = true
        }
        
        do {
            try await healthKitManager.requestAuthorization()
            
            // 獲取當前週的時間範圍
            let (weekStart, weekEnd) = getCurrentWeekDates()
            
            // 獲取指定時間範圍內的鍛煉
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(
                start: weekStart, end: weekEnd)
            // 過濾僅包含跑步類型的鍛煉
            let runWorkouts = workouts.filter { $0.workoutActivityType == .running }
            // 計算跑步距離總和
            let totalDistance = ViewModelUtils.calculateTotalDistance(runWorkouts)
            
            Logger.debug("在入週跑量完成，週跑量為\(totalDistance)公里")
            
            // 更新UI
            await MainActor.run {
                self.currentWeekDistance = totalDistance
            }
            
        } catch {
            Logger.error("加載本週跑量時出錯: \(error)")
        }
        
        await MainActor.run {
            isLoadingDistance = false
        }
    }
    
    // 載入週訓練回顧數據
    func loadWeeklySummary() async {
        await MainActor.run {
            isLoadingWeeklySummary = true
            weeklySummaryError = nil
        }
        
        do {
            // 獲取當前訓練週數
            guard let currentWeek = calculateCurrentTrainingWeek() else {
                throw NSError(
                    domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法計算當前訓練週數"])
            }
            
            // 從API獲取週訓練回顧數據
            Logger.debug("嘗試得到第\(currentWeek-1)週的週回顧")
            let summary = try await weeklySummaryService.createWeeklySummary(
                weekNumber: currentWeek - 1)
            
            await MainActor.run {
                self.weeklySummary = summary
                self.isLoadingWeeklySummary = false
            }
            
        } catch {
            Logger.error("載入週訓練回顧失敗: \(error)")
            
            await MainActor.run {
                self.weeklySummaryError = error
                self.isLoadingWeeklySummary = false
            }
            
            // 嘗試從本地存儲加載
            if let savedSummary = WeeklySummaryStorage.shared.loadWeeklySummary() {
                await MainActor.run {
                    self.weeklySummary = savedSummary
                }
            }
        }
    }
    
    // 獲取週摘要列表的方法
    func fetchWeeklySummaries() async {
        await MainActor.run {
            isLoadingWeeklySummaries = true
            weeklySummariesError = nil
        }
        do {
            let items = try await weeklySummaryService.fetchWeeklySummaries()
            await MainActor.run {
                weeklySummaries = items
                isLoadingWeeklySummaries = false
            }
        } catch {
            Logger.error("載入週摘要列表失敗: \(error)")
            await MainActor.run {
                weeklySummariesError = error
                isLoadingWeeklySummaries = false
            }
        }
    }
    
    // 判斷是否應該顯示產生下週課表按鈕
    // 判斷是否應該顯示產生課表按鈕，並返回應該產生的週數
    func shouldShowNextWeekButton(plan: WeeklyPlan) -> (shouldShow: Bool, nextWeek: Int) {
        // 計算當前實際訓練週數
        guard let currentTrainingWeek = calculateCurrentTrainingWeek() else {
            // 如果無法計算當前訓練週數，則使用計劃週數+1
            let nextWeek = plan.weekOfPlan + 1
            let hasNextWeek = nextWeek <= plan.totalWeeks
            return (hasNextWeek, nextWeek)
        }
        
        // 如果當前實際訓練週數大於計畫週數，則應該顯示按鈕產生對應週數的課表
        if currentTrainingWeek > plan.weekOfPlan {
            // 確保不超過總週數
            let hasNextWeek = currentTrainingWeek <= plan.totalWeeks
            return (hasNextWeek, currentTrainingWeek)
        } else {
            // 如果當前實際訓練週數等於或小於計畫週數，不需要顯示按鈕
            return (false, currentTrainingWeek)
        }
    }
    
    func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        return ViewModelUtils.formatDistance(distance, unit: unit)
    }
    
    func formatShortDate(_ date: Date) -> String {
        return ViewModelUtils.formatShortDate(date)
    }
    
    func formatTime(_ date: Date) -> String {
        return ViewModelUtils.formatTime(date)
    }
    
    func formatPace(_ paceInSeconds: Double) -> String {
        return ViewModelUtils.formatPace(paceInSeconds)
    }
    
    func weekdayName(for index: Int) -> String {
        return ViewModelUtils.weekdayName(for: index)
    }
    
    // 用於除錯的日期格式化工具
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    private func formatDebugDate(_ date: Date) -> String {
        return ViewModelUtils.formatDebugDate(date)
    }
    
    // 獲取指定週訓練回顧的方法
    func fetchWeeklySummary(weekNumber: Int) async {
        await MainActor.run {
            isLoadingWeeklySummary = true
            weeklySummaryError = nil
        }
        do {
            let summary = try await weeklySummaryService.getWeeklySummary(weekNumber: weekNumber)
            Logger.info("fetchWeeklySummary for week : \(weekNumber)")
            WeeklySummaryStorage.shared.saveWeeklySummary(summary, weekNumber: weekNumber)
            await MainActor.run {
                self.weeklySummary = summary
                self.lastFetchedWeekNumber = weekNumber
                self.showWeeklySummary = true
                self.isLoadingWeeklySummary = false
            }
        } catch {
            Logger.error("載入週訓練回顧(第 \(weekNumber) 週)失敗: \(error)")
            await MainActor.run {
                self.weeklySummaryError = error
            }
        }
    }
}
