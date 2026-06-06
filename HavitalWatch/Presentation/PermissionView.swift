import SwiftUI

struct PermissionView: View {
    let request: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("權限")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text("允許訓練記錄")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("需要 Health 與定位權限，才能記錄跑步與路線。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: request) {
                Label("允許", systemImage: "checkmark.circle.fill")
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
