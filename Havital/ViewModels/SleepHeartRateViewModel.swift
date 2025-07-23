import SwiftUI
import HealthKit

@MainActor
class SleepHeartRateViewModel: ObservableObject {
    @Published var heartRateData: [(Date, Double)] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .week
    
    // 透過外部設定的管理器
    var healthKitManager: HealthKitManager?
    var sharedHealthDataManager: SharedHealthDataManager?
    
    init() {
        setupNotificationObservers()
    }
    
    deinit {
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
        isLoading = true
        error = nil
        
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
                    self.error = "HealthKit 管理器未初始化"
                    isLoading = false
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
                if let sharedDataManager = sharedHealthDataManager {
                    await sharedDataManager.loadHealthDataIfNeeded()
                    
                    let healthData = sharedDataManager.healthData
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    for record in healthData {
                        if let date = dateFormatter.date(from: record.date),
                           date >= startDate && date <= now,
                           let restingHeartRate = record.restingHeartRate {
                            points.append((date, Double(restingHeartRate)))
                        }
                    }
                } else {
                    print("SharedHealthDataManager 未提供，無法載入 Garmin 數據")
                    self.error = "無法載入 Garmin 心率數據"
                }
                
            case .unbound:
                self.error = "請先選擇數據來源"
            }
            
            heartRateData = points.sorted { $0.0 < $1.0 }
            isLoading = false
        } catch {
            print("Error loading sleep heart rate data: \(error)")
            self.error = "無法載入睡眠心率數據"
            isLoading = false
            heartRateData = []
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
