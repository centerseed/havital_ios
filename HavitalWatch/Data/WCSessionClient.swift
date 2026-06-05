import Foundation
import WatchConnectivity
import WidgetKit

final class WCSessionClient: NSObject, WCSessionDelegate {
    static let shared = WCSessionClient()

    private let store = WorkoutSnapshotStore()
    private(set) var isLoggedIn = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        switch userInfo["type"] as? String {
        case "today_plan":
            guard
                let data = userInfo["payload"] as? Data,
                let dto = try? JSONDecoder().decode(WatchPlanSnapshotDTO.self, from: data)
            else {
                return
            }
            store.save(dto)
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: .watchPlanUpdated, object: nil)
        case "auth":
            isLoggedIn = (userInfo["logged_in"] as? Bool) ?? false
            NotificationCenter.default.post(name: .watchAuthUpdated, object: nil)
        default:
            break
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
