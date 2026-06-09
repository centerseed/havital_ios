import SwiftUI

struct WelcomeView: View {
    let title: String
    let message: String
    var systemImage: String = "figure.run"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WatchTheme.brand)
                Text("Paceriz")
                    .font(WatchTheme.metricLabel)
                    .foregroundStyle(WatchTheme.brand)
            }
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(WatchTheme.neutral)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(WatchTheme.ambientBackground)
        .foregroundStyle(.white)
    }
}
