import SwiftUI

struct RPEView: View {
    @State private var rpe: Double = 5
    let complete: (Int) -> Void
    let skip: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("今天的體感")
                .font(.caption2)
                .foregroundStyle(.green)
            Text("\(Int(rpe))")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .monospacedDigit()
                .focusable(true)
                .digitalCrownRotation($rpe, from: 1, through: 10, by: 1, sensitivity: .medium)
            Text("/10")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(RPEFeedback.text(for: Int(rpe)))
                .font(.footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Button {
                complete(Int(rpe))
            } label: {
                Label("完成", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button(action: skip) {
                Label("稍後再說", systemImage: "chevron.right")
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
