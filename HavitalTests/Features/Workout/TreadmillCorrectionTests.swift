import XCTest
import Combine
@testable import paceriz_dev

// MARK: - Treadmill Correction Tests

/// Tests for:
/// 1. TreadmillCorrection model decode (including missing field backward compat)
/// 2. WorkoutV2Detail.isTreadmillCorrected logic
/// 3. WorkoutRemoteDataSource.applyTreadmillCorrection path + body
/// 4. WorkoutRepositoryImpl.applyTreadmillCorrection cache invalidation + refreshSubject
final class TreadmillCorrectionTests: XCTestCase {

    // MARK: - 1. Model Decode Tests

    func testTreadmillCorrection_Decode_FullFields() throws {
        let json = """
        {
            "type": "treadmill",
            "source": "user_treadmill_correction",
            "actual_distance_m": 5230.0,
            "avg_incline_percent": 1.5,
            "original_distance_m": 4800.0,
            "original_avg_pace_s_per_km": 360.0,
            "original_dynamic_vdot": 42.5,
            "corrected_avg_pace_s_per_km": 330.0,
            "corrected_dynamic_vdot": 44.0,
            "notes": "console distance",
            "applied_at": "2026-05-29T10:00:00Z"
        }
        """
        let correction = try JSONDecoder().decode(TreadmillCorrection.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(correction.type, "treadmill")
        XCTAssertEqual(correction.source, "user_treadmill_correction")
        XCTAssertEqual(correction.actualDistanceM, 5230.0)
        XCTAssertEqual(correction.avgInclinePercent, 1.5)
        XCTAssertEqual(correction.originalDistanceM, 4800.0)
        XCTAssertEqual(correction.correctedAvgPaceSPerKm, 330.0)
        XCTAssertEqual(correction.notes, "console distance")
        XCTAssertEqual(correction.appliedAt, "2026-05-29T10:00:00Z")
    }

    func testTreadmillCorrection_Decode_OptionalFieldsAbsent_NilValues() throws {
        let json = """
        {
            "type": "treadmill",
            "source": "user_treadmill_correction",
            "actual_distance_m": 5000.0
        }
        """
        let correction = try JSONDecoder().decode(TreadmillCorrection.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(correction.actualDistanceM, 5000.0)
        XCTAssertNil(correction.avgInclinePercent)
        XCTAssertNil(correction.originalDistanceM)
        XCTAssertNil(correction.notes)
        XCTAssertNil(correction.appliedAt)
    }

    /// 舊資料沒有 correction 欄位，WorkoutV2Detail 解碼必須不 crash
    func testWorkoutV2Detail_Decode_WithoutCorrectionField_CorrectionIsNil() throws {
        let json = """
        {
            "id": "workout_abc",
            "provider": "garmin",
            "activity_type": "running",
            "sport_type": "treadmill_running",
            "start_time": "2026-05-29T08:00:00Z",
            "end_time": "2026-05-29T09:00:00Z",
            "user_id": "user_1",
            "schema_version": "2.0",
            "source": "garmin",
            "storage_path": "/workouts/abc",
            "original_id": "orig_abc",
            "provider_user_id": "garmin_user_1"
        }
        """
        let detail = try JSONDecoder().decode(WorkoutV2Detail.self, from: json.data(using: .utf8)!)

        XCTAssertNil(detail.correction, "correction should be nil for old records without this field")
        XCTAssertFalse(detail.isTreadmillCorrected, "isTreadmillCorrected should be false when correction is nil")
    }

    func testWorkoutV2Detail_Decode_WithCorrectionField_CorrectionPresent() throws {
        let json = """
        {
            "id": "workout_abc",
            "provider": "garmin",
            "activity_type": "running",
            "sport_type": "treadmill_running",
            "start_time": "2026-05-29T08:00:00Z",
            "end_time": "2026-05-29T09:00:00Z",
            "user_id": "user_1",
            "schema_version": "2.0",
            "source": "garmin",
            "storage_path": "/workouts/abc",
            "original_id": "orig_abc",
            "provider_user_id": "garmin_user_1",
            "correction": {
                "type": "treadmill",
                "source": "user_treadmill_correction",
                "actual_distance_m": 5000.0
            }
        }
        """
        let detail = try JSONDecoder().decode(WorkoutV2Detail.self, from: json.data(using: .utf8)!)

        XCTAssertNotNil(detail.correction)
        XCTAssertEqual(detail.correction?.actualDistanceM, 5000.0)
    }

    // MARK: - 2. isTreadmillCorrected Logic Tests

    func testIsTreadmillCorrected_TypeTreadmill_SourceUserCorrection_ReturnsTrue() throws {
        let correction = TreadmillCorrection(
            type: "treadmill",
            source: "user_treadmill_correction",
            actualDistanceM: 5000,
            avgInclinePercent: nil,
            originalDistanceM: nil,
            originalAvgPaceSPerKm: nil,
            originalDynamicVdot: nil,
            correctedAvgPaceSPerKm: nil,
            correctedDynamicVdot: nil,
            notes: nil,
            appliedAt: nil
        )
        let detail = makeDetail(correction: correction)
        XCTAssertTrue(detail.isTreadmillCorrected)
    }

    func testIsTreadmillCorrected_WrongType_ReturnsFalse() throws {
        let correction = TreadmillCorrection(
            type: "other",
            source: "user_treadmill_correction",
            actualDistanceM: 5000,
            avgInclinePercent: nil, originalDistanceM: nil, originalAvgPaceSPerKm: nil,
            originalDynamicVdot: nil, correctedAvgPaceSPerKm: nil, correctedDynamicVdot: nil,
            notes: nil, appliedAt: nil
        )
        XCTAssertFalse(makeDetail(correction: correction).isTreadmillCorrected)
    }

    func testIsTreadmillCorrected_WrongSource_ReturnsFalse() throws {
        let correction = TreadmillCorrection(
            type: "treadmill",
            source: "auto",
            actualDistanceM: 5000,
            avgInclinePercent: nil, originalDistanceM: nil, originalAvgPaceSPerKm: nil,
            originalDynamicVdot: nil, correctedAvgPaceSPerKm: nil, correctedDynamicVdot: nil,
            notes: nil, appliedAt: nil
        )
        XCTAssertFalse(makeDetail(correction: correction).isTreadmillCorrected)
    }

    func testIsTreadmillCorrected_NilCorrection_ReturnsFalse() throws {
        XCTAssertFalse(makeDetail(correction: nil).isTreadmillCorrected)
    }

    // MARK: - 3. WorkoutRemoteDataSource Tests

    func testApplyTreadmillCorrection_UsesCorrectPath() async throws {
        let mockHTTPClient = MockHTTPClient()
        let mockParser = MockAPIParser()
        let sut = WorkoutRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)

        let responseDetail = makeDetailJSON(id: "workout_xyz")
        mockHTTPClient.setResponse(
            for: "/v2/workouts/workout_xyz/treadmill-correction",
            method: .POST,
            data: responseDetail
        )

        _ = try await sut.applyTreadmillCorrection(
            id: "workout_xyz",
            actualDistanceM: 5000,
            avgInclinePercent: 1.5,
            notes: "console"
        )

        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/v2/workouts/workout_xyz/treadmill-correction")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .POST)
    }

    func testApplyTreadmillCorrection_BodyContainsRequiredFields() async throws {
        let mockHTTPClient = MockHTTPClient()
        let mockParser = MockAPIParser()
        let sut = WorkoutRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)

        let responseDetail = makeDetailJSON(id: "workout_xyz")
        mockHTTPClient.setResponse(
            for: "/v2/workouts/workout_xyz/treadmill-correction",
            method: .POST,
            data: responseDetail
        )

        _ = try await sut.applyTreadmillCorrection(
            id: "workout_xyz",
            actualDistanceM: 5230,
            avgInclinePercent: 2.0,
            notes: "test note"
        )

        guard let bodyData = mockHTTPClient.lastRequest?.body else {
            XCTFail("Request body should not be nil")
            return
        }
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(bodyJSON?["actual_distance_m"] as? Double, 5230)
        XCTAssertEqual(bodyJSON?["avg_incline_percent"] as? Double, 2.0)
        XCTAssertEqual(bodyJSON?["notes"] as? String, "test note")
    }

    func testApplyTreadmillCorrection_OptionalFieldsAbsent_BodyOmitsNilKeys() async throws {
        let mockHTTPClient = MockHTTPClient()
        let mockParser = MockAPIParser()
        let sut = WorkoutRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)

        let responseDetail = makeDetailJSON(id: "workout_xyz")
        mockHTTPClient.setResponse(
            for: "/v2/workouts/workout_xyz/treadmill-correction",
            method: .POST,
            data: responseDetail
        )

        _ = try await sut.applyTreadmillCorrection(
            id: "workout_xyz",
            actualDistanceM: 5000,
            avgInclinePercent: nil,
            notes: nil
        )

        guard let bodyData = mockHTTPClient.lastRequest?.body else {
            XCTFail("Request body should not be nil")
            return
        }
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(bodyJSON?["actual_distance_m"] as? Double, 5000)
        // Nil optional fields must be absent from the serialised body (not encoded as null)
        XCTAssertNil(bodyJSON?["avg_incline_percent"], "avg_incline_percent should be omitted when nil")
        XCTAssertNil(bodyJSON?["notes"], "notes should be omitted when nil")
    }

    func testApplyTreadmillCorrection_NetworkError_ThrowsError() async {
        let mockHTTPClient = MockHTTPClient()
        let mockParser = MockAPIParser()
        let sut = WorkoutRemoteDataSource(httpClient: mockHTTPClient, parser: mockParser)

        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        mockHTTPClient.setError(
            for: "/v2/workouts/workout_err/treadmill-correction",
            method: .POST,
            error: networkError
        )

        do {
            _ = try await sut.applyTreadmillCorrection(
                id: "workout_err",
                actualDistanceM: 5000,
                avgInclinePercent: nil,
                notes: nil
            )
            XCTFail("Should throw network error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - 4. WorkoutRepositoryImpl Cache Invalidation + refreshSubject Tests

    func testApplyTreadmillCorrection_Repository_ClearsDetailCacheAndFiresRefreshSubject() async throws {
        let mockRemote = MockWorkoutRemoteDataSourceForCorrection()
        let localDS = WorkoutLocalDataSource()
        let sut = WorkoutRepositoryImpl(
            remoteDataSource: mockRemote,
            localDataSource: localDS
        )

        // Pre-populate detail cache with a stale record
        let staleDetail = makeWorkoutV2Detail(id: "workout_cache_test", correction: nil)
        localDS.saveWorkoutDetail(staleDetail)
        XCTAssertNotNil(localDS.getWorkoutDetail(id: "workout_cache_test"), "Stale detail should be cached")

        // Prepare mock remote to return updated detail
        let updatedDetail = makeWorkoutV2Detail(
            id: "workout_cache_test",
            correction: TreadmillCorrection(
                type: "treadmill", source: "user_treadmill_correction",
                actualDistanceM: 5000, avgInclinePercent: nil,
                originalDistanceM: nil, originalAvgPaceSPerKm: nil, originalDynamicVdot: nil,
                correctedAvgPaceSPerKm: nil, correctedDynamicVdot: nil,
                notes: nil, appliedAt: nil
            )
        )
        mockRemote.correctionResultToReturn = updatedDetail

        // Track refreshSubject firing
        var refreshFired = false
        var cancellables = Set<AnyCancellable>()
        sut.workoutsDidRefresh
            .sink { refreshFired = true }
            .store(in: &cancellables)

        let result = try await sut.applyTreadmillCorrection(
            id: "workout_cache_test",
            actualDistanceM: 5000,
            avgInclinePercent: nil,
            notes: nil
        )

        XCTAssertTrue(result.isTreadmillCorrected, "Returned detail should be corrected")
        XCTAssertTrue(refreshFired, "refreshSubject should fire after correction — ViewModel subscribes and relays to CacheEventBus")

        // Detail cache should now contain updated detail
        let cachedDetail = localDS.getWorkoutDetail(id: "workout_cache_test")
        XCTAssertNotNil(cachedDetail)
        XCTAssertTrue(cachedDetail?.isTreadmillCorrected == true, "Cached detail should reflect the correction")
    }

    // MARK: - Helpers

    private func makeDetail(correction: TreadmillCorrection?) -> WorkoutV2Detail {
        makeWorkoutV2Detail(id: "test", correction: correction)
    }

    private func makeWorkoutV2Detail(id: String, correction: TreadmillCorrection?) -> WorkoutV2Detail {
        // Build via JSON to remain independent of struct init changes
        var json: [String: Any] = [
            "id": id,
            "provider": "garmin",
            "activity_type": "running",
            "sport_type": "treadmill_running",
            "start_time": "2026-05-29T08:00:00Z",
            "end_time": "2026-05-29T09:00:00Z",
            "user_id": "user_1",
            "schema_version": "2.0",
            "source": "garmin",
            "storage_path": "/workouts/\(id)",
            "original_id": "orig_\(id)",
            "provider_user_id": "garmin_user_1"
        ]
        if let c = correction {
            var correctionDict: [String: Any] = [:]
            if let t = c.type { correctionDict["type"] = t }
            if let s = c.source { correctionDict["source"] = s }
            if let d = c.actualDistanceM { correctionDict["actual_distance_m"] = d }
            if let i = c.avgInclinePercent { correctionDict["avg_incline_percent"] = i }
            json["correction"] = correctionDict
        }
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(WorkoutV2Detail.self, from: data)
    }

    private func makeDetailJSON(id: String) -> Data {
        // ResponseProcessor tries direct parse first; WorkoutV2Detail has no "data" key so direct works.
        let json: [String: Any] = [
            "id": id,
            "provider": "garmin",
            "activity_type": "running",
            "sport_type": "treadmill_running",
            "start_time": "2026-05-29T08:00:00Z",
            "end_time": "2026-05-29T09:00:00Z",
            "user_id": "user_1",
            "schema_version": "2.0",
            "source": "garmin",
            "storage_path": "/workouts/\(id)",
            "original_id": "orig_\(id)",
            "provider_user_id": "garmin_user_1"
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
}

// MARK: - Mock for Repository test

/// Minimal subclass of WorkoutRemoteDataSource to override only applyTreadmillCorrection
private final class MockWorkoutRemoteDataSourceForCorrection: WorkoutRemoteDataSource {
    var correctionResultToReturn: WorkoutV2Detail?
    var correctionError: Error?

    override func applyTreadmillCorrection(
        id: String,
        actualDistanceM: Double,
        avgInclinePercent: Double?,
        notes: String?
    ) async throws -> WorkoutV2Detail {
        if let error = correctionError { throw error }
        guard let detail = correctionResultToReturn else {
            throw DomainError.notFound("Mock correction detail not configured")
        }
        return detail
    }
}
