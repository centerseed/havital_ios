import Foundation

// MARK: - 快取管理協議
protocol Cacheable: AnyObject {
    /// 快取的唯一識別符
    var cacheIdentifier: String { get }
    
    /// 清空快取
    func clearCache()
    
    /// 獲取快取大小（位元組）
    func getCacheSize() -> Int
    
    /// 檢查快取是否過期
    func isExpired() -> Bool
}

// MARK: - 快取事件監聽協議
protocol CacheEventListener: AnyObject {
    func onCacheInvalidated(for identifier: String, reason: CacheInvalidationReason)
}

// MARK: - 快取失效原因
enum CacheInvalidationReason: Hashable {
    case userLogout
    case dataChanged(DataType)
    case manualClear
    case expired
    case onboardingCompleted      // 新用戶 Onboarding 完成，需清除舊緩存並強制刷新
    case reonboardingCompleted    // Re-onboarding 完成，通知 UI 關閉 sheet
    case weekChanged              // 跨週事件：App 從背景恢復時發現已跨週，需更新 selectedWeek
    /// 公制／英制切換（T-0366）。**不清任何快取**——資料沒變，變的是要用哪個單位畫。
    /// 存在的理由：課表日卡的「課表」行、詳情頁的配速帶、目標卡的賽距這些字串是
    /// **投影時就組好存起來的**，View 再怎麼觀察 `UnitManager` 也不會重算它們。
    case unitSystemChanged
}

// MARK: - 資料類型
enum DataType: Hashable {
    case workouts
    case trainingPlan
    case trainingPlanV2
    case weeklySummary
    case targets
    case user
    case healthData
    case hrv
    case vdot
}