import Foundation

// MARK: - HeartRateRecomputeRepository
/// 改心率後重算過去單堂跑力的後端出口（`SPEC-hr-zones` §5.5、§5.8）。
/// Domain Layer - 只定義介面。
protocol HeartRateRecomputeRepository {
    /// 排入重算最近 `days` 個當地日。409／422 是後端的正常回答，映射成 outcome；其餘失敗照實 throw。
    func startRecompute(days: HeartRateRecomputeDays) async throws -> HeartRateRecomputeOutcome

    /// 最近一次重算工作（進度與結果）；從沒跑過 `job` 為 nil。
    func latestStatus() async throws -> HeartRateRecomputeStatus

    /// 手錶最大心率偏差提醒＋手錶自動更新說明。
    func watchCheck() async throws -> HeartRateWatchCheck

    /// 使用者按「先不用」：後端兩週內不再提醒。
    func dismissWatchReminder() async throws
}
