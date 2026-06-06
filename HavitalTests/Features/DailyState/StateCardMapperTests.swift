import XCTest
@testable import paceriz_dev

final class StateCardMapperTests: XCTestCase {
    private func dto(narrative: String?, chips: [String]?, locked: Bool) -> StateCardDTO {
        StateCardDTO(lens: "pre", source: "llm", headline: "H", factType: "trait_surfacing",
            narrativeText: narrative, chips: chips, causeChips: ["疲勞累積"],
            action: .init(kind: "affirm",
                          sessionRef: .init(runType: "easy", distanceKm: 12, pace: "6:45"),
                          rizoHandoff: nil),
            divergence: .init(present: false, flagText: nil, suggestedRizoScenario: nil),
            access: .init(isPaid: !locked, locked: locked, upsell: locked ? .init(reason: "unlock_full_read") : nil))
    }

    func test_maps_paid() {
        let e = StateCardMapper.toEntity(from: dto(narrative: "五段", chips: ["輕鬆跑紀律"], locked: false))
        XCTAssertEqual(e.lens, .pre)
        XCTAssertEqual(e.headline, "H")
        XCTAssertEqual(e.narrativeText, "五段")
        XCTAssertEqual(e.chips, ["輕鬆跑紀律"])
        XCTAssertEqual(e.causeChips, ["疲勞累積"])
        XCTAssertEqual(e.actionLine, "12K easy · 6:45")
        XCTAssertFalse(e.isLocked)
    }

    func test_maps_free_nil_chips() {
        let e = StateCardMapper.toEntity(from: dto(narrative: nil, chips: nil, locked: true))
        XCTAssertNil(e.narrativeText)
        XCTAssertEqual(e.chips, [])           // nil → 空(優雅)
        XCTAssertTrue(e.isLocked)
    }
}
