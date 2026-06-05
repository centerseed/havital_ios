import SwiftUI

@main
struct HavitalWatchApp: App {
    init() {
        WCSessionClient.shared.activate()
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
