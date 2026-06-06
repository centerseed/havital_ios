import XCTest
@testable import paceriz_dev

final class StateCardDTOTests: XCTestCase {
    func test_decodes_paid_card() throws {
        let json = """
        {"lens":"pre","source":"llm","headline":"你的輕鬆跑控得很好","fact_type":"trait_surfacing",
         "narrative_text":"今天照計畫 12 公里輕鬆跑。","chips":["輕鬆跑紀律"],"cause_chips":[],
         "action":{"kind":"affirm","session_ref":{"run_type":"easy","distance_km":12.0,"pace":"6:45"},"rizo_handoff":null},
         "divergence":{"present":false,"flag_text":null,"suggested_rizo_scenario":null},
         "access":{"is_paid":true,"locked":false,"upsell":null}}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StateCardDTO.self, from: json)
        XCTAssertEqual(dto.lens, "pre")
        XCTAssertEqual(dto.headline, "你的輕鬆跑控得很好")
        XCTAssertEqual(dto.chips, ["輕鬆跑紀律"])
        XCTAssertEqual(dto.action?.sessionRef?.distanceKm, 12.0)
        XCTAssertEqual(dto.access.locked, false)
    }

    func test_decodes_free_locked_card_missing_chips() throws {
        // 後端未部署 chips 時:chips 缺 → nil(優雅降級);narrative null
        let json = """
        {"lens":"pre","source":"fallback","headline":"你的輕鬆跑控得很好","fact_type":"trait_surfacing",
         "narrative_text":null,
         "action":{"kind":"affirm","session_ref":null,"rizo_handoff":null},
         "divergence":{"present":false,"flag_text":null,"suggested_rizo_scenario":null},
         "access":{"is_paid":false,"locked":true,"upsell":{"reason":"unlock_full_read"}}}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(StateCardDTO.self, from: json)
        XCTAssertNil(dto.narrativeText)
        XCTAssertNil(dto.chips)
        XCTAssertEqual(dto.access.locked, true)
    }
}
