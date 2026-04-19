#if DEBUG
import XCTest
@testable import paceriz_dev

final class V2FixtureExportHelpersTests: XCTestCase {

    func testRedactPIIRedactsNestedSensitiveKeys() {
        let input: [String: Any] = [
            "email": "runner@example.com",
            "safe": "value",
            "nested": [
                "uid": "user_123",
                "items": [
                    ["accessToken": "secret-token"],
                    ["plain": "kept"]
                ]
            ]
        ]

        let redacted = V2FixtureExportHelpers.redactPII(input) as? [String: Any]
        let nested = redacted?["nested"] as? [String: Any]
        let items = nested?["items"] as? [[String: Any]]

        XCTAssertEqual(redacted?["email"] as? String, "[REDACTED]")
        XCTAssertEqual(redacted?["safe"] as? String, "value")
        XCTAssertEqual(nested?["uid"] as? String, "[REDACTED]")
        XCTAssertEqual(items?.first?["accessToken"] as? String, "[REDACTED]")
        XCTAssertEqual(items?.last?["plain"] as? String, "kept")
    }

    func testBuildMetaEnvelopeHashesUidAndRedactsResponsePayload() throws {
        let rawJSON = """
        {
          "email": "runner@example.com",
          "nested": {
            "uid": "abc123",
            "value": "ok"
          }
        }
        """.data(using: .utf8)!
        let now = ISO8601DateFormatter().date(from: "2026-04-19T10:00:00Z")!

        let envelope = V2FixtureExportHelpers.buildMetaEnvelope(
            endpoint: "/v2/plan/status",
            targetType: "race_run",
            rawData: rawJSON,
            uid: "user-42",
            now: now,
            appVersion: "1.2.3",
            buildNumber: "456"
        )

        let meta = try XCTUnwrap(envelope["_meta"] as? [String: Any])
        let response = try XCTUnwrap(envelope["response"] as? [String: Any])
        let nested = try XCTUnwrap(response["nested"] as? [String: Any])

        XCTAssertEqual(meta["endpoint"] as? String, "/v2/plan/status")
        XCTAssertEqual(meta["target_type"] as? String, "race_run")
        XCTAssertEqual(meta["app_version"] as? String, "1.2.3")
        XCTAssertEqual(meta["build_number"] as? String, "456")
        XCTAssertEqual(meta["uid_hash"] as? String, V2FixtureExportHelpers.sha256Prefix8("user-42"))
        XCTAssertEqual(response["email"] as? String, "[REDACTED]")
        XCTAssertEqual(nested["uid"] as? String, "[REDACTED]")
        XCTAssertEqual(nested["value"] as? String, "ok")
    }

    func testWriteFixtureFileCreatesReadableJSONOnDisk() throws {
        let envelope: [String: Any] = [
            "_meta": ["endpoint": "/v2/plan/status", "target_type": "maintenance"],
            "response": ["ok": true]
        ]
        let now = ISO8601DateFormatter().date(from: "2026-04-19T10:00:00Z")!

        let url = try V2FixtureExportHelpers.writeFixtureFile(
            envelope: envelope,
            endpoint: "/v2/plan/status",
            targetType: "maintenance",
            now: now
        )
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.contains("v2_maintenance_v2_plan_status_20260419-100000"))

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = json?["response"] as? [String: Any]
        XCTAssertEqual(response?["ok"] as? Bool, true)
    }
}
#endif
