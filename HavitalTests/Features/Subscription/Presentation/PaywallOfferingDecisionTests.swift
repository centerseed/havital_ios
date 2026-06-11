import XCTest
@testable import paceriz_dev

/// Paywall offering 選擇的純邏輯測試——覆蓋 6/30 前後 × 有/無買斷四象限 + fail-safe + 防漏。
/// 上線最在意的兩種失敗：①該看到 eb1 的看不到；②不該看到的看到 eb1（營收漏洞）。這裡鎖死。
final class PaywallOfferingDecisionTests: XCTestCase {

    private let GRAD = "graduate"
    private let DEF = "default"
    private let EB = "Early bird"

    private func decide(
        eligible: Bool,
        available: Set<String>,
        rcCurrent: String?,
        rcIsEarlyBird: Bool
    ) -> PaywallOfferingDecision.Result {
        PaywallOfferingDecision.decide(.init(
            isEb1Eligible: eligible,
            availableOfferingIds: available,
            rcCurrentOfferingId: rcCurrent,
            rcIsEarlyBird: rcIsEarlyBird,
            graduateId: GRAD,
            defaultId: DEF
        ))
    }

    // MARK: - 四象限

    func test_beforeSunset_noBuyout_showsPublicEarlyBird() {
        // 公開早鳥窗口期內、無買斷 → 公開 Early bird，早鳥樣式
        let r = decide(eligible: false, available: [EB, DEF, GRAD], rcCurrent: EB, rcIsEarlyBird: true)
        XCTAssertEqual(r.offeringId, EB)
        XCTAssertTrue(r.isEarlyBirdDisplay)
    }

    func test_beforeSunset_buyout_showsGraduate() {
        let r = decide(eligible: true, available: [EB, DEF, GRAD], rcCurrent: EB, rcIsEarlyBird: true)
        XCTAssertEqual(r.offeringId, GRAD)
        XCTAssertTrue(r.isEarlyBirdDisplay)
    }

    func test_afterSunset_noBuyout_showsStandard_noEb1Leak() {
        // 6/30 後、無買斷 → default 標準價，無早鳥（關鍵：不可漏 eb1 給非買斷者）
        let r = decide(eligible: false, available: [DEF, GRAD], rcCurrent: DEF, rcIsEarlyBird: false)
        XCTAssertEqual(r.offeringId, DEF)
        XCTAssertFalse(r.isEarlyBirdDisplay)
        XCTAssertNotEqual(r.offeringId, GRAD)
    }

    func test_afterSunset_buyout_keepsGraduateEb1() {
        // 6/30 後、有買斷 → graduate eb1 仍可見（關鍵：畢業生保住福利）
        let r = decide(eligible: true, available: [DEF, GRAD], rcCurrent: DEF, rcIsEarlyBird: false)
        XCTAssertEqual(r.offeringId, GRAD)
        XCTAssertTrue(r.isEarlyBirdDisplay)
    }

    // MARK: - Fail-safe

    func test_eligibleButGraduateMissing_fallsBackToCurrent_noCrash() {
        // ops 沒設 graduate offering → 退回 RC current，不崩、不亂給
        let r = decide(eligible: true, available: [DEF], rcCurrent: DEF, rcIsEarlyBird: false)
        XCTAssertEqual(r.offeringId, DEF)
        XCTAssertFalse(r.isEarlyBirdDisplay)
    }

    func test_nilRcCurrent_fallsBackToDefault() {
        let r = decide(eligible: false, available: [DEF], rcCurrent: nil, rcIsEarlyBird: false)
        XCTAssertEqual(r.offeringId, DEF)
    }

    // MARK: - 防漏鐵則

    func test_notEligible_neverSelectsGraduate_evenIfPresent() {
        // 非 eligible 即使 graduate 存在也絕不選它（杜絕人人永久早鳥）
        for (rc, eb) in [(EB, true), (DEF, false)] {
            let r = decide(eligible: false, available: [EB, DEF, GRAD], rcCurrent: rc, rcIsEarlyBird: eb)
            XCTAssertNotEqual(r.offeringId, GRAD, "non-eligible 不可被導到 graduate（rc=\(rc)）")
        }
    }
}
