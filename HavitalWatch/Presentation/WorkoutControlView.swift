import SwiftUI

struct WorkoutControlView: View {
    let isPaused: Bool
    let togglePause: () -> Void
    let end: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: togglePause) {
                Label(isPaused ? "繼續" : "暫停", systemImage: isPaused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isPaused ? .green : .orange)

            Button(role: .destructive, action: end) {
                Label("結束", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
