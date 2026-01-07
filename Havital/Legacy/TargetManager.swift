import Foundation
import Combine

// ⚠️ DEPRECATED - 此檔案已被 Clean Architecture 重構取代
// 請使用: Features/Target/Presentation/ViewModels/TargetFeatureViewModel.swift
//
// ✅ 遷移狀態：
//   - TrainingPlanOverviewDetailView.swift → TargetFeatureViewModel
//
// 此檔案可在下一次清理時安全刪除

/// Target Manager - 實現雙軌緩存策略（Cache-First with Background Refresh）
/// 遵循 CLAUDE.md 架構原則
@available(*, deprecated, message: "Use TargetFeatureViewModel from Features/Target instead")
@MainActor
class TargetManager: ObservableObject, @preconcurrency TaskManageable {
    // MARK: - Published Properties
    @Published var targets: [Target] = []
    @Published var mainTarget: Target?
    @Published var supportingTargets: [Target] = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Task Management
    let taskRegistry = TaskRegistry()

    // MARK: - Dependencies
    private let repository: TargetRepository
    private let storage: TargetStorage

    // MARK: - Singleton
    static let shared = TargetManager()

    private init(
        repository: TargetRepository = DependencyContainer.shared.resolve(),
        storage: TargetStorage = .shared
    ) {
        self.repository = repository
        self.storage = storage
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - 雙軌緩存：載入所有賽事

    /// 載入所有賽事（雙軌策略）
    /// 軌道 A: 立即顯示緩存
    /// 軌道 B: 背景更新
    func loadTargets() async {
        await executeTask(id: TaskID("load_targets")) { [weak self] in
            guard let self = self else { return }

            // 軌道 A: 立即顯示緩存（同步）
            let cachedTargets = self.storage.getTargets()
            if !cachedTargets.isEmpty {
                Logger.debug("📦 [TargetManager] 立即顯示緩存: \(cachedTargets.count) 個賽事")
                await self.updateTargetsState(cachedTargets)
            }

            // 軌道 B: 背景更新（非同步）
            Task.detached { [weak self] in
                await self?.executeTask(id: TaskID("background_refresh_targets")) {
                    await self?.refreshTargetsInBackground()
                }
            }
        }
    }

    /// 背景更新賽事數據
    private func refreshTargetsInBackground() async {
        do {
            Logger.debug("🔄 [TargetManager] 背景更新賽事資料...")
            let latestTargets = try await repository.getTargets()

            // 保存到緩存
            storage.saveTargets(latestTargets)
            Logger.debug("💾 [TargetManager] 已更新緩存: \(latestTargets.count) 個賽事")

            // 更新 UI
            await updateTargetsState(latestTargets)
        } catch {
            // 背景更新失敗不影響已顯示的緩存
            Logger.debug("⚠️ [TargetManager] 背景更新失敗，保持現有緩存: \(error.localizedDescription)")
        }
    }

    /// 更新 UI 狀態
    private func updateTargetsState(_ newTargets: [Target]) async {
        await MainActor.run {
            self.targets = newTargets
            self.mainTarget = newTargets.first { $0.isMainRace }
            self.supportingTargets = newTargets.filter { !$0.isMainRace }
            Logger.debug("✅ [TargetManager] UI 已更新: 主賽事=\(self.mainTarget?.name ?? "無"), 支援賽事=\(self.supportingTargets.count)")
        }
    }

    // MARK: - 強制刷新（無緩存）

    /// 強制從 API 重新載入（用於用戶主動刷新）
    func forceRefresh() async {
        await executeTask(id: TaskID("force_refresh_targets")) { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }

            defer {
                Task { @MainActor in
                    self.isLoading = false
                }
            }

            do {
                Logger.debug("🔄 [TargetManager] 強制刷新賽事資料...")
                let latestTargets = try await self.repository.getTargets()

                // 保存到緩存
                self.storage.saveTargets(latestTargets)

                // 更新 UI
                await self.updateTargetsState(latestTargets)

                Logger.debug("✅ [TargetManager] 強制刷新完成")
            } catch {
                Logger.error("❌ [TargetManager] 強制刷新失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }

    // MARK: - 載入單個賽事（雙軌）

    /// 載入特定賽事（雙軌策略）
    func loadTarget(id: String) async -> Target? {
        return await executeTask(id: TaskID("load_target_\(id)")) { [weak self] in
            guard let self = self else {
                throw SystemError.unknownError("Manager deallocated")
            }

            // 軌道 A: 立即從緩存讀取
            if let cachedTarget = self.storage.getTarget(id: id) {
                Logger.debug("📦 [TargetManager] 從緩存讀取賽事: \(cachedTarget.name)")

                // 軌道 B: 背景更新
                Task.detached { [weak self] in
                    await self?.refreshTargetInBackground(id: id)
                }

                return cachedTarget
            }

            // 沒有緩存時直接從 API 載入
            Logger.debug("🔄 [TargetManager] 從 API 載入賽事: \(id)")
            let target = try await self.repository.getTarget(id: id)
            self.storage.saveTarget(target)

            // 記錄錯誤到狀態（如果有的話會在 executeTask 的 catch 中處理）
            await MainActor.run {
                self.error = nil
            }

            return target
        }
    }

    /// 背景更新單個賽事
    private func refreshTargetInBackground(id: String) async {
        do {
            Logger.debug("🔄 [TargetManager] 背景更新賽事: \(id)")
            let latestTarget = try await repository.getTarget(id: id)
            storage.saveTarget(latestTarget)

            // 如果是當前顯示的賽事，更新 UI
            if latestTarget.isMainRace {
                await MainActor.run {
                    self.mainTarget = latestTarget
                }
            }

            Logger.debug("✅ [TargetManager] 背景更新賽事完成: \(latestTarget.name)")
        } catch {
            Logger.debug("⚠️ [TargetManager] 背景更新賽事失敗，保持現有緩存: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD 操作

    /// 創建新賽事
    func createTarget(_ target: Target) async throws -> Target {
        let result = await executeTask(id: TaskID("create_target")) { [weak self] in
            guard let self = self else { throw SystemError.unknownError("Manager deallocated") }

            Logger.debug("➕ [TargetManager] 創建新賽事: \(target.name)")

            let newTarget = try await self.repository.createTarget(target)

            // 保存到緩存
            self.storage.saveTarget(newTarget)

            // 重新載入所有賽事
            await self.loadTargets()

            Logger.debug("✅ [TargetManager] 賽事創建成功: \(newTarget.name)")
            return newTarget
        }

        guard let newTarget = result else {
            throw SystemError.unknownError("Failed to create target: task was cancelled or failed")
        }

        return newTarget
    }

    /// 更新賽事
    func updateTarget(id: String, target: Target) async throws -> Target {
        let result = await executeTask(id: TaskID("update_target_\(id)")) { [weak self] in
            guard let self = self else { throw SystemError.unknownError("Manager deallocated") }

            Logger.debug("✏️ [TargetManager] 更新賽事: \(id)")

            let updatedTarget = try await self.repository.updateTarget(id: id, target: target)

            // 保存到緩存
            self.storage.saveTarget(updatedTarget)

            // 重新載入所有賽事
            await self.loadTargets()

            Logger.debug("✅ [TargetManager] 賽事更新成功: \(updatedTarget.name)")
            return updatedTarget
        }

        guard let updatedTarget = result else {
            throw SystemError.unknownError("Failed to update target: task was cancelled or failed")
        }

        return updatedTarget
    }

    /// 刪除賽事
    func deleteTarget(id: String) async throws {
        let result = await executeTask(id: TaskID("delete_target_\(id)")) { [weak self] in
            guard let self = self else { throw SystemError.unknownError("Manager deallocated") }

            Logger.debug("🗑️ [TargetManager] 刪除賽事: \(id)")

            try await self.repository.deleteTarget(id: id)

            // 從緩存移除
            self.storage.removeTarget(id: id)

            // 重新載入所有賽事
            await self.loadTargets()

            Logger.debug("✅ [TargetManager] 賽事刪除成功")
        }

        if result == nil {
            throw SystemError.unknownError("Failed to delete target: task was cancelled or failed")
        }
    }

    // MARK: - Helper Methods

    /// 獲取主賽事（從當前狀態）
    func getMainTarget() -> Target? {
        return mainTarget ?? storage.getMainTarget()
    }

    /// 獲取支援賽事（從當前狀態）
    func getSupportingTargets() -> [Target] {
        return supportingTargets.isEmpty ? storage.getSupportingTargets() : supportingTargets
    }

    /// 檢查是否有賽事
    func hasTargets() -> Bool {
        return !targets.isEmpty || storage.hasTargets()
    }
}
