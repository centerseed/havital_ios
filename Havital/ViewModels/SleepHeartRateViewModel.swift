import SwiftUI
import HealthKit

class SleepHeartRateViewModel: ObservableObject, TaskManageable {
    // MARK: - TaskManageable Properties
    var activeTasks: [String: Task<Void, Never>] = [:]
    @Published var heartRateData: [(Date, Double)] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .week
    
    // 透過外部設定的管理器
    var healthKitManager: HealthKitManager?
    // 直接使用單例
    private let sharedHealthDataManager = SharedHealthDataManager.shared
    
    init() {
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
                
            case .unbound:
                await MainActor.run {
                    self.error = "請先選擇數據來源"
                }
            }
            
            await MainActor.run {
                heartRateData = points.sorted { $0.0 < $1.0 }
                isLoading = false
            }
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
}
