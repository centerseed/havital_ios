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

    /// 格式化配速為完整描述
    /// - Parameter pace: 配速字串，格式為 "mm:ss"
    /// - Returns: 格式化後的配速描述，例如："5:30/km"
    static func formatPaceWithUnit(_ pace: String?) -> String {
        guard let formatted = pace else { return "--:--/km" }
        return "\(formatPace(formatted))/km"
    }

    // MARK: - 建議配速計算

    /// 獲取建議配速
    /// - Parameters:
    ///   - trainingType: 訓練類型
    ///   - vdot: VDOT 數值
    /// - Returns: 建議配速字串，格式為 "mm:ss"
    static func getSuggestedPace(for trainingType: String, vdot: Double) -> String {
        // 基於 Jack Daniels VDOT 表格計算建議配速
        // 這裡使用簡化的計算公式，實際應用中應使用完整的 VDOT 表格

        switch trainingType {
        case "easy", "easyRun", "recovery", "recovery_run":
            // E配速：約59-74% VO2max
            return calculatePaceForPercentage(0.65, vdot: vdot)

        case "marathon":
            // M配速：約80-85% VO2max
            return calculatePaceForPercentage(0.83, vdot: vdot)

        case "threshold", "tempo":
            // T配速：約88% VO2max
            return calculatePaceForPercentage(0.88, vdot: vdot)

        case "interval":
            // I配速：約95-100% VO2max
            return calculatePaceForPercentage(0.98, vdot: vdot)

        case "repetition":
            // R配速：約105-120% VO2max
            return calculatePaceForPercentage(1.05, vdot: vdot)

        default:
            // 默認使用輕鬆跑配速
            return calculatePaceForPercentage(0.65, vdot: vdot)
        }
    }

    /// 計算指定百分比 VO2max 對應的配速
    /// - Parameters:
    ///   - percentage: VO2max 百分比 (0.0-1.2)
    ///   - vdot: VDOT 數值
    /// - Returns: 配速字串，格式為 "mm:ss"
    static func calculatePaceForPercentage(_ percentage: Double, vdot: Double) -> String {
        // VDOT 配速計算公式（簡化版）
        // 實際公式更複雜，這裡使用近似計算

        // 基準配速：VDOT 45 對應約 5:30/km (330秒/km)
        let baseSecondsPerKm = 330.0
        let baseVDOT = 45.0

        // VDOT 每增加1，配速約快6秒
        let vdotDiff = vdot - baseVDOT
        let adjustedSeconds = baseSecondsPerKm - (vdotDiff * 6.0)

        // 根據強度百分比調整
        // percentage 越高，配速越快（秒數越少）
        let intensityFactor = 2.0 - percentage // E配速(0.65) -> 1.35, I配速(0.98) -> 1.02
        let finalSeconds = adjustedSeconds * intensityFactor

        // 轉換為 mm:ss 格式
        let minutes = Int(finalSeconds / 60)
        let seconds = Int(finalSeconds.truncatingRemainder(dividingBy: 60))

        return String(format: "%d:%02d", minutes, seconds)
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


