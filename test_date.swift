import Foundation

let today = Date()
let calendar = Calendar.current
let weekday = calendar.component(.weekday, from: today)

print("今天是星期", weekday, "(1=週日, 2=週一, ..., 7=週六)")

let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd EEEE"
print("今天日期:", formatter.string(from: today))

// 測試 daysFromMonday 計算
let daysFromMonday = (weekday + 5) % 7
print("距離週一天數:", daysFromMonday)

// 測試週一計算
if let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today)) {
    print("本週一:", formatter.string(from: thisMonday))
    
    // 測試一週7天的映射
    for i in 0..<7 {
        if let dayDate = calendar.date(byAdding: .day, value: i, to: thisMonday) {
            let dayName = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"][i]
            print("dayIndex \(i) = \(dayName):", formatter.string(from: dayDate))
        }
    }
}
