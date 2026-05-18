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

                Text(L10n.ForceUpdate.title.localized)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(L10n.ForceUpdate.message.localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    guard let urlString = updateUrl,
                          let url = URL(string: urlString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Text(L10n.ForceUpdate.cta.localized)
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
