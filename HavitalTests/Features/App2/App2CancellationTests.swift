//
//  App2CancellationTests.swift
//  HavitalTests
//
//  被取消的載入輪不得發布任何 UI 結果（AGENTS.md 陷阱 5；2026-08-29 外審 D04/E03）：
//  optional-load 路徑用 `try?` 把取消折成 nil，若不另外判 `Task.isCancelled`，
//  部分成功＋部分被取消會組出殘缺畫面蓋掉舊資料。
//
//  records VM 的取消行為已在 `App2RecordsViewModelTests`（URLError(.cancelled) 樣式）；
//  這裡補的是 period summary 與 metric detail 兩條 optional-load 路徑的真實 task 取消。
//

import XCTest
@testable import paceriz_dev

@MainActor
final class App2CancellationTests: XCTestCase {

    // MARK: - Hanging fakes（掛住直到被取消，取消時 Task.sleep 自己丟 CancellationError）

    private final class HangingStatsSource: WorkoutStatsDataSourceProtocol {
        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    private final class ImmediateStatsSource: WorkoutStatsDataSourceProtocol {
        func fetchWorkoutStats(days: Int, weeks: Int?) async throws -> WorkoutStatsResponse {
            let json = """
            { "data": { "total_workouts": 0, "total_distance_km": 0.0,
                        "provider_distribution": {}, "activity_type_distribution": {},
                        "period_days": 30 } }
            """
            return try JSONDecoder().decode(WorkoutStatsResponse.self, from: Data(json.utf8))
        }

        func fetchRecentWorkouts(pageSize: Int) async throws -> [WorkoutV2] { [] }

        func fetchWorkoutsPage(pageSize: Int?, cursor: String?) async throws -> WorkoutListResponse {
            WorkoutListResponse(
                workouts: [],
                pagination: PaginationInfo(
                    nextCursor: nil, prevCursor: nil, hasMore: false, hasNewer: false,
                    oldestId: nil, newestId: nil, totalItems: nil, pageSize: pageSize
                )
            )
        }
    }

    private final class HangingHealthSource: HealthDailyDataSourceProtocol {
        func fetchHealthDaily(limit: Int) async throws -> HealthDailyResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    private final class HangingVdotSource: VDOTDataSourceProtocol {
        func getVDOTs(limit: Int) async throws -> VDOTResponse {
            try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            throw CancellationError()
        }
    }

    // MARK: - 訓練量詳情：stats 成功、health 被取消 → 不發布

    func test_volumeDetail_cancelledLoadDoesNotPublish() async {
        let vm = App2VolumeDetailViewModel(
            insight: App2Insight(id: "volume", label: "訓練量", value: nil, direction: .unknown, verdict: nil),
            narrative: nil,
            workoutDataSource: ImmediateStatsSource(),
            healthDataSource: HangingHealthSource(),
            profileRepository: nil
        )

        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.detail, "被取消的載入輪不得發布 detail")
    }

    // MARK: - 期間總結：全部載入被取消 → 不發布

    func test_periodSummary_cancelledLoadDoesNotPublish() async {
        let card = App2PlanEndCard(
            kind: .race, raceName: "測試賽", raceDate: "2026-12-06",
            distanceLabel: nil, totalWeeks: 2, targetTime: nil,
            estimatedFinish: nil, actualFinish: nil, narrative: nil
        )
        let vm = App2PeriodSummaryViewModel(
            card: card,
            planRepository: MockTrainingPlanV2Repository(),
            workoutDataSource: HangingStatsSource(),
            vdotDataSource: HangingVdotSource()
        )

        let load = Task { await vm.revalidate() }
        try? await Task.sleep(nanoseconds: 200_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(vm.summary, "被取消的載入輪不得發布 summary")
    }
}
