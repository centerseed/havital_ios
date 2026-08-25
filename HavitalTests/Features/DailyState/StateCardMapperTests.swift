import XCTest
@testable import paceriz_dev

final class StateCardMapperTests: XCTestCase {
    private func dto(narrative: String?, chips: [String]?, locked: Bool, mileageProgression: String? = nil) -> StateCardDTO {
        StateCardDTO(lens: "pre", source: "llm", headline: "H", factType: "trait_surfacing",
            narrativeText: narrative, collapsedReason: nil, chips: chips, causeChips: ["cause-chip"],
            mileageProgression: mileageProgression,
            action: .init(kind: "affirm",
                          sessionRef: .init(runType: "easy", distanceKm: 12, pace: "6:45"),
                          rizoHandoff: nil),
            divergence: .init(present: false, flagText: nil, suggestedRizoScenario: nil),
            access: .init(isPaid: !locked, locked: locked, upsell: locked ? .init(reason: "unlock_full_read") : nil),
            benchmarkCalibration: nil, insights: nil)
    }

    func test_maps_paid() {
        let e = StateCardMapper.toEntity(from: dto(narrative: "五段", chips: ["輕鬆跑紀律"], locked: false))
        XCTAssertEqual(e.lens, .pre)
        XCTAssertEqual(e.headline, "H")
        XCTAssertEqual(e.narrativeText, "五段")
        XCTAssertEqual(e.chips, ["輕鬆跑紀律"])
        XCTAssertEqual(e.causeChips, ["cause-chip"])
        XCTAssertEqual(e.actionLine, "12K easy · 6:45")
        XCTAssertFalse(e.isLocked)
    }

    func test_maps_free_nil_chips() {
        let e = StateCardMapper.toEntity(from: dto(narrative: nil, chips: nil, locked: true))
        XCTAssertNil(e.narrativeText)
        XCTAssertEqual(e.chips, [])           // nil → 空(優雅)
        XCTAssertTrue(e.isLocked)
    }

    func test_mapper_carries_mileage_progression() {
        let e = StateCardMapper.toEntity(from: dto(narrative: nil, chips: nil, locked: true, mileageProgression: "目前在打底階段，本週約 12 公里。"))
        XCTAssertEqual(e.mileageProgression, "目前在打底階段，本週約 12 公里。")
    }

    func test_mapper_nil_mileage_progression() {
        let e = StateCardMapper.toEntity(from: dto(narrative: nil, chips: nil, locked: false))
        XCTAssertNil(e.mileageProgression)
    }

    // T-0241:collapsed_reason 有值 → displayHeadline 用理由句;nil/空 → 退 headline。
    func test_collapsed_reason_replaces_display_headline() {
        var d = dto(narrative: nil, chips: nil, locked: false)
        d = StateCardDTO(lens: d.lens, source: d.source, headline: d.headline, factType: d.factType,
                         narrativeText: d.narrativeText,
                         collapsedReason: "Take it easy today - 34 km this week already",
                         chips: d.chips, causeChips: d.causeChips,
                         mileageProgression: d.mileageProgression, action: d.action,
                         divergence: d.divergence, access: d.access, benchmarkCalibration: nil, insights: nil)
        let e = StateCardMapper.toEntity(from: d)
        XCTAssertEqual(e.collapsedReason, "Take it easy today - 34 km this week already")
        XCTAssertEqual(e.displayHeadline, "Take it easy today - 34 km this week already")
    }

    func test_display_headline_falls_back_when_no_reason() {
        let e = StateCardMapper.toEntity(from: dto(narrative: nil, chips: nil, locked: false))
        XCTAssertNil(e.collapsedReason)
        XCTAssertEqual(e.displayHeadline, "H")
    }
}
