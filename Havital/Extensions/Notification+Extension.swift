import Foundation

extension Notification.Name {
    // MARK: - Health Data Notifications
    /// Garmin 健康數據刷新通知
    static let garminHealthDataRefresh = Notification.Name("garminHealthDataRefresh")
    
    /// Strava 健康數據刷新通知
    static let stravaHealthDataRefresh = Notification.Name("stravaHealthDataRefresh")
    
    /// Apple Health 數據更新通知
    static let appleHealthDataRefresh = Notification.Name("appleHealthDataRefresh")
    
    /// 數據源切換通知
    static let dataSourceChanged = Notification.Name("dataSourceChanged")
    
    // MARK: - Standardized Data Update Notifications
    /// 訓練計劃數據更新
    static let trainingPlanDidUpdate = Notification.Name("trainingPlanDidUpdate")
    
    /// HRV 數據更新
    static let hrvDataDidUpdate = Notification.Name("hrvDataDidUpdate")
    
    /// VDOT 數據更新
    static let vdotDataDidUpdate = Notification.Name("vdotDataDidUpdate")
    
    /// 用戶數據更新
    static let userDataDidUpdate = Notification.Name("userDataDidUpdate")
    
    /// 運動記錄更新 (already exists, keeping for reference)
    static let workoutsDidUpdate = Notification.Name("workoutsDidUpdate")
    
    // MARK: - Cache Events
    /// 快取失效通知
    static let cacheDidInvalidate = Notification.Name("cacheDidInvalidate")
    
    /// 全域數據刷新
    static let globalDataRefresh = Notification.Name("globalDataRefresh")
}

// MARK: - Notification UserInfo Keys
extension String {
    static let dataTypeKey = "dataType"
    static let cacheIdentifierKey = "cacheIdentifier"
    static let errorKey = "error"
    static let sourceKey = "source"
}