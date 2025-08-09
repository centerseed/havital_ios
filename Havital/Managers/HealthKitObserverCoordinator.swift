import Foundation
import HealthKit

// MARK: - HealthKit Observer 中央協調器
// 用於解決多個管理器同時設置 HealthKit Observer 導致的併發崩潰問題
actor HealthKitObserverCoordinator {
    static let shared = HealthKitObserverCoordinator()
    
    // 記錄已註冊的 Observer 類型
    private var registeredObservers: Set<String> = []
    
    // 記錄正在執行的 Observer 查詢
    private var activeQueries: [String: HKQuery] = [:]
    
    // HealthStore 實例
    private let healthStore = HKHealthStore()
    
    private init() {
        print("HealthKitObserverCoordinator: 初始化")
    }
    
    // MARK: - Observer 管理
    
    /// 註冊並執行 HealthKit Observer（防止重複）
    /// - Parameters:
    ///   - type: Observer 類型標識符（如 "workout", "hrv", "rhr"）
    ///   - query: 要執行的 HKObserverQuery
    ///   - enableBackground: 是否啟用背景傳遞
    func registerObserver(
        type: String,
        query: HKObserverQuery,
        enableBackground: Bool = true,
        sampleType: HKSampleType? = nil
    ) async -> Bool {
        // 檢查是否已經註冊過相同類型的 Observer
        guard !registeredObservers.contains(type) else {
            print("HealthKitObserverCoordinator: Observer '\(type)' 已經註冊，跳過重複註冊")
            return false
        }
        
        // 停止任何現有的相同類型查詢
        if let existingQuery = activeQueries[type] {
            healthStore.stop(existingQuery)
            activeQueries.removeValue(forKey: type)
            print("HealthKitObserverCoordinator: 停止現有的 '\(type)' 查詢")
        }
        
        // 註冊新的 Observer
        registeredObservers.insert(type)
        activeQueries[type] = query
        
        // 執行查詢
        healthStore.execute(query)
        print("HealthKitObserverCoordinator: 成功註冊並執行 '\(type)' Observer")
        
        // 啟用背景傳遞（如果需要）
        if enableBackground, let sampleType = sampleType {
            await enableBackgroundDelivery(for: sampleType, type: type)
        }
        
        return true
    }
    
    /// 移除指定類型的 Observer
    func removeObserver(type: String) {
        registeredObservers.remove(type)
        
        if let query = activeQueries.removeValue(forKey: type) {
            healthStore.stop(query)
            print("HealthKitObserverCoordinator: 移除 '\(type)' Observer")
        }
    }
    
    /// 移除所有 Observer
    func removeAllObservers() {
        for (type, query) in activeQueries {
            healthStore.stop(query)
            print("HealthKitObserverCoordinator: 停止 '\(type)' Observer")
        }
        
        activeQueries.removeAll()
        registeredObservers.removeAll()
        print("HealthKitObserverCoordinator: 已移除所有 Observer")
    }
    
    /// 檢查指定類型的 Observer 是否已註冊
    func isObserverRegistered(type: String) -> Bool {
        return registeredObservers.contains(type)
    }
    
    /// 獲取已註冊的 Observer 數量
    func registeredObserverCount() -> Int {
        return registeredObservers.count
    }
    
    // MARK: - 背景傳遞管理
    
    /// 為指定的樣本類型啟用背景傳遞
    private func enableBackgroundDelivery(for sampleType: HKSampleType, type: String) async {
        await withCheckedContinuation { continuation in
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                if success {
                    print("HealthKitObserverCoordinator: '\(type)' 背景傳遞已啟用")
                } else if let error = error {
                    print("HealthKitObserverCoordinator: '\(type)' 背景傳遞啟用失敗: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
    
    /// 停用指定樣本類型的背景傳遞
    func disableBackgroundDelivery(for sampleType: HKSampleType, type: String) async {
        await withCheckedContinuation { continuation in
            healthStore.disableBackgroundDelivery(for: sampleType) { success, error in
                if success {
                    print("HealthKitObserverCoordinator: '\(type)' 背景傳遞已停用")
                } else if let error = error {
                    print("HealthKitObserverCoordinator: '\(type)' 背景傳遞停用失敗: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - 調試信息
    
    /// 獲取當前狀態的調試信息
    func getDebugInfo() -> String {
        let info = """
        HealthKitObserverCoordinator 狀態:
        - 已註冊 Observer: \(registeredObservers.sorted().joined(separator: ", "))
        - 活躍查詢數量: \(activeQueries.count)
        - HealthStore 可用: \(HKHealthStore.isHealthDataAvailable())
        """
        return info
    }
    
    /// 打印當前狀態（用於調試）
    func printCurrentStatus() {
        print("========== HealthKitObserverCoordinator Status ==========")
        print(getDebugInfo())
        print("========================================================")
    }
}

// MARK: - Observer 類型常量
extension HealthKitObserverCoordinator {
    enum ObserverType {
        static let workout = "workout"
        static let heartRateVariability = "hrv"
        static let restingHeartRate = "rhr"
        static let workoutBackground = "workout_background"
        static let unifiedWorkout = "unified_workout"
    }
}