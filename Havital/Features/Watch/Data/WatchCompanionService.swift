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

    enum WatchAvailability: Equatable {
        case ready
        case appNotInstalled
        case noWatch
        case unavailable
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
    func sendTodayPlan(_ dto: WatchPlanSnapshotDTO) -> Bool {
        guard session.isSupported,
              sendAvailability == .ready,
              let userInfo = try? Self.todayPlanUserInfo(for: dto) else {
            return false
        }

        do {
            try session.updateApplicationContext(userInfo)
        } catch {
            NSLog("WatchCompanionService updateApplicationContext failed: \(error.localizedDescription)")
        }

        session.transferUserInfo(userInfo)

        if session.isReachable {
            session.sendMessage(userInfo, replyHandler: nil) { error in
                NSLog("WatchCompanionService sendMessage failed: \(error.localizedDescription)")
            }
        }

        return true
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

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        self.session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }
}

extension Notification.Name {
    static let watchAvailabilityChanged = Notification.Name("paceriz.watch.availabilityChanged")
}
