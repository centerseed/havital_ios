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

    func test_decodeMissingAppliesToWeek_succeedsWithOptionalField() throws {
        let json = """
        {"skipped_items":[],"applied_items":[]}
        """
        let dto = try decodeDataField(json)
        XCTAssertNil(dto.appliesToWeek)
    }

    func test_decodeBeginnerSkippedItems_withReasonField() throws {
        let json = """
        {"applies_to_week":9,"skipped_items":[{"index":0,"reason":"beginner_engine_controlled"}],"applied_items":[]}
        """
        let dto = try decodeDataField(json)
        XCTAssertEqual(dto.skippedItems[0].reason, "beginner_engine_controlled")
    }
}
