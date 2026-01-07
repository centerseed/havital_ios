import Foundation
import SwiftUI

// MARK: - 基礎數據 ViewModel
/// 為所有數據 ViewModel 提供標準化的基礎實現
/// 遵循 UnifiedWorkoutManager 的最佳實踐模式
@MainActor
class BaseDataViewModel<DataType: Codable, ManagerType: DataManageable>: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var data: [DataType] = []
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    // MARK: - Dependencies
    let manager: ManagerType
    
    // MARK: - Notification Observers
    var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    init(manager: ManagerType) {
        self.manager = manager
        setupNotificationObservers()
    }
    
    deinit {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// 初始化數據載入
    func initialize() async {
        await manager.initialize()
        await loadData()
    }
    
    /// 載入數據
    func loadData() async {
        isLoading = true
        syncError = nil
        
        await manager.loadData()
        
        // 同步管理器狀態到 ViewModel
        isLoading = manager.isLoading
        lastSyncTime = manager.lastSyncTime
        syncError = manager.syncError
    }
    
    /// 刷新數據
    func refreshData() async {
        _ = await manager.refreshData()
        
        // 同步管理器狀態到 ViewModel
        isLoading = manager.isLoading
        lastSyncTime = manager.lastSyncTime
        syncError = manager.syncError
    }
    
    /// 清除所有數據
    func clearAllData() async {
        await manager.clearAllData()
        
        data = []
        lastSyncTime = nil
        syncError = nil
    }
    
    // MARK: - Notification Management
    
    /// 設置通知觀察者 - 子類應該重寫此方法來監聽特定的通知
    func setupNotificationObservers() {
        // 監聽全域數據刷新
        let globalRefreshObserver = NotificationCenter.default.addObserver(
            forName: .globalDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
        notificationObservers.append(globalRefreshObserver)
        
        // 監聽快取失效
        let cacheInvalidateObserver = NotificationCenter.default.addObserver(
            forName: .cacheDidInvalidate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 檢查是否影響當前數據類型
            if let cacheIdentifier = notification.userInfo?["cacheIdentifier"] as? String,
               cacheIdentifier == self.manager.cacheIdentifier {
                Task {
                    await self.refreshData()
                }
            }
        }
        notificationObservers.append(cacheInvalidateObserver)
    }
    
    
    // MARK: - Helper Methods
    
    /// 檢查是否有數據
    var hasData: Bool {
        return !data.isEmpty
    }
    
    /// 檢查是否需要刷新
    var shouldRefresh: Bool {
        return manager.isExpired()
    }
    
    /// 獲取快取狀態
    var cacheSize: Int {
        return manager.getCacheSize()
    }
}

// MARK: - Convenience Extensions
extension BaseDataViewModel {
    
    /// 執行帶有錯誤處理的非同步操作
    func executeWithErrorHandling(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            syncError = error.localizedDescription
            
            Logger.firebase(
                "ViewModel 操作失敗",
                level: .error,
                jsonPayload: [
                    "view_model": String(describing: type(of: self)),
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    /// 背景刷新（不顯示 loading 狀態）
    func backgroundRefresh() async where ManagerType: ObservableObject {
        await manager.backgroundRefresh()
        
        // 同步狀態但不顯示 loading
        lastSyncTime = manager.lastSyncTime
        if let error = manager.syncError {
            syncError = error
        }
    }
}