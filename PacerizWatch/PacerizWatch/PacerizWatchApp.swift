import SwiftUI

@main
struct PacerizWatchApp: App {
    @StateObject private var watchDataManager = WatchDataManager.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScheduleListView()
            }
            .environmentObject(watchDataManager)
        }
    }
}
