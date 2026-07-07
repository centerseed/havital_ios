import XCTest
@testable import paceriz_dev

final class ApplyAdjustmentItemsResponseDTOTests: XCTestCase {

    private func decodeDataField(_ json: String) throws -> ApplyAdjustmentItemsResponseDTO {
        let wrapper = """
        {"success":true,"data":\(json)}
        """
        let data = Data(wrapper.utf8)
        struct Envelope: Decodable {
            let data: ApplyAdjustmentItemsResponseDTO
        }
        return try JSONDecoder().decode(Envelope.self, from: data).data
    }

    func test_decodeMissingAppliesToWeek_failsWithCurrentDTO() {
        let json = """
        {"skipped_items":[],"applied_items":[]}
        """
        XCTAssertThrowsError(try decodeDataField(json)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "applies_to_week")
        }
    }

    func test_decodeBeginnerSkippedItems_withReasonField() throws {
        let json = """
        {"applies_to_week":9,"skipped_items":[{"index":0,"reason":"beginner_engine_controlled"}],"applied_items":[]}
        """
        // 現行 DTO 缺 content → 此測試也應 RED，Task A4 一併修
        XCTAssertThrowsError(try decodeDataField(json))
    }
}
