import XCTest
@testable import paceriz_dev

final class WatchCompanionServiceTests: XCTestCase {
    func test_todayPlanUserInfo_encodesPayloadWithExpectedType() throws {
        let dto = WatchPlanSnapshotDTO(
            date: "2026-06-05",
            runType: "interval",
            totalDistanceMeters: 5_000,
            totalSeconds: 1_800,
            planId: "plan-1",
            segments: [
                WatchSegmentDTO(
                    kind: "run",
                    measure: "distance",
                    targetMeters: 800,
                    targetSeconds: nil,
                    paceLowSecPerKm: 270,
                    paceHighSecPerKm: 270,
                    label: "800m",
                    repIndex: 1,
                    repTotal: 3
                )
            ]
        )

        let userInfo = try WatchCompanionService.todayPlanUserInfo(for: dto)

        XCTAssertEqual(userInfo["type"] as? String, "today_plan")
        let payload = try XCTUnwrap(userInfo["payload"] as? Data)
        let decoded = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: payload)
        XCTAssertEqual(decoded, dto)
    }

    func test_authUserInfo_encodesAuthState() {
        let userInfo = WatchCompanionService.authUserInfo(loggedIn: true)

        XCTAssertEqual(userInfo["type"] as? String, "auth")
        XCTAssertEqual(userInfo["logged_in"] as? Bool, true)
    }
}
