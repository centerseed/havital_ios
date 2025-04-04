import Foundation

class TargetStorage {
    static let shared = TargetStorage()
    private let defaults = UserDefaults.standard
    
    private let targetsKey = "user_targets"
    private let mainTargetKey = "main_target"
    
    private init() {}
    
    // 保存單一目標
    func saveTarget(_ target: Target) {
        do {
            // 先檢查是否已有目標清單
            var targets = getTargets()
            
            // 查找是否已存在此目標
            if let index = targets.firstIndex(where: { $0.id == target.id }) {
                // 更新現有目標
                targets[index] = target
            } else {
                // 添加新目標
                targets.append(target)
            }
            
            // 保存更新後的目標清單
            saveTargets(targets)
            
            // 如果是主要目標，則更新主要目標
            if target.isMainRace {
                saveMainTarget(target)
            }
        }
    }
    
    // 保存目標陣列
    func saveTargets(_ targets: [Target]) {
        do {
            let data = try JSONEncoder().encode(targets)
            defaults.set(data, forKey: targetsKey)
            defaults.synchronize()
            
            // 找出並更新主要目標
            if let mainTarget = targets.first(where: { $0.isMainRace }) {
                saveMainTarget(mainTarget)
            }
        } catch {
            print("保存目標清單失敗: \(error)")
        }
    }
    
    // 保存主要目標
    func saveMainTarget(_ target: Target) {
        do {
            let data = try JSONEncoder().encode(target)
            defaults.set(data, forKey: mainTargetKey)
            defaults.synchronize()
        } catch {
            print("保存主要目標失敗: \(error)")
        }
    }
    
    // 獲取所有目標
    func getTargets() -> [Target] {
        guard let data = defaults.data(forKey: targetsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([Target].self, from: data)
        } catch {
            print("獲取目標清單失敗: \(error)")
            return []
        }
    }
    
    // 獲取主要目標
    func getMainTarget() -> Target? {
        guard let data = defaults.data(forKey: mainTargetKey) else {
            // 如果沒有主要目標，嘗試從所有目標中找出主要目標
            let targets = getTargets()
            if let mainTarget = targets.first(where: { $0.isMainRace }) {
                saveMainTarget(mainTarget)
                return mainTarget
            }
            return nil
        }
        
        do {
            return try JSONDecoder().decode(Target.self, from: data)
        } catch {
            print("獲取主要目標失敗: \(error)")
            return nil
        }
    }
    
    // 獲取特定目標
    func getTarget(id: String) -> Target? {
        let targets = getTargets()
        return targets.first { $0.id == id }
    }
    
    // 移除特定目標
    func removeTarget(id: String) {
        var targets = getTargets()
        targets.removeAll { $0.id == id }
        
        // 重新保存更新後的目標清單
        saveTargets(targets)
        
        // 如果移除的是主要目標，清除主要目標
        if let mainTarget = getMainTarget(), mainTarget.id == id {
            defaults.removeObject(forKey: mainTargetKey)
            
            // 嘗試從剩餘目標中找出新的主要目標
            if let newMainTarget = targets.first(where: { $0.isMainRace }) {
                saveMainTarget(newMainTarget)
            }
        }
    }
    
    // 清除所有目標
    func clearAllTargets() {
        defaults.removeObject(forKey: targetsKey)
        defaults.removeObject(forKey: mainTargetKey)
        defaults.synchronize()
    }
    
    // 檢查是否有目標
    func hasTargets() -> Bool {
        return !getTargets().isEmpty
    }
    
    // 檢查是否有主要目標
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
}
