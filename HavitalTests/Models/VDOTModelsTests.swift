import XCTest
@testable import paceriz_dev

final class VDOTModelsTests: XCTestCase {
    func testDecodesPaceAndLiveVDOTWithoutWeightVDOT() throws {
        let json = #"{"datetime":1784073600,"dynamic_vdot":45.2,"pace_vdot":45.2,"live_vdot":52.1}"#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(VDOTEntry.self, from: json)

        XCTAssertEqual(entry.resolvedPaceVdot, 45.2)
        XCTAssertEqual(entry.liveVdot, 52.1)
        XCTAssertNil(entry.weightVdot)
    }

    func testLegacyDynamicVDOTMapsToPaceCompatibilityValue() throws {
        let json = #"{"datetime":1784073600,"dynamic_vdot":43.0,"weight_vdot":41.0}"#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(VDOTEntry.self, from: json)

        XCTAssertEqual(entry.resolvedPaceVdot, 43.0)
    }
}
