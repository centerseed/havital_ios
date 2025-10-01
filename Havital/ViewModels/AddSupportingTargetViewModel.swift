import Foundation
import SwiftUI

@MainActor
class AddSupportingTargetViewModel: BaseSupportingTargetViewModel {

    func createTarget() async -> Bool {
        isLoading = true
        error = nil

        do {
            // 使用基礎類的方法創建 Target 對象
            let target = createTargetObject(id: UUID().uuidString) // 臨時ID，實際會由API返回

            // 創建目標賽事
            let createdTarget = try await TargetService.shared.createTarget(target)
            // 存儲到本地，以便後續顯示
            TargetStorage.shared.saveTarget(createdTarget)
            print("支援賽事已建立並保存: \(createdTarget.name)")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            print("建立支援賽事失敗: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
}
