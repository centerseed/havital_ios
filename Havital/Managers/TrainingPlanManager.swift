import Foundation
import SwiftUI

// MARK: - 統一訓練計劃管理器
/// 遵循 DataManageable 協議，提供標準化的訓練計劃數據管理
class TrainingPlanManager: ObservableObject, DataManageable {
    
    // MARK: - Type Definitions
    typealias DataType = WeeklyPlan
    typealias ServiceType = TrainingPlanService
    
    // MARK: - Published Properties (DataManageable Requirements)
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var showNetworkErrorToast = false
    
    // MARK: - Training Plan Specific Properties
    @Published var currentWeeklyPlan: WeeklyPlan?
    @Published var trainingOverview: TrainingPlanOverview?
    @Published var selectedWeek: Int = 1
    @Published var currentWeek: Int = 1
    @Published var weekDateInfo: WeekDateInfo?
    @Published var modifications: [Modification] = []
    
    // MARK: - Status Properties
    @Published var noWeeklyPlanAvailable: Bool = false
    @Published var showNewWeekPrompt: Bool = false
    @Published var showFinalWeekPrompt: Bool = false
    
    // MARK: - Dependencies
    let service: TrainingPlanService
    private let cacheManager: TrainingPlanCacheManager
    // WeekDateService is an enum with static methods, no need for instance
    
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    
    // MARK: - Cacheable Properties
    var cacheIdentifier: String { "TrainingPlanManager" }
    
    // MARK: - Singleton
    static let shared = TrainingPlanManager()
    
    // MARK: - Initialization
    private init() {
        self.service = TrainingPlanService.shared
        self.cacheManager = TrainingPlanCacheManager()
        
        // 註冊到 CacheEventBus
        CacheEventBus.shared.register(self)
        
        setupNotificationObservers()
    }
    
    // MARK: - DataManageable Implementation
    
    func initialize() async {
        Logger.firebase(
            "TrainingPlanManager 初始化",
            level: .info,
            labels: ["module": "TrainingPlanManager", "action": "initialize"]
        )
        
        // 計算當前週
        await updateCurrentWeek()
        
        // 載入概覽和週計劃
        await loadTrainingOverview()
        await loadData()
    }
    
    func loadData() async {
        await executeTask(id: TaskID("load_weekly_plan_\(selectedWeek)")) { [weak self] () -> Void in
            guard let self = self else { return }
            
            do {
                try await self.performLoadWeeklyPlan()
            } catch {
                // 處理載入錯誤，但不影響已有的緩存數據
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("週計劃載入任務被取消，忽略錯誤")
                    return
                }
                
                await MainActor.run {
                    // 雙軌架構核心：網路錯誤時顯示Toast，不影響現有緩存UI
                    self.syncError = error.localizedDescription
                    
                    // 只有在沒有任何緩存數據時才顯示錯誤狀態
                    if self.currentWeeklyPlan == nil {
                        // 檢查是否為404（需要顯示週回顧）還是網路錯誤
                        if let httpError = error as? HTTPError, case .notFound(_) = httpError {
                            self.updatePlanStatus(for: nil) // 404: 顯示週回顧
                        } else if error is TrainingPlanService.WeeklyPlanError {
                            self.updatePlanStatus(for: nil) // API層404: 顯示週回顧  
                        } else {
                            // 網路錯誤：不改變UI狀態，觸發Toast提示
                            self.showNetworkErrorToast = true
                            Logger.debug("網路錯誤，保持現有UI狀態，顯示Toast提示")
                        }
                    } else {
                        // 如果有緩存數據，顯示Toast提示網路問題但保持現有UI
                        self.showNetworkErrorToast = true
                        Logger.debug("有緩存數據的情況下網路錯誤，顯示Toast提示但保持現有UI")
                    }
                }
                
                Logger.error("週計劃載入失敗: \(error.localizedDescription)")
            }
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        return await executeTask(id: TaskID("force_refresh_weekly_plan_\(selectedWeek)")) { [weak self] () -> Void in
            guard let self = self else { return }
            
            do {
                try await self.performRefreshWeeklyPlan()
            } catch {
                // 處理強制刷新錯誤
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("週計劃強制刷新任務被取消，忽略錯誤")
                    return
                }
                
                await MainActor.run {
                    self.syncError = error.localizedDescription
                }
                
                Logger.error("週計劃強制刷新失敗: \(error.localizedDescription)")
                throw error
            }
        } != nil
    }
    
    func clearAllData() async {
        await MainActor.run {
            currentWeeklyPlan = nil
            trainingOverview = nil
            modifications = []
            noWeeklyPlanAvailable = false
            showNewWeekPrompt = false
            showFinalWeekPrompt = false
            lastSyncTime = nil
            syncError = nil
            showNetworkErrorToast = false
        }
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "訓練計劃數據已清除",
            level: .info,
            labels: ["module": "TrainingPlanManager", "action": "clear_all_data"]
        )
    }
    
    /// 清除網路錯誤Toast狀態
    @MainActor
    func clearNetworkErrorToast() {
        showNetworkErrorToast = false
        syncError = nil
    }
    
    // MARK: - Cacheable Implementation
    
    func clearCache() {
        cacheManager.clearCache()
    }
    
    func getCacheSize() -> Int {
        return cacheManager.getCacheSize()
    }
    
    func isExpired() -> Bool {
        return cacheManager.isExpired()
    }
    
    // MARK: - Core Training Plan Logic
    
    private func performLoadWeeklyPlan() async throws {
        Logger.debug("開始雙軌載入週計劃，週次: \(selectedWeek)")
        
        // 軌道 A: 立即顯示緩存 (同步執行)
        if let cachedPlan = cacheManager.loadWeeklyPlan(for: selectedWeek) {
            await MainActor.run {
                self.currentWeeklyPlan = cachedPlan
                self.updatePlanStatus(for: cachedPlan)
                self.isLoading = false
                self.lastSyncTime = Date() // 使用當前時間作為緩存載入時間
            }
            
            Logger.debug("軌道 A: 成功顯示緩存的週計劃")
            
            // 軌道 B: 背景更新 (非同步執行)
            Task.detached { [weak self] in
                await self?.executeTask(id: TaskID("background_refresh_weekly_plan_\(self?.selectedWeek ?? 0)")) { () -> Void in
                    await self?.performBackgroundRefresh()
                }
            }
            return
        }
        
        // 從 API 獲取 - 這裡需要根據實際 API 邏輯調整
        // 目前 API 沒有直接通過週數獲取計劃的方法
        // 可能需要先獲取 overview，然後根據 planId 獲取具體計劃
        
        do {
            // 嘗試通過 overview 獲取當前週的計劃 ID
            let overview = try await service.getTrainingPlanOverview()
            
            await MainActor.run {
                self.trainingOverview = overview
            }
            
            // 這裡需要根據 overview 的結構來確定如何獲取具體週的計劃
            // 暫時設置為 nil，表示需要生成新計劃
            let plan: WeeklyPlan? = nil
            
            await MainActor.run {
                self.currentWeeklyPlan = plan
                self.updatePlanStatus(for: plan)
            }
            
            cacheManager.saveWeeklyPlan(plan, for: selectedWeek)
        } catch {
            // 如果獲取失敗，設置為需要生成新計劃
            await MainActor.run {
                self.currentWeeklyPlan = nil
                self.updatePlanStatus(for: nil)
            }
            throw error
        }
        
        // 發送通知
        NotificationCenter.default.post(name: .trainingPlanDidUpdate, object: nil)
        
        Logger.firebase(
            "週計劃載入完成",
            level: .info,
            labels: ["module": "TrainingPlanManager", "action": "load_weekly_plan"],
            jsonPayload: ["week": selectedWeek, "plan_available": currentWeeklyPlan != nil]
        )
    }
    
    private func performRefreshWeeklyPlan() async throws {
        // 強制從 API 刷新
        let overview = try await service.getTrainingPlanOverview()
        
        await MainActor.run {
            self.trainingOverview = overview
            // 根據實際 API 結構調整計劃獲取邏輯
            self.currentWeeklyPlan = nil
            self.updatePlanStatus(for: nil)
        }
        
        cacheManager.saveWeeklyPlan(nil, for: selectedWeek)
        
        // 發送通知
        NotificationCenter.default.post(name: .trainingPlanDidUpdate, object: nil)
    }
    
    /// 雙軌策略：背景更新最新數據
    private func performBackgroundRefresh() async {
        Logger.debug("軌道 B: 開始背景更新週計劃")
        
        do {
            let latestPlan = try await fetchLatestWeeklyPlan()
            
            // 更新 UI 和緩存
            await MainActor.run {
                self.currentWeeklyPlan = latestPlan
                self.updatePlanStatus(for: latestPlan)
                self.lastSyncTime = Date()
                self.syncError = nil
            }
            
            // 保存到緩存
            cacheManager.saveWeeklyPlan(latestPlan, for: selectedWeek)
            
            // 通知更新
            NotificationCenter.default.post(name: .trainingPlanDidUpdate, object: nil)
            
            Logger.debug("軌道 B: 背景更新完成")
            
        } catch {
            // 背景更新失敗不影響已顯示的緩存內容
            await MainActor.run {
                self.syncError = error.localizedDescription
                // 背景更新失敗時顯示Toast提示，但保持現有UI
                self.showNetworkErrorToast = true
            }
            
            Logger.debug("軌道 B: 背景更新失敗，保持現有緩存，顯示Toast提示: \(error.localizedDescription)")
        }
    }
    
    /// 獲取最新週計劃的統一入口
    private func fetchLatestWeeklyPlan() async throws -> WeeklyPlan? {
        // 這裡需要根據實際 API 實現
        // 目前使用 overview + planId 的方式
        let overview = try await service.getTrainingPlanOverview()
        
        await MainActor.run {
            self.trainingOverview = overview
        }
        
        // 根據 overview 構建 planId 獲取具體計劃
        let planId = "\(overview.id)_\(selectedWeek)"
        
        do {
            return try await service.getWeeklyPlanById(planId: planId)
        } catch TrainingPlanService.WeeklyPlanError.notFound {
            // 404 是正常情況，表示該週還沒有計劃
            return nil
        }
    }
    
    /// 原有的背景刷新方法，重構為使用新的雙軌策略
    private func backgroundRefreshWeeklyPlan() async {
        // 委託給新的雙軌策略方法
        await performBackgroundRefresh()
    }
    
    /// 獲取當週計劃（處理 404 情況）
    private func fetchCurrentWeekPlan() async -> WeeklyPlan? {
        do {
            // 這裡需要根據實際 API 實現調整
            // 如果有直接獲取週計劃的 API，使用它
            // 否則通過 overview 來推斷是否有當週計劃
            
            // 暫時返回 nil，表示需要根據實際 API 結構調整
            return nil
        } catch {
            // 404 或其他錯誤，返回 nil
            return nil
        }
    }
    
    func loadTrainingOverview() async {
        await executeTask(id: TaskID("load_training_overview")) { [weak self] () -> Void in
            guard let self = self else { return }
            
            Logger.debug("開始雙軌載入訓練概覽")
            
            // 軌道 A: 立即顯示緩存
            if let cachedOverview = self.cacheManager.loadTrainingOverview() {
                await MainActor.run {
                    self.trainingOverview = cachedOverview
                }
                
                Logger.debug("軌道 A: 成功顯示緩存的訓練概覽")
                
                // 軌道 B: 背景更新
                Task.detached { [weak self] in
                    await self?.executeTask(id: TaskID("background_refresh_overview")) { () -> Void in
                        await self?.refreshTrainingOverviewInBackground()
                    }
                }
                return
            }
            
            // 沒有緩存時，直接從 API 獲取
            do {
                let overview = try await APICallTracker.$currentSource.withValue("TrainingPlanManager: loadTrainingOverview") {
                    try await self.service.getTrainingPlanOverview()
                }

                await MainActor.run {
                    self.trainingOverview = overview
                }

                self.cacheManager.saveTrainingOverview(overview)

                Logger.debug("訓練概覽初次載入成功")
                
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("訓練概覽載入任務被取消，忽略錯誤")
                    return
                }
                
                Logger.error("訓練概覽載入失敗: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// 背景刷新訓練概覽
    private func refreshTrainingOverviewInBackground() async {
        Logger.debug("軌道 B: 開始背景更新訓練概覽")

        do {
            let latestOverview = try await APICallTracker.$currentSource.withValue("TrainingPlanManager: refreshTrainingOverviewInBackground") {
                try await service.getTrainingPlanOverview()
            }

            await MainActor.run {
                self.trainingOverview = latestOverview
            }

            cacheManager.saveTrainingOverview(latestOverview)

            Logger.debug("軌道 B: 訓練概覽背景更新完成")

            // 🔄 檢查 Onboarding Backfill 結果（背景執行）
            // 在 overview 載入完成後檢查 backfill 狀態，記錄到 cloud logging
            let currentDataSource = UserPreferenceManager.shared.dataSourcePreference
            if currentDataSource == .strava || currentDataSource == .garmin {
                BackfillService.shared.checkAndLogBackfillResult(provider: currentDataSource)
            }

        } catch {
            // 背景更新失敗不影響已顯示的緩存內容
            Logger.debug("軌道 B: 訓練概覽背景更新失敗，保持現有緩存: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Week Management
    
    func switchToWeek(_ week: Int) async {
        guard week != selectedWeek else { return }
        
        await MainActor.run {
            selectedWeek = week
        }
        
        await loadData()
    }
    
    func updateCurrentWeek() async {
        let calculatedWeek = calculateCurrentTrainingWeek()
        
        await MainActor.run {
            currentWeek = calculatedWeek
            weekDateInfo = getWeekDateInfo(for: calculatedWeek)
        }
    }
    
    var availableWeeks: [Int] {
        let currentWeek = calculateCurrentTrainingWeek()
        guard currentWeek > 0 else { return [] }
        return Array(1...currentWeek)
    }
    
    // MARK: - Plan Generation
    
    func generateNewWeekPlan() async -> Bool {
        return await executeTask(id: TaskID("generate_new_week_\(selectedWeek)")) { [weak self] () -> Void in
            guard let self = self else { return }
            
            do {
                Logger.debug("開始生成新週計劃，週次: \(self.selectedWeek)")
                
                // 使用實際的 API 方法
                let newPlan = try await self.service.createWeeklyPlan(targetWeek: self.selectedWeek)
                
                await MainActor.run {
                    self.currentWeeklyPlan = newPlan
                    self.showNewWeekPrompt = false
                    self.noWeeklyPlanAvailable = false
                    self.updatePlanStatus(for: newPlan)
                }
                
                self.cacheManager.saveWeeklyPlan(newPlan, for: self.selectedWeek)
                
                // 發送通知
                NotificationCenter.default.post(name: .trainingPlanDidUpdate, object: nil)
                
                Logger.debug("新週計劃生成成功，週次: \(self.selectedWeek)")
                
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("新週計劃生成任務被取消，忽略錯誤")
                    return
                }
                
                await MainActor.run {
                    self.syncError = error.localizedDescription
                }
                
                Logger.error("新週計劃生成失敗: \(error.localizedDescription)")
                throw error
            }
        } != nil
    }
    
    // MARK: - Modifications Management
    
    func loadModifications() async {
        await executeTask(id: TaskID("load_modifications")) { [weak self] () -> Void in
            guard let self = self else { return }
            
            do {
                Logger.debug("開始載入修改項目")
                
                // 使用實際的 API 方法 (不需要週數參數)
                let mods = try await self.service.getModifications()
                
                await MainActor.run {
                    self.modifications = mods
                }
                
                Logger.debug("修改項目載入成功，數量: \(mods.count)")
                
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("修改項目載入任務被取消，忽略錯誤")
                    return
                }
                
                Logger.error("修改項目載入失敗: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    func saveModification(_ content: String, expiresAt: String? = nil, isOneTime: Bool = false, priority: Int = 1) async -> Bool {
        return await executeTask(id: TaskID("save_modification_\(Date().timeIntervalSince1970)")) { [weak self] () -> Void in
            guard let self = self else { return }
            
            do {
                Logger.debug("開始保存修改項目: \(content.prefix(50))...")
                
                // 使用正確的 NewModification 結構
                let newMod = NewModification(
                    content: content,
                    expiresAt: expiresAt,
                    isOneTime: isOneTime,
                    priority: priority
                )
                let savedMod = try await self.service.createModification(newMod)
                
                // 重新載入修改列表
                await self.loadModifications()
                
                Logger.debug("修改項目保存成功，內容: \(savedMod.content.prefix(30))...")
                
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("修改項目保存任務被取消，忽略錯誤")
                    return
                }
                
                Logger.error("修改項目保存失敗: \(error.localizedDescription)")
                throw error
            }
        } != nil
    }
    
    // 便利方法：僅使用描述文字創建修改
    func saveSimpleModification(_ content: String) async -> Bool {
        return await saveModification(content, isOneTime: false, priority: 1)
    }
    
    // MARK: - Private Helper Methods
    
    private func updatePlanStatus(for plan: WeeklyPlan?) {
        if let plan = plan {
            noWeeklyPlanAvailable = false
            showNewWeekPrompt = false
            showFinalWeekPrompt = false
        } else {
            noWeeklyPlanAvailable = true
            showNewWeekPrompt = (selectedWeek == currentWeek)
            showFinalWeekPrompt = (selectedWeek > currentWeek)
        }
    }
    
    private func calculateCurrentTrainingWeek() -> Int {
        // TODO: 實現正確的當前訓練週計算邏輯
        // 暫時返回週1
        return 1
    }
    
    private func getWeekDateInfo(for week: Int) -> WeekDateInfo? {
        // TODO: 實現正確的週日期信息獲取邏輯
        // 暫時返回當前週的信息
        let today = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today
        
        var daysMap: [Int: Date] = [:]
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                daysMap[i + 1] = date
            }
        }
        
        return WeekDateInfo(startDate: startOfWeek, endDate: endOfWeek, daysMap: daysMap)
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .userDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.clearAllData()
                await self?.initialize()
            }
        }
    }
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Cache Manager
private class TrainingPlanCacheManager: BaseCacheManagerTemplate<TrainingPlanCacheData> {
    
    init() {
        super.init(identifier: "training_plan", defaultTTL: 1800) // 30 minutes
    }
    
    // MARK: - Specialized Cache Methods
    
    func saveWeeklyPlan(_ plan: WeeklyPlan?, for week: Int) {
        var cacheData = loadFromCache() ?? TrainingPlanCacheData()
        cacheData.weeklyPlans[week] = plan
        saveToCache(cacheData)
    }
    
    func loadWeeklyPlan(for week: Int) -> WeeklyPlan? {
        return loadFromCache()?.weeklyPlans[week] ?? nil
    }
    
    func saveTrainingOverview(_ overview: TrainingPlanOverview) {
        var cacheData = loadFromCache() ?? TrainingPlanCacheData()
        cacheData.trainingOverview = overview
        saveToCache(cacheData)
    }
    
    func loadTrainingOverview() -> TrainingPlanOverview? {
        return loadFromCache()?.trainingOverview
    }
}

// MARK: - Cache Data Structure
private struct TrainingPlanCacheData: Codable {
    var weeklyPlans: [Int: WeeklyPlan?] = [:]
    var trainingOverview: TrainingPlanOverview?
}
