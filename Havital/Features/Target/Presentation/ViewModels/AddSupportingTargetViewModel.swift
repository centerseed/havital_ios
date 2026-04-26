import Foundation
import SwiftUI

@MainActor
class AddSupportingTargetViewModel: BaseSupportingTargetViewModel {

    // MARK: - Dependencies (Clean Architecture)
    private let targetRepository: TargetRepository

    // MARK: - S07 Inline Upsell State (AC-PAYWALL-24)
    /// True when user has no premium access. Set on onAppear so the upsell card
    /// shows immediately on screen entry, not only after tapping Save.
    var showTargetRaceInlineUpsell: Bool = false

    init(targetRepository: TargetRepository = DependencyContainer.shared.resolve()) {
        self.targetRepository = targetRepository
        super.init()
    }

    func checkSubscriptionAccess() {
        let subscriptionManager = SubscriptionStateManager.shared
        if subscriptionManager.isEnforcementEnabled,
           !subscriptionManager.hasPremiumAccess {
            showTargetRaceInlineUpsell = true
            Logger.debug("[AddSupportingTargetVM] ⛔ 進入畫面：無 premium access，顯示 target_race inline upsell card")
        }
    }

    func createTarget() async -> Bool {
        // Defense-in-depth: re-check subscription in case onAppear check was bypassed.
        let subscriptionManager = SubscriptionStateManager.shared
        if subscriptionManager.isEnforcementEnabled,
           !subscriptionManager.hasPremiumAccess {
            showTargetRaceInlineUpsell = true
            return false
        }

        isLoading = true
        error = nil

        do {
            // 使用基礎類的方法創建 Target 對象
            let target = createTargetObject(id: UUID().uuidString) // 臨時ID，實際會由API返回

            // 創建目標賽事 (Clean Architecture: ViewModel → Repository)
            let createdTarget = try await targetRepository.createTarget(target)
            // 存儲到本地，以便後續顯示
            TargetStorage.shared.saveTarget(createdTarget)
            Logger.debug("[AddSupportingTargetVM] 支援賽事已建立並保存: \(createdTarget.name)")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            Logger.error("[AddSupportingTargetVM] 建立支援賽事失敗: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
}
