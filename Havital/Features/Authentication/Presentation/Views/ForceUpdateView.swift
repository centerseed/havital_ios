import SwiftUI

struct ForceUpdateView: View {
    let updateUrl: String?

    private var isEnabled: Bool { updateUrl != nil }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text("需要更新 Paceriz")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("您的 App 版本過舊，請前往 App Store 更新至最新版本後繼續使用。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    guard let urlString = updateUrl,
                          let url = URL(string: urlString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Text("前往 App Store 更新")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isEnabled ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!isEnabled)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .interactiveDismissDisabled(true)
    }
}
