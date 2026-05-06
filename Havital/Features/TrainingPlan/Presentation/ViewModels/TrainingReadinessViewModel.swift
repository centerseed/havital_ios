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

    // MARK: - Plan Type Fallback
    /// Injected provider for fallback plan type when readiness doc lacks plan_type (V1 docs).
    /// Defaults to nil; callers should wire DependencyContainer.shared.resolve() at construction.
    var planOverviewProvider: (() -> PlanOverviewV2?)? = nil

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

    /// Effective plan type for conditional UI display.
    /// Fallback chain:
    ///   1. readinessData?.planType  (V2 doc — direct field)
    ///   2. planOverviewProvider()?.targetType  (V1 fallback via PlanOverviewV2)
    ///   3. .unknown  (default: show everything — conservative strategy)
    var effectivePlanType: ReadinessPlanType {
        if let pt = readinessData?.planType {
            return ReadinessPlanType(from: pt)
        }
        if let targetType = planOverviewProvider?()?.targetType {
            return ReadinessPlanType(from: targetType)
        }
        return .unknown
    }

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
        return metrics?.speed
    }

    /// Endurance metric (nil-safe)
    var enduranceMetric: EnduranceMetric? {
        return metrics?.endurance
    }

    /// Race fitness metric (nil-safe)
    var raceFitnessMetric: RaceFitnessMetric? {
        return metrics?.raceFitness
    }

    /// Training load metric (nil-safe)
    var trainingLoadMetric: TrainingLoadMetric? {
        return metrics?.trainingLoad
    }

    /// Recovery metric (nil-safe)
    var recoveryMetric: RecoveryMetric? {
        return metrics?.recovery
    }

    /// Estimated race time from race fitness metric (nil-safe)
    var estimatedRaceTime: String? {
        return raceFitnessMetric?.estimatedRaceTime
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
