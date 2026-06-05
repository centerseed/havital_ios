import XCTest
@testable import HavitalWatch

final class RPEFeedbackTests: XCTestCase {
    func test_lowBand_1to3() {
        for value in 1...3 {
            XCTAssertEqual(RPEFeedback.text(for: value), "輕巧地完成 ✓")
        }
    }

    func test_mediumBand_4to5() {
        for value in 4...5 {
            XCTAssertEqual(RPEFeedback.text(for: value), "節奏掌握得不錯 ✓")
        }
    }

    func test_highBand_6to7() {
        for value in 6...7 {
            XCTAssertEqual(RPEFeedback.text(for: value), "紮實的一次 ✓")
        }
    }

    func test_maxBand_8to10() {
        for value in 8...10 {
            XCTAssertEqual(RPEFeedback.text(for: value), "硬仗打完了 💪")
        }
    }
}
