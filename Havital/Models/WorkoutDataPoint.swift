import Foundation

// 確保DataPoint結構體存在並正確定義
struct DataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}
