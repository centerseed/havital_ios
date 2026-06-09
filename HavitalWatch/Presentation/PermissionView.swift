import SwiftUI

struct PermissionView: View {
    let request: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WatchTheme.tooFast)
                Text("watch.permission.title")
                    .font(WatchTheme.metricLabel)
                    .foregroundStyle(WatchTheme.tooFast)
            }
            Text("watch.permission.heading")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text("watch.permission.body")
                .font(.footnote)
                .foregroundStyle(WatchTheme.neutral)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: request) {
                Label("watch.permission.allow", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.brand)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(WatchTheme.ambientBackground)
        .foregroundStyle(.white)
    }
}
