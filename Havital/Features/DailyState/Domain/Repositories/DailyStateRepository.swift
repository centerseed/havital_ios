import Foundation

// MARK: - DailyStateRepository
/// Domain Layer — 今日狀態資料存取契約。ViewModel 依賴此 protocol，非 Impl。
protocol DailyStateRepository {
    func fetchTodayState() async throws -> DailyStateCard
}
