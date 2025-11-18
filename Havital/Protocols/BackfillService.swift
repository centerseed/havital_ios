// Havital/Protocols/BackfillService.swift
import Foundation

/// Backfill 服務協議（Garmin 和 Strava 共用）
protocol BackfillService {
    /// 觸發 Backfill
    /// - Parameters:
    ///   - startDate: 開始日期（YYYY-MM-DD 格式）
    ///   - days: 天數（最多 90 天）
    /// - Returns: Backfill 回應，包含 backfill_id 和狀態
    func triggerBackfill(startDate: String, days: Int) async throws -> BackfillResponse

    /// 查詢 Backfill 狀態
    /// - Parameter backfillId: Backfill ID
    /// - Returns: Backfill 狀態回應，包含進度和完成狀態
    func getBackfillStatus(backfillId: String) async throws -> BackfillStatusResponse
}
