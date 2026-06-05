import Foundation

enum WatchFormatting {
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return "\(max(0, Int(meters.rounded()))) m"
    }

    static func time(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    static func pace(_ secondsPerKm: Int?) -> String {
        guard let secondsPerKm, secondsPerKm > 0 else { return "--/km" }
        return String(format: "%d:%02d/km", secondsPerKm / 60, secondsPerKm % 60)
    }

    static func paceSecondsPerKm(speedMps: Double) -> Int? {
        speedMps > 0.1 ? Int(1000 / speedMps) : nil
    }

    static func localDayString(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
