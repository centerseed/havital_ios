import XCTest
@testable import paceriz_dev

/// SubscriptionStatusDTO 解碼測試
///
/// 後端新版 `/api/v1/subscription/status` 回傳 9 個欄位（含 4 個新欄位：
/// trial_remaining_days、is_early_bird、has_override、in_intro_trial），
/// 以及 rizo_usage 內的 remaining / resets_at。舊版後端不會回傳這些欄位——
/// DTO 必須向後相容（缺欄位時以 nil 預設，不 crash）。
final class SubscriptionStatusDTOTests: XCTestCase {

    private var decoder: JSONDecoder { JSONDecoder() }

    func testDecodeAllNineFieldsFromBackendResponse() throws {
        let json = """
        {
            "status": "trial_active",
            "expires_at": "2026-05-01T00:00:00Z",
            "plan_type": "monthly",
            "rizo_usage": {"used": 3, "limit": 10, "remaining": 7, "resets_at": "2026-04-22T00:00:00Z"},
            "billing_issue": false,
            "enforcement_enabled": true,
            "trial_remaining_days": 12,
            "is_early_bird": true,
            "has_override": false,
            "in_intro_trial": true
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(SubscriptionStatusDTO.self, from: json)

        XCTAssertEqual(dto.status, "trial_active")
        XCTAssertEqual(dto.expiresAt, "2026-05-01T00:00:00Z")
        XCTAssertEqual(dto.planType, "monthly")
        XCTAssertEqual(dto.billingIssue, false)
        XCTAssertEqual(dto.enforcementEnabled, true)
        XCTAssertEqual(dto.trialRemainingDays, 12)
        XCTAssertEqual(dto.isEarlyBird, true)
        XCTAssertEqual(dto.hasOverride, false)
        XCTAssertEqual(dto.inIntroTrial, true)
        XCTAssertNotNil(dto.rizoUsage)
    }

    func testDecodeRizoUsageRemainingAndResetsAt() throws {
        let json = """
        {
            "status": "subscribed",
            "rizo_usage": {"used": 2, "limit": 10, "remaining": 8, "resets_at": "2026-04-22T00:00:00Z"}
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(SubscriptionStatusDTO.self, from: json)

        let rizo = try XCTUnwrap(dto.rizoUsage)
        XCTAssertEqual(rizo.used, 2)
        XCTAssertEqual(rizo.limit, 10)
        XCTAssertEqual(rizo.remaining, 8)
        XCTAssertEqual(rizo.resetsAt, "2026-04-22T00:00:00Z")
    }

    func testDecodeMissingOptionalFieldsUsesDefaults() throws {
        // 模擬舊版後端：只回傳 status 與 expires_at，其他欄位通通缺席。
        // DTO 必須能成功解碼，所有 Optional 為 nil。
        let json = """
        {
            "status": "subscribed",
            "expires_at": "2026-12-31T00:00:00Z"
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(SubscriptionStatusDTO.self, from: json)

        XCTAssertEqual(dto.status, "subscribed")
        XCTAssertEqual(dto.expiresAt, "2026-12-31T00:00:00Z")
        XCTAssertNil(dto.planType)
        XCTAssertNil(dto.rizoUsage)
        XCTAssertNil(dto.billingIssue)
        XCTAssertNil(dto.enforcementEnabled)
        XCTAssertNil(dto.trialRemainingDays)
        XCTAssertNil(dto.isEarlyBird)
        XCTAssertNil(dto.hasOverride)
        XCTAssertNil(dto.inIntroTrial)
    }

    func testDecodeRizoUsageWithoutRemainingOrResetsAt() throws {
        // 舊版後端的 rizo_usage 只有 used/limit。
        let json = """
        {
            "status": "subscribed",
            "rizo_usage": {"used": 4, "limit": 10}
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(SubscriptionStatusDTO.self, from: json)

        let rizo = try XCTUnwrap(dto.rizoUsage)
        XCTAssertEqual(rizo.used, 4)
        XCTAssertEqual(rizo.limit, 10)
        XCTAssertNil(rizo.remaining)
        XCTAssertNil(rizo.resetsAt)
    }
}
