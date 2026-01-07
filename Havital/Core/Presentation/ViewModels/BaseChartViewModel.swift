import SwiftUI
import HealthKit

class BaseChartViewModel<T: ChartDataPoint>: ObservableObject {
    @Published var dataPoints: [T] = []
    @Published var selectedPoint: T?
    @Published var isLoading = true
    
    var chartColor: Color { .blue }
    
    // 子類可以覆寫這些屬性來自定義行為
    var minimumYAxisValue: Double? { nil }  // nil 表示沒有最小值限制
    var minimumPadding: Double { 1.0 }      // 默認最小 padding 為 1.0
    
    var yAxisRange: ClosedRange<Double>? {
        guard !dataPoints.isEmpty else { return nil }
        let values = dataPoints.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        
        // 計算範圍大小的10%作為padding
        let range = maxValue - minValue
        let padding = max(range * 0.1, minimumPadding)
        
        // 如果有設置最小值，則使用它作為下界的限制
        let lowerBound = minimumYAxisValue.map { max($0, minValue - padding) } ?? (minValue - padding)
        let upperBound = maxValue + padding
        
        return lowerBound...upperBound
    }
    
    func findClosestPoint(to date: Date) -> T? {
        dataPoints.min { first, second in
            abs(first.date.timeIntervalSince(date)) < abs(second.date.timeIntervalSince(date))
        }
    }
    
    func loadData() async {
        // 由子類實現
    }
}
