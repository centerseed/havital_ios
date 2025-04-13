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
            print("支援賽事已建立: \(createdTarget.name)")
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
