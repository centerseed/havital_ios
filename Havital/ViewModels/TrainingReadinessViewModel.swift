import Foundation
import SwiftUI
import Combine

/// Training Readiness ViewModel
@MainActor
class TrainingReadinessViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var readinessData: TrainingReadinessResponse?
    @Published var syncError: String?
    @Published var lastSyncTime: Date?

    // MARK: - Dependencies
    private let manager: TrainingReadinessManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(manager: TrainingReadinessManager = .shared) {
        self.manager = manager

        // Sync initial state
        syncManagerState()

        // Observe manager changes
        setupObservers()
    }

    // MARK: - Public Methods

    /// Load data
    func loadData() async {
        await manager.loadData()
        syncManagerState()
    }

    /// Refresh data
    func refreshData() async {
        await manager.refreshData()
        syncManagerState()
    }

    /// Force refresh with recalculation
    func forceRefresh() async {
        await manager.forceRefresh()
        syncManagerState()
    }

    // MARK: - Private Methods

    /// Sync state from manager to viewmodel
    private func syncManagerState() {
        isLoading = manager.isLoading
        readinessData = manager.readinessData
        syncError = manager.syncError
        lastSyncTime = manager.lastSyncTime
    }

    /// Setup observers for manager changes
    private func setupObservers() {
        // Observe manager's published properties
        // This ensures UI updates when manager state changes

        manager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isLoading = newValue
            }
            .store(in: &cancellables)

        manager.$readinessData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.readinessData = newValue
            }
            .store(in: &cancellables)

        manager.$syncError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.syncError = newValue
            }
            .store(in: &cancellables)

        manager.$lastSyncTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.lastSyncTime = newValue
            }
            .store(in: &cancellables)
    }
}

// MARK: - Computed Properties for UI
extension TrainingReadinessViewModel {

    /// Overall score (nil-safe)
    var overallScore: Double? {
        return readinessData?.overallScore
    }

    /// Overall score formatted
    var overallScoreFormatted: String {
        guard let score = overallScore else { return "--" }
        return String(format: "%.0f", score)
    }

    /// Metrics (nil-safe)
    var metrics: TrainingReadinessMetrics? {
        return readinessData?.metrics
    }

    /// Check if data exists
    var hasData: Bool {
        return readinessData?.hasData ?? false
    }

    /// Check if at least one metric exists
    var hasAnyMetric: Bool {
        return metrics?.hasAnyMetric ?? false
    }

    /// Should show empty state
    var shouldShowEmptyState: Bool {
        return !isLoading && !hasData
    }

    /// Data status description
    var dataStatusDescription: String {
        if isLoading {
            return NSLocalizedString("common.loading", comment: "")
        } else if let error = syncError {
            return error
        } else if !hasData {
            return NSLocalizedString("training_readiness.no_data", comment: "")
        } else {
            return NSLocalizedString("training_readiness.data_ready", comment: "")
        }
    }

    /// Last updated description
    var lastUpdatedDescription: String {
        guard let lastSync = lastSyncTime else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: lastSync)
    }

    // ✅ New: Overall status text (雙行狀態描述)
    var overallStatusText: String? {
        return readinessData?.overallStatusText
    }

    // ✅ New: Last updated time from API (e.g., "10:30 更新")
    var lastUpdatedTime: String? {
        return readinessData?.lastUpdatedTime
    }

    /// Get overall status lines (split by \n)
    var overallStatusLines: [String] {
        guard let text = overallStatusText else { return [] }
        return text.split(separator: "\n").map { String($0) }
    }
}

// MARK: - Metric Helpers
extension TrainingReadinessViewModel {

    /// Speed metric (nil-safe)
    var speedMetric: SpeedMetric? {
        let metric = metrics?.speed
        if let metric = metric {
            print("[TrainingReadinessViewModel] 🏃 速度指標載入: score=\(metric.score)")
        }
        return metric
    }

    /// Endurance metric (nil-safe)
    var enduranceMetric: EnduranceMetric? {
        let metric = metrics?.endurance
        if let metric = metric {
            print("[TrainingReadinessViewModel] 💪 耐力指標載入: score=\(metric.score)")
        }
        return metric
    }

    /// Race fitness metric (nil-safe)
    var raceFitnessMetric: RaceFitnessMetric? {
        let metric = metrics?.raceFitness
        if let metric = metric {
            print("[TrainingReadinessViewModel] 🏁 比賽適能指標載入: score=\(metric.score)")
        }
        return metric
    }

    /// Training load metric (nil-safe)
    var trainingLoadMetric: TrainingLoadMetric? {
        let metric = metrics?.trainingLoad
        if let metric = metric {
            print("[TrainingReadinessViewModel] 📊 訓練負荷指標載入: score=\(metric.score)")
        }
        return metric
    }

    /// Recovery metric (nil-safe)
    var recoveryMetric: RecoveryMetric? {
        return metrics?.recovery
    }

    /// Format score
    func formatScore(_ score: Double?) -> String {
        guard let score = score else { return "--" }
        return String(format: "%.0f", score)
    }

    /// Format percentage
    func formatPercentage(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        return String(format: "%.1f%%", value)
    }

    /// Format TSB value
    func formatTSB(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        return String(format: "%.1f", value)
    }

    // ✅ New: Get status text lines (split by \n) for any status_text field
    func getStatusLines(_ statusText: String?) -> [String] {
        guard let text = statusText else { return [] }
        return text.split(separator: "\n").map { String($0) }
    }
}
