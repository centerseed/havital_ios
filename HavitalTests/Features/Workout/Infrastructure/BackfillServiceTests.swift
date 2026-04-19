import XCTest
@testable import paceriz_dev

final class BackfillServiceTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: BackfillService!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = BackfillService(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testTriggerStravaBackfillPostsExpectedBodyAndReturnsBackfillId() async throws {
        let path = "/strava/backfill"
        try mockHTTPClient.setJSONResponse(
            for: path,
            method: .POST,
            response: BackfillTriggerResponse(
                success: true,
                data: BackfillTriggerData(
                    backfillId: "strava-backfill-1",
                    status: "processing",
                    message: "ok"
                )
            )
        )

        let backfillId = try await sut.triggerStravaBackfill(days: 7)

        XCTAssertEqual(backfillId, "strava-backfill-1")
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, path)
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .POST)
        XCTAssertGreaterThan(mockParser.parseCount, 0)

        let body = try XCTUnwrap(mockHTTPClient.lastRequest?.body)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["days"] as? Int, 7)

        let startDate = try XCTUnwrap(payload["start_date"] as? String)
        let expectedDate = DateFormatter.backfillRequestDate.string(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
        XCTAssertEqual(startDate, expectedDate)
    }

    func testTriggerStravaBackfillReturnsNilWhenServerResponds429() async throws {
        mockHTTPClient.setError(
            for: "/strava/backfill",
            method: .POST,
            error: HTTPError.httpError(429, "already in progress")
        )

        let backfillId = try await sut.triggerStravaBackfill(days: 14)

        XCTAssertNil(backfillId)
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/strava/backfill")
        XCTAssertEqual(mockParser.parseCount, 0)
    }

    func testTriggerGarminBackfillCapsDaysAt90InRequestBody() async throws {
        let path = "/garmin/backfill"
        try mockHTTPClient.setJSONResponse(
            for: path,
            method: .POST,
            response: BackfillTriggerResponse(
                success: true,
                data: BackfillTriggerData(
                    backfillId: "garmin-backfill-1",
                    status: "monitoring",
                    message: "ok"
                )
            )
        )

        let backfillId = try await sut.triggerGarminBackfill(days: 120)

        XCTAssertEqual(backfillId, "garmin-backfill-1")
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, path)
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .POST)

        let body = try XCTUnwrap(mockHTTPClient.lastRequest?.body)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["days"] as? Int, 90)

        let startDate = try XCTUnwrap(payload["start_date"] as? String)
        let expectedDate = DateFormatter.backfillRequestDate.string(
            from: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        )
        XCTAssertEqual(startDate, expectedDate)
    }

    func testGetGarminBackfillStatusBuildsPathAndParsesResponse() async throws {
        let path = "/garmin/backfill/garmin-123"
        try mockHTTPClient.setJSONResponse(
            for: path,
            response: GarminBackfillStatusResponse(
                success: true,
                data: GarminBackfillStatusData(
                    backfillId: "garmin-123",
                    userId: "user-1",
                    status: "completed",
                    startDate: "2026-04-01",
                    endDate: "2026-04-10",
                    days: 10,
                    triggeredAt: "2026-04-10T00:00:00Z",
                    completedAt: "2026-04-10T01:00:00Z",
                    progress: GarminBackfillProgress(
                        initialWorkoutCount: 1,
                        currentWorkoutCount: 4,
                        newWorkouts: 3,
                        lastWorkoutReceivedAt: "2026-04-10T00:55:00Z",
                        lastCheckedAt: "2026-04-10T01:00:00Z",
                        elapsedSeconds: 3600
                    ),
                    completionReason: "done",
                    error: nil
                )
            )
        )

        let response = try await sut.getGarminBackfillStatus(backfillId: "garmin-123")

        XCTAssertEqual(response.data.backfillId, "garmin-123")
        XCTAssertEqual(response.data.status, "completed")
        XCTAssertEqual(response.data.progress?.newWorkouts, 3)
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, path)
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .GET)
        XCTAssertGreaterThan(mockParser.parseCount, 0)
    }
}

private extension DateFormatter {
    static let backfillRequestDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
