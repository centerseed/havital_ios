import Combine
import HealthKit
import SwiftUI

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var weeklyPlan: WeeklyPlan?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentWeekDistance: Double = 0.0
    @Published var isLoadingDistance = false
    @Published var currentVDOT: Double = 0.0
    @Published var targetVDOT: Double = 0.0
    @Published var isLoadingVDOT = false
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
            self.currentWeek = calculateCurrentTrainingWeek() ?? 1
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
                        self.currentWeek = calculateCurrentTrainingWeek() ?? 1
                    }
                } catch {
                    Logger.error("初始化獲取訓練計劃概覽失敗: \(error)")
                }
            }
        }
        // 監聽 overview 變化，自動計算週數並載入對應週計畫
        $trainingOverview
            .compactMap { $0 }
            .sink { [weak self] overview in
                guard let self = self else { return }
                let week = self.calculateCurrentTrainingWeek() ?? 1
                self.currentWeek = week
                if let info = WeekDateService.weekDateInfo(createdAt: overview.createdAt, weekNumber: week) {
                    self.weekDateInfo = info
                }
                Task { await self.loadWeeklyPlan() }
            }
            .store(in: &cancellables)
        // 若初始化已讀取到 trainingOverview，立即載入週計劃
        if trainingOverview != nil {
            Task { await loadWeeklyPlan() }
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
        guard let overview = trainingOverview, !overview.createdAt.isEmpty else {
            Logger.debug("無法計算訓練週數: 缺少 overview 或建立時間")
            return nil
        }

        // 解析 createdAt，支持帶小數秒和不帶小數秒
        var createdAtDate: Date?
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        createdAtDate = isoFormatter.date(from: overview.createdAt)
        if createdAtDate == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            createdAtDate = isoFormatter.date(from: overview.createdAt)
        }
        guard let startDate = createdAtDate else {
            Logger.debug("無法解析建立時間: \(overview.createdAt)")
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)
        // 計算建立日期所在週的週一
        let createdWeekday = calendar.component(.weekday, from: startDate)
        let createdIndex = (createdWeekday + 5) % 7  // Monday=0..Sunday=6
        guard let createdMonday = calendar.date(byAdding: .day,
                                               value: -createdIndex,
                                               to: calendar.startOfDay(for: startDate)) else {
            Logger.debug("無法計算建立日期所在週的週一")
            return nil
        }

        // 計算今天所在週的週一
        let today = now()
        let todayWeekday = calendar.component(.weekday, from: today)
        let todayIndex = (todayWeekday + 5) % 7
        guard let todayMonday = calendar.date(byAdding: .day,
                                             value: -todayIndex,
                                             to: calendar.startOfDay(for: today)) else {
            Logger.debug("無法計算今天所在週的週一")
            return nil
        }

        // 計算週差並 +1
        let seconds = todayMonday.timeIntervalSince(createdMonday)
        let weekCount = Int(floor(seconds / (7 * 24 * 3600))) + 1
        return max(weekCount, 1)
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

    func loadWeeklyPlan() async {
        planStatus = .loading
        // 首先嘗試從本地加載數據
        if let savedPlan = TrainingPlanStorage.loadWeeklyPlan() {
            // 立即更新UI
            await MainActor.run {
                self.currentPlanWeek = savedPlan.weekOfPlan
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: savedPlan.weekOfPlan) {
                    self.weekDateInfo = info
                }
                self.selectedWeek = savedPlan.weekOfPlan
                let cw = self.calculateCurrentTrainingWeek() ?? 0
                self.planStatus = cw > savedPlan.totalWeeks ? .completed : .ready(savedPlan)
                updatePromptViews()
            }

            // 異步從API獲取最新數據
            do {
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                Logger.info("Load weekly plan with planId: \(overviewId)_\(currentWeek).")
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                    planId: "\(overviewId)_\(self.currentWeek)")
                
                // 檢查計劃是否有變更
                let planChanged =
                    savedPlan.id != newPlan.id || savedPlan.weekOfPlan != newPlan.weekOfPlan

                await MainActor.run {
                    self.weeklyPlan = newPlan
                    self.currentPlanWeek = newPlan.weekOfPlan
                    if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                        self.weekDateInfo = info
                    }
                    self.selectedWeek = newPlan.weekOfPlan

                    // 如果計劃有變更，清除舊的訓練記錄
                    if planChanged {
                        self.workoutsByDay.removeAll()
                        self.expandedDayIndices.removeAll()
                    }
                    let cw = self.calculateCurrentTrainingWeek() ?? 0
                    self.planStatus = cw > newPlan.totalWeeks ? .completed : .ready(newPlan)
                    updatePromptViews()
                }
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404: 無週計劃
                await MainActor.run {
                    let cw = calculateCurrentTrainingWeek() ?? 0
                    self.planStatus = .noPlan
                    updatePromptViews()
                }
            } catch {
                // 其他錯誤: 使用本地數據並記錄
                Logger.error("API加載計劃失敗，使用本地數據: \(error)")
                await MainActor.run {
                    self.planStatus = .error(error)
                }
            }
        } else {
            // 本地無數據，必須等待API
            do {
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                    planId: "\(overviewId)_\(self.currentWeek)")
                
                await MainActor.run {
                    self.weeklyPlan = newPlan
                    self.currentPlanWeek = newPlan.weekOfPlan
                    if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                        self.weekDateInfo = info
                    }
                    self.selectedWeek = newPlan.weekOfPlan
                    let cw = self.calculateCurrentTrainingWeek() ?? 0
                    self.planStatus = cw > newPlan.totalWeeks ? .completed : .ready(newPlan)
                    updatePromptViews()
                }
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404: 無週計劃
                await MainActor.run {
                    let cw = calculateCurrentTrainingWeek() ?? 0
                    self.planStatus = .noPlan
                    updatePromptViews()
                }
            } catch {
                await MainActor.run {
                    self.planStatus = .error(error)
                }
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

            await MainActor.run {
                self.weeklyPlan = plan
                self.selectedWeek = week
                self.currentPlanWeek = plan.weekOfPlan
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: plan.weekOfPlan) {
                    self.weekDateInfo = info
                }
                let cw = self.calculateCurrentTrainingWeek() ?? 0
                self.planStatus = cw > plan.totalWeeks ? .completed : .ready(plan)
                updatePromptViews()
            }
            // 載入該週的健康資料
            await loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
            await loadCurrentWeekDistance(healthKitManager: healthKitManager)
            await identifyTodayTraining()

        } catch let err as TrainingPlanService.WeeklyPlanError where err == .notFound {
            // 404 錯誤：依週數區分提示
            await MainActor.run {
                let cw = calculateCurrentTrainingWeek() ?? 0
                self.planStatus = cw == week ? .noPlan : .noPlan
                updatePromptViews()
            }
        } catch {
            await MainActor.run {
                self.planStatus = .error(error)
            }
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

        // 然後嘗試從API獲取最新數據
        do {
            let overview = try await TrainingPlanService.shared.getTrainingPlanOverview()

            // 成功獲取後更新UI
            await MainActor.run {
                self.trainingOverview = overview
            }

            Logger.debug("成功載入訓練計劃概覽")
            Logger.debug("Plan Overview id \(overview.id)")

            // 將訓練計劃概覽存入本地緩存
            TrainingPlanStorage.saveTrainingPlanOverview(overview)

            // 計算並輸出當前訓練週數
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
        planStatus = .loading

        do {
            Logger.debug("開始產生第 \(targetWeek) 週課表...")
            _ = try await TrainingPlanService.shared.createWeeklyPlan(targetWeek: targetWeek)

            // 產生成功後重新載入課表
            do {
                //let newPlan = try await TrainingPlanService.shared.getWeeklyPlan(
                //    caller: "generateNextWeekPlan")
                
                guard let overviewId = trainingOverview?.id else { throw NSError() }
                let newPlan = try await TrainingPlanService.shared.getWeeklyPlanById(
                    planId: "\(overviewId)_\(self.currentWeek)")

                // 更新當前計劃週數
                currentPlanWeek = newPlan.weekOfPlan

                // 重新計算週日期信息
                if let info = WeekDateService.weekDateInfo(createdAt: self.trainingOverview!.createdAt, weekNumber: newPlan.weekOfPlan) {
                    self.weekDateInfo = info
                }

                await MainActor.run {
                    self.weeklyPlan = newPlan
                    self.error = nil

                    // 清除舊的訓練記錄和展開狀態
                    self.workoutsByDay.removeAll()
                    self.expandedDayIndices.removeAll()
                    let cw = self.calculateCurrentTrainingWeek() ?? 0
                    self.planStatus = cw > newPlan.totalWeeks ? .completed : .ready(newPlan)
                    updatePromptViews()
                }
                await MainActor.run {
                    noWeeklyPlanAvailable = false
                }

                // 重新載入訓練計劃概覽，確保獲取最新資訊
                Logger.debug("重新載入訓練計劃概覽")
                await loadTrainingOverview()

                // 重新載入訓練記錄
                await loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager())

                Logger.debug("成功產生第 \(targetWeek) 週課表並更新 UI")
            } catch {
                Logger.error("重新載入課表失敗: \(error)")

                await MainActor.run {
                    self.error = error
                }
            }
        } catch {
            Logger.error("產生第 \(targetWeek) 週課表失敗: \(error)")

            await MainActor.run {
                self.error = error
            }
        }

        planStatus = .loading
    }

    // Flag to ensure initial data load only once
    private var hasLoadedInitialData = false

    /// 只在第一次執行：載入週計劃、概覽、VDOT、記錄、距離等
    func loadAllInitialData(healthKitManager: HealthKitManager) async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true

        // 先載入並顯示本地週計劃，再獨立 Task 非阻塞刷新 API
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadWeeklyPlan()
        }
        // 非取消任務：獨立 Task 執行、非阻塞
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadTrainingOverview()
        }
        // 如果計劃週數落後，嘗試刷新一次
        /*
        if let currentWeek = calculateCurrentTrainingWeek(), let plan = weeklyPlan, plan.weekOfPlan < currentWeek {
            await refreshWeeklyPlan(healthKitManager: healthKitManager)
        }        await loadVDOTData()*/
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

                await MainActor.run {
                    // 更新計劃內容，不變動 planStatus
                    withTransaction(Transaction(animation: nil)) {
                        self.weeklyPlan = newPlan
                    }
                    self.error = nil
                    // 若週數變更，再清除舊記錄
                    if planWeekChanged {
                        Logger.debug("偵測到計劃週數變更，清除舊的訓練記錄")
                        self.workoutsByDay.removeAll()
                        self.expandedDayIndices.removeAll()
                    }
                    let cw = self.calculateCurrentTrainingWeek() ?? 0
                    self.planStatus = cw > newPlan.totalWeeks ? .completed : .ready(newPlan)
                    updatePromptViews()
                }

                Logger.debug("完成更新計劃")

                // 重新載入訓練記錄
                await loadWorkoutsForCurrentWeek(healthKitManager: HealthKitManager())
                await identifyTodayTraining()

                if newPlan.totalDistance > 0 {
                    await loadCurrentWeekDistance(healthKitManager: healthKitManager)
                }

                await loadVDOTData()

                break  // 成功後跳出重試迴圈
            } catch let error as TrainingPlanService.WeeklyPlanError where error == .notFound {
                // 404 時標記無週計劃並結束重試
                break
            } catch {
                currentRetry += 1
                if currentRetry >= maxRetries {
                    await MainActor.run {
                        self.error = error
                        Logger.error("刷新訓練計劃失敗 (已重試 \(maxRetries) 次): \(error)")
                    }
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
            let totalDistance = calculateTotalDistance(runWorkouts)

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

    // 加載VDOT數據
    func loadVDOTData() async {
        await MainActor.run {
            isLoadingVDOT = true
        }

        // 簡化處理：使用默認值
        await MainActor.run {
            self.currentVDOT = 40.0
            self.targetVDOT = 45.0
            self.isLoadingVDOT = false
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

    // 輔助方法
    private func calculateTotalDistance(_ workouts: [HKWorkout]) -> Double {
        var total = 0.0
        for workout in workouts {
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) {
                total += distance / 1000  // 轉換為公里
            }
        }
        return total
    }

    func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        if let unit = unit {
            return String(format: "%.2f \(unit)", distance)
        } else {
            return String(Int(distance))
        }
    }
    
    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func formatPace(_ paceInSeconds: Double) -> String {
        let minutes = Int(paceInSeconds) / 60
        let seconds = Int(paceInSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    func weekdayName(for index: Int) -> String {
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return "星期" + weekdays[index - 1]
    }

    // 用於除錯的日期格式化工具
    private func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // Load all modifications
    func loadModifications() async {
        do {
            let mods = try await TrainingPlanService.shared.getModifications()
            await MainActor.run { self.modifications = mods }
        } catch {
            Logger.error("載入修改課表失敗: \(error)")
        }
    }

    /// Load description of modifications
    func loadModificationsDescription() async {
        do {
            let desc = try await TrainingPlanService.shared.getModificationsDescription()
            await MainActor.run { self.modDescription = desc }
        } catch {
            Logger.error("載入修改描述失敗: \(error)")
        }
    }

    /// Toggle applied state and update modifications
    func toggleModificationApplied(at index: Int) async {
        guard modifications.indices.contains(index) else { return }
        var mods = modifications
        mods[index].applied.toggle()
        do {
            let updated = try await TrainingPlanService.shared.updateModifications(mods)
            await MainActor.run { self.modifications = updated }
        } catch {
            Logger.error("更新修改課表失敗: \(error)")
        }
    }

    /// Add new modification
    func addModification(content: String, expiresAt: String?, isOneTime: Bool, priority: Int) async
    {
        let newMod = NewModification(
            content: content, expiresAt: expiresAt, isOneTime: isOneTime, priority: priority)
        do {
            let created = try await TrainingPlanService.shared.createModification(newMod)
            await MainActor.run { self.modifications.append(created) }
        } catch {
            Logger.error("新增修改課表失敗: \(error)")
        }
    }

    /// Clear all modifications
    func clearAllModifications() async {
        do {
            try await TrainingPlanService.shared.clearModifications()
            await MainActor.run { self.modifications.removeAll() }
        } catch {
            Logger.error("清空修改課表失敗: \(error)")
        }
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
                self.isLoadingWeeklySummary = false
            }
        }
    }

    /// 下拉刷新專用：僅更新訓練記錄、跑量與 VDOT，不觸發 planStatus 或 weeklyPlan 變動
    func refreshData(healthKitManager: HealthKitManager) async {
        // 讀取訓練記錄
        await loadWorkoutsForCurrentWeek(healthKitManager: healthKitManager)
        // 讀取本週跑量
        if let plan = weeklyPlan, plan.totalDistance > 0 {
            await loadCurrentWeekDistance(healthKitManager: healthKitManager)
        }
        // 讀取 VDOT
        await loadVDOTData()
    }
}
