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

    // The cold-launch auto-retry decision — the behavioral heart of the next-day fix.
    func test_resolvePendingSend_noPending_returnsNoPending() {
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: false, availability: .unavailable),
            .noPending
        )
    }

    func test_resolvePendingSend_pendingAndReady_retries() {
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: true, availability: .ready),
            .retry
        )
    }

    func test_resolvePendingSend_pendingButStillActivating_keepsWaiting() {
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: true, availability: .unavailable),
            .keepWaiting
        )
    }

    func test_resolvePendingSend_pendingButTerminalState_fails() {
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: true, availability: .appNotInstalled),
            .fail(.appNotInstalled)
        )
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: true, availability: .noWatch),
            .fail(.noWatch)
        )
    }

    // MARK: - Cold-launch settling (the 1.4.3 residual "next-day can't send" bug)
    //
    // Right after a cold-launch activation, `WCSession.isWatchAppInstalled` can read a
    // transient `false` before the watch handshake completes. 9989b75 gave `.unavailable`
    // a grace (keepWaiting) but still treated `.appNotInstalled` as terminal — so the
    // transient false surfaced an "Install Paceriz" prompt and killed the queued send even
    // though the app was installed (proven by day-1 having worked). These pin the fix:
    // demote a transient `.appNotInstalled` to `.unavailable` until the state settles.

    func test_effectiveAvailability_transientAppNotInstalled_demotedToUnavailable() {
        XCTAssertEqual(
            WatchCompanionService.effectiveAvailability(raw: .appNotInstalled, settled: false),
            .unavailable
        )
    }

    func test_effectiveAvailability_settledAppNotInstalled_staysAppNotInstalled() {
        XCTAssertEqual(
            WatchCompanionService.effectiveAvailability(raw: .appNotInstalled, settled: true),
            .appNotInstalled
        )
    }

    func test_effectiveAvailability_definitiveStatesPassThroughWhileUnsettled() {
        XCTAssertEqual(WatchCompanionService.effectiveAvailability(raw: .ready, settled: false), .ready)
        XCTAssertEqual(WatchCompanionService.effectiveAvailability(raw: .noWatch, settled: false), .noWatch)
        XCTAssertEqual(WatchCompanionService.effectiveAvailability(raw: .unavailable, settled: false), .unavailable)
    }

    // The behavioral payoff: while unsettled, a queued send keeps waiting (so a later
    // settle → ready retries and actually sends) instead of failing on a false negative.
    func test_resolvePendingSend_transientAppNotInstalled_keepsWaiting_thenRetriesOnSettle() {
        let transient = WatchCompanionService.effectiveAvailability(raw: .appNotInstalled, settled: false)
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: true, availability: transient),
            .keepWaiting
        )
        // …then the watch state settles to installed → ready → retry → send.
        XCTAssertEqual(
            WatchCompanionService.resolvePendingSend(hasPending: true, availability: .ready),
            .retry
        )
    }

    // Integration through the service: after a cold-launch activate(), a transient
    // not-installed read reports `.unavailable` (connecting), NOT `.appNotInstalled`.
    func test_sendAvailability_afterActivate_transientNotInstalled_isUnavailableNotInstallPrompt() {
        let session = SpyWatchPlanSession()
        session.isWatchAppInstalled = false // transient false right after cold-launch activation
        let service = WatchCompanionService(session: session)

        service.activate()

        XCTAssertEqual(service.sendAvailability, .unavailable)
        XCTAssertNotEqual(service.sendAvailability, .appNotInstalled)
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
