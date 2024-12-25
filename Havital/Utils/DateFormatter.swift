import Foundation

struct DateFormatterUtil {
    static func formatDate(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd EEEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}
