import XCTest
@testable import paceriz_dev

final class DomainErrorMappingTests: XCTestCase {

    func testToDomainError_ParseErrorDecodingFailed_MapsToDataCorruption() {
        let detail = ParseErrorDetail(
            type: .missingKey,
            description: "缺少必要欄位: weeks",
            missingField: "weeks",
            codingPath: "data.plan.weeks",
            expectedType: "PlanStatusV2Response",
            responsePreview: "{\"success\":true}"
        )
        let error = ParseError.decodingFailed(detail)

        let mapped = error.toDomainError()

        guard case .dataCorruption(let message) = mapped else {
            XCTFail("Expected .dataCorruption, got \(mapped)")
            return
        }
        XCTAssertTrue(message.contains("decode_failed"))
        XCTAssertTrue(message.contains("weeks"))
    }

    func testToDomainError_DecodingError_MapsToDataCorruption() {
        let error = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "invalid json shape")
        )

        let mapped = error.toDomainError()

        guard case .dataCorruption = mapped else {
            XCTFail("Expected .dataCorruption, got \(mapped)")
            return
        }
    }

    func testShouldShowErrorView_DataCorruption_IsTrueForGlobalBehavior() {
        let error = DomainError.dataCorruption("schema mismatch")
        XCTAssertTrue(error.shouldShowErrorView)
    }
}
