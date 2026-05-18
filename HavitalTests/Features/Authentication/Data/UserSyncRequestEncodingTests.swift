import XCTest
@testable import paceriz_dev

final class UserSyncRequestEncodingTests: XCTestCase {
    func test_encode_includesTopLevelLanguageAndKeepsDeviceLocaleSeparate() throws {
        let request = UserSyncRequest(
            firebaseUid: "uid-123",
            idToken: "token-123",
            fcmToken: nil,
            language: "en-US",
            deviceInfo: DeviceInfo(
                model: "iPhone",
                osVersion: "26.5",
                appVersion: "1.0.0",
                locale: "zh_TW"
            )
        )

        let payload = try encodedJSONObject(request)
        let deviceInfo = try XCTUnwrap(payload["device_info"] as? [String: Any])

        XCTAssertEqual(payload["language"] as? String, "en-US")
        XCTAssertEqual(deviceInfo["locale"] as? String, "zh_TW")
    }

    func test_encode_omitsLanguageWhenNoPreferenceIsProvided() throws {
        let request = UserSyncRequest(
            firebaseUid: "uid-123",
            idToken: "token-123",
            deviceInfo: DeviceInfo(locale: "ja_JP")
        )

        let payload = try encodedJSONObject(request)

        XCTAssertNil(payload["language"])
        XCTAssertNotNil(payload["device_info"])
    }

    private func encodedJSONObject(_ request: UserSyncRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
