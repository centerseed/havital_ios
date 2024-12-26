import SwiftUI
import HealthKit

@MainActor
class SleepHeartRateViewModel: ObservableObject {
    @Published var heartRateData: [(Date, Double)] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedTimeRange: TimeRange = .week
    private let healthKitManager: HealthKitManager
    
    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }
    
    func loadHeartRateData() async {
        isLoading = true
        error = nil
        
        do {
            try await healthKitManager.requestAuthorization()
            
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
            var currentDate = startDate
            
            while currentDate <= now {
                if let heartRate = try await healthKitManager.fetchSleepHeartRateAverage(for: currentDate) {
                    points.append((currentDate, heartRate))
                }
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
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
