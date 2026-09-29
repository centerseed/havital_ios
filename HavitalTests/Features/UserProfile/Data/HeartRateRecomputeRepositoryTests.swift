import XCTest
@testable import paceriz_dev

/// SPEC-heart-rate-and-training-readiness-surfaces AC-HR-07~13：後端契約（`SPEC-hr-zones` §5.5／§5.8）的 App 端解碼。
final class HeartRateRecomputeRepositoryTests: XCTestCase {

    private final class FakeHTTPClient: HTTPClient {
        var response: Result<Data, Error> = .success(Data())
        private(set) var requests: [(path: String, method: HTTPMethod, body: Data?)] = []

        func request(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?, timeout: TimeInterval?) async throws -> Data {
            requests.append((path, method, body))
            return try response.get()
        }

        func stream(path: String, method: HTTPMethod, body: Data?, customHeaders: [String: String]?) async throws -> HTTPByteStreamResponse {
            throw URLError(.unsupportedURL)
        }
    }

    private func json(_ text: String) -> Data { Data(text.utf8) }

    private let queuedJob = """
    {"job_id":"j1","status":"queued","days":14,"total":3,"done":0,"recomputed":0,"skipped":0,"failed":0,"failed_workout_ids":[]}
    """

    private func makeRepo(_ client: FakeHTTPClient) -> HeartRateRecomputeRepositoryImpl {
        HeartRateRecomputeRepositoryImpl(httpClient: client, parser: DefaultAPIParser.shared)
    }

    // MARK: - PUT /user 的 heart_rate.changed

    func test_putResponseReportsChangedFromBackend() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"heart_rate":{"changed":true,"changed_fields":["max_hr"]}},"message":"ok"}"#))
        let ds = UserProfileRemoteDataSource(httpClient: client, parser: DefaultAPIParser.shared)
        let report = try await ds.updateUserProfile(["max_hr": 193, "relaxing_hr": 50])
        XCTAssertTrue(report.changed)
        XCTAssertEqual(report.changedFields, ["max_hr"])
        XCTAssertEqual(client.requests.first?.path, "/user")
        XCTAssertEqual(client.requests.first?.method, .PUT)
    }

    func test_putResponseWithoutHeartRateBlockMeansNotChanged() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"message":"ok"}"#))
        let ds = UserProfileRemoteDataSource(httpClient: client, parser: DefaultAPIParser.shared)
        let report = try await ds.updateUserProfile(["display_name": "x"])
        XCTAssertFalse(report.changed)
    }

    // MARK: - POST /user/heart-rate/recompute

    func test_startQueuedReturnsTheJobAndPostsTheDays() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"outcome":"queued","job":\#(queuedJob),"message":"queued msg"}}"#))
        let outcome = try await makeRepo(client).startRecompute(days: .fourteen)
        guard case .queued(let job, let message) = outcome else { return XCTFail("expected queued, got \(outcome)") }
        XCTAssertEqual(job.jobId, "j1")
        XCTAssertEqual(job.status, .queued)
        XCTAssertEqual(message, "queued msg")
        XCTAssertEqual(client.requests.first?.path, "/user/heart-rate/recompute")
        XCTAssertEqual(client.requests.first?.method, .POST)
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(client.requests.first?.body)) as? [String: Int]
        XCTAssertEqual(body, ["days": 14])
    }

    func test_startWithNothingToRecomputeCarriesTheBackendMessage() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"outcome":"nothing_to_recompute","job":null,"message":"none"}}"#))
        let outcome = try await makeRepo(client).startRecompute(days: .thirty)
        guard case .nothingToRecompute(let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertEqual(message, "none")
    }

    func test_start409ReturnsTheRunningJob() async throws {
        let client = FakeHTTPClient()
        let body = #"{"success":true,"data":{"outcome":"already_running","job":\#(queuedJob),"message":"busy"}}"#
        client.response = .failure(HTTPError.httpError(409, body))
        let outcome = try await makeRepo(client).startRecompute(days: .sixty)
        guard case .alreadyRunning(let job, let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertEqual(job.jobId, "j1")
        XCTAssertEqual(message, "busy")
    }

    func test_start422MeansNoHeartRateParameters() async throws {
        let client = FakeHTTPClient()
        client.response = .failure(HTTPError.httpError(422, #"{"success":true,"data":{"outcome":"no_hr_params","job":null,"message":"set hr first"}}"#))
        let outcome = try await makeRepo(client).startRecompute(days: .fourteen)
        guard case .noHeartRateParameters(let message) = outcome else { return XCTFail("got \(outcome)") }
        XCTAssertEqual(message, "set hr first")
    }

    func test_otherFailuresAreThrownNotFaked() async {
        let client = FakeHTTPClient()
        client.response = .failure(HTTPError.serverError(503, "down"))
        do {
            _ = try await makeRepo(client).startRecompute(days: .fourteen)
            XCTFail("must throw")
        } catch {}
    }

    // MARK: - GET status / watch-check

    func test_statusDecodesProgressAndMessage() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"job":{"job_id":"j1","status":"running","days":30,"total":10,"done":4,"recomputed":3,"skipped":1,"failed":0,"failed_workout_ids":[]},"message":"4/10"}}"#))
        let status = try await makeRepo(client).latestStatus()
        XCTAssertEqual(status.job?.status, .running)
        XCTAssertEqual(status.job?.done, 4)
        XCTAssertEqual(status.job?.total, 10)
        XCTAssertEqual(status.message, "4/10")
        XCTAssertEqual(client.requests.first?.method, .GET)
    }

    func test_statusWithNoJobIsNil() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"job":null,"message":null}}"#))
        let status = try await makeRepo(client).latestStatus()
        XCTAssertNil(status.job)
    }

    func test_watchCheckDecodesReminderAndAutoUpdateNote() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"reminder":{"watch_max_hr":180,"profile_max_hr":197,"deviation_pct":8.6,"since":"2026-09-01","latest_workout_day":"2026-09-17","watch_resting_hr":50},"auto_update":{"local_date":"2026-09-20","max_hr":193,"previous_max_hr":197,"deviation_since":"2026-09-01"}}}"#))
        let check = try await makeRepo(client).watchCheck()
        XCTAssertEqual(check.reminder?.watchMaxHr, 180)
        XCTAssertEqual(check.reminder?.deviationPct, 8.6)
        XCTAssertEqual(check.autoUpdate?.localDate, "2026-09-20")
        XCTAssertEqual(check.autoUpdate?.maxHr, 193)
        XCTAssertEqual(check.autoUpdate?.previousMaxHr, 197)
        XCTAssertEqual(client.requests.first?.path, "/user/heart-rate/watch-check")
        XCTAssertEqual(client.requests.first?.method, .GET)

        client.response = .success(json(#"{"success":true,"data":{"reminder":null,"auto_update":null}}"#))
        let none = try await makeRepo(client).watchCheck()
        XCTAssertNil(none.reminder)
        XCTAssertNil(none.autoUpdate)
    }

    func test_watchCheckFromOlderBackendWithoutAutoUpdateStillDecodes() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"reminder":null}}"#))
        let check = try await makeRepo(client).watchCheck()
        XCTAssertNil(check.autoUpdate)
    }

    func test_dismissPostsToTheDismissPath() async throws {
        let client = FakeHTTPClient()
        client.response = .success(json(#"{"success":true,"data":{"dismissed":true}}"#))
        try await makeRepo(client).dismissWatchReminder()
        XCTAssertEqual(client.requests.first?.path, "/user/heart-rate/watch-check/dismiss")
        XCTAssertEqual(client.requests.first?.method, .POST)
    }

    // MARK: - 最大心率來源文字（SPEC-hr-zones §5.7、HZ-INV-02）

    func test_sourceParsesTheFourValuesAndTreatsUnknownAsSystemDefault() {
        XCTAssertEqual(HeartRateParameterSource(raw: "user_set"), .userSet)
        XCTAssertEqual(HeartRateParameterSource(raw: "watch"), .watch)
        XCTAssertEqual(HeartRateParameterSource(raw: "observed"), .observed)
        XCTAssertEqual(HeartRateParameterSource(raw: "system_default"), .systemDefault)
        XCTAssertEqual(HeartRateParameterSource(raw: "something_new"), .systemDefault)
        XCTAssertEqual(HeartRateParameterSource(raw: nil), .systemDefault)
    }

    func test_userProfileDecodesMaxHrSourceAndToleratesUnknownValue() throws {
        let watch = try JSONDecoder().decode(User.self, from: json(#"{"max_hr":193,"max_hr_source":"watch"}"#))
        XCTAssertEqual(watch.maxHrSource, .watch)
        let unknown = try JSONDecoder().decode(User.self, from: json(#"{"max_hr":193,"max_hr_source":"zzz"}"#))
        XCTAssertEqual(unknown.maxHrSource, .systemDefault)
        let absent = try JSONDecoder().decode(User.self, from: json(#"{"max_hr":193}"#))
        XCTAssertEqual(absent.maxHrSource, .systemDefault)
    }
}
