import Foundation

// 確保DataPoint結構體存在並正確定義
struct DataPoint: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let value: Double
    
    // 實現 Equatable 協議
    static func == (lhs: DataPoint, rhs: DataPoint) -> Bool {
        return lhs.time == rhs.time && lhs.value == rhs.value
    }
}
