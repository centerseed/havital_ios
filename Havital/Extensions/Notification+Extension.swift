import Foundation

extension Notification.Name {
    /// Garmin 健康數據刷新通知
    static let garminHealthDataRefresh = Notification.Name("garminHealthDataRefresh")
    
    /// Apple Health 數據更新通知
    static let appleHealthDataRefresh = Notification.Name("appleHealthDataRefresh")
    
    /// 數據源切換通知
    static let dataSourceChanged = Notification.Name("dataSourceChanged")
}