import SwiftUI

struct DataSourceBindingReminderOverlay: View {
    let onGoToSettings: () -> Void
    let onLater: () -> Void

    var body: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    Image(systemName: "link.badge.plus")
                        .font(AppFont.systemScaled(size: 44))
                        .foregroundColor(.blue)

                    Text(L10n.ContentView.dataSourceRequired.localized)
                        .font(AppFont.title2())
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(L10n.ContentView.dataSourceRequiredMessage.localized)
                        .font(AppFont.body())
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    VStack(spacing: 12) {
                        Button(action: onGoToSettings) {
                            Text(L10n.ContentView.goToSettings.localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .accessibilityIdentifier("DataSourceReminder_GoToSettingsButton")

                        Button(action: onLater) {
                            Text(L10n.ContentView.later.localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.18))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .accessibilityIdentifier("DataSourceReminder_LaterButton")
                    }
                }
                .padding(24)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(18)
                .shadow(radius: 12)
                .padding(.horizontal, 28)
                .accessibilityIdentifier("DataSourceReminder_Sheet")
            )
    }
}
