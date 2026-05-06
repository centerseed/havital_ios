import Combine
import XCTest
@testable import paceriz_dev

@MainActor
final class WorkoutDetailUnitConversionTests: XCTestCase {
    override func tearDown() {
        UnitManager.shared.currentUnitSystem = .metric
        super.tearDown()
    }

    func testPaceUsesMinutesPerMileWhenUnitSystemIsImperial() {
        UnitManager.shared.currentUnitSystem = .imperial

        let viewModel = WorkoutDetailViewModelV2(
            workout: WorkoutV2(
                id: "workout-imperial-pace",
                provider: "apple_health",
                activityType: "running",
                startTimeUtc: "2026-05-01T00:00:00Z",
                endTimeUtc: "2026-05-01T00:50:00Z",
                durationSeconds: 3000,
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
            ),
            repository: WorkoutDetailUnitConversionMockRepository()
        )

        XCTAssertEqual(viewModel.pace, "8:02/mi")
    }
}

private final class WorkoutDetailUnitConversionMockRepository: WorkoutRepository {
    let refreshSubject = PassthroughSubject<Void, Never>()
    var workoutsDidRefresh: AnyPublisher<Void, Never> { refreshSubject.eraseToAnyPublisher() }
    var workoutsDidUpdateNotification: Notification.Name { Notification.Name("WorkoutDetailUnitConversionMockRepository") }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] { [] }
    func getAllWorkouts() -> [WorkoutV2] { [] }
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] { [] }
    func getAllWorkoutsAsync() async -> [WorkoutV2] { [] }
    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] { [] }
    func refreshWorkouts() async throws -> [WorkoutV2] { [] }
    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse { emptyResponse(pageSize: pageSize) }
    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse { emptyResponse(pageSize: pageSize) }
    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse { emptyResponse(pageSize: pageSize) }
    func getWorkout(id: String) async throws -> WorkoutV2 { throw WorkoutRepositoryError.dataSourceUnavailable }
    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail { throw WorkoutRepositoryError.dataSourceUnavailable }
    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail { throw WorkoutRepositoryError.dataSourceUnavailable }
    func clearWorkoutDetailCache(id: String) async {}
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 { workout }
    func updateTrainingNotes(id: String, notes: String) async throws {}
    func deleteWorkout(id: String) async throws {}
    func invalidateRefreshCooldown() {}
    func clearCache() async {}
    func preloadData() async {}

    private func emptyResponse(pageSize: Int) -> WorkoutListResponse {
        WorkoutListResponse(
            workouts: [],
            pagination: PaginationInfo(
                nextCursor: nil,
                prevCursor: nil,
                hasMore: false,
                hasNewer: false,
                oldestId: nil,
                newestId: nil,
                totalItems: 0,
                pageSize: pageSize
            )
        )
    }
}
