import XCTest
import Foundation
import HealthKit
@testable import paceriz_dev

/// AC-WORKOUT-LOG-06 ~ AC-WORKOUT-LOG-09
/// SPEC-workout-upload-error-noise-filtering
final class WorkoutUploadFailureDispositionACTests: XCTestCase {

    // MARK: - AC-WORKOUT-LOG-06 只有資料驗證失敗是 permanent

    func test_ac_workout_log_06_only_data_validation_failure_is_permanent() {
        XCTAssertEqual(
            AppleHealthWorkoutUploadService.classifyUploadFailureKind(WorkoutV2ServiceError.invalidWorkoutData),
            .permanent
        )
        XCTAssertEqual(
            AppleHealthWorkoutUploadService.classifyUploadFailureKind(HTTPError.badRequest("duration must be positive")),
            .permanent
        )
        XCTAssertEqual(
            AppleHealthWorkoutUploadService.classifyUploadFailureKind(BusinessError.validationFailed(["duration"])),
            .permanent
        )

        let transientErrors: [Error] = [
            WorkoutV2ServiceError.uploadTimedOut,
            WorkoutV2ServiceError.uploadInterrupted,
            WorkoutV2ServiceError.retryLimitReached,
            WorkoutV2ServiceError.dataSourceNotAppleHealth,
            URLError(.timedOut),
            URLError(.networkConnectionLost),
            HTTPError.timeout,
            HTTPError.serverError(503, "unavailable"),
            APIError.http(.serverError(500, "boom")),
            CancellationError(),
            NSError(domain: "Unknown", code: -1, userInfo: nil)
        ]
        for error in transientErrors {
            XCTAssertEqual(
                AppleHealthWorkoutUploadService.classifyUploadFailureKind(error),
                .transient,
                "expected transient for \(error)"
            )
        }
    }

    // MARK: - AC-WORKOUT-LOG-07 transient 失敗不得被永久放棄

    func test_ac_workout_log_07_transient_failure_is_never_permanently_abandoned() {
        let farPast = WorkoutUploadTracker.maxRetryCooldownSeconds + 1

        for retryCount in [1, 3, 4, 10, 50] {
            XCTAssertTrue(
                WorkoutUploadTracker.shouldRetryUpload(
                    retryCount: retryCount,
                    kind: .transient,
                    secondsSinceLastFailure: farPast
                ),
                "transient retryCount=\(retryCount) must stay retryable"
            )
        }
    }

    func test_ac_workout_log_07_permanent_failure_stops_at_max_attempts() {
        let farPast = WorkoutUploadTracker.maxRetryCooldownSeconds + 1

        XCTAssertTrue(
            WorkoutUploadTracker.shouldRetryUpload(
                retryCount: WorkoutUploadTracker.maxRetryAttempts - 1,
                kind: .permanent,
                secondsSinceLastFailure: farPast
            )
        )
        XCTAssertFalse(
            WorkoutUploadTracker.shouldRetryUpload(
                retryCount: WorkoutUploadTracker.maxRetryAttempts,
                kind: .permanent,
                secondsSinceLastFailure: farPast
            )
        )
    }

    func test_ac_workout_log_07_transient_cooldown_backs_off_and_caps() {
        let base = WorkoutUploadTracker.baseRetryCooldownSeconds
        let cap = WorkoutUploadTracker.maxRetryCooldownSeconds

        XCTAssertEqual(WorkoutUploadTracker.retryCooldownSeconds(retryCount: 1, kind: .transient), base)
        XCTAssertEqual(WorkoutUploadTracker.retryCooldownSeconds(retryCount: 2, kind: .transient), base * 2)
        XCTAssertEqual(WorkoutUploadTracker.retryCooldownSeconds(retryCount: 3, kind: .transient), base * 4)
        XCTAssertEqual(WorkoutUploadTracker.retryCooldownSeconds(retryCount: 99, kind: .transient), cap)
        XCTAssertEqual(WorkoutUploadTracker.retryCooldownSeconds(retryCount: 9, kind: .permanent), base)

        // 冷卻期內不重試，冷卻期滿就重試
        XCTAssertFalse(
            WorkoutUploadTracker.shouldRetryUpload(retryCount: 2, kind: .transient, secondsSinceLastFailure: base * 2 - 1)
        )
        XCTAssertTrue(
            WorkoutUploadTracker.shouldRetryUpload(retryCount: 2, kind: .transient, secondsSinceLastFailure: base * 2)
        )
    }

    // MARK: - AC-WORKOUT-LOG-08 舊版失敗記錄（無 kind）視為 transient

    func test_ac_workout_log_08_legacy_failure_record_without_kind_is_transient() {
        let legacyRecord: [String: Any] = [
            "retryCount": 3,
            "lastFailureTime": 1_756_000_000.0,
            "lastFailureReason": "timeout"
        ]

        XCTAssertEqual(WorkoutUploadTracker.failureKind(from: legacyRecord), .transient)
        XCTAssertTrue(
            WorkoutUploadTracker.shouldRetryUpload(
                retryCount: legacyRecord["retryCount"] as? Int ?? 0,
                kind: WorkoutUploadTracker.failureKind(from: legacyRecord),
                secondsSinceLastFailure: WorkoutUploadTracker.maxRetryCooldownSeconds + 1
            )
        )

        let permanentRecord: [String: Any] = ["retryCount": 3, "kind": "permanent"]
        XCTAssertEqual(WorkoutUploadTracker.failureKind(from: permanentRecord), .permanent)
    }

    // MARK: - AC-WORKOUT-LOG-09 跳過與未嘗試不進失敗帳本；錯誤訊息可辨識

    func test_ac_workout_log_09_skip_and_untried_are_not_recorded_as_failures() {
        for error in [WorkoutV2ServiceError.dataSourceNotAppleHealth, WorkoutV2ServiceError.retryLimitReached] {
            let handling = AppleHealthWorkoutUploadService.classifyBatchUploadError(error)
            XCTAssertFalse(handling.shouldMarkWorkoutFailed, "\(error) must not enter the failure ledger")
            XCTAssertFalse(handling.shouldLogToCloud, "\(error) must not be reported as a prod error")
        }
    }

    func test_ac_workout_log_09_transient_batch_failure_is_recorded_as_transient() {
        let handling = AppleHealthWorkoutUploadService.classifyBatchUploadError(URLError(.timedOut))
        XCTAssertTrue(handling.shouldMarkWorkoutFailed)
        XCTAssertEqual(handling.failureKind, .transient)

        let validation = AppleHealthWorkoutUploadService.classifyBatchUploadError(WorkoutV2ServiceError.invalidWorkoutData)
        XCTAssertTrue(validation.shouldMarkWorkoutFailed)
        XCTAssertEqual(validation.failureKind, .permanent)
    }

    func test_ac_workout_log_09_error_descriptions_are_distinguishable() {
        let errors: [WorkoutV2ServiceError] = [
            .invalidWorkoutData,
            .dataSourceNotAppleHealth,
            .uploadTimedOut,
            .uploadInterrupted,
            .retryLimitReached,
            .noHeartRateData
        ]
        let descriptions = errors.map { $0.errorDescription ?? "" }

        XCTAssertEqual(Set(descriptions).count, errors.count, "each failure must be distinguishable to the user")
        for description in descriptions {
            XCTAssertFalse(description.isEmpty)
            XCTAssertFalse(description.hasPrefix("workout_upload.error."), "missing localization: \(description)")
        }

        let invalidDataDescription = WorkoutV2ServiceError.invalidWorkoutData.errorDescription
        for error in errors.dropFirst() {
            XCTAssertNotEqual(error.errorDescription, invalidDataDescription)
        }
    }
}

// MARK: - Owner path（真實 tracker 持久化 ＋ 真實批次上傳）

/// AC-WORKOUT-LOG-07 / 08 / 09 走真實的 `WorkoutUploadTracker` 持久化與
/// `AppleHealthWorkoutUploadService.uploadWorkouts` 擁有者路徑，不用 in-memory 假資料。
final class WorkoutUploadFailureLedgerOwnerPathTests: XCTestCase {

    private let tracker = WorkoutUploadTracker.shared
    private var originalDataSource: DataSourceType!

    override func setUp() {
        super.setUp()
        tracker.clearAllFailureRecords()
        originalDataSource = UserPreferencesManager.shared.dataSourcePreference
    }

    override func tearDown() {
        tracker.clearAllFailureRecords()
        UserPreferencesManager.shared.dataSourcePreference = originalDataSource
        super.tearDown()
    }

    // MARK: AC-WORKOUT-LOG-07 持久化路徑

    func test_persisted_transient_failures_never_stop_being_retryable() {
        let workout = makeWorkout(durationSeconds: 1800, offsetDays: 1)
        let farFuture = Date().addingTimeInterval(WorkoutUploadTracker.maxRetryCooldownSeconds + 60)

        for attempt in 1...6 {
            tracker.markWorkoutAsFailed(workout, reason: "timeout", kind: .transient, apiVersion: .v2)
            XCTAssertEqual(tracker.failureRecord(for: workout)?["retryCount"] as? Int, attempt)
            XCTAssertTrue(
                tracker.shouldRetryUpload(workout, now: farFuture),
                "transient attempt \(attempt) must stay retryable"
            )
        }

        // 冷卻期內仍然節流
        XCTAssertFalse(tracker.shouldRetryUpload(workout, now: Date()))
    }

    func test_persisted_permanent_failures_stop_at_max_attempts() {
        let workout = makeWorkout(durationSeconds: 1800, offsetDays: 2)
        let farFuture = Date().addingTimeInterval(WorkoutUploadTracker.maxRetryCooldownSeconds + 60)

        for _ in 1..<WorkoutUploadTracker.maxRetryAttempts {
            tracker.markWorkoutAsFailed(workout, reason: "validation", kind: .permanent, apiVersion: .v2)
            XCTAssertTrue(tracker.shouldRetryUpload(workout, now: farFuture))
        }

        tracker.markWorkoutAsFailed(workout, reason: "validation", kind: .permanent, apiVersion: .v2)
        XCTAssertFalse(tracker.shouldRetryUpload(workout, now: farFuture))

        tracker.clearFailureRecord(workout)
        XCTAssertTrue(tracker.shouldRetryUpload(workout, now: Date()))
    }

    // MARK: AC-WORKOUT-LOG-08 舊版持久化記錄

    func test_persisted_legacy_record_without_kind_is_released() throws {
        let workout = makeWorkout(durationSeconds: 1800, offsetDays: 3)
        let stableId = tracker.generateStableWorkoutId(workout)
        let legacy: [String: Any] = [
            stableId: [
                "retryCount": WorkoutUploadTracker.maxRetryAttempts + 2,
                "lastFailureTime": Date().addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970,
                "lastFailureReason": "upload timeout",
                "firstFailureTime": Date().addingTimeInterval(-48 * 60 * 60).timeIntervalSince1970
            ]
        ]
        UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "failed_workouts_v2")

        let record = try XCTUnwrap(tracker.failureRecord(for: workout))
        XCTAssertNil(record["kind"])
        XCTAssertTrue(
            tracker.shouldRetryUpload(workout, now: Date()),
            "a pre-fix record must not stay permanently abandoned"
        )
    }

    // MARK: AC-WORKOUT-LOG-09 批次擁有者路徑

    func test_batch_upload_skip_does_not_enter_the_ledger() async {
        UserPreferencesManager.shared.dataSourcePreference = .garmin
        let service = AppleHealthWorkoutUploadService(workoutRepository: MockWorkoutRepository())
        let workout = makeWorkout(durationSeconds: 1800, offsetDays: 4)

        let result = await service.uploadWorkouts([workout])

        XCTAssertEqual(result.total, 1)
        XCTAssertEqual(result.success, 0)
        XCTAssertEqual(result.failed, 1)
        XCTAssertNil(tracker.failureRecord(for: workout), "a skip is not a failure")
        guard case .dataSourceNotAppleHealth? = result.failedWorkouts.first?.error as? WorkoutV2ServiceError else {
            return XCTFail("expected dataSourceNotAppleHealth, got \(String(describing: result.failedWorkouts.first?.error))")
        }
    }

    func test_batch_upload_validation_failure_is_recorded_exactly_once_as_permanent() async {
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        let service = AppleHealthWorkoutUploadService(workoutRepository: MockWorkoutRepository())
        let workout = makeWorkout(durationSeconds: 0, offsetDays: 5)

        let result = await service.uploadWorkouts([workout])

        XCTAssertEqual(result.failed, 1)
        guard case .invalidWorkoutData? = result.failedWorkouts.first?.error as? WorkoutV2ServiceError else {
            return XCTFail("expected invalidWorkoutData, got \(String(describing: result.failedWorkouts.first?.error))")
        }

        let record = tracker.failureRecord(for: workout)
        XCTAssertEqual(record?["retryCount"] as? Int, 1, "one upload attempt must write one ledger entry")
        XCTAssertEqual(record?["kind"] as? String, WorkoutUploadFailureKind.permanent.rawValue)
    }

    func test_single_upload_owner_writes_the_ledger_exactly_once() async {
        UserPreferencesManager.shared.dataSourcePreference = .appleHealth
        let service = AppleHealthWorkoutUploadService(workoutRepository: MockWorkoutRepository())
        let workout = makeWorkout(durationSeconds: 0, offsetDays: 6)

        do {
            _ = try await service.uploadWorkout(workout)
            XCTFail("expected the upload to fail")
        } catch {
            guard case .invalidWorkoutData? = error as? WorkoutV2ServiceError else {
                return XCTFail("expected invalidWorkoutData, got \(error)")
            }
        }

        let record = tracker.failureRecord(for: workout)
        XCTAssertEqual(record?["retryCount"] as? Int, 1, "one upload attempt must write one ledger entry")
        XCTAssertEqual(record?["kind"] as? String, WorkoutUploadFailureKind.permanent.rawValue)
    }

    // MARK: - Helpers

    private func makeWorkout(durationSeconds: TimeInterval, offsetDays: Int) -> HKWorkout {
        let start = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(TimeInterval(offsetDays) * 86_400)
        return HKWorkout(
            activityType: .running,
            start: start,
            end: start.addingTimeInterval(durationSeconds),
            duration: durationSeconds,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: nil
        )
    }
}
