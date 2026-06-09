import XCTest
import WatchConnectivity
@testable import paceriz_dev

final class WatchCompanionServiceTests: XCTestCase {
    private final class SpyWatchPlanSession: WatchPlanSessioning {
        var isSupported = true
        var activationState: WCSessionActivationState = .activated
        var isPaired = true
        var isWatchAppInstalled = true
        var isReachable = false

        private(set) var didActivate = false
        private(set) var applicationContexts: [[String: Any]] = []
        private(set) var transferredUserInfos: [[String: Any]] = []
        private(set) var sentMessages: [[String: Any]] = []

        func activate() {
            didActivate = true
        }

        func updateApplicationContext(_ context: [String: Any]) throws {
            applicationContexts.append(context)
        }

        func transferUserInfo(_ userInfo: [String: Any]) {
            transferredUserInfos.append(userInfo)
        }

        func sendMessage(
            _ message: [String: Any],
            replyHandler: (([String: Any]) -> Void)?,
            errorHandler: ((Error) -> Void)?
        ) {
            sentMessages.append(message)
            replyHandler?(["ok": true])
        }
    }

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

    func test_sendTodayPlan_updatesLatestContextAndQueuesFallbackTransfer() throws {
        let session = SpyWatchPlanSession()
        let service = WatchCompanionService(session: session)
        let dto = makeTodayPlanDTO()

        XCTAssertEqual(service.sendTodayPlan(dto), .sent)

        XCTAssertEqual(session.applicationContexts.count, 1)
        XCTAssertEqual(session.transferredUserInfos.count, 1)
        XCTAssertEqual(session.sentMessages.count, 0)
        try assertTodayPlanPayload(session.applicationContexts[0], equals: dto)
        try assertTodayPlanPayload(session.transferredUserInfos[0], equals: dto)
    }

    func test_sendTodayPlan_sendsImmediateMessageWhenWatchIsReachable() throws {
        let session = SpyWatchPlanSession()
        session.isReachable = true
        let service = WatchCompanionService(session: session)
        let dto = makeTodayPlanDTO()

        XCTAssertEqual(service.sendTodayPlan(dto), .sent)

        XCTAssertEqual(session.applicationContexts.count, 1)
        XCTAssertEqual(session.transferredUserInfos.count, 1)
        XCTAssertEqual(session.sentMessages.count, 1)
        try assertTodayPlanPayload(session.sentMessages[0], equals: dto)
    }

    // Regression for the "next-day re-send fails" report (user fmc7…):
    // when the session is not yet activated (cold launch, async activate still in flight),
    // sendTodayPlan must report WHY it failed and must NOT silently queue a transfer.
    func test_sendTodayPlan_whenNotActivated_reportsNotReadyAndDoesNotTransfer() {
        let session = SpyWatchPlanSession()
        session.activationState = .notActivated
        let service = WatchCompanionService(session: session)

        XCTAssertEqual(service.sendTodayPlan(makeTodayPlanDTO()), .notReady(.unavailable))
        XCTAssertEqual(session.applicationContexts.count, 0)
        XCTAssertEqual(session.transferredUserInfos.count, 0)
        XCTAssertEqual(session.sentMessages.count, 0)
    }

    func test_sendTodayPlan_whenWatchNotPaired_reportsNoWatch() {
        let session = SpyWatchPlanSession()
        session.isPaired = false
        let service = WatchCompanionService(session: session)

        XCTAssertEqual(service.sendTodayPlan(makeTodayPlanDTO()), .notReady(.noWatch))
    }

    func test_sendTodayPlan_whenAppNotInstalled_reportsAppNotInstalled() {
        let session = SpyWatchPlanSession()
        session.isWatchAppInstalled = false
        let service = WatchCompanionService(session: session)

        XCTAssertEqual(service.sendTodayPlan(makeTodayPlanDTO()), .notReady(.appNotInstalled))
    }

    private func makeTodayPlanDTO() -> WatchPlanSnapshotDTO {
        WatchPlanSnapshotDTO(
            date: "2026-06-05",
            runType: "easy",
            totalDistanceMeters: 3_000,
            totalSeconds: nil,
            planId: "plan-today",
            segments: [
                WatchSegmentDTO(
                    kind: "run",
                    measure: "distance",
                    targetMeters: 3_000,
                    targetSeconds: nil,
                    paceLowSecPerKm: 395,
                    paceHighSecPerKm: 435,
                    label: "輕鬆跑",
                    repIndex: nil,
                    repTotal: nil
                )
            ]
        )
    }

    private func assertTodayPlanPayload(
        _ userInfo: [String: Any],
        equals expected: WatchPlanSnapshotDTO,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(userInfo["type"] as? String, "today_plan", file: file, line: line)
        let payload = try XCTUnwrap(userInfo["payload"] as? Data, file: file, line: line)
        let decoded = try JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: payload)
        XCTAssertEqual(decoded, expected, file: file, line: line)
    }
}
