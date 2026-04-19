import Foundation
import Observation

// MARK: - MethodologyCoordinator

/// Coordinator for methodology loading and switching.
/// Cross-boundary state is accessed exclusively through injected closures — no direct parent reference.
@MainActor
@Observable
final class MethodologyCoordinator {

    // MARK: - Observable State

    var availableMethodologies: [MethodologyV2] = []

    // MARK: - Dependencies

    @ObservationIgnored private let repository: TrainingPlanV2Repository
    @ObservationIgnored private let currentTargetType: () -> String?
    @ObservationIgnored private let currentOverviewId: () -> String?
    @ObservationIgnored private let onMethodologyChanged: (PlanOverviewV2) async -> Void
    @ObservationIgnored private let onPaywallNeeded: () -> Void
    @ObservationIgnored private let onNetworkError: (Error) -> Void

    // MARK: - Init

    init(
        repository: TrainingPlanV2Repository,
        currentTargetType: @escaping () -> String?,
        currentOverviewId: @escaping () -> String?,
        onMethodologyChanged: @escaping (PlanOverviewV2) async -> Void,
        onPaywallNeeded: @escaping () -> Void,
        onNetworkError: @escaping (Error) -> Void
    ) {
        self.repository = repository
        self.currentTargetType = currentTargetType
        self.currentOverviewId = currentOverviewId
        self.onMethodologyChanged = onMethodologyChanged
        self.onPaywallNeeded = onPaywallNeeded
        self.onNetworkError = onNetworkError
    }

    // MARK: - Public Methods

    func loadMethodologies() async {
        Logger.debug("[MethodologyCoordinator] 載入可用方法論列表...")
        do {
            let methodologies = try await repository.getMethodologies(targetType: currentTargetType())
            self.availableMethodologies = methodologies
            Logger.info("[MethodologyCoordinator] ✅ 載入 \(methodologies.count) 個方法論")
        } catch {
            Logger.error("[MethodologyCoordinator] ❌ 載入方法論失敗: \(error.localizedDescription)")
        }
    }

    func changeMethodology(methodologyId: String, startFromStage: String? = nil) async {
        Logger.debug("[MethodologyCoordinator] 切換方法論: \(methodologyId), 起始階段: \(startFromStage ?? "nil")")

        guard let overviewId = currentOverviewId() else {
            Logger.error("[MethodologyCoordinator] ❌ 無法切換方法論：overview ID 為 nil")
            return
        }

        do {
            let updatedOverview = try await repository.updateOverview(
                overviewId: overviewId,
                startFromStage: startFromStage,
                methodologyId: methodologyId
            )
            await onMethodologyChanged(updatedOverview)
            Logger.info("[MethodologyCoordinator] ✅ 方法論已切換至: \(methodologyId)")
        } catch {
            let domainError = error.toDomainError()
            switch domainError {
            case .subscriptionRequired, .trialExpired, .forbidden:
                onPaywallNeeded()
            default:
                Logger.error("[MethodologyCoordinator] ❌ 切換方法論失敗: \(domainError.localizedDescription)")
                onNetworkError(domainError)
            }
        }
    }
}
