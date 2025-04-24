import Foundation
import SwiftUI

@MainActor
class EditSupportingTargetViewModel: BaseSupportingTargetViewModel {
    @Published var showDeleteConfirmation = false
    private let targetId: String
    
    init(target: Target) {
        self.targetId = target.id
        super.init()
        
        // 從現有目標中加載數據
        self.raceName = target.name
        self.raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        
        // 設置距離
        if let distanceStr = availableDistances.keys.first(where: { Int(Double($0) ?? 0) == target.distanceKm }) {
            self.selectedDistance = distanceStr
        }
        
        // 設置目標時間
        self.targetHours = target.targetTime / 3600
        self.targetMinutes = (target.targetTime % 3600) / 60
    }
    
    func updateTarget() async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // 使用基礎類的方法創建 Target 對象
            let target = createTargetObject(id: targetId)
            
            // 更新賽事於雲端
            let updated = try await TargetService.shared.updateTarget(id: targetId, target: target)
            // 同步本地儲存並通知更新
            TargetStorage.shared.saveTarget(updated)
            NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
            print("支援賽事已更新並同步本地: \(updated.name)")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            print("更新支援賽事失敗: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    func deleteTarget() async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // 刪除目標賽事
            try await TargetService.shared.deleteTarget(id: targetId)
            print("支援賽事已刪除")
            isLoading = false
            return true
        } catch let nsError as NSError where nsError.domain == "APIClient" && nsError.code == 404 {
            // 雲端已不存在，從本地也刪除
            TargetStorage.shared.removeTarget(id: targetId)
            NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
            print("支援賽事在雲端不存在，本地已刪除")
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            print("刪除支援賽事失敗: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
}
