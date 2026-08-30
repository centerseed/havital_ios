import Combine
import XCTest
@testable import paceriz_dev

/// Track B 背景刷新回寫畫面時，**圖表資料要整份換掉**（8/28 盤點 F5；外審 D04／E03／E11）。
///
/// `processTimeSeriesData` 只在對應欄位有值時才寫，缺席的欄位它不碰。強制刷新那條路徑
/// 本來就先清空再處理，背景回寫那條沒有——於是刷回來的那一份少了某個序列時，畫面上留著
/// 上一份的曲線，心率 Y 軸也停在上一份的範圍。使用者看到的是一張已經不屬於這筆 workout
/// 的圖，而且它不會自己好。
///
/// `TreadmillCorrectionTests` 測的是 repository **發出**那一份（F5 的上半段）；這裡測的是
/// ViewModel **收到之後**做了什麼（下半段）。
@MainActor
final class WorkoutDetailBackgroundRefreshTests: XCTestCase {

    func testBackgroundRefreshWithoutTimeSeriesClearsStaleSeriesAndAxis() async {
        let repository = MockWorkoutRepository()
        repository.detailToReturn = Self.detail(
            id: "workout-refresh",
            heartRates: [150, 160, 170],
            cadences: [180, 182, 184]
        )

        let viewModel = WorkoutDetailViewModelV2(
            workout: Self.workout(id: "workout-refresh"),
            repository: repository
        )
        await viewModel.loadWorkoutDetail()

        XCTAssertEqual(viewModel.heartRates.count, 3, "前提：第一份 payload 有心率序列")
        XCTAssertEqual(viewModel.cadences.count, 3, "前提：第一份 payload 有步頻序列")
        XCTAssertNotEqual(
            viewModel.yAxisRange.min,
            WorkoutDetailViewModelV2.defaultHeartRateAxisRange.min,
            "前提：心率 Y 軸已依第一份序列算過"
        )

        // 刷回來的那一份完全沒有 time_series（後端重算中、或那一筆本來就沒有明細）。
        repository.emitDetailRefresh(Self.detail(id: "workout-refresh", heartRates: nil, cadences: nil))
        await Self.settle()

        XCTAssertTrue(viewModel.heartRates.isEmpty, "新的一份沒有心率，舊曲線不得留在畫面上")
        XCTAssertTrue(viewModel.cadences.isEmpty, "新的一份沒有步頻，舊曲線不得留在畫面上")
        XCTAssertEqual(
            viewModel.yAxisRange.min,
            WorkoutDetailViewModelV2.defaultHeartRateAxisRange.min,
            "沒有心率序列時 Y 軸要退回預設，不留上一份的範圍"
        )
    }

    /// 部分欄位缺席也是同一條：刷回來的那一份有心率、沒有步頻，步頻那張圖就該空掉。
    func testBackgroundRefreshWithPartialPayloadReplacesEverySeries() async {
        let repository = MockWorkoutRepository()
        repository.detailToReturn = Self.detail(
            id: "workout-partial",
            heartRates: [140, 145, 150],
            cadences: [176, 178, 180]
        )

        let viewModel = WorkoutDetailViewModelV2(
            workout: Self.workout(id: "workout-partial"),
            repository: repository
        )
        await viewModel.loadWorkoutDetail()
        XCTAssertEqual(viewModel.cadences.count, 3)

        repository.emitDetailRefresh(
            Self.detail(id: "workout-partial", heartRates: [100, 102, 104], cadences: nil)
        )
        await Self.settle()

        XCTAssertEqual(viewModel.heartRates.map(\.value), [100, 102, 104], "心率換成新的那一份")
        XCTAssertTrue(viewModel.cadences.isEmpty, "新的一份沒有步頻 → 舊步頻不得留著")
    }

    /// **主路徑還沒載完就回來的那一份不得被丟掉**（外審 D04／E03／E11）。
    ///
    /// repository 是一拿到快取就立刻丟 Track B，那一次刷新很可能比主路徑先回來。
    /// 舊版的 observer 要求 `state.hasData`，於是那一份被靜靜丟掉——而且**不會有第二次
    /// 事件**，畫面就停在剛剛那份 24 小時內的舊快取上，正是 F5 要修掉的症狀。
    func testRefreshArrivingBeforeInitialLoadIsAppliedAfterwards() async {
        let repository = MockWorkoutRepository()
        repository.detailToReturn = Self.detail(
            id: "workout-race",
            heartRates: [150, 160, 170],
            cadences: [180, 182, 184]
        )

        let viewModel = WorkoutDetailViewModelV2(
            workout: Self.workout(id: "workout-race"),
            repository: repository
        )

        // 主路徑都還沒開始，Track B 就回來了（後端那一份沒有步頻）。
        repository.emitDetailRefresh(
            Self.detail(id: "workout-race", heartRates: [90, 92, 94], cadences: nil)
        )
        await Self.settle()

        await viewModel.loadWorkoutDetail()
        await Self.settle()

        XCTAssertEqual(
            viewModel.heartRates.map(\.value), [90, 92, 94],
            "載完之後要補上那一份背景刷新，不是留著舊快取"
        )
        XCTAssertTrue(viewModel.cadences.isEmpty, "補套用時同樣是整份換掉")
    }

    /// 只認這一筆 workout 的刷新（repository 是 app 範圍的單例）。
    func testBackgroundRefreshForAnotherWorkoutIsIgnored() async {
        let repository = MockWorkoutRepository()
        repository.detailToReturn = Self.detail(
            id: "workout-mine",
            heartRates: [150, 160, 170],
            cadences: nil
        )

        let viewModel = WorkoutDetailViewModelV2(
            workout: Self.workout(id: "workout-mine"),
            repository: repository
        )
        await viewModel.loadWorkoutDetail()

        repository.emitDetailRefresh(Self.detail(id: "someone-else", heartRates: nil, cadences: nil))
        await Self.settle()

        XCTAssertEqual(viewModel.heartRates.count, 3, "別人的刷新不得清掉這一頁的圖")
    }

    // MARK: - Helpers

    /// `workoutDetailDidRefresh` 走 `receive(on: DispatchQueue.main)`，讓那一跳先跑完。
    private static func settle() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    private static func workout(id: String) -> WorkoutV2 {
        WorkoutV2(
            id: id,
            provider: "garmin",
            activityType: "running",
            startTimeUtc: "2026-05-29T08:00:00Z",
            endTimeUtc: "2026-05-29T09:00:00Z",
            durationSeconds: 3600,
            distanceMeters: 10000,
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

    /// 走 JSON 建，跟 `TreadmillCorrectionTests` 同一個理由：不綁 struct 的 init 簽名。
    private static func detail(
        id: String,
        heartRates: [Int]?,
        cadences: [Int]?
    ) -> WorkoutV2Detail {
        var json: [String: Any] = [
            "id": id,
            "provider": "garmin",
            "activity_type": "running",
            "start_time": "2026-05-29T08:00:00Z",
            "end_time": "2026-05-29T09:00:00Z",
            "duration_seconds": 3600,
            "distance_meters": 10000,
            "user_id": "user_1",
            "schema_version": "2.0",
            "source": "garmin",
            "storage_path": "/workouts/\(id)",
            "original_id": "orig_\(id)",
            "provider_user_id": "garmin_user_1"
        ]
        var series: [String: Any] = [:]
        if let heartRates { series["heart_rates_bpm"] = heartRates }
        if let cadences { series["cadences_spm"] = cadences }
        if !series.isEmpty {
            let count = max(heartRates?.count ?? 0, cadences?.count ?? 0)
            series["timestamps_s"] = Array(0..<count)
            json["time_series"] = series
        }
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(WorkoutV2Detail.self, from: data)
    }
}
