import XCTest
@testable import paceriz_dev

final class ReadinessDialogBuilderTests: XCTestCase {

    func test_highReadiness_speaksGo() {
        let r = TrainingReadinessResponse.fixture(overallStatusText: "狀態良好", overallScore: 85)
        XCTAssertEqual(ReadinessDialogBuilder.build(from: r), "你今天的訓練準備度是 85 分，狀態良好。")
    }

    func test_lowReadiness_speaksCaution() {
        let r = TrainingReadinessResponse.fixture(overallStatusText: "建議減量", overallScore: 40)
        XCTAssertEqual(ReadinessDialogBuilder.build(from: r), "你今天的訓練準備度是 40 分，建議減量。")
    }

    func test_nilScore_speaksStatusOnly() {
        let r = TrainingReadinessResponse.fixture(overallStatusText: "資料不足", overallScore: nil)
        XCTAssertEqual(ReadinessDialogBuilder.build(from: r), "你今天的訓練準備度資料尚未取得，資料不足。")
    }

    func test_nilStatusText_speaksScoreOnly() {
        let r = TrainingReadinessResponse.fixture(overallStatusText: nil, overallScore: 72)
        XCTAssertEqual(ReadinessDialogBuilder.build(from: r), "你今天的訓練準備度是 72 分。")
    }

    func test_allNil_speaksFallback() {
        let r = TrainingReadinessResponse.fixture(overallStatusText: nil, overallScore: nil)
        XCTAssertEqual(ReadinessDialogBuilder.build(from: r), "你今天的訓練準備度資料尚未取得。")
    }

    func test_fractionalScore_rounds() {
        let r = TrainingReadinessResponse.fixture(overallStatusText: "狀態良好", overallScore: 84.9)
        XCTAssertEqual(ReadinessDialogBuilder.build(from: r), "你今天的訓練準備度是 85 分，狀態良好。")
    }
}

// MARK: - Fixture

extension TrainingReadinessResponse {
    /// 最小測試工廠。僅設定與 ReadinessDialogBuilder 相關的欄位，其餘填入佔位值。
    static func fixture(overallStatusText: String?, overallScore: Double?) -> TrainingReadinessResponse {
        TrainingReadinessResponse(
            date: "2026-06-19",
            overallScore: overallScore,
            overallStatusText: overallStatusText,
            lastUpdatedTime: nil,
            metrics: nil,
            dataSource: nil,
            lastUpdated: nil,
            planType: nil
        )
    }
}
