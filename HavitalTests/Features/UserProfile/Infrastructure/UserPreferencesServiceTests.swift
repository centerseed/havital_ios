import XCTest
@testable import paceriz_dev

final class UserPreferencesServiceTests: XCTestCase {
    private var mockHTTPClient: MockHTTPClient!
    private var mockParser: MockAPIParser!
    private var sut: UserPreferencesService!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        mockParser = MockAPIParser()
        sut = UserPreferencesService(httpClient: mockHTTPClient, parser: mockParser)
    }

    override func tearDown() {
        sut = nil
        mockParser = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    func testGetPreferencesDecodesAPIFieldsAndLeavesLocalFieldsNil() async throws {
        let response = UserPreferences(
            language: "zh-TW",
            timezone: "Asia/Taipei",
            unitSystem: "metric",
            supportedLanguages: ["zh-TW", "en-US"],
            languageNames: ["zh-TW": "繁體中文", "en-US": "English"]
        )
        try mockHTTPClient.setJSONResponse(for: "/user/preferences", response: response)

        let result = try await sut.getPreferences()

        XCTAssertEqual(result.language, "zh-TW")
        XCTAssertEqual(result.timezone, "Asia/Taipei")
        XCTAssertEqual(result.unitSystem, "metric")
        XCTAssertEqual(result.supportedLanguages, ["zh-TW", "en-US"])
        XCTAssertEqual(result.languageNames["en-US"], "English")
        XCTAssertNil(result.dataSourcePreference)
        XCTAssertNil(result.email)
        XCTAssertGreaterThan(mockParser.parseCount, 0)
    }

    func testGetPreferencesDecodesTimezoneIsSetTrue() async throws {
        let response = UserPreferences(
            language: "zh-TW",
            timezone: "Asia/Taipei",
            timezoneIsSet: true,
            supportedLanguages: ["zh-TW"],
            languageNames: ["zh-TW": "繁體中文"]
        )
        try mockHTTPClient.setJSONResponse(for: "/user/preferences", response: response)

        let result = try await sut.getPreferences()

        XCTAssertTrue(result.timezoneIsSet)
    }

    /// T-0428 尚未部署前，後端回應可能完全沒有 `timezone_is_set` 欄位；
    /// iOS 端缺席一律視為 false，不能拿 `timezone` 本身（永遠有預設值）誤判成已初始化。
    func testGetPreferencesDefaultsTimezoneIsSetToFalseWhenFieldMissing() async throws {
        let json: [String: Any] = [
            "language": "zh-TW",
            "timezone": "Asia/Taipei",
            "supported_languages": ["zh-TW"],
            "language_names": ["zh-TW": "繁體中文"]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        mockHTTPClient.setResponse(for: "/user/preferences", data: data)

        let result = try await sut.getPreferences()

        XCTAssertFalse(result.timezoneIsSet)
    }

    func testUpdatePreferencesSendsOnlyProvidedFields() async throws {
        try mockHTTPClient.setJSONResponse(for: "/user/preferences", method: .PUT, response: EmptyAPIResponse())

        try await sut.updatePreferences(language: "ja-JP", timezone: nil)

        XCTAssertEqual(mockHTTPClient.lastRequest?.path, "/user/preferences")
        XCTAssertEqual(mockHTTPClient.lastRequest?.method, .PUT)
        let body = try XCTUnwrap(mockHTTPClient.lastRequest?.body)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(payload["language"], "ja-JP")
        XCTAssertNil(payload["timezone"])
        XCTAssertEqual(payload.count, 1)
    }

    func testUpdatePreferencesRejectsEmptyPayload() async {
        do {
            try await sut.updatePreferences(language: nil, timezone: nil)
            XCTFail("Expected updatePreferences to throw for empty payload")
        } catch let error as APIError {
            guard case .system(let systemError) = error,
                  case .unknownError(let message) = systemError else {
                return XCTFail("Unexpected APIError: \(error)")
            }
            XCTAssertTrue(message.contains("至少需要提供語言或時區其中之一"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct EmptyAPIResponse: Codable {}
