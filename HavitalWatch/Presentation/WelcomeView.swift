import SwiftUI

struct WelcomeView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paceriz")
                .font(.caption2)
                .foregroundStyle(.green)
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
