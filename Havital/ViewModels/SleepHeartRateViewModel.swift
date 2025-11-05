import SwiftUI
import HealthKit

// MARK: - Cache Data Structure
private struct CachePoint: Codable {
    let timeInterval: TimeInterval
    let value: Double
}

class SleepHeartRateViewModel: ObservableObject, TaskManageable {
    // MARK: - TaskManageable Properties (Actor-based)
    let taskRegistry = TaskRegistry()
    @Published var heartRateData: [(Date, Double)] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .month

    // 透過外部設定的管理器
    var healthKitManager: HealthKitManager?
    // 直接使用單例
    private let sharedHealthDataManager = SharedHealthDataManager.shared

    // MARK: - 智能緩存機制
    private var lastUpdateTime: Date?
    private let cacheKey = "sleep_heart_rate_data_cache"
    private let cacheTimeKey = "sleep_heart_rate_data_cache_time"

    init() {
        loadCachedData()
        setupNotificationObservers()
    }
    
    deinit {
        cancelAllTasks()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 設置通知監聽
    private func setupNotificationObservers() {
        // 監聽 Garmin 數據刷新通知
        NotificationCenter.default.addObserver(
            forName: .garminHealthDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadHeartRateData()
            }
        }
        
        // 監聽 Apple Health 數據刷新通知
        NotificationCenter.default.addObserver(
            forName: .appleHealthDataRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadHeartRateData()
            }
        }
        
        // 監聽數據源切換通知
        NotificationCenter.default.addObserver(
            forName: .dataSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadHeartRateData()
            }
        }
    }
    
    func loadHeartRateData() async {
        // ✅ 智能緩存檢查：避免頻繁更新
        if !shouldRefreshData() {
            print("📊 [SleepHeartRateViewModel] 使用緩存數據，距離上次更新: \(lastUpdateTime?.description ?? "未知")")
            return
        }

        // 使用實例唯一的 ID 來避免不同實例間的任務衝突
        let instanceId = ObjectIdentifier(self).hashValue
        let taskId = "load_heart_rate_\(instanceId)_\(selectedTimeRange.rawValue)"

        guard await executeTask(id: taskId, operation: {
            return try await self.performLoadHeartRateData()
        }) != nil else {
            return
        }
    }
    
    private func performLoadHeartRateData() async throws {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        let dataSourcePreference = UserPreferenceManager.shared.dataSourcePreference
        
        do {
            let now = Date()
            let startDate: Date
            
            switch selectedTimeRange {
            case .week:
                startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            case .month:
                startDate = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            case .threeMonths:
                startDate = Calendar.current.date(byAdding: .month, value: -3, to: now)!
            }
            
            var points: [(Date, Double)] = []
            
            switch dataSourcePreference {
            case .appleHealth:
                // 從 HealthKit 獲取數據
                guard let healthKit = healthKitManager else {
                    await MainActor.run {
                        self.error = "HealthKit 管理器未初始化"
                        self.isLoading = false
                    }
                    return
                }
                
                try await healthKit.requestAuthorization()
                
                var currentDate = startDate
                while currentDate <= now {
                    if let heartRate = try await healthKit.fetchSleepHeartRateAverage(for: currentDate) {
                        points.append((currentDate, heartRate))
                    }
                    currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
                }
                
            case .garmin:
                // 從 API 獲取數據
                await sharedHealthDataManager.loadHealthDataIfNeeded()
                
                let healthData = sharedHealthDataManager.healthData
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                print("Garmin 心率數據載入: 共 \(healthData.count) 筆健康記錄")
                
                // 調試：檢查每筆記錄的 restingHeartRate 字段
                for record in healthData {
                    print("記錄: 日期=\(record.date), restingHeartRate=\(record.restingHeartRate ?? -1)")
                    
                    if let date = dateFormatter.date(from: record.date),
                       date >= startDate && date <= now {
                        
                        if let restingHeartRate = record.restingHeartRate {
                            points.append((date, Double(restingHeartRate)))
                            print("✅ 添加心率數據: 日期=\(record.date), 心率=\(restingHeartRate)")
                        } else {
                            print("❌ 該日期無靜息心率數據: \(record.date)")
                        }
                    } else {
                        print("⏰ 日期超出範圍: \(record.date)")
                    }
                }
                
                print("最終心率數據點數: \(points.count)")
                
            case .strava:
                // 從 API 獲取 Strava 數據
                await sharedHealthDataManager.loadHealthDataIfNeeded()
                
                let healthData = sharedHealthDataManager.healthData
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                print("Strava 心率數據載入: 共 \(healthData.count) 筆健康記錄")
                
                // 調試：檢查每筆記錄的 restingHeartRate 字段
                for record in healthData {
                    print("記錄: 日期=\(record.date), restingHeartRate=\(record.restingHeartRate ?? -1)")
                    
                    if let date = dateFormatter.date(from: record.date),
                       date >= startDate && date <= now {
                        
                        if let restingHeartRate = record.restingHeartRate {
                            points.append((date, Double(restingHeartRate)))
                            print("✅ 添加心率數據: 日期=\(record.date), 心率=\(restingHeartRate)")
                        } else {
                            print("❌ 該日期無靜息心率數據: \(record.date)")
                        }
                    } else {
                        print("⏰ 日期超出範圍: \(record.date)")
                    }
                }
                
                print("最終 Strava 心率數據點數: \(points.count)")
                
            case .unbound:
                await MainActor.run {
                    self.error = "請先選擇數據來源"
                }
            }
            
            await MainActor.run {
                heartRateData = points.sorted { $0.0 < $1.0 }
                isLoading = false
            }

            // ✅ 保存緩存
            saveCachedData()
            lastUpdateTime = Date()
        } catch {
            print("Error loading sleep heart rate data: \(error)")
            await MainActor.run {
                self.error = "無法載入睡眠心率數據"
                self.isLoading = false
                self.heartRateData = []
            }
            throw error
        }
    }
    
    var yAxisRange: ClosedRange<Double> {
        guard !heartRateData.isEmpty else { return 40...100 }
        
        let values = heartRateData.map { $0.1 }
        let min = values.min() ?? 40
        let max = values.max() ?? 100
        
        // 添加 10% 的 padding
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "一週"
        case month = "一個月"
        case threeMonths = "三個月"
    }

    // MARK: - 智能緩存輔助函數

    /// 檢查是否需要刷新數據
    /// - Returns: true 表示需要刷新，false 表示使用緩存
    private func shouldRefreshData() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        // 檢查上次更新時間
        guard let lastUpdate = lastUpdateTime else {
            print("📊 [SleepHeartRateViewModel] 從未更新過，需要刷新")
            return true // 從未更新過
        }

        // 檢查是否超過2小時
        let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: now)!
        if lastUpdate < twoHoursAgo {
            // 特殊規則：中午12點到晚上12點只更新一次
            if currentHour >= 12 {
                // 檢查今天12點之後是否已更新過
                let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
                if lastUpdate >= todayNoon {
                    print("📊 [SleepHeartRateViewModel] 今天12點後已更新過，使用緩存")
                    return false // 今天12點後已更新過，不需要再更新
                }
            }
            print("📊 [SleepHeartRateViewModel] 超過2小時且符合更新條件，需要刷新")
            return true
        }

        print("📊 [SleepHeartRateViewModel] 未超過2小時，使用緩存")
        return false
    }

    /// 從 UserDefaults 載入緩存數據
    private func loadCachedData() {
        guard let timeData = UserDefaults.standard.object(forKey: cacheTimeKey) as? Date else {
            return
        }

        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let cached = try decoder.decode([CachePoint].self, from: data)
            heartRateData = cached.map { (Date(timeIntervalSince1970: $0.timeInterval), $0.value) }
            lastUpdateTime = timeData
            print("📊 [SleepHeartRateViewModel] 成功載入緩存數據: \(heartRateData.count) 筆")
        } catch {
            print("📊 [SleepHeartRateViewModel] 載入緩存失敗: \(error)")
        }
    }

    /// 保存數據到 UserDefaults
    private func saveCachedData() {
        let encoder = JSONEncoder()
        // 將 Date 轉換為 TimeInterval 以便序列化
        let serializable = heartRateData.map { CachePoint(timeInterval: $0.0.timeIntervalSince1970, value: $0.1) }

        do {
            let data = try encoder.encode(serializable)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimeKey)
            print("📊 [SleepHeartRateViewModel] 成功保存緩存數據: \(heartRateData.count) 筆")
        } catch {
            print("📊 [SleepHeartRateViewModel] 保存緩存失敗: \(error)")
        }
    }
}
