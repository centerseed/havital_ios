import Combine
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

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

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

    /// Subscribe to plan overview updates so that a plan-type change forces a readiness re-fetch.
    /// Called externally after DI setup (e.g. from the app bootstrap or a coordinator).
    func subscribeToOverviewUpdates(repo: any TrainingPlanV2Repository) {
        repo.overviewDidUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.forceRefresh()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Public Methods

    /// Initialize and load data
    func initialize() async {
        Logger.debug("[TrainingReadinessManager] 初始化")

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
        Logger.debug("[TrainingReadinessManager] force refresh started")
        await executeTask(id: TaskID("force_refresh_readiness")) { [weak self] in
            guard let self = self else { return }

            // Clear cache to ensure fresh API data
            await MainActor.run {
                self.storage.clearReadinessData()
                Logger.debug("[TrainingReadinessManager] local cache cleared")
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
        Logger.debug("[TrainingReadinessManager] all data cleared")
    }

    // MARK: - Private Methods

    /// Load data from local cache
    private func loadLocalData() {
        if let cachedData = storage.loadReadinessData() {
            readinessData = cachedData
            lastSyncTime = storage.getLastFetchTime()
            Logger.debug("[TrainingReadinessManager] loaded from cache")
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
            Logger.debug("[TrainingReadinessManager] calling API: forceCalculate=\(forceCalculate)")
            let response = try await APICallTracker.$currentSource.withValue("TrainingReadinessManager: fetchFromAPI") {
                try await service.getTodayReadiness(forceCalculate: forceCalculate)
            }

            Logger.debug("[TrainingReadinessManager] API success: overallScore=\(response.overallScore ?? 0), planType=\(response.planType ?? "nil")")

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

            Logger.debug("[TrainingReadinessManager] saved to cache, refresh complete")

        } catch {
            // Use standardized isCancellationError extension for consistency
            if error.isCancellationError {
                Logger.debug("[TrainingReadinessManager] task cancelled, ignoring")
                return
            }

            // Handle real errors
            await MainActor.run {
                self.syncError = error.localizedDescription
                if showLoading {
                    self.isLoading = false
                }
            }

            Logger.error("[TrainingReadinessManager] load failed: \(error.localizedDescription)")
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
