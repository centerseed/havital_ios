import SwiftUI

struct NoPlanPaywallConversionView: View {
    let content: NoPlanConversionContent
    let isWeekOne: Bool
    let onPrimaryCTA: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            TrainingProgressNudge(content: content)

            if let preview = content.nextWeekPreview {
                LockedWeekPreviewCard(preview: preview, onTap: onPrimaryCTA)
            }

            VStack(spacing: 8) {
                Button(action: onPrimaryCTA) {
                    Text(NSLocalizedString(isWeekOne ? "paywall.conversion.cta_generate" : "paywall.conversion.cta_unlock", comment: ""))
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("NoPlanConversion_PrimaryCTA")

                if !isWeekOne {
                    Text(NSLocalizedString("paywall.conversion.daily_value_hint", comment: ""))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                    Button(action: onRestore) {
                        Text(NSLocalizedString("paywall.conversion.cta_restore", comment: ""))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("NoPlanConversion_Restore")
                }
            }
        }
    }
}
