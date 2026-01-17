import Foundation
import SwiftUI

/// Training Readiness Manager
/// Implements DataManageable and TaskManageable protocols
///
/// ⚠️ DEPRECATED: 此類需要重構為 UseCase 模式
/// 遷移計劃:
/// 1. 創建 GetTrainingReadinessUseCase
/// 2. 使用 TrainingPlanRepository 替代直接 Service 調用
/// 3. 移除 Singleton 模式，改用依賴注入
@available(*, deprecated, message: "Needs refactoring to UseCase pattern")
@MainActor
class TrainingReadinessManager: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    // MARK: - Training Readiness Data
    @Published var readinessData: TrainingReadinessResponse?

    // MARK: - Dependencies
    private let service: TrainingReadinessService
    private let storage: TrainingReadinessStorage

    // MARK: - TaskManageable
    let taskRegistry = TaskRegistry()

    // MARK: - Singleton
    static let shared = TrainingReadinessManager()

    // MARK: - Initialization
    private init(
        service: TrainingReadinessService = .shared,
        storage: TrainingReadinessStorage = .shared
    ) {
        self.service = service
        self.storage = storage

        setupNotificationObservers()
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Public Methods

    /// Initialize and load data
    func initialize() async {
        print("[TrainingReadinessManager] 初始化")

        // Load cached data first (Track A: immediate)
        loadLocalData()

        // Then refresh in background (Track B: background)
        Task.detached { [weak self] in
            await self?.backgroundRefresh()
        }
    }

    /// Load data (cache-first strategy)
    func loadData() async {
        await executeTask(id: TaskID("load_readiness_data")) { [weak self] in
            guard let self = self else { return }

            // Track A: Load cache immediately
            if let cachedData = self.storage.loadReadinessData() {
                await MainActor.run {
                    self.readinessData = cachedData
                    self.isLoading = false
                    self.lastSyncTime = self.storage.getLastFetchTime()
                }

                // Track B: Refresh in background
                Task.detached { [weak self] in
                    await self?.backgroundRefresh()
                }
                return
            }

            // No cache: fetch from API
            await self.fetchFromAPI(showLoading: true)
        }
    }

    /// Refresh data (force fetch from API)
    func refreshData() async {
        await executeTask(id: TaskID("refresh_readiness_data")) { [weak self] in
            guard let self = self else { return }
            await self.fetchFromAPI(showLoading: true, forceCalculate: false)
        }
    }

    /// Force refresh with recalculation
    func forceRefresh() async {
        print("[TrainingReadinessManager] 🔄 開始強制刷新（force_calculate=true）")
        await executeTask(id: TaskID("force_refresh_readiness")) { [weak self] in
            guard let self = self else { return }

            // 清除緩存，確保從 API 獲取最新數據
            await MainActor.run {
                self.storage.clearReadinessData()
                print("[TrainingReadinessManager] 🗑️ 已清除本地緩存")
            }

            await self.fetchFromAPI(showLoading: true, forceCalculate: true)
        }
    }

    /// Clear all data
    func clearAllData() async {
        await MainActor.run {
            readinessData = nil
            lastSyncTime = nil
            syncError = nil
        }
        storage.clearReadinessData()
        print("[TrainingReadinessManager] 已清除所有數據")
    }

    // MARK: - Private Methods

    /// Load data from local cache
    private func loadLocalData() {
        if let cachedData = storage.loadReadinessData() {
            readinessData = cachedData
            lastSyncTime = storage.getLastFetchTime()
            print("[TrainingReadinessManager] 從緩存載入數據")
        }
    }

    /// Background refresh (no loading state)
    private func backgroundRefresh() async {
        await executeTask(id: TaskID("background_refresh_readiness")) { [weak self] in
            guard let self = self else { return }
            await self.fetchFromAPI(showLoading: false, forceCalculate: false)
        }
    }

    /// Fetch data from API
    private func fetchFromAPI(showLoading: Bool, forceCalculate: Bool = false) async {
        if showLoading {
            await MainActor.run {
                self.isLoading = true
                self.syncError = nil
            }
        }

        do {
            print("[TrainingReadinessManager] 📡 調用 API: forceCalculate=\(forceCalculate)")
            let response = try await APICallTracker.$currentSource.withValue("TrainingReadinessManager: fetchFromAPI") {
                try await service.getTodayReadiness(forceCalculate: forceCalculate)
            }

            print("[TrainingReadinessManager] ✅ API 回應成功")
            print("[TrainingReadinessManager] 📊 整體分數: \(response.overallScore ?? 0)")

            // 詳細記錄每個指標的分數和描述
            if let speed = response.metrics?.speed {
                print("[TrainingReadinessManager] 🏃 速度分數: \(speed.score), 描述: \(speed.description ?? "無")")
            }
            if let endurance = response.metrics?.endurance {
                print("[TrainingReadinessManager] 💪 耐力分數: \(endurance.score), 描述: \(endurance.description ?? "無")")
            }
            if let raceFitness = response.metrics?.raceFitness {
                print("[TrainingReadinessManager] 🏁 比賽適能分數: \(raceFitness.score), 描述: \(raceFitness.description ?? "無")")
                print("[TrainingReadinessManager] ⏱️ 預計完賽時間: \(raceFitness.estimatedRaceTime ?? "未設定")")
            }
            if let trainingLoad = response.metrics?.trainingLoad {
                print("[TrainingReadinessManager] 📊 訓練負荷分數: \(trainingLoad.score), 描述: \(trainingLoad.description ?? "無")")
            }

            print("[TrainingReadinessManager] 📈 指標數量: speed=\(response.metrics?.speed != nil ? "✓" : "✗"), endurance=\(response.metrics?.endurance != nil ? "✓" : "✗"), raceFitness=\(response.metrics?.raceFitness != nil ? "✓" : "✗"), trainingLoad=\(response.metrics?.trainingLoad != nil ? "✓" : "✗")")

            await MainActor.run {
                self.readinessData = response
                self.lastSyncTime = Date()
                self.syncError = nil
                if showLoading {
                    self.isLoading = false
                }
            }

            // Save to cache
            storage.saveReadinessData(response)

            print("[TrainingReadinessManager] 💾 已儲存到緩存")
            print("[TrainingReadinessManager] ✅ 刷新完成")

        } catch {
            // Use standardized isCancellationError extension for consistency
            if error.isCancellationError {
                print("[TrainingReadinessManager] 任務被取消，忽略錯誤")
                return
            }

            // Handle real errors
            await MainActor.run {
                self.syncError = error.localizedDescription
                if showLoading {
                    self.isLoading = false
                }
            }

            print("[TrainingReadinessManager] 載入失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Listen for workout updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWorkoutUpdate),
            name: .workoutsDidUpdate,
            object: nil
        )

        // Listen for user data changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDataUpdate),
            name: .userDataDidUpdate,
            object: nil
        )
    }

    @objc private func handleWorkoutUpdate() {
        Task {
            await backgroundRefresh()
        }
    }

    @objc private func handleUserDataUpdate() {
        Task {
            await backgroundRefresh()
        }
    }
}

// MARK: - Computed Properties
extension TrainingReadinessManager {

    /// Check if data is available
    var hasData: Bool {
        return readinessData?.hasData ?? false
    }

    /// Get overall score (nil-safe)
    var overallScore: Double? {
        return readinessData?.overallScore
    }

    /// Get metrics (nil-safe)
    var metrics: TrainingReadinessMetrics? {
        return readinessData?.metrics
    }

    /// Cache status description
    var cacheStatusDescription: String {
        return storage.cacheStatusDescription
    }

    /// Should show empty state
    var shouldShowEmptyState: Bool {
        return !isLoading && readinessData == nil
    }

    /// Data status description for UI
    var dataStatusDescription: String {
        if isLoading {
            return "載入中..."
        } else if let error = syncError {
            return "載入失敗: \(error)"
        } else if !hasData {
            return "暫無訓練準備度數據"
        } else {
            return "準備度分析完成"
        }
    }
}
