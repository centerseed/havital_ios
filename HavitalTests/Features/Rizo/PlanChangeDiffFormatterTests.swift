import XCTest
@testable import paceriz_dev

final class PlanChangeDiffFormatterTests: XCTestCase {

    private func face(_ cat: String, _ rt: String?, _ km: Double?) -> PlanChangeDayFace {
        PlanChangeDayFace(category: cat, runType: rt, distanceKm: km)
    }

    func test_distance_only_change_shows_type_and_old_new_km() {
        let day = PlanChangeDiffDay(dayIndex: 6,
                                    from: face("run", "lsd", 15.0),
                                    to: face("run", "lsd", 12.0))
        let line = PlanChangeDiffFormatter.line(for: day)
        XCTAssertTrue(line.contains("15 → 12"), line)
        XCTAssertTrue(line.contains(NSLocalizedString("training.type.lsd", comment: "")), line)
    }

    func test_type_change_shows_old_arrow_new_type() {
        let day = PlanChangeDiffDay(dayIndex: 3,
                                    from: face("run", "easy", 5.0),
                                    to: face("run", "interval", 6.0))
        let line = PlanChangeDiffFormatter.line(for: day)
        XCTAssertTrue(line.contains(NSLocalizedString("training.type.easy", comment: "")), line)
        XCTAssertTrue(line.contains(NSLocalizedString("training.type.interval", comment: "")), line)
        XCTAssertTrue(line.contains("→"), line)
    }

    func test_cross_category_rest_to_run() {
        let day = PlanChangeDiffDay(dayIndex: 4,
                                    from: face("rest", nil, nil),
                                    to: face("run", "easy", 5.0))
        let line = PlanChangeDiffFormatter.line(for: day)
        XCTAssertTrue(line.contains(NSLocalizedString("training.type.rest", comment: "")), line)
        XCTAssertTrue(line.contains(NSLocalizedString("training.type.easy", comment: "")), line)
    }

    func test_unknown_run_type_falls_back_to_raw() {
        let day = PlanChangeDiffDay(dayIndex: 1,
                                    from: face("run", "easy", 5.0),
                                    to: face("run", "totally_new_type", 5.0))
        let line = PlanChangeDiffFormatter.line(for: day)
        XCTAssertTrue(line.contains("totally_new_type"), line)  // 查無 key → 顯示原值，不空白
    }

    func test_decimal_distance_not_rounded() {
        let day = PlanChangeDiffDay(dayIndex: 2,
                                    from: face("run", "fartlek", 4.85),
                                    to: face("run", "fartlek", 3.0))
        let line = PlanChangeDiffFormatter.line(for: day)
        XCTAssertTrue(line.contains("4.85"), line)   // 不可四捨五入成 5
        XCTAssertTrue(line.contains("3 "), line + " (3 應為整數無小數)")
    }

    func test_lines_joins_multiple_days() {
        let days = [
            PlanChangeDiffDay(dayIndex: 6, from: face("run", "lsd", 15.0), to: face("run", "lsd", 12.0)),
            PlanChangeDiffDay(dayIndex: 7, from: face("rest", nil, nil), to: face("run", "easy", 5.0)),
        ]
        let text = PlanChangeDiffFormatter.text(for: days)
        XCTAssertEqual(text.split(separator: "\n").count, 2)
    }
}
