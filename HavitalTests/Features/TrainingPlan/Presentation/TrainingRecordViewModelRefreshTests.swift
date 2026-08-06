//
//  TrainingRecordViewModelRefreshTests.swift
//  HavitalTests
//
//  T-0460 regression：下拉刷新只回後端第一頁，不得砍掉「載入更多」已堆出的較舊紀錄。
//  對應 SPEC-training-record-and-workout-detail.md AC-RECORD-02
//  （「重新請求最新資料並更新目前列表」——取代成第一頁不是更新）。
//
//  與 WorkoutLocalDataSourceTests.testUpsertWorkouts_SmallBatch_DoesNotShrinkCache 的分工：
//  那支釘 cache 層「小批次 upsert 不縮清單」；這支釘 ViewModel 層的 state 不被 API
//  回傳的第一頁蓋掉——T-0460 正是 cache 沒縮、但 ViewModel 沒讀 cache 全量造成的。
//

import XCTest
@testable import paceriz_dev

@MainActor
final class TrainingRecordViewModelRefreshTests: XCTestCase {

    private var mockRepository: MockWorkoutRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockWorkoutRepository()
    }

    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }

    /// AC-RECORD-02：已載入 5 筆時刷新只回最新 2 筆，列表仍須保有 5 筆。
    func testRefreshDoesNotTruncateAlreadyLoadedWorkouts() async {
        let loaded = makeWorkouts(count: 5)   // workout_0 最舊 … workout_4 最新
        mockRepository.workoutsToReturn = loaded

        let viewModel = TrainingRecordViewModel(repository: mockRepository)
        await viewModel.loadWorkouts()
        XCTAssertEqual(viewModel.workouts.count, 5, "precondition: list should hold 5 workouts")

        // 刷新只回後端第一頁 = 最新的 2 筆
        mockRepository.workoutsToReturn = [loaded[4], loaded[3]]
        await viewModel.refreshWorkouts()

        XCTAssertEqual(
            viewModel.workouts.count, 5,
            "refresh returning only page 1 must not drop older workouts (T-0460)"
        )
        XCTAssertEqual(
            Set(viewModel.workouts.map(\.id)), Set(loaded.map(\.id)),
            "refresh must still cover every original workout id"
        )
    }

    /// 刷新帶回全新的一筆時，必須併進列表且排在最前面。
    func testRefreshMergesNewestWorkoutIntoExistingList() async {
        let loaded = makeWorkouts(count: 3, dayOffset: 1)
        mockRepository.workoutsToReturn = loaded

        let viewModel = TrainingRecordViewModel(repository: mockRepository)
        await viewModel.loadWorkouts()

        let newest = makeWorkout(id: "workout_new", day: 20)
        mockRepository.workoutsToReturn = [newest]
        await viewModel.refreshWorkouts()

        XCTAssertEqual(viewModel.workouts.count, 4, "new workout should be merged in, not replace the list")
        XCTAssertEqual(viewModel.workouts.first?.id, "workout_new", "newest workout should sort first")
    }

    /// 刷新那一頁涵蓋的範圍內，後端已刪除的紀錄必須跟著消失，不得留成幽靈。
    /// （T-0460 judge 回合 1 的 P1：只做 union 會讓刪掉的近期紀錄永遠留在列表上。）
    func testRefreshDropsWorkoutsDeletedWithinRefreshedPage() async {
        let loaded = makeWorkouts(count: 5)   // workout_0 最舊 … workout_4 最新
        mockRepository.workoutsToReturn = loaded

        let viewModel = TrainingRecordViewModel(repository: mockRepository)
        await viewModel.loadWorkouts()
        XCTAssertEqual(viewModel.workouts.count, 5, "precondition: list should hold 5 workouts")

        // 後端把 workout_3 刪了：第一頁涵蓋 workout_4…workout_3 的時間範圍，但只回 workout_4
        mockRepository.workoutsToReturn = [loaded[4]]
        await viewModel.refreshWorkouts()

        XCTAssertFalse(
            viewModel.workouts.contains { $0.id == "workout_3" },
            "workout deleted server-side within the refreshed page must disappear"
        )
        XCTAssertEqual(
            viewModel.workouts.map(\.id), ["workout_4", "workout_2", "workout_1", "workout_0"],
            "older workouts outside the refreshed page must survive"
        )
    }

    /// 刷新回空（例如後端暫時無資料）時，不得把已載入的列表清成 empty。
    func testRefreshWithEmptyResponseKeepsExistingWorkouts() async {
        mockRepository.workoutsToReturn = makeWorkouts(count: 3)

        let viewModel = TrainingRecordViewModel(repository: mockRepository)
        await viewModel.loadWorkouts()

        mockRepository.workoutsToReturn = []
        await viewModel.refreshWorkouts()

        XCTAssertEqual(viewModel.workouts.count, 3, "an empty refresh must not clear already-loaded workouts")
    }

    // MARK: - Helpers

    private func makeWorkouts(count: Int, dayOffset: Int = 1) -> [WorkoutV2] {
        (0..<count).map { index in
            makeWorkout(id: "workout_\(index)", day: dayOffset + index)
        }
    }

    private func makeWorkout(id: String, day: Int) -> WorkoutV2 {
        let dayString = String(format: "%02d", day)
        return WorkoutV2(
            id: id,
            provider: "apple_health",
            activityType: "running",
            startTimeUtc: "2026-01-\(dayString)T10:00:00Z",
            endTimeUtc: "2026-01-\(dayString)T11:00:00Z",
            durationSeconds: 3600,
            distanceMeters: 10000,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: "Apple Watch",
            basicMetrics: nil,
            advancedMetrics: nil,
            createdAt: "2026-01-\(dayString)T11:00:00Z",
            schemaVersion: "2.0",
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }
}
