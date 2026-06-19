import XCTest
@testable import paceriz_dev

final class WeeklyMileageDialogBuilderTests: XCTestCase {

    func test_sumsDistance() {
        let ws = [
            WorkoutV2.fixture(distanceMeters: 5000),
            WorkoutV2.fixture(distanceMeters: 8200)
        ]
        XCTAssertEqual(WeeklyMileageDialogBuilder.build(from: ws), "你這週已經跑了 13.2 公里，共 2 次。")
    }

    func test_empty_speaksZero() {
        XCTAssertEqual(WeeklyMileageDialogBuilder.build(from: []), "你這週還沒有跑步紀錄。")
    }
}

// MARK: - Fixture

extension WorkoutV2 {
    /// 最小測試工廠。僅設定與 WeeklyMileageDialogBuilder 相關的欄位，其餘填入佔位值。
    static func fixture(distanceMeters: Double) -> WorkoutV2 {
        WorkoutV2(
            id: UUID().uuidString,
            provider: "garmin",
            activityType: "running",
            startTimeUtc: nil,
            endTimeUtc: nil,
            durationSeconds: 1800,
            distanceMeters: distanceMeters,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: nil,
            basicMetrics: nil,
            advancedMetrics: nil,
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }
}
