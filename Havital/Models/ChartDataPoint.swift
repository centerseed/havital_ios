import Foundation

protocol ChartDataPoint {
    var date: Date { get }
    var value: Double { get }
    var formattedValue: String { get }
}

struct HRVDataPoint: ChartDataPoint, Codable {
    let date: Date
    let value: Double
    
    var formattedValue: String {
        "\(Int(value)) ms"
    }
}

struct HeartRateDataPoint: ChartDataPoint {
    let date: Date
    let value: Double
    
    var formattedValue: String {
        String(format: NSLocalizedString("chart.unit.cadence_per_min", comment: ""), Int(value))
    }
}
