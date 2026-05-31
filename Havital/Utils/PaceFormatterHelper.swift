//
//  PaceFormatterHelper.swift
//  Havital
//
//  配速格式化和計算工具
//

import Foundation

struct PaceFormatterHelper {

    // MARK: - 配速格式化

    /// 格式化配速字串
    /// - Parameter pace: 配速字串，格式為 "mm:ss"
    /// - Returns: 格式化後的配速字串
    static func formatPace(_ pace: String?) -> String {
        guard let pace = pace else { return "--:--" }

        // 驗證配速格式
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return pace }

        let minutes = components[0]
        let seconds = components[1]

        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 格式化配速為完整描述（依 UnitManager 設定決定單位）
    /// - Parameter pace: 配速字串，格式為 "mm:ss"
    /// - Returns: 格式化後的配速描述，例如："5:30/km" 或 "8:51/mi"
    static func formatPaceWithUnit(_ pace: String?) -> String {
        return MainActor.assumeIsolated { UnitManager.shared.formatPaceString(pace) }
    }

    // MARK: - 配速轉換

    /// 將配速字串轉換為秒數
    /// - Parameter pace: 配速字串，格式為 "mm:ss"
    /// - Returns: 配速對應的秒數，失敗返回 nil
    static func paceToSeconds(_ pace: String) -> Double? {
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        let minutes = Double(components[0])
        let seconds = Double(components[1])

        return minutes * 60 + seconds
    }

    /// 將秒數轉換為配速字串
    /// - Parameter seconds: 秒數
    /// - Returns: 配速字串，格式為 "mm:ss"
    static func secondsToPace(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - 距離計算

    /// 根據配速和時間計算距離
    /// - Parameters:
    ///   - pace: 配速字串，格式為 "mm:ss"
    ///   - timeMinutes: 時間（分鐘）
    /// - Returns: 距離（公里），失敗返回 nil
    static func calculateDistance(pace: String, timeMinutes: Double) -> Double? {
        guard let paceSeconds = paceToSeconds(pace) else { return nil }
        let paceMinutesPerKm = paceSeconds / 60.0
        guard paceMinutesPerKm > 0 else { return nil }

        return timeMinutes / paceMinutesPerKm
    }

    /// 根據配速和時間計算距離（公尺）
    /// - Parameters:
    ///   - pace: 配速字串，格式為 "mm:ss"
    ///   - timeMinutes: 時間（分鐘）
    ///   - roundTo: 四捨五入到指定公尺（預設100m）
    /// - Returns: 距離（公尺），失敗返回 nil
    static func calculateDistanceMeters(pace: String, timeMinutes: Double, roundTo: Double = 100.0) -> Double? {
        guard let distanceKm = calculateDistance(pace: pace, timeMinutes: timeMinutes) else {
            return nil
        }
        let meters = distanceKm * 1000.0
        return round(meters / roundTo) * roundTo
    }

    /// 根據距離和配速計算時間
    /// - Parameters:
    ///   - distanceKm: 距離（公里）
    ///   - pace: 配速字串，格式為 "mm:ss"
    /// - Returns: 時間（分鐘），失敗返回 nil
    static func calculateTime(distanceKm: Double, pace: String) -> Double? {
        guard let paceSeconds = paceToSeconds(pace) else { return nil }
        let paceMinutesPerKm = paceSeconds / 60.0
        return distanceKm * paceMinutesPerKm
    }
}


