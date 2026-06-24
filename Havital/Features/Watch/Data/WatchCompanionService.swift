import Foundation
import WatchConnectivity

protocol WatchPlanSessioning: AnyObject {
    var isSupported: Bool { get }
    var activationState: WCSessionActivationState { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    var isReachable: Bool { get }

    func activate()
    func updateApplicationContext(_ context: [String: Any]) throws
    func transferUserInfo(_ userInfo: [String: Any])
    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )
}

final class DefaultWatchPlanSession: WatchPlanSessioning {
    private let session: WCSession

    init(session: WCSession = .default) {
        self.session = session
    }

    var isSupported: Bool {
        WCSession.isSupported()
    }

    var activationState: WCSessionActivationState {
        session.activationState
    }

    var isPaired: Bool {
        session.isPaired
    }

    var isWatchAppInstalled: Bool {
        session.isWatchAppInstalled
    }

    var isReachable: Bool {
        session.isReachable
    }

    func setDelegate(_ delegate: WCSessionDelegate?) {
        session.delegate = delegate
    }

    func activate() {
        session.activate()
    }

    func updateApplicationContext(_ context: [String: Any]) throws {
        try session.updateApplicationContext(context)
    }

    func transferUserInfo(_ userInfo: [String: Any]) {
        session.transferUserInfo(userInfo)
    }

    func sendMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }
}

final class WatchCompanionService: NSObject, WCSessionDelegate {
    static let shared = WatchCompanionService()
    private let session: WatchPlanSessioning
    private static let logTag = "WatchCompanion"

    // After a cold-launch (re)activation, WCSession's paired/installed flags can read stale
    // for a brief window before the watch handshake completes. In that window a raw
    // `.appNotInstalled` is a FALSE NEGATIVE — the root cause of the "next-day cold launch
    // shows Install / can't send" report even though the watch app is installed (the 1.4.3
    // bug that 9989b75 only half-fixed: it gave `.unavailable` a grace but still treated a
    // transient `.appNotInstalled` as terminal). We suppress that transient until the state
    // settles: a real `sessionWatchStateDidChange`, a positive activation, or a grace deadline.
    private var hasSettledWatchState = true
    private var settleDeadline: DispatchWorkItem?
    private static let settleGrace: TimeInterval = 3.0

    enum WatchAvailability: Equatable {
        case ready
        case appNotInstalled
        case noWatch
        case unavailable
    }

    /// Outcome of a send attempt. Carries WHY a send failed so the UI can show a
    /// specific, honest message and logs can pinpoint the failing boundary in prod.
    enum SendOutcome: Equatable {
        case sent
        case notReady(WatchAvailability)
        case encodingFailed
    }

    /// What to do with a send that was queued while the session was still activating,
    /// re-evaluated whenever availability changes. This is the core of the fix for the
    /// "next-day cold launch can't send" bug, extracted so it is unit-testable rather
    /// than buried in the View.
    enum PendingSendResolution: Equatable {
        case noPending
        case retry
        case keepWaiting
        case fail(WatchAvailability)
    }

    static func resolvePendingSend(
        hasPending: Bool,
        availability: WatchAvailability
    ) -> PendingSendResolution {
        guard hasPending else { return .noPending }
        switch availability {
        case .ready:
            return .retry
        case .unavailable:
            return .keepWaiting // session still activating — wait for the next change
        case .appNotInstalled, .noWatch:
            return .fail(availability)
        }
    }

    init(session: WatchPlanSessioning = DefaultWatchPlanSession()) {
        self.session = session
        super.init()
    }

    func activate() {
        guard session.isSupported else { return }
        (session as? DefaultWatchPlanSession)?.setDelegate(self)
        // Re-entering activation: treat the watch state as unsettled again until the
        // handshake proves otherwise, so a transient `.appNotInstalled` is not trusted.
        hasSettledWatchState = false
        armSettleDeadline()
        session.activate()
    }

    /// Live read of the session, before cold-launch settling is applied.
    var rawAvailability: WatchAvailability {
        guard session.isSupported else { return .unavailable }

        guard session.activationState == .activated else { return .unavailable }
        guard session.isPaired else { return .noWatch }
        guard session.isWatchAppInstalled else { return .appNotInstalled }
        return .ready
    }

    var sendAvailability: WatchAvailability {
        Self.effectiveAvailability(raw: rawAvailability, settled: hasSettledWatchState)
    }

    /// During the unsettled cold-launch window, demote a transient `.appNotInstalled` to
    /// `.unavailable` ("still connecting") so the UI does not show a false "Install Paceriz"
    /// prompt and a queued send keeps waiting (then retries on settle) instead of giving up.
    /// Positive/definitive states (`.ready`, `.noWatch`) always pass through.
    static func effectiveAvailability(
        raw: WatchAvailability,
        settled: Bool
    ) -> WatchAvailability {
        if !settled, raw == .appNotInstalled { return .unavailable }
        return raw
    }

    private func armSettleDeadline() {
        settleDeadline?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.markWatchStateSettled()
            NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
        }
        settleDeadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleGrace, execute: work)
    }

    private func markWatchStateSettled() {
        settleDeadline?.cancel()
        settleDeadline = nil
        hasSettledWatchState = true
    }

    @discardableResult
    func sendTodayPlan(_ dto: WatchPlanSnapshotDTO) -> SendOutcome {
        let outcome = performSendTodayPlan(dto)
        emitWatchDiagnostic(reason: "send", outcome: outcome)
        return outcome
    }

    private func performSendTodayPlan(_ dto: WatchPlanSnapshotDTO) -> SendOutcome {
        let availability = sendAvailability
        guard availability == .ready else {
            Logger.warn("sendTodayPlan blocked: availability=\(availability)", tag: Self.logTag)
            return .notReady(availability)
        }

        guard let userInfo = try? Self.todayPlanUserInfo(for: dto) else {
            Logger.error("sendTodayPlan failed: today plan payload encoding failed", tag: Self.logTag)
            return .encodingFailed
        }

        do {
            try session.updateApplicationContext(userInfo)
        } catch {
            Logger.error("updateApplicationContext failed: \(error.localizedDescription)", tag: Self.logTag)
        }

        session.transferUserInfo(userInfo)

        if session.isReachable {
            session.sendMessage(userInfo, replyHandler: nil) { error in
                Logger.error("sendMessage failed: \(error.localizedDescription)", tag: Self.logTag)
            }
        }

        return .sent
    }

    /// Diagnostics-only: report the live WCSession booleans + send outcome to analytics so we
    /// can see the REAL on-device state of a customer's watch send path. No behaviour change.
    /// No-op when DI is not bootstrapped (e.g. unit tests) so existing tests are unaffected.
    private func emitWatchDiagnostic(reason: String, outcome: SendOutcome?) {
        guard DependencyContainer.shared.isRegistered(AnalyticsService.self) else { return }
        let analytics: AnalyticsService = DependencyContainer.shared.resolve()
        analytics.track(.watchSendDiagnostic(
            reason: reason,
            outcome: outcome.map { String(describing: $0) } ?? "n/a",
            availability: String(describing: sendAvailability),
            activationState: session.activationState.rawValue,
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable,
            settled: hasSettledWatchState
        ))
    }

    @discardableResult
    func pushAuth(loggedIn: Bool) -> Bool {
        guard session.isSupported else { return false }
        let userInfo = Self.authUserInfo(loggedIn: loggedIn)
        try? session.updateApplicationContext(userInfo)
        session.transferUserInfo(userInfo)
        if session.isReachable {
            session.sendMessage(userInfo, replyHandler: nil, errorHandler: nil)
        }
        return true
    }

    static func todayPlanUserInfo(for dto: WatchPlanSnapshotDTO) throws -> [String: Any] {
        [
            "type": "today_plan",
            "payload": try JSONEncoder().encode(dto)
        ]
    }

    static func authUserInfo(loggedIn: Bool) -> [String: Any] {
        [
            "type": "auth",
            "logged_in": loggedIn
        ]
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // A positive read at activation is authoritative; otherwise let the state settle
        // (a later watch-state change or the grace deadline) before trusting a negative.
        if rawAvailability == .ready { markWatchStateSettled() }
        emitWatchDiagnostic(reason: "activation", outcome: nil)
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Availability drops out of `.ready` here; republish so any cached UI state
        // (e.g. the "send to watch" button) cannot stay stale and accept a tap that
        // will fail the live guard in `sendTodayPlan`.
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        self.session.activate()
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // The system has reported the authoritative watch state — settling is over.
        markWatchStateSettled()
        emitWatchDiagnostic(reason: "state_change", outcome: nil)
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }
}

extension Notification.Name {
    static let watchAvailabilityChanged = Notification.Name("paceriz.watch.availabilityChanged")
}
