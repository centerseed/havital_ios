import SwiftUI

// MARK: - 裝置資料說明 Sheet
struct DeviceInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.Record.deviceInfoTitle.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)
                    Text(L10n.Record.deviceInfoNativeSupport.localized)
                    Text(L10n.Record.deviceInfoLimitations.localized)
                    Text(L10n.Record.deviceInfoFutureSupport.localized)
                }
                .padding()
            }
            .navigationTitle(L10n.Record.deviceInfoDescription.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close.localized) { dismiss() }
                }
            }
        }
    }
}
