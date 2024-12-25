import SwiftUI
import HealthKit

class HRVChartViewModel: BaseChartViewModel<HRVDataPoint> {
    private let healthKitManager: HealthKitManager
    
    override var chartColor: Color { .blue }
    
    override var minimumYAxisValue: Double? { 0 }  // HRV 不能小於 0
    
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
        
        let samples = await healthKitManager.fetchHRVData(start: startDate, end: endDate)
        await MainActor.run {
            self.dataPoints = samples.map { HRVDataPoint(date: $0.0, value: $0.1) }
        }
    }
}
