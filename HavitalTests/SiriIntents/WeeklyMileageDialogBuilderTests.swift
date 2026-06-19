import XCTest
@testable import paceriz_dev

final class WeeklyMileageDialogBuilderTests: XCTestCase {

    // MARK: - V1 path (running array)

    func test_v1_sumsDistance() {
        let ws = [
            WorkoutV2.fixture(distanceMeters: 5000),
            WorkoutV2.fixture(distanceMeters: 8200)
        ]
        XCTAssertEqual(WeeklyMileageDialogBuilder.build(from: ws), "你這週已經跑了 13.2 公里，共 2 次。")
    }

    func test_v1_empty_speaksNoRunRecord() {
        XCTAssertEqual(WeeklyMileageDialogBuilder.build(from: []), "你這週還沒有跑步紀錄。")
    }

    // MARK: - V2 path (precomputed totals)

    /// V2 overload formats precomputed km from WeekMetricsCalculator without re-summing.
    func test_v2_formatsPrecomputedKm() {
        XCTAssertEqual(
            WeeklyMileageDialogBuilder.build(totalKm: 13.2, count: 2),
            "你這週已經訓練了 13.2 公里，共 2 次。"
        )
    }

    func test_v2_singleWorkout() {
        XCTAssertEqual(
            WeeklyMileageDialogBuilder.build(totalKm: 5.0, count: 1),
            "你這週已經訓練了 5.0 公里，共 1 次。"
        )
    }

    func test_v2_empty_speaksNoTrainingRecord() {
        XCTAssertEqual(
            WeeklyMileageDialogBuilder.build(totalKm: 0.0, count: 0),
            "你這週還沒有訓練紀錄。"
        )
    }

    /// Rounding: 1/3 km should display as 0.3 (not 0.333…).
    func test_v2_roundsToOneDecimal() {
        XCTAssertEqual(
            WeeklyMileageDialogBuilder.build(totalKm: 1.0 / 3.0, count: 1),
            "你這週已經訓練了 0.3 公里，共 1 次。"
        )
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
