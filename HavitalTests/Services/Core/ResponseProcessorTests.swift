import XCTest
@testable import paceriz_dev

final class ResponseProcessorTests: XCTestCase {
    private struct PlainPayload: Codable, Equatable {
        let value: Int
    }

    func testExtractData_directJSONObject_doesNotMisclassifyAsWrappedResponse() throws {
        let rawData = Data(#"{"value": 42}"#.utf8)

        let result = try ResponseProcessor.extractData(
            PlainPayload.self,
            from: rawData,
            using: DefaultAPIParser.shared
        )

        XCTAssertEqual(result, PlainPayload(value: 42))
    }

    func testExtractData_wrappedResponse_stillUsesWrappedPayload() throws {
        let rawData = Data(#"{"success": true, "data": {"value": 42}}"#.utf8)

        let result = try ResponseProcessor.extractData(
            PlainPayload.self,
            from: rawData,
            using: DefaultAPIParser.shared
        )

        XCTAssertEqual(result, PlainPayload(value: 42))
    }
}
