//
//  MockWorkoutRepository.swift
//  HavitalTests
//
//  Mock implementation of WorkoutRepository for testing
//

import Combine
import Foundation
@testable import paceriz_dev

class MockWorkoutRepository: WorkoutRepository {

    // MARK: - Test Data

    var workoutsToReturn: [WorkoutV2] = []
    /// `getWorkoutDetail` / `refreshWorkoutDetail` 要回的那一份。nil ＝ 照舊丟 notFound。
    var detailToReturn: WorkoutV2Detail?
    var errorToThrow: Error?

    // MARK: - Call Tracking

    var getWorkoutsInDateRangeCallCount = 0
    var getWorkoutsInDateRangeLastParams: (startDate: Date, endDate: Date)?

    var getAllWorkoutsCallCount = 0
    var getWorkoutsCallCount = 0
    var getWorkoutsLastParams: (limit: Int?, offset: Int?)?
    var refreshWorkoutsCallCount = 0
    /// `refreshWorkouts` 成功前讓測試把 mock 的本地資料換成遠端新值。
    var onRefreshWorkouts: (() -> Void)?
    var getWorkoutCallCount = 0
    var syncWorkoutCallCount = 0
    var deleteWorkoutCallCount = 0
    var deleteWorkoutLastId: String?
    var clearCacheCallCount = 0
    var preloadDataCallCount = 0

    /// 補史往返的次數 —— 課表頁切週卡頓的那一段（T-0374）。
    var ensureMonthLoadedCallCount = 0
    var ensureMonthLoadedLastParams: (year: Int, month: Int)?
    /// 讓測試把補史掛在半空中：用來證明「切週沒有在等它」。
    /// nil ＝ 立刻返回（既有測試不受影響）。
    var ensureMonthLoadedGate: (() async -> Void)?

    // MARK: - WorkoutRepository Implementation

    var workoutsDidUpdateNotification: Notification.Name {
        return .workoutsDidUpdate
    }

    var workoutsDidRefresh: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
    /// Track B 背景刷新完成的回寫（F5）。**測試可以自己推一次**——
    /// `emitDetailRefresh(_:)`。沒人推就等於恆空，既有使用這個 mock 的測試不受影響。
    private let detailRefreshSubject = PassthroughSubject<WorkoutV2Detail, Never>()
    var workoutDetailDidRefresh: AnyPublisher<WorkoutV2Detail, Never> {
        detailRefreshSubject.eraseToAnyPublisher()
    }

    /// 從外面推一次 Track B 背景刷新（模擬 repository 把刷回來的那一份交出去）。
    func emitDetailRefresh(_ detail: WorkoutV2Detail) { detailRefreshSubject.send(detail) }

    /// `refreshWorkoutDetail` 一進來就會呼叫的 hook（nil ＝ 不做任何事，既有測試不受影響）。
    var onRefreshWorkoutDetail: (() -> Void)?
    var workoutsPaginationDidUpdate: AnyPublisher<PaginationInfo, Never> { Empty().eraseToAnyPublisher() }
    func getCachedPagination() -> PaginationInfo? { nil }

    func getWorkoutsInDateRange(startDate: Date, endDate: Date) -> [WorkoutV2] {
        getWorkoutsInDateRangeCallCount += 1
        getWorkoutsInDateRangeLastParams = (startDate, endDate)
        return workoutsToReturn
    }

    func getAllWorkouts() -> [WorkoutV2] {
        getAllWorkoutsCallCount += 1
        return workoutsToReturn
    }

    // MARK: - New Async Methods

    func getWorkoutsInDateRangeAsync(startDate: Date, endDate: Date) async -> [WorkoutV2] {
        getWorkoutsInDateRangeCallCount += 1
        getWorkoutsInDateRangeLastParams = (startDate, endDate)
        return workoutsToReturn
    }

    func getAllWorkoutsAsync() async -> [WorkoutV2] {
        getAllWorkoutsCallCount += 1
        return workoutsToReturn
    }

    func getLatestWorkout() async throws -> WorkoutV2? {
        if let error = errorToThrow { throw error }
        return workoutsToReturn.sorted { $0.endDate > $1.endDate }.first
    }

    func ensureMonthLoaded(year: Int, month: Int) async {
        ensureMonthLoadedCallCount += 1
        ensureMonthLoadedLastParams = (year, month)
        if let ensureMonthLoadedGate { await ensureMonthLoadedGate() }
    }

    // MARK: - Pagination Methods

    func loadInitialWorkouts(pageSize: Int) async throws -> WorkoutListResponse {
        if let error = errorToThrow {
            throw error
        }
        let pagination = PaginationInfo(
            nextCursor: nil,
            prevCursor: nil,
            hasMore: false,
            hasNewer: false,
            oldestId: nil,
            newestId: nil,
            totalItems: workoutsToReturn.count,
            pageSize: pageSize
        )
        return WorkoutListResponse(workouts: workoutsToReturn, pagination: pagination)
    }

    func loadMoreWorkouts(afterCursor: String, pageSize: Int) async throws -> WorkoutListResponse {
        if let error = errorToThrow {
            throw error
        }
        let pagination = PaginationInfo(
            nextCursor: nil,
            prevCursor: afterCursor,
            hasMore: false,
            hasNewer: false,
            oldestId: nil,
            newestId: nil,
            totalItems: workoutsToReturn.count,
            pageSize: pageSize
        )
        return WorkoutListResponse(workouts: workoutsToReturn, pagination: pagination)
    }

    func refreshLatestWorkouts(beforeCursor: String?, pageSize: Int) async throws -> WorkoutListResponse {
        if let error = errorToThrow {
            throw error
        }
        let pagination = PaginationInfo(
            nextCursor: nil,
            prevCursor: beforeCursor,
            hasMore: false,
            hasNewer: false,
            oldestId: nil,
            newestId: nil,
            totalItems: workoutsToReturn.count,
            pageSize: pageSize
        )
        return WorkoutListResponse(workouts: workoutsToReturn, pagination: pagination)
    }

    func getWorkouts(limit: Int?, offset: Int?) async throws -> [WorkoutV2] {
        getWorkoutsCallCount += 1
        getWorkoutsLastParams = (limit, offset)
        if let error = errorToThrow {
            throw error
        }
        return workoutsToReturn
    }

    func refreshWorkouts() async throws -> [WorkoutV2] {
        refreshWorkoutsCallCount += 1
        onRefreshWorkouts?()
        if let error = errorToThrow {
            throw error
        }
        return workoutsToReturn
    }

    func getWorkout(id: String) async throws -> WorkoutV2 {
        getWorkoutCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        guard let workout = workoutsToReturn.first(where: { $0.id == id }) else {
            throw DomainError.notFound("Workout not found")
        }
        return workout
    }

    func syncWorkout(_ workout: WorkoutV2) async throws -> WorkoutV2 {
        syncWorkoutCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        return workout
    }

    func deleteWorkout(id: String) async throws {
        deleteWorkoutCallCount += 1
        deleteWorkoutLastId = id
        if let error = errorToThrow {
            throw error
        }
    }

    func getWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        if let error = errorToThrow {
            throw error
        }
        guard let detailToReturn else {
            throw DomainError.notFound("Mock not implemented")
        }
        return detailToReturn
    }

    func refreshWorkoutDetail(id: String) async throws -> WorkoutV2Detail {
        // 讓測試在這次強制刷新**還在飛的時候**插隊做事（例如推一次 Track B 背景刷新），
        // 用來重現「手動刷新的 loading 期間收到背景事件」那個競態。
        if let onRefreshWorkoutDetail {
            onRefreshWorkoutDetail()
            // observer 走 `receive(on: DispatchQueue.main)`，讓那一跳在回應之前先落地，
            // 否則測不到「背景那份已經進了 pending」的狀態。
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if let error = errorToThrow {
            throw error
        }
        guard let detailToReturn else {
            throw DomainError.notFound("Mock not implemented")
        }
        return detailToReturn
    }

    func clearWorkoutDetailCache(id: String) async {
        // Mock implementation
    }

    func updateTrainingNotes(id: String, notes: String) async throws {
        if let error = errorToThrow {
            throw error
        }
    }

    var applyTreadmillCorrectionCallCount = 0
    var applyTreadmillCorrectionLastParams: (id: String, actualDistanceM: Double, avgInclinePercent: Double?, notes: String?)?
    var treadmillCorrectionDetailToReturn: WorkoutV2Detail?

    func applyTreadmillCorrection(
        id: String,
        actualDistanceM: Double,
        avgInclinePercent: Double?,
        notes: String?
    ) async throws -> WorkoutV2Detail {
        applyTreadmillCorrectionCallCount += 1
        applyTreadmillCorrectionLastParams = (id, actualDistanceM, avgInclinePercent, notes)
        if let error = errorToThrow { throw error }
        guard let detail = treadmillCorrectionDetailToReturn else {
            throw DomainError.notFound("Mock treadmill detail not configured")
        }
        return detail
    }

    func invalidateRefreshCooldown() {}

    func clearCache() async {
        clearCacheCallCount += 1
    }

    func preloadData() async {
        preloadDataCallCount += 1
    }

    // MARK: - Reset

    func reset() {
        workoutsToReturn = []
        errorToThrow = nil
        getWorkoutsInDateRangeCallCount = 0
        getWorkoutsInDateRangeLastParams = nil
        getAllWorkoutsCallCount = 0
        getWorkoutsCallCount = 0
        refreshWorkoutsCallCount = 0
        onRefreshWorkouts = nil
        getWorkoutCallCount = 0
        syncWorkoutCallCount = 0
        deleteWorkoutCallCount = 0
        clearCacheCallCount = 0
        preloadDataCallCount = 0
        ensureMonthLoadedCallCount = 0
        ensureMonthLoadedLastParams = nil
        ensureMonthLoadedGate = nil
        applyTreadmillCorrectionCallCount = 0
        applyTreadmillCorrectionLastParams = nil
        treadmillCorrectionDetailToReturn = nil
    }
}
