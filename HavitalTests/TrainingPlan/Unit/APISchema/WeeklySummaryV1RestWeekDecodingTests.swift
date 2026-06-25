import XCTest
@testable import paceriz_dev

/// V1 週回顧（WeeklyTrainingSummary）休息週解碼容錯測試。
///
/// 來源：prod DecodingError（過去 12h 4 筆 WeeklyTrainingSummary 解碼失敗）。
/// 休息週後端回應的 `data` 物件實況（見 Fixtures/WeeklySummary/v1_rest_week.json）：
///   - 省略 `id` 欄位（missingKey）
///   - 省略整個 `heart_rate` 物件
///   - `pace.average` 為 null（nullValue）
/// 舊 DTO 把 id / pace.average / heart_rate 宣告成非 optional → 整包 throw，
/// 導致該用戶週回顧頁完全開不出來（Swift Codable 全有或全無）。
///
/// fixture 走外部 JSON 檔（與 WeeklySummaryV2DecodingTests 同慣例）：
/// 避免在 Swift 寫死 CJK 字串（i18n pre-commit gate）。
final class WeeklySummaryV1RestWeekDecodingTests: XCTestCase {

    private func loadFixture(_ name: String) throws -> Data {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixtureURL = testDir.appendingPathComponent("Fixtures/WeeklySummary/\(name).json")
        return try Data(contentsOf: fixtureURL)
    }

    func test_restWeek_decodes_without_throwing() throws {
        let data = try loadFixture("v1_rest_week")

        // 修復前：缺 id / 缺 heart_rate / pace.average=null → throw DecodingError
        let summary = try JSONDecoder().decode(WeeklyTrainingSummary.self, from: data)

        // 缺 id → 預設空字串，不再 throw
        XCTAssertEqual(summary.id, "")
        XCTAssertEqual(summary.trainingCompletion.percentage, 0.0, accuracy: 0.001)

        // pace.average=null → 預設 ""；trend 後端有給 → 照常解出（非預設空字串）
        XCTAssertEqual(summary.trainingAnalysis.pace.average, "")
        XCTAssertFalse(summary.trainingAnalysis.pace.trend.isEmpty)

        // heart_rate 整個缺 → 預設物件（數值 0），不 throw
        XCTAssertEqual(summary.trainingAnalysis.heartRate.average, 0, accuracy: 0.001)
        XCTAssertEqual(summary.trainingAnalysis.heartRate.max, 0, accuracy: 0.001)

        // distance 正常解
        XCTAssertEqual(summary.trainingAnalysis.distance.total, 0.0, accuracy: 0.001)
    }
}
