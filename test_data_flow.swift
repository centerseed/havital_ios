import Foundation

// 模擬 WeekDateService 的邏輯
print("=== WeekDateService 模擬 ===")
let calendar = Calendar(identifier: .gregorian)

// 假設今天是 2025-09-12 (星期五)
let today = Date()
let weekday = calendar.component(.weekday, from: today)
print("今天是星期", weekday, "(1=週日, 2=週一, ..., 7=週六)")

// 計算本週週一
let offsetToMonday = (weekday + 5) % 7
guard let thisMonday = calendar.date(byAdding: .day, value: -offsetToMonday, to: calendar.startOfDay(for: today)) else {
    exit(1)
}

print("本週一:", DateFormatter().string(from: thisMonday))

// WeekDateService 中的 daysMap 邏輯
var daysMap = [Int: Date]()
for i in 0..<7 {
    if let d = calendar.date(byAdding: .day, value: i, to: thisMonday) {
        daysMap[i + 1] = d  // key 是 1-7
    }
}

print("\n=== WeekDateService daysMap (key: 1-7) ===")
for key in 1...7 {
    if let date = daysMap[key] {
        let dayName = ["", "週一", "週二", "週三", "週四", "週五", "週六", "週日"][key]
        print("key \(key) = \(dayName):", DateFormatter().string(from: date))
    }
}

print("\n=== 模型數據中的 dayIndex (應該是什麼?) ===")
// 假設模型中的 days 數組
let modelDayIndices = ["0", "1", "2", "3", "4", "5", "6"] // 還是 ["1", "2", "3", "4", "5", "6", "7"] ?

for (arrayIndex, dayIndexString) in modelDayIndices.enumerated() {
    let dayIndexInt = Int(dayIndexString) ?? 0
    let dayName = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"][arrayIndex]
    print("數組位置 \(arrayIndex), dayIndex=\"\(dayIndexString)\", dayIndexInt=\(dayIndexInt) -> \(dayName)")
}
