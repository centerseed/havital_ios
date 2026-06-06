import Foundation
import WatchConnectivity
import WidgetKit

final class WCSessionClient: NSObject, WCSessionDelegate {
    static let shared = WCSessionClient()

    private let store: WorkoutSnapshotStore
    private(set) var isLoggedIn = false

    init(store: WorkoutSnapshotStore = WorkoutSnapshotStore()) {
        self.store = store
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        applyIncomingPayload(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyIncomingPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyIncomingPayload(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        replyHandler(["ok": applyIncomingPayload(message)])
    }

    @discardableResult
    func applyIncomingPayload(_ payload: [String: Any]) -> Bool {
        switch payload["type"] as? String {
        case "today_plan":
            guard
                let data = payload["payload"] as? Data,
                let dto = try? JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: data)
            else {
                return false
            }
            store.save(dto)
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: .watchPlanUpdated, object: nil)
            return true
        case "auth":
            isLoggedIn = (payload["logged_in"] as? Bool) ?? false
            NotificationCenter.default.post(name: .watchAuthUpdated, object: nil)
            return true
        default:
            return false
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}

extension Notification.Name {
    static let watchPlanUpdated = Notification.Name("paceriz.watch.planUpdated")
    static let watchAuthUpdated = Notification.Name("paceriz.watch.authUpdated")
}
