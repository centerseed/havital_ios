import SwiftUI

struct RPEView: View {
    @State private var rpe: Double = 5
    let complete: (Int) -> Void
    let skip: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            Text("watch.rpe.title")
                .font(WatchTheme.metricLabel)
                .foregroundStyle(WatchTheme.brand)
            Text("\(Int(rpe))")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(rpeColor)
                .monospacedDigit()
                .focusable(true)
                .digitalCrownRotation($rpe, from: 1, through: 10, by: 1, sensitivity: .medium)
            Text("/10")
                .font(.caption)
                .foregroundStyle(WatchTheme.neutral)
            Text(RPEFeedback.text(for: Int(rpe)))
                .font(.footnote)
                .foregroundStyle(WatchTheme.neutral)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Button {
                complete(Int(rpe))
            } label: {
                Label("watch.action.done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.brand)
            .padding(.top, 2)

            Button(action: skip) {
                Label("watch.rpe.later", systemImage: "chevron.right")
            }
            .font(.caption)
            .foregroundStyle(WatchTheme.neutral)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .background(WatchTheme.ambientBackground)
        .foregroundStyle(.white)
    }

    private var rpeColor: Color {
        switch Int(rpe) {
        case ...3: return WatchTheme.brand
        case 4...6: return .white
        case 7...8: return WatchTheme.tooFast
        default: return WatchTheme.tooSlow
        }
    }
}
