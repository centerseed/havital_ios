import SwiftUI

struct WorkoutControlView: View {
    let isPaused: Bool
    let togglePause: () -> Void
    let end: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: togglePause) {
                Label(isPaused ? "watch.control.resume" : "watch.control.pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isPaused ? WatchTheme.brand : WatchTheme.tooFast)

            Button(role: .destructive, action: end) {
                Label("watch.control.end", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(WatchTheme.activeBackground)
        .foregroundStyle(.white)
    }
}
