import SwiftUI
import HealthKit

class SleepHeartRateViewModel: BaseChartViewModel<HeartRateDataPoint> {
    private let healthKitManager: HealthKitManager
    
    override var chartColor: Color { .purple }
    override var minimumYAxisValue: Double? { 0 }    // 心率不能小於 0
    override var minimumPadding: Double { 5.0 }      // 心率使用較大的最小 padding
    
    override init() {
        self.healthKitManager = HealthKitManager()
        super.init()
    }
    
    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        super.init()
    }
    
    override func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await healthKitManager.requestAuthorization()
            
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            
            var points: [(Date, Double)] = []
            var currentDate = startDate
            
            while currentDate <= endDate {
                if let heartRate = try await healthKitManager.fetchSleepHeartRateAverage(for: currentDate) {
                    points.append((currentDate, heartRate))
                }
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            await MainActor.run {
                self.dataPoints = points.map { HeartRateDataPoint(date: $0.0, value: $0.1) }
            }
        } catch {
            print("Error loading sleep heart rate data: \(error)")
            await MainActor.run {
                self.dataPoints = []
            }
        }
    }
}
