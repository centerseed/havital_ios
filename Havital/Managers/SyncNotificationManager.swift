import Foundation
import UserNotifications

// 將這個類添加到您的專案中，用於集中管理所有與訓練數據同步相關的通知
class SyncNotificationManager {
    static let shared = SyncNotificationManager()
    
    // 是否已經顯示了批量同步開始的通知
    private var hasShownBulkSyncStartNotification = false
    
    // 是否正在進行大量上傳
    private var isBulkSyncInProgress = false
    
    // 上次發送通知的時間
    private var lastNotificationTime: Date?
    
    // 累計上傳成功的記錄數
    private var totalSuccessCount = 0
    
    // 通知的冷卻時間（秒）
    private let notificationCooldown: TimeInterval = 30
    
    private init() {}
    
    // 重置通知狀態（例如在用戶登出時）
    func reset() {
        hasShownBulkSyncStartNotification = false
        isBulkSyncInProgress = false
        lastNotificationTime = nil
        totalSuccessCount = 0
    }
    
    // 開始批量同步
    func startBulkSync(count: Int) async {
        // 批量同步邏輯
        isBulkSyncInProgress = true
        
        // 避免重複發送開始通知
        if !hasShownBulkSyncStartNotification {
            await sendSyncStartNotification(count: count)
            hasShownBulkSyncStartNotification = true
        }
    }
    
    // 記錄成功上傳
    func recordSuccess(count: Int) {
        totalSuccessCount += count
    }
    
    // 結束批量同步，發送結果通知
    func endBulkSync() async {
        // 確保只在真正有上傳成功的情況下發送通知
        if totalSuccessCount > 0 {
            await sendSyncCompletionNotification(count: totalSuccessCount)
        }
        
        // 重置狀態
        isBulkSyncInProgress = false
        hasShownBulkSyncStartNotification = false
        totalSuccessCount = 0
    }
    
    // 正常同步完成（非批量）
    func notifySyncCompletion(count: Int) async {
        // 如果正在進行批量同步，只累計數量而不發送通知
        if isBulkSyncInProgress {
            totalSuccessCount += count
            return
        }
        
        // 檢查是否應該發送通知（避免頻繁通知）
        if shouldSendNotification() {
            await sendSyncCompletionNotification(count: count)
        }
    }
    
    // 決定是否應該發送通知
    private func shouldSendNotification() -> Bool {
        guard let lastTime = lastNotificationTime else {
            // 如果從未發送過通知，允許發送
            lastNotificationTime = Date()
            return true
        }
        
        let timeElapsed = Date().timeIntervalSince(lastTime)
        if timeElapsed > notificationCooldown {
            // 如果距離上次通知時間超過冷卻時間，允許發送
            lastNotificationTime = Date()
            return true
        }
        
        // 否則不發送
        return false
    }
    
    // 發送同步開始通知
    private func sendSyncStartNotification(count: Int) async {
        // 先移除所有現有的同步通知
        removeAllSyncNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "開始同步訓練數據"
        content.body = "正在同步 \(count) 條訓練記錄，完成後將通知您"
        content.sound = .default
        
        // 使用固定的識別符
        let request = UNNotificationRequest(
            identifier: "sync-training-data-start",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            lastNotificationTime = Date()
        } catch {
            print("發送開始同步通知失敗: \(error)")
        }
    }
    
    // 發送同步完成通知
    private func sendSyncCompletionNotification(count: Int) async {
        // 先移除所有現有的同步通知
        removeAllSyncNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "訓練數據同步完成"
        content.body = "已成功同步 \(count) 條訓練記錄"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "sync-training-data-completion",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            lastNotificationTime = Date()
        } catch {
            print("發送同步完成通知失敗: \(error)")
        }
    }
    
    // 移除所有同步相關的通知
    private func removeAllSyncNotifications() {
        let center = UNUserNotificationCenter.current()
        let identifiers = ["sync-training-data-start", "sync-training-data-completion"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
