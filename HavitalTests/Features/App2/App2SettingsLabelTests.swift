import XCTest
@testable import paceriz_dev

/// 訂閱狀態顯示字。
///
/// 這一組存在的理由是一個真缺陷：2.0 設定頁原本直接印
/// `status.planType ?? status.status.rawValue` ＋硬寫的 `d`，畫面出現 `expired · 0d`。
/// 判準只有一條 —— **後端識別字不得出現在顯示字裡**，而且三語都要有字。
final class App2SettingsLabelTests: XCTestCase {

    private func status(
        _ state: SubscriptionStatus,
        planType: String? = nil,
        trialEndAt: TimeInterval? = nil,
        billingIssue: Bool = false,
        inGracePeriod: Bool = false,
        graceRemainingDays: Int? = nil
    ) -> SubscriptionStatusEntity {
        SubscriptionStatusEntity(
            status: state,
            expiresAt: nil,
            planType: planType,
            billingIssue: billingIssue,
            enforcementEnabled: true,
            trialEndAt: trialEndAt,
            inGracePeriod: inGracePeriod,
            graceRemainingDays: graceRemainingDays
        )
    }

    /// 後端識別字原樣：`SubscriptionStatus` 的 rawValue ＋ 已知 planType。
    ///
    /// 比對用**完全相等**而不是子字串 —— 英文在地化字本來就長得像識別字
    /// （`Expired`／`Trial`），子字串比對會把正確的翻譯也判成洩漏。
    private let rawIdentifiers = [
        "active", "expired", "trial", "none", "cancelled", "gracePeriod",
        "yearly", "monthly", "some_unknown_plan"
    ]

    private func assertNoRawIdentifier(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(label.isEmpty, "顯示字不得為空", file: file, line: line)
        XCTAssertFalse(
            rawIdentifiers.contains(label),
            "顯示字就是後端識別字本身: \(label)", file: file, line: line
        )
        // snake_case 只會來自識別字，不會來自任何一種語言的文案。
        XCTAssertFalse(label.contains("_"), "顯示字含 snake_case 片段: \(label)", file: file, line: line)
        // 硬寫的天數單位（`0d`）是同一個缺陷的另一半。
        XCTAssertNil(
            label.range(of: #"\b\d+d\b"#, options: .regularExpression),
            "天數單位沒有在地化: \(label)", file: file, line: line
        )
    }

    func test_compactStateLabel_neverLeaksBackendIdentifiers() {
        let cases: [SubscriptionStatusEntity?] = [
            nil,
            status(.active, planType: "yearly"),
            status(.active, planType: "monthly"),
            status(.active, planType: "some_unknown_plan"),
            status(.expired),
            status(.cancelled),
            status(.none),
            status(.trial, trialEndAt: Date().addingTimeInterval(6 * 86400).timeIntervalSince1970),
            status(.trial),
            status(.gracePeriod, planType: "yearly"),
            status(.expired, billingIssue: true),
            status(.none, inGracePeriod: true, graceRemainingDays: 5)
        ]
        for entity in cases {
            assertNoRawIdentifier(SubscriptionStatusEntity.compactStateLabel(for: entity))
        }
    }

    /// 1.x 設定頁的「方案：…」與 2.0 共用同一支，一起鎖。
    func test_tierLabel_neverLeaksBackendIdentifiers() {
        let cases: [SubscriptionStatusEntity?] = [
            nil,
            status(.active, planType: "yearly"),
            status(.trial, trialEndAt: Date().addingTimeInterval(3 * 86400).timeIntervalSince1970),
            status(.expired),
            status(.none, inGracePeriod: true, graceRemainingDays: 2)
        ]
        for entity in cases {
            assertNoRawIdentifier(SubscriptionStatusEntity.tierLabel(for: entity))
        }
    }

    func test_compactStateLabel_expiredUsesLocalizedExpiredString() {
        XCTAssertEqual(
            SubscriptionStatusEntity.compactStateLabel(for: status(.expired)),
            NSLocalizedString("profile.subscription.expired", comment: "")
        )
    }

    func test_compactStateLabel_billingIssueTakesPrecedence() {
        XCTAssertEqual(
            SubscriptionStatusEntity.compactStateLabel(
                for: status(.active, planType: "yearly", billingIssue: true)
            ),
            NSLocalizedString("profile.subscription.billing_issue", comment: "")
        )
    }

    func test_compactStateLabel_activeIncludesPlanNameAndRenewingState() {
        let label = SubscriptionStatusEntity.compactStateLabel(for: status(.active, planType: "yearly"))
        XCTAssertTrue(label.contains(NSLocalizedString("profile.subscription.plan.yearly", comment: "")), label)
        XCTAssertTrue(label.contains(NSLocalizedString("app2.settings.subscription_active", comment: "")), label)
    }

    func test_compactStateLabel_nilStatusIsFreeNotEmpty() {
        XCTAssertEqual(
            SubscriptionStatusEntity.compactStateLabel(for: nil),
            NSLocalizedString("profile.subscription.free", comment: "")
        )
    }
}
