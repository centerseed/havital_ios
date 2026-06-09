import SwiftUI

@main
struct HavitalWatchApp: App {
    init() {
        WCSessionClient.shared.activate()
        #if DEBUG
        // Sync test hook: feed a real today_plan payload through the actual receive
        // handler (decode → store → notify), exactly as a phone transfer would, so the
        // receive→display chain can be exercised on the simulator without WCSession's
        // unreliable sim transport. Launch with `-injectTodayPlan`.
        if ProcessInfo.processInfo.arguments.contains("-injectTodayPlan") {
            PermissionGate.debugAssumeGranted = true
            WCSessionClient.shared.applyIncomingPayload(WatchSyncTestFixture.todayPlanPayload())
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                rootView
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if let screen = WatchUIDebugScreen.current {
            WatchUIDebugGalleryView(screen: screen)
        } else {
            TodayWorkoutView()
        }
        #else
        TodayWorkoutView()
        #endif
    }
}
