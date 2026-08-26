import XCTest
import Foundation
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
