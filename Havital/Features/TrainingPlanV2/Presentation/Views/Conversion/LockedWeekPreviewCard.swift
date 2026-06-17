import SwiftUI

struct LockedWeekPreviewCard: View {
    let preview: WeekPreview
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lock.fill").foregroundColor(.orange)
                    Text(String(format: NSLocalizedString("paywall.conversion.locked_preview_title", comment: ""), preview.week))
                        .font(AppFont.headline())
                    Spacer()
                }
                Text(bodyText)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .blur(radius: 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("LockedWeekPreviewCard")
    }

    private var bodyText: String {
        let recovery = preview.isRecovery ? NSLocalizedString("paywall.conversion.recovery_suffix", comment: "") : ""
        let displayValue = preview.targetKmDisplay ?? preview.targetKm
        let km = String(format: "%.0f", displayValue)
        let unit = preview.distanceUnit ?? "km"
        return String(format: NSLocalizedString("paywall.conversion.locked_preview_body", comment: ""), km, unit, recovery)
    }
}
