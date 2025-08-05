import Foundation

// MARK: - 統一數據管理協議
/// 結合 TaskManageable 和 Cacheable，為所有數據管理器提供標準化介面
protocol DataManageable: TaskManageable, Cacheable {
    associatedtype DataType: Codable
    associatedtype ServiceType
    
    // 核心數據屬性
    var isLoading: Bool { get set }
    var lastSyncTime: Date? { get set }
    var syncError: String? { get set }
    
    // 依賴服務
    var service: ServiceType { get }
    
    // 標準化方法
    func initialize() async
    func loadData() async
    func refreshData() async -> Bool
    func clearAllData() async
}

// MARK: - 預設實現
extension DataManageable where Self: ObservableObject {
    
    /// 標準化的數據載入模式
    func executeDataLoadingTask<T>(
        id: String,
        showLoading: Bool = true,
        operation: @escaping () async throws -> T
    ) async -> T? {
        // 防禦性檢查：確保 ID 有效
        guard !id.isEmpty, id.count < 100 else {
            // TaskManagement 錯誤只記錄在本地，不上傳到雲端
            print("[DataManageable] 無效的任務 ID: \(String(id.prefix(50)))")
            return nil
        }
        
        // 防止重複調用
        if showLoading {
            let currentlyLoading = await MainActor.run { 
                guard self is AnyObject else { return false } // 檢查對象是否已釋放
                return self.isLoading 
            }
            if currentlyLoading {
                print("[DataManageable] 數據載入中，跳過重複調用: \(id)")
                return nil
            }
        }
        
        return await executeTask(id: id) {
            if showLoading {
                await MainActor.run {
                    self.isLoading = true
                    self.syncError = nil
                }
            }
            
            do {
                let result = try await operation()
                
                if showLoading {
                    await MainActor.run {
                        self.isLoading = false
                        self.lastSyncTime = Date()
                    }
                }
                
                return result
            } catch {
                if showLoading {
                    await MainActor.run {
                        self.syncError = error.localizedDescription
                        self.isLoading = false
                    }
                }
                throw error
            }
        }
    }
    
    /// 背景更新（不顯示 loading 狀態）
    func backgroundRefresh() async {
        _ = await executeDataLoadingTask(id: "background_refresh", showLoading: false) {
            return await self.refreshData()
        }
    }
}

// MARK: - 基礎 API 服務協議
protocol APIServiceProtocol {
    var apiClient: APIClient { get }
    
    func handleAPIError(_ error: Error, context: String) -> Error
}

extension APIServiceProtocol {
    func handleAPIError(_ error: Error, context: String) -> Error {
        Logger.firebase(
            "API 請求失敗: \(context)",
            level: .error,
            jsonPayload: [
                "context": context,
                "error": error.localizedDescription,
                "error_type": String(describing: type(of: error))
            ]
        )
        return error
    }
}

// MARK: - 基礎快取管理器協議
protocol BaseCacheManager: Cacheable {
    associatedtype CacheDataType: Codable
    
    var cacheKey: String { get }
    var defaultTTL: TimeInterval { get }
    
    func saveToCache(_ data: CacheDataType)
    func loadFromCache() -> CacheDataType?
    func shouldRefresh(customTTL: TimeInterval?) -> Bool
}

extension BaseCacheManager {
    func shouldRefresh(customTTL: TimeInterval? = nil) -> Bool {
        let ttl = customTTL ?? defaultTTL
        
        guard let lastSync = UserDefaults.standard.object(forKey: "\(cacheKey)_timestamp") as? Date else {
            return true
        }
        
        return Date().timeIntervalSince(lastSync) > ttl
    }
    
    func getCacheSize() -> Int {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return 0 }
        return data.count
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: "\(cacheKey)_timestamp")
        
        Logger.firebase(
            "快取已清除",
            level: .info,
            jsonPayload: ["cache_identifier": cacheIdentifier]
        )
    }
    
    func saveToCache(_ data: CacheDataType) {
        do {
            let encodedData = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encodedData, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_timestamp")
        } catch {
            Logger.firebase(
                "快取保存失敗",
                level: .error,
                jsonPayload: [
                    "cache_identifier": cacheIdentifier,
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    func loadFromCache() -> CacheDataType? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        
        do {
            return try JSONDecoder().decode(CacheDataType.self, from: data)
        } catch {
            Logger.firebase(
                "快取讀取失敗",
                level: .error,
                jsonPayload: [
                    "cache_identifier": cacheIdentifier,
                    "error": error.localizedDescription
                ]
            )
            clearCache() // 清除損壞的快取
            return nil
        }
    }
}
