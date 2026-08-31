import Foundation
import SwiftUI

// MARK: - UnitSystem

enum UnitSystem: String, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"

    /// 目前設定的單位制，**nonisolated**。
    ///
    /// 純投影層（`App2PlanEndProjection`、`App2RaceDatabaseViewModel.DistanceFilter`）
    /// 也要照設定畫，但它們不在 MainActor 上，拿不到 `UnitManager.shared`。
    /// 讀的是 `UnitManager` 寫入的**同一個** UserDefaults key，不是第二份狀態：
    /// 寫入者只有 `UnitManager`。
    ///
    /// 這條**不會**驅動重繪 —— 需要切換當場重畫的畫面要自己
    /// `@ObservedObject var unitManager = UnitManager.shared`。
    static var current: UnitSystem {
        UserDefaults.standard.string(forKey: UnitManager.defaultsKey)
            .flatMap(UnitSystem.init(rawValue:)) ?? .metric
    }

    var displayName: String {
        switch self {
        case .metric:
            return L10n.Unit.metric.localized
        case .imperial:
            return L10n.Unit.imperial.localized
        }
    }

    var apiValue: String { rawValue }

    var distanceSuffix: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    var paceSuffix: String {
        switch self {
        case .metric: return "/km"
        case .imperial: return "/mi"
        }
    }

    /// 秒／km → 秒／(km 或 mi)。**配速換算的唯一係數住在這裡**，
    /// 呼叫端不得自己乘 1.60934（2026-08-26 收斂：原本 `UnitManager`、
    /// `App2WorkoutDetailProjection`、`App2SessionDetailProjection` 各寫一份）。
    func convertedPaceSeconds(_ secondsPerKm: Double) -> Double {
        switch self {
        case .metric: return secondsPerKm
        case .imperial: return secondsPerKm * 1.60934
        }
    }

    /// km → (km 或 mi)。**距離換算的唯一係數住在這裡**，呼叫端不得自己乘 0.621371
    /// （2026-09-01 收斂：`UnitManager` 與 `App2WorkoutDetailProjection.distanceMetric`
    /// 各寫一份，其餘十幾處乾脆寫死 `km`）。
    func convertedDistance(_ km: Double) -> Double {
        switch self {
        case .metric: return km
        case .imperial: return km * 0.621371
        }
    }

    /// `12.4 km`／`7.7 mi`
    func formatDistance(_ km: Double) -> String {
        String(format: "%.1f %@", convertedDistance(km), distanceSuffix)
    }

    /// 配速數字本身（`5:30`），**不含**單位字 —— 值與單位分兩個 `Text` 畫的版面要這個。
    func paceValue(secondsPerKm: Double) -> String {
        let rounded = max(Int(convertedPaceSeconds(secondsPerKm).rounded()), 0)
        return String(format: "%d:%02d", rounded / 60, rounded % 60)
    }

    /// 秒／km → `5:30/km`／`8:51/mi`
    func formatPace(secondsPerKm: Double) -> String {
        paceValue(secondsPerKm: secondsPerKm) + paceSuffix
    }

    /// 後端給的是**每公里** `mm:ss` 字串；解析後走同一條換算。
    /// 解析不出來就原樣回傳（不猜、不硬接單位）。
    func formatPaceString(_ pace: String?) -> String {
        guard let pace else { return "--:--/\(distanceSuffix)" }
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return pace }
        return formatPace(secondsPerKm: Double(components[0] * 60 + components[1]))
    }
}

// MARK: - UnitManager

@MainActor
class UnitManager: ObservableObject {
    static let shared = UnitManager()

    /// 單位制設定的唯一 key。`UnitSystem.current`（nonisolated 讀）也用它，
    /// **寫入者只有這個類別**。
    static let defaultsKey = "unit_system_preference"

    @Published var currentUnitSystem: UnitSystem {
        didSet {
            saveToDefaults()
        }
    }

    private init() {
        self.currentUnitSystem = UnitSystem.current
    }

    // 下面四支只是把當前設定餵給 `UnitSystem` 上的同名純函式。
    // **換算規則不在這裡**（見 `UnitSystem`）——投影層拿得到 `UnitSystem`
    // 卻拿不到 MainActor 的 `shared`，兩邊必須是同一份實作。

    /// Format a distance value (in km) to a display string with unit suffix
    func formatDistance(_ km: Double) -> String {
        currentUnitSystem.formatDistance(km)
    }

    /// 轉換距離數字（不帶單位字串）
    func convertedDistance(_ km: Double) -> Double {
        currentUnitSystem.convertedDistance(km)
    }

    /// 格式化配速（輸入：秒/km，輸出：含單位的配速字串如 "5:30/km" 或 "8:51/mi"）
    func formatPace(secondsPerKm: Double) -> String {
        currentUnitSystem.formatPace(secondsPerKm: secondsPerKm)
    }

    /// 格式化配速（輸入："mm:ss" 字串，輸出：含單位如 "5:30/km"）
    func formatPaceString(_ pace: String?) -> String {
        currentUnitSystem.formatPaceString(pace)
    }

    func saveToDefaults() {
        UserDefaults.standard.set(currentUnitSystem.rawValue, forKey: Self.defaultsKey)
    }
}
