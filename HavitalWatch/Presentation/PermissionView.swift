import SwiftUI

struct PermissionView: View {
    let request: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("watch.permission.title")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text("watch.permission.heading")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("watch.permission.body")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: request) {
                Label("watch.permission.allow", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color.black)
        .foregroundStyle(.white)
    }
}
