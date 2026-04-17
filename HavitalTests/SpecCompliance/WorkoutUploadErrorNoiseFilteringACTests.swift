import XCTest
import Foundation
import HealthKit
@testable import paceriz_dev

final class WorkoutUploadErrorNoiseFilteringACTests: XCTestCase {
    private typealias CapturedLog = (message: String, level: LogLevel, labels: [String: String], jsonPayload: [String: Any]?)

    func test_ac_workout_log_01_device_locked_healthkit_skip_is_not_error() async throws {
        let error = makeDeviceLockedHealthKitError()
        var logs: [CapturedLog] = []

        XCTAssertTrue(WorkoutBackgroundManager.isProtectedDataUnavailableError(error))

        let handling = WorkoutBackgroundManager.reportPendingWorkoutCheckError(error) { message, level, labels, jsonPayload in
            logs.append((message, level, labels, jsonPayload))
        }

        XCTAssertEqual(handling.level, .info)
        XCTAssertEqual(handling.action, "check_upload_deferred")
        XCTAssertTrue(handling.isRecoverable)
        XCTAssertTrue(handling.message.contains("裝置鎖定"))
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].message, handling.message)
        XCTAssertEqual(logs[0].level, .info)
        XCTAssertEqual(logs[0].labels["action"], "check_upload_deferred")
        XCTAssertEqual(logs[0].jsonPayload?["classification"] as? String, "device_locked_deferred")
    }

    func test_ac_workout_log_02_non_locked_healthkit_failures_still_report() async throws {
        let error = NSError(
            domain: "com.apple.healthkit",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Authorization denied"]
        )
        var logs: [CapturedLog] = []

        XCTAssertFalse(WorkoutBackgroundManager.isProtectedDataUnavailableError(error))

        let handling = WorkoutBackgroundManager.reportPendingWorkoutCheckError(error) { message, level, labels, jsonPayload in
            logs.append((message, level, labels, jsonPayload))
        }

        XCTAssertEqual(handling.level, .error)
        XCTAssertEqual(handling.action, "check_upload_error")
        XCTAssertFalse(handling.isRecoverable)
        XCTAssertEqual(handling.message, "檢查待上傳健身記錄失敗")
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].level, .error)
        XCTAssertEqual(logs[0].labels["action"], "check_upload_error")
        XCTAssertEqual(logs[0].jsonPayload?["classification"] as? String, "check_upload_error")
    }

    func test_ac_workout_log_03_cancelled_upload_is_short_circuited() async throws {
        let cancelledErrors: [Error] = [
            CancellationError(),
            URLError(.cancelled),
            NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorCancelled,
                userInfo: [NSLocalizedDescriptionKey: "cancelled"]
            )
        ]

        for error in cancelledErrors {
            var logs: [CapturedLog] = []
            let batchHandling = AppleHealthWorkoutUploadService.classifyBatchUploadError(error)
            XCTAssertFalse(batchHandling.shouldLogToCloud)
            XCTAssertFalse(batchHandling.shouldMarkWorkoutFailed)

            let reportedBatchHandling = AppleHealthWorkoutUploadService.reportBatchUploadFailure(
                error,
                workoutId: "workout-1"
            ) { message, level, labels, jsonPayload in
                logs.append((message, level, labels, jsonPayload))
            }
            XCTAssertFalse(reportedBatchHandling.shouldLogToCloud)

            let detailHandling = AppleHealthWorkoutUploadService.reportDetailedUploadError(
                error,
                derivedErrorType: "network_error",
                workoutType: "run",
                errorReport: makeDetailedErrorReport()
            ) { message, level, labels, jsonPayload in
                logs.append((message, level, labels, jsonPayload))
            }
            XCTAssertFalse(detailHandling.shouldLogToCloud)
            XCTAssertNil(detailHandling.level)
            XCTAssertNil(detailHandling.action)
            XCTAssertEqual(logs.count, 0)

            do {
                _ = try AppleHealthWorkoutUploadService.resolveUploadTaskResult(
                    .failure(error),
                    workoutId: "workout-1"
                )
                XCTFail("Expected cancellation to be rethrown")
            } catch {
                XCTAssertTrue(error.isCancellationError)
                XCTAssertFalse(error is WorkoutV2ServiceError)
            }
        }
    }

    func test_ac_workout_log_04_non_cancelled_errors_keep_reporting() async throws {
        let timeoutError = URLError(.timedOut)
        let apiError = NSError(
            domain: "APIClient",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"]
        )
        var timeoutLogs: [CapturedLog] = []
        var apiLogs: [CapturedLog] = []

        XCTAssertTrue(AppleHealthWorkoutUploadService.isExpectedUploadError(timeoutError))
        XCTAssertFalse(AppleHealthWorkoutUploadService.isExpectedUploadError(apiError))

        let timeoutBatch = AppleHealthWorkoutUploadService.reportBatchUploadFailure(
            timeoutError,
            workoutId: "timeout-workout"
        ) { message, level, labels, jsonPayload in
            timeoutLogs.append((message, level, labels, jsonPayload))
        }
        XCTAssertTrue(timeoutBatch.shouldLogToCloud)
        XCTAssertTrue(timeoutBatch.shouldMarkWorkoutFailed)
        XCTAssertEqual(timeoutLogs.count, 1)
        XCTAssertEqual(timeoutLogs[0].message, "Workout 上傳失敗")
        XCTAssertEqual(timeoutLogs[0].level, .error)
        XCTAssertEqual(timeoutLogs[0].labels["action"], "batch_upload_failed")
        XCTAssertEqual(timeoutLogs[0].jsonPayload?["workoutId"] as? String, "timeout-workout")

        let timeoutDetail = AppleHealthWorkoutUploadService.reportDetailedUploadError(
            timeoutError,
            derivedErrorType: "network_error",
            workoutType: "run",
            errorReport: makeDetailedErrorReport()
        ) { message, level, labels, jsonPayload in
            timeoutLogs.append((message, level, labels, jsonPayload))
        }
        XCTAssertTrue(timeoutDetail.shouldLogToCloud)
        XCTAssertEqual(timeoutDetail.level, .warn)
        XCTAssertEqual(timeoutDetail.action, "workout_upload_error")
        XCTAssertEqual(timeoutLogs.count, 2)
        XCTAssertEqual(timeoutLogs[1].message, "Apple Health 運動記錄 V2 API 上傳失敗 - 詳細分析")
        XCTAssertEqual(timeoutLogs[1].level, .warn)
        XCTAssertEqual(timeoutLogs[1].labels["action"], "workout_upload_error")
        XCTAssertEqual(timeoutLogs[1].labels["error_type"], "network_error")

        let apiDetail = AppleHealthWorkoutUploadService.reportDetailedUploadError(
            apiError,
            derivedErrorType: "http_error",
            workoutType: "run",
            errorReport: makeDetailedErrorReport()
        ) { message, level, labels, jsonPayload in
            apiLogs.append((message, level, labels, jsonPayload))
        }
        XCTAssertTrue(apiDetail.shouldLogToCloud)
        XCTAssertEqual(apiDetail.level, .error)
        XCTAssertEqual(apiDetail.action, "workout_upload_error")
        XCTAssertEqual(apiLogs.count, 1)
        XCTAssertEqual(apiLogs[0].message, "Apple Health 運動記錄 V2 API 上傳失敗 - 詳細分析")
        XCTAssertEqual(apiLogs[0].level, .error)
        XCTAssertEqual(apiLogs[0].labels["action"], "workout_upload_error")
        XCTAssertEqual(apiLogs[0].labels["error_type"], "http_error")
    }

    func test_ac_workout_log_05_recoverable_events_do_not_duplicate_logs() async throws {
        let deviceLockedError = makeDeviceLockedHealthKitError()
        let cancelledError = URLError(.cancelled)
        var deviceLockedLogs: [CapturedLog] = []
        var cancellationLogs: [CapturedLog] = []

        let backgroundHandling = WorkoutBackgroundManager.reportPendingWorkoutCheckError(deviceLockedError) { message, level, labels, jsonPayload in
            deviceLockedLogs.append((message, level, labels, jsonPayload))
        }
        XCTAssertEqual(backgroundHandling.level, .info)
        XCTAssertEqual(backgroundHandling.action, "check_upload_deferred")
        XCTAssertEqual(deviceLockedLogs.count, 1)

        let batchHandling = AppleHealthWorkoutUploadService.reportBatchUploadFailure(
            cancelledError,
            workoutId: "cancelled-workout"
        ) { message, level, labels, jsonPayload in
            cancellationLogs.append((message, level, labels, jsonPayload))
        }
        XCTAssertFalse(batchHandling.shouldLogToCloud)

        let detailHandling = AppleHealthWorkoutUploadService.reportDetailedUploadError(
            cancelledError,
            derivedErrorType: "network_error",
            workoutType: "run",
            errorReport: makeDetailedErrorReport()
        ) { message, level, labels, jsonPayload in
            cancellationLogs.append((message, level, labels, jsonPayload))
        }
        XCTAssertFalse(detailHandling.shouldLogToCloud)
        XCTAssertNil(detailHandling.action)
        XCTAssertNil(detailHandling.level)
        XCTAssertEqual(cancellationLogs.count, 0)
    }

    private func makeDeviceLockedHealthKitError() -> NSError {
        NSError(
            domain: "com.apple.healthkit",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Protected health data is inaccessible because device is locked"
            ]
        )
    }

    private func makeDetailedErrorReport() -> [String: Any] {
        [
            "device_details": ["manufacturer": "Apple"],
            "source_details": ["bundle_id": "com.apple.health"],
            "error_details": ["error_description": "test error"]
        ]
    }
}
