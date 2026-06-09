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

    init(session: WatchPlanSessioning = DefaultWatchPlanSession()) {
        self.session = session
        super.init()
    }

    func activate() {
        guard session.isSupported else { return }
        (session as? DefaultWatchPlanSession)?.setDelegate(self)
        session.activate()
    }

    var sendAvailability: WatchAvailability {
        guard session.isSupported else { return .unavailable }

        guard session.activationState == .activated else { return .unavailable }
        guard session.isPaired else { return .noWatch }
        guard session.isWatchAppInstalled else { return .appNotInstalled }
        return .ready
    }

    @discardableResult
    func sendTodayPlan(_ dto: WatchPlanSnapshotDTO) -> SendOutcome {
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
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }
}

extension Notification.Name {
    static let watchAvailabilityChanged = Notification.Name("paceriz.watch.availabilityChanged")
}
