import Foundation
import SwiftUI

// MARK: - TargetFeatureViewModel
/// Clean Architecture ViewModel for Target feature
/// Replaces TargetManager.shared
///
/// Uses unified helpers:
/// - EventSubscriptionHelper for CacheEventBus subscriptions
/// - DualTrackCacheHelper (via Repository) for caching
@MainActor
class TargetFeatureViewModel: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - ViewModel Name (for logging)
    private let viewModelName = "TargetVM"

    // MARK: - Published State

    /// All targets
    @Published var targets: [Target] = []

    /// Main race target
    @Published var mainTarget: Target?

    /// Supporting targets (non-main races)
    @Published var supportingTargets: [Target] = []

    /// Loading state
    @Published var isLoading = false

    /// Error state
    @Published var error: Error?

    // MARK: - Convenience Properties

    /// Sorted supporting targets (by race date, ascending)
    var sortedSupportingTargets: [Target] {
        supportingTargets.sorted { $0.raceDate < $1.raceDate }
    }

    /// Check if any targets exist
    var hasTargets: Bool {
        !targets.isEmpty
    }

    /// Check if main target exists
    var hasMainTarget: Bool {
        mainTarget != nil
    }

    // MARK: - Task Management
    let taskRegistry = TaskRegistry()

    // MARK: - Dependencies
    private let repository: TargetRepository

    // MARK: - Initialization

    /// Primary initializer with dependency injection
    init(repository: TargetRepository) {
        self.repository = repository
        setupEventSubscriptions()
    }

    // MARK: - Event Subscriptions

    /// Setup CacheEventBus subscriptions using EventSubscriptionHelper
    private func setupEventSubscriptions() {
        // Subscribe to userLogout - clear state
        EventSubscriptionHelper.subscribeToUserLogout(viewModelName: viewModelName) { [weak self] in
            self?.repository.clearCache()
            self?.targets = []
            self?.mainTarget = nil
            self?.supportingTargets = []
            self?.error = nil
        }

        // Subscribe to onboardingCompleted - force refresh
        EventSubscriptionHelper.subscribeToOnboardingCompleted(viewModelName: viewModelName) { [weak self] in
            self?.repository.clearCache()
            await self?.forceRefresh()
        }

        // Subscribe to target data changes
        EventSubscriptionHelper.subscribeToDataChanged(dataType: .targets, viewModelName: viewModelName) { [weak self] in
            await self?.loadTargets()
        }
    }

    /// Convenience initializer for Views (uses DI Container)
    convenience init() {
        self.init(repository: DependencyContainer.shared.resolve())
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Load Operations

    /// Load all targets with dual-track caching
    func loadTargets() async {
        await executeTask(id: TaskID("load_targets")) { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }

            do {
                let loadedTargets = try await self.repository.getTargets()
                await MainActor.run {
                    self.updateTargetsState(loadedTargets)
                }
            } catch {
                // Use centralized cancellation check
                if error.isCancellationError {
                    Logger.debug("[TargetVM] Task cancelled, ignoring error")
                } else {
                    await MainActor.run {
                        self.error = error
                    }
                    Logger.error("[TargetVM] Error: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    /// Load single target by ID
    func loadTarget(id: String) async -> Target? {
        do {
            return try await repository.getTarget(id: id)
        } catch {
            if error.isCancellationError {
                Logger.debug("[TargetVM] Task cancelled, ignoring error")
                return nil
            }
            self.error = error
            Logger.error("[TargetVM] Error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Refresh Operations

    /// Force refresh all targets from API
    func forceRefresh() async {
        await executeTask(id: TaskID("force_refresh_targets")) { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }

            do {
                let refreshedTargets = try await self.repository.forceRefresh()
                await MainActor.run {
                    self.updateTargetsState(refreshedTargets)
                }
                Logger.debug("[TargetVM] Force refresh complete")
            } catch {
                // Use centralized cancellation check
                if error.isCancellationError {
                    Logger.debug("[TargetVM] Task cancelled, ignoring error")
                } else {
                    await MainActor.run {
                        self.error = error
                    }
                    Logger.error("[TargetVM] Error: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    // MARK: - CRUD Operations

    /// Create new target
    func createTarget(_ target: Target) async throws -> Target {
        let result = await executeTask(id: TaskID("create_target")) { [weak self] in
            guard let self = self else {
                throw TargetError.operationFailed("ViewModel deallocated")
            }

            await MainActor.run { self.isLoading = true }

            defer {
                Task { @MainActor in self.isLoading = false }
            }

            let createdTarget = try await self.repository.createTarget(target)

            // Reload targets to update state
            await self.loadTargets()

            Logger.debug("[TargetVM] Target created: \(createdTarget.name)")
            return createdTarget
        }

        guard let newTarget = result else {
            throw TargetError.createFailed(reason: "Task was cancelled")
        }

        return newTarget
    }

    /// Update existing target
    func updateTarget(id: String, target: Target) async throws -> Target {
        let result = await executeTask(id: TaskID("update_target_\(id)")) { [weak self] in
            guard let self = self else {
                throw TargetError.operationFailed("ViewModel deallocated")
            }

            await MainActor.run { self.isLoading = true }

            defer {
                Task { @MainActor in self.isLoading = false }
            }

            let updatedTarget = try await self.repository.updateTarget(id: id, target: target)

            // Reload targets to update state
            await self.loadTargets()

            Logger.debug("[TargetVM] Target updated: \(updatedTarget.name)")
            return updatedTarget
        }

        guard let updated = result else {
            throw TargetError.updateFailed(reason: "Task was cancelled")
        }

        return updated
    }

    /// Delete target
    func deleteTarget(id: String) async throws {
        await executeTask(id: TaskID("delete_target_\(id)")) { [weak self] in
            guard let self = self else {
                throw TargetError.operationFailed("ViewModel deallocated")
            }

            await MainActor.run { self.isLoading = true }

            defer {
                Task { @MainActor in self.isLoading = false }
            }

            try await self.repository.deleteTarget(id: id)

            // Reload targets to update state
            await self.loadTargets()

            Logger.debug("[TargetVM] Target deleted: \(id)")
        }
    }

    // MARK: - Helper Methods

    /// Get main target synchronously (from current state or cache)
    func getMainTarget() -> Target? {
        return mainTarget ?? TargetLocalDataSource().getMainTarget()
    }

    /// Get supporting targets synchronously
    func getSupportingTargets() -> [Target] {
        return supportingTargets.isEmpty ? TargetLocalDataSource().getSupportingTargets() : supportingTargets
    }

    /// Check if targets exist (including cache)
    func hasTargetsIncludingCache() -> Bool {
        return !targets.isEmpty || repository.hasCache()
    }

    // MARK: - Private Methods

    /// Update all target-related state
    /// Note: This is already on MainActor so no await needed
    private func updateTargetsState(_ newTargets: [Target]) {
        self.targets = newTargets
        self.mainTarget = newTargets.first { $0.isMainRace }
        self.supportingTargets = newTargets.filter { !$0.isMainRace }
        Logger.debug("[TargetVM] State updated: main=\(self.mainTarget?.name ?? "none"), supporting=\(self.supportingTargets.count)")
    }
}
