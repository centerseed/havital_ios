#if DEBUG
import Combine
import SwiftUI

@MainActor
final class UITestWorkoutDetailRPEMockRepository: ObservableObject, WorkoutRepository {
    private let subject = PassthroughSubject<Void, Never>()
    private(set) var workout = UITestWorkoutDetailRPEMockRepository.makeWorkout(rpe: nil)

    @Published private(set) var currentRPE: Int?
    @Published private(set) var lastUpdateRPE: Int?
    @Published private(set) var updateCallCount = 0

    var workoutsDidRefresh: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
    var workoutsPaginationDidUpdate: AnyPublisher<PaginationInfo, Never> { Empty().eraseToAnyPublisher() }
    func getCachedPagination() -> PaginationInfo? { nil }
    var workoutsDidUpdateNotification: Notification.Name { Notification.Name("UITestWorkoutDetailRPEMockRepositoryDidUpdate") }

    init(initialRPE: Int?) {
        currentRPE = initialRPE
        workout = Self.makeWorkout(rpe: initialRPE)
    }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] { [workout] }
    func getAllWorkouts() -> [WorkoutV2] { [workout] }
    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] { [workout] }
    func getAllWorkoutsAsync() async -> [WorkoutV2] { [workout] }
    func getLatestWorkout() async throws -> WorkoutV2? { workout }
    func ensureMonthLoaded(year: Int, month: Int) async {}
    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] { [workout] }
    func refreshWorkouts() async throws -> [WorkoutV2] { [workout] }
    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(workouts: [workout], pagination: Self.pagination(pageSize: pageSize))
    }
    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(workouts: [], pagination: Self.pagination(pageSize: pageSize))
    }
    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse {
        WorkoutListResponse(workouts: [workout], pagination: Self.pagination(pageSize: pageSize))
    }
    func getWorkout(id: String) async throws -> WorkoutV2 { workout }
    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail { try Self.makeDetail(rpe: currentRPE) }
    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail { try Self.makeDetail(rpe: currentRPE) }
    func clearWorkoutDetailCache(id: String) async {}
    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 { workout }
    func updateTrainingNotes(id: String, notes: String) async throws {}

    func updateRPE(id: String, rpe: Int?) async throws {
        updateCallCount += 1
        lastUpdateRPE = rpe
        currentRPE = rpe
        workout = Self.makeWorkout(rpe: rpe)
        subject.send(())
    }

    func deleteWorkout(id: String) async throws {}
    func invalidateRefreshCooldown() {}
    func clearCache() async {}
    func preloadData() async {}

    private static func makeWorkout(rpe: Int?) -> WorkoutV2 {
        WorkoutV2(
            id: "uitest-workout-rpe",
            provider: "uitest",
            activityType: "running",
            startTimeUtc: "2026-05-06T00:00:00Z",
            endTimeUtc: "2026-05-06T00:35:00Z",
            durationSeconds: 2100,
            distanceMeters: 5000,
            distanceDisplay: 5.0,
            distanceUnit: "km",
            deviceName: nil,
            basicMetrics: BasicMetrics(totalDistanceM: 5000, totalDurationS: 2100),
            advancedMetrics: AdvancedMetrics(dynamicVdot: 38.0, tss: 42.0, rpe: rpe.map(Double.init)),
            createdAt: "2026-05-06T00:40:00Z",
            schemaVersion: "v2",
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }

    private static func pagination(pageSize: Int) -> PaginationInfo {
        PaginationInfo(
            nextCursor: nil,
            prevCursor: nil,
            hasMore: false,
            hasNewer: false,
            oldestId: "uitest-workout-rpe",
            newestId: "uitest-workout-rpe",
            totalItems: 1,
            pageSize: pageSize
        )
    }

    private static func makeDetail(rpe: Int?) throws -> WorkoutV2Detail {
        let rpeJSON = rpe.map(String.init) ?? "null"
        let json = """
        {
          "id": "uitest-workout-rpe",
          "provider": "uitest",
          "activity_type": "running",
          "sport_type": "running",
          "start_time": "2026-05-06T00:00:00Z",
          "end_time": "2026-05-06T00:35:00Z",
          "user_id": "uitest-user",
          "schema_version": "v2",
          "source": "uitest",
          "storage_path": "uitest/workouts/rpe.json",
          "created_at": "2026-05-06T00:40:00Z",
          "updated_at": "2026-05-06T00:40:00Z",
          "original_id": "uitest-original",
          "provider_user_id": "uitest-provider-user",
          "garmin_user_id": null,
          "webhook_storage_path": null,
          "basic_metrics": {
            "total_distance_m": 5000,
            "total_duration_s": 2100,
            "moving_duration_s": 2100,
            "avg_pace_s_per_km": 420
          },
          "advanced_metrics": {
            "dynamic_vdot": 38.0,
            "tss": 42.0,
            "training_type": "easy_run",
            "rpe": \(rpeJSON)
          },
          "time_series": null,
          "route_data": null,
          "device_info": null,
          "environment": null,
          "metadata": null,
          "laps": null,
          "daily_plan_summary": null,
          "ai_summary": null,
          "share_card_content": null,
          "training_notes": null
        }
        """
        return try JSONDecoder().decode(WorkoutV2Detail.self, from: Data(json.utf8))
    }
}

struct UITestWorkoutDetailRPEHostView: View {
    @StateObject private var repository: UITestWorkoutDetailRPEMockRepository

    init() {
        let initialRPE = Self.initialRPEFromEnvironment()
        let repository = UITestWorkoutDetailRPEMockRepository(initialRPE: initialRPE)
        DependencyContainer.shared.replace(repository as WorkoutRepository, for: WorkoutRepository.self)
        _repository = StateObject(wrappedValue: repository)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("UITest Workout Detail RPE Host")
                        .accessibilityIdentifier("UITest_RPE_HostTitle")
                    Text("current_rpe:\(repository.currentRPE.map(String.init) ?? "nil")")
                        .accessibilityIdentifier("UITest_RPE_CurrentValue")
                    Text("last_update_rpe:\(repository.lastUpdateRPE.map(String.init) ?? "nil")")
                        .accessibilityIdentifier("UITest_RPE_LastUpdate")
                    Text("update_call_count:\(repository.updateCallCount)")
                        .accessibilityIdentifier("UITest_RPE_UpdateCallCount")
                }
                .font(AppFont.caption())
                .padding(.vertical, 8)

                WorkoutDetailViewV2(workout: repository.workout)
            }
        }
    }

    private static func initialRPEFromEnvironment() -> Int? {
        let value = ProcessInfo.processInfo.environment["UITEST_RPE_INITIAL"] ?? "none"
        guard value != "none" else { return nil }
        return Int(value)
    }
}
#endif
