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
        await executeDataLoadingTask(id: "load_weekly_plan") {
            try await self.performLoadWeeklyPlan()
        }
    }
    
    @discardableResult
    func refreshData() async -> Bool {
        await executeDataLoadingTask(id: "refresh_weekly_plan") {
            try await self.performRefreshWeeklyPlan()
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
        }
        
        cacheManager.clearCache()
        
        Logger.firebase(
            "訓練計劃數據已清除",
            level: .info,
            labels: ["module": "TrainingPlanManager", "action": "clear_all_data"]
        )
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
        // 優先從快取載入
        if let cachedPlan = cacheManager.loadWeeklyPlan(for: selectedWeek),
           !cacheManager.shouldRefresh() {
            await MainActor.run {
                self.currentWeeklyPlan = cachedPlan
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
    
    func loadTrainingOverview() async {
        await executeDataLoadingTask(id: "load_training_overview", showLoading: false) {
            // 先嘗試從快取載入
            if let cachedOverview = self.cacheManager.loadTrainingOverview(),
               !self.cacheManager.shouldRefresh() {
                await MainActor.run {
                    self.trainingOverview = cachedOverview
                }
                return
            }
            
            // 從 API 獲取
            let overview = try await self.service.getTrainingPlanOverview()
            
            await MainActor.run {
                self.trainingOverview = overview
            }
            
            self.cacheManager.saveTrainingOverview(overview)
            
            Logger.firebase(
                "訓練概覽載入成功",
                level: .info,
                labels: ["module": "TrainingPlanManager", "action": "load_overview"],
                jsonPayload: ["total_weeks": overview.totalWeeks]
            )
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
        return await executeDataLoadingTask(id: "generate_new_week") {
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
            
            Logger.firebase(
                "新週計劃生成成功",
                level: .info,
                labels: ["module": "TrainingPlanManager", "action": "generate_new_week"],
                jsonPayload: ["week": self.selectedWeek]
            )
            
            return true
        } != nil
    }
    
    // MARK: - Modifications Management
    
    func loadModifications() async {
        await executeDataLoadingTask(id: "load_modifications", showLoading: false) {
            // 使用實際的 API 方法 (不需要週數參數)
            let mods = try await self.service.getModifications()
            
            await MainActor.run {
                self.modifications = mods
            }
        }
    }
    
    func saveModification(_ content: String, expiresAt: String? = nil, isOneTime: Bool = false, priority: Int = 1) async -> Bool {
        return await executeDataLoadingTask(id: "save_modification") {
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
            return true
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