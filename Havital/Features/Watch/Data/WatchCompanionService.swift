import Foundation
import WatchConnectivity

final class WatchCompanionService: NSObject, WCSessionDelegate {
    static let shared = WatchCompanionService()

    enum WatchAvailability: Equatable {
        case ready
        case appNotInstalled
        case noWatch
        case unavailable
    }

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    var sendAvailability: WatchAvailability {
        guard WCSession.isSupported() else { return .unavailable }

        let session = WCSession.default
        guard session.activationState == .activated else { return .unavailable }
        guard session.isPaired else { return .noWatch }
        guard session.isWatchAppInstalled else { return .appNotInstalled }
        return .ready
    }

    @discardableResult
    func sendTodayPlan(_ dto: WatchPlanSnapshotDTO) -> Bool {
        guard WCSession.isSupported(),
              let userInfo = try? Self.todayPlanUserInfo(for: dto) else {
            return false
        }
        WCSession.default.transferUserInfo(userInfo)
        return true
    }

    @discardableResult
    func pushAuth(loggedIn: Bool) -> Bool {
        guard WCSession.isSupported() else { return false }
        WCSession.default.transferUserInfo(Self.authUserInfo(loggedIn: loggedIn))
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
        WCSession.default.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        NotificationCenter.default.post(name: .watchAvailabilityChanged, object: nil)
    }
}

extension Notification.Name {
    static let watchAvailabilityChanged = Notification.Name("paceriz.watch.availabilityChanged")
}
