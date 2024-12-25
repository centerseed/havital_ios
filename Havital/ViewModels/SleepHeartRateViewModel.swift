import SwiftUI
import HealthKit

class SleepHeartRateViewModel: BaseChartViewModel<HeartRateDataPoint> {
    private let healthKitManager: HealthKitManager
    
    override var chartColor: Color { .purple }
    
    override var minimumYAxisValue: Double? { 0 }     // 心率不能小於 0
    override var minimumPadding: Double { 5.0 }       // 心率使用較大的最小 padding
    
    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        super.init()
    }
    
    override func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // 使用 async/await 包裝 completion handler
        let success = await withCheckedContinuation { continuation in
            healthKitManager.requestAuthorization { success in
                continuation.resume(returning: success)
            }
        }
        
        guard success else { return }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
        
        var points: [(Date, Double)] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            if let heartRate = try? await healthKitManager.fetchSleepHeartRateAverage(for: currentDate) {
                points.append((currentDate, heartRate))
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        await MainActor.run {
            self.dataPoints = points.map { HeartRateDataPoint(date: $0.0, value: $0.1) }
        }
    }
}
