import Foundation

/// 配速格式化工具（iOS 和 watchOS 共用）
struct PaceFormatter {
    /// 將配速字符串（"4:30"）轉換為秒數
    static func paceToSeconds(_ pace: String) -> TimeInterval? {
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return TimeInterval(components[0] * 60 + components[1])
    }

    /// 將秒數轉換為配速字符串（"4:30"）
    static func secondsToPace(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// 計算配速區間（±20秒）
    static func paceRange(targetPace: String, variance: TimeInterval = 20) -> (min: String, max: String)? {
        guard let targetSeconds = paceToSeconds(targetPace) else { return nil }

        // 慢的（數字大）在左，快的（數字小）在右
        let slowPace = secondsToPace(targetSeconds + variance)  // 4'50" (慢)
        let fastPace = secondsToPace(targetSeconds - variance)  // 4'10" (快)

        return (min: slowPace, max: fastPace)
    }

    /// 判斷當前配速是否在區間內
    static func isPaceInRange(currentPace: TimeInterval, targetPace: String, variance: TimeInterval = 20) -> PaceStatus {
        guard let targetSeconds = paceToSeconds(targetPace) else { return .unknown }

        let diff = currentPace - targetSeconds

        if abs(diff) <= variance {
            return .ideal
        } else if diff > variance {
            return .tooSlow
        } else {
            return .tooFast
        }
    }

    /// 配速狀態
    enum PaceStatus {
        case ideal      // 理想配速
        case tooFast    // 過快
        case tooSlow    // 過慢
        case unknown    // 未知
    }
}

/// 心率區間判斷工具
struct HeartRateZoneDetector {
    /// 判斷當前心率在哪個區間
    static func detectZone(currentHR: Int, zones: [WatchHeartRateZone]) -> WatchHeartRateZone? {
        return zones.first { zone in
            currentHR >= zone.minHR && currentHR <= zone.maxHR
        }
    }

    /// 判斷心率狀態（相對於目標區間）
    static func heartRateStatus(currentHR: Int, targetRange: WatchHeartRateRange?) -> HeartRateStatus {
        guard let range = targetRange, range.isValid else { return .unknown }
        guard let minHR = range.min, let maxHR = range.max else { return .unknown }

        if currentHR >= minHR && currentHR <= maxHR {
            return .inRange
        } else if currentHR > maxHR {
            return .tooHigh
        } else {
            return .tooLow
        }
    }

    /// 心率狀態
    enum HeartRateStatus {
        case inRange    // 在目標區間內
        case tooHigh    // 過高
        case tooLow     // 過低
        case unknown    // 未知
    }
}

/// 距離格式化工具
struct DistanceFormatter {
    /// 格式化距離顯示（公里）
    static func formatKilometers(_ km: Double) -> String {
        if km >= 10 {
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.2f km", km)
        }
    }

    /// 格式化距離顯示（米）
    static func formatMeters(_ meters: Double) -> String {
        if meters >= 1000 {
            return formatKilometers(meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
}

/// 時間格式化工具
struct DurationFormatter {
    /// 格式化時長（HH:MM:SS 或 MM:SS）
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// 格式化為簡短顯示（如"1h 23m"）
    static func formatShort(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
