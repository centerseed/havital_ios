import Foundation

// MARK: - DailyStateRepository
/// Domain Layer — 今日狀態資料存取契約。ViewModel 依賴此 protocol，非 Impl。
protocol DailyStateRepository {
    func fetchTodayState() async throws -> DailyStateCard
    /// 上一次成功取得的今日狀態（顯示層快照，不打網路，沒有就是 nil）。
    /// 2.0 冷啟先用它把狀況卡渲染出來，`fetchTodayState()` 回來後再靜默替換。
    /// **不是第二份真相**：只有畫面讀它，任何寫入路徑都不讀。
    func cachedTodayState() -> DailyStateCard?
    /// 套用指標跑校準 → 回新完賽預估秒數(nil = 重算未即時回,下次自然重算補)。
    func applyBenchmark(_ calibration: SameDayBenchmarkCalibration) async throws -> Int?
    /// 預約下次指標跑(用戶選幾週後,排 milestone)→ 回排定週次(nil = 後端未回)。
    func scheduleNextBenchmark(_ calibration: SameDayBenchmarkCalibration, weeksAhead: Int) async throws -> Int?
}
