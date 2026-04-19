import XCTest
@testable import paceriz_dev

final class FeedbackServiceTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: FeedbackService!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = FeedbackService(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        mockHTTPClient.reset()
        mockParser.reset()
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testSubmitFeedbackPostsExpectedPayload() async throws {
        let path = "/feedback/report"
        try mockHTTPClient.setJSONResponse(
            for: path,
            method: .POST,
            response: FeedbackResponse(issueNumber: 123, issueUrl: "https://example.com/issues/123")
        )

        let response = try await sut.submitFeedback(
            type: .suggestion,
            category: .other,
            description: "希望新增分享卡版型",
            email: "",
            images: ["data:image/jpeg;base64,abc123"]
        )

        XCTAssertEqual(response.issueNumber, 123)
        XCTAssertEqual(mockHTTPClient.lastRequest?.path, path)
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .POST)
        XCTAssertGreaterThan(mockParser.parseCount, 0)

        let body = try XCTUnwrap(mockHTTPClient.lastRequest?.body)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(payload["type"] as? String, "suggestion")
        XCTAssertEqual(payload["category"] as? String, "other")
        XCTAssertEqual(payload["description"] as? String, "希望新增分享卡版型")
        XCTAssertEqual(payload["email"] as? String, "")
        XCTAssertFalse((payload["app_version"] as? String ?? "").isEmpty)
        XCTAssertFalse((payload["device_info"] as? String ?? "").isEmpty)
        XCTAssertEqual(payload["images"] as? [String], ["data:image/jpeg;base64,abc123"])
    }

    func testSubmitFeedbackPropagatesHTTPError() async {
        mockHTTPClient.setError(
            for: "/feedback/report",
            method: .POST,
            error: HTTPError.serverError(500, "boom")
        )

        do {
            _ = try await sut.submitFeedback(
                type: .issue,
                category: .weeklyPlan,
                description: "週計畫生成失敗",
                email: "runner@example.com",
                images: nil
            )
            XCTFail("Expected request to throw")
        } catch let error as HTTPError {
            if case .serverError(let code, let message) = error {
                XCTAssertEqual(code, 500)
                XCTAssertEqual(message, "boom")
            } else {
                XCTFail("Unexpected HTTPError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
