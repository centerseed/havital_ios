import Foundation

class TargetStorage {
    static let shared = TargetStorage()
    private let defaults = UserDefaults.standard
    
    // 只保留一個鍵，用於儲存所有目標的陣列
    private let targetsKey = "user_targets_all" // 可以改個名字以示區別，或沿用舊名
    
    private init() {}
    
    // 保存單一目標到主列表
    func saveTarget(_ target: Target) {
        var targets = getTargets() // 獲取當前所有目標
        
        // 查找是否已存在此目標
        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            // 更新現有目標
            targets[index] = target
        } else {
            // 添加新目標
            targets.append(target)
        }
        
        // 保存更新後的完整列表
        saveTargets(targets)
        
        // 發送通知，表示目標數據已更新 (可以根據需要決定是否保留或修改通知邏輯)
        NotificationCenter.default.post(name: .targetUpdated, object: nil)
        if !target.isMainRace {
             NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
        }
    }
    
    // 保存目標陣列 (這是核心的保存方法)
    func saveTargets(_ targets: [Target]) {
        do {
            let data = try JSONEncoder().encode(targets)
            defaults.set(data, forKey: targetsKey)
            defaults.synchronize() // 確保立即寫入 UserDefaults (雖然通常不是絕對必要)
            
             // 發送通知，表示目標數據已更新
            NotificationCenter.default.post(name: .targetUpdated, object: nil)
            // 可選：如果需要區分主要和支援賽事更新，可以在此處添加更細緻的通知邏輯
             if targets.contains(where: { !$0.isMainRace }) {
                NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil)
             }

        } catch {
            print("保存目標清單失敗: \(error)")
        }
    }
    
    // (已移除) 不再需要單獨保存主要目標的方法
    // func saveMainTarget(_ target: Target) { ... }
    
    // 獲取所有目標
    func getTargets() -> [Target] {
        guard let data = defaults.data(forKey: targetsKey) else {
            return [] // 如果沒有數據，返回空陣列
        }
        
        do {
            // 從儲存的數據解碼回 [Target] 陣列
            return try JSONDecoder().decode([Target].self, from: data)
        } catch {
            print("獲取目標清單失敗: \(error)")
            return [] // 解碼失敗也返回空陣列
        }
    }
    
    // 獲取主要目標 (從所有目標中查找)
    func getMainTarget() -> Target? {
        let targets = getTargets()
        // 直接在所有目標中查找第一個 isMainRace 為 true 的目標
        return targets.first { $0.isMainRace }
    }
    
    // 獲取特定目標 (從所有目標中查找)
    func getTarget(id: String) -> Target? {
        let targets = getTargets()
        return targets.first { $0.id == id }
    }
    
    // 移除特定目標
    func removeTarget(id: String) {
        var targets = getTargets()
        let initialCount = targets.count
        targets.removeAll { $0.id == id }
        
        // 只有在實際移除了目標時才重新保存
        if targets.count < initialCount {
            saveTargets(targets) // 保存更新後的列表
            
            // 發送通知
            NotificationCenter.default.post(name: .targetUpdated, object: nil)
            // 如果你關心被移除的是否為支援賽事，可以在這裡檢查並發送 supportingTargetUpdated
            // (但通常移除就是更新，targetUpdated 可能就夠了)
        }
    }
    
    // 清除所有目標 (只需要移除一個鍵)
    func clearAllTargets() {
        defaults.removeObject(forKey: targetsKey)
        defaults.synchronize()
        // 發送通知
        NotificationCenter.default.post(name: .targetUpdated, object: nil)
        NotificationCenter.default.post(name: .supportingTargetUpdated, object: nil) // 清空也算支援賽事更新
    }
    
    // 檢查是否有目標
    func hasTargets() -> Bool {
        return !getTargets().isEmpty
    }
    
    // 檢查是否有主要目標 (基於查找結果)
    func hasMainTarget() -> Bool {
        return getMainTarget() != nil
    }
    
    // 獲取離當前日期最近的目標
    func getUpcomingTarget() -> Target? {
        let targets = getTargets()
        let now = Date().timeIntervalSince1970
        
        // 過濾出未來的目標，並按日期排序
        let upcomingTargets = targets
            .filter { $0.raceDate > Int(now) }
            .sorted { $0.raceDate < $1.raceDate }
            
        return upcomingTargets.first
    }
    
    // 獲取按日期排序的所有目標（由近到遠）
    func getSortedTargets() -> [Target] {
        let targets = getTargets()
        return targets.sorted { $0.raceDate < $1.raceDate }
    }
    
    // 獲取所有支援賽事（非主要賽事） (基於查找結果)
    func getSupportingTargets() -> [Target] {
        let targets = getTargets()
        return targets.filter { !$0.isMainRace }
    }
    
    // 獲取所有支援賽事，並按日期排序（由近到遠） (基於查找結果)
    func getSortedSupportingTargets() -> [Target] {
        let supportingTargets = getSupportingTargets()
        return supportingTargets.sorted { $0.raceDate < $1.raceDate }
    }
    
    // 檢查是否有支援賽事 (基於查找結果)
    func hasSupportingTargets() -> Bool {
        return !getSupportingTargets().isEmpty
    }
    
    // 獲取最近的支援賽事 (基於查找結果)
    func getUpcomingSupportingTarget() -> Target? {
        let now = Date().timeIntervalSince1970
        
        let upcomingTargets = getSupportingTargets()
            .filter { $0.raceDate > Int(now) }
            .sorted { $0.raceDate < $1.raceDate }
            
        return upcomingTargets.first
    }
}

// 擴充 Notification.Name (保持不變，除非你有新的通知需求)
extension Notification.Name {
    static let targetUpdated = Notification.Name("targetUpdated")
    static let supportingTargetUpdated = Notification.Name("supportingTargetUpdated") // 這個通知現在會在任何可能影響支援賽事列表的操作後發送
    static let garminDataSourceMismatch = Notification.Name("garminDataSourceMismatch") // 當後端數據源是 Garmin 但本地未連接時發送
}
