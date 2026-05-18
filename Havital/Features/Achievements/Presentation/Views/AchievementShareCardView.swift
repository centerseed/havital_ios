import SwiftUI
import UIKit

struct AchievementShareCardView: View {
    let shareable: AchievementShareable

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Paceriz")
                    .font(AppFont.headline())
                    .foregroundColor(.blue)
                Spacer()
                Text(L10n.Achievements.Share.badgeLabel.localized)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(shareable.titleKey.localizedOrFallback(default: L10n.Achievements.Share.item.localized))
                    .font(AppFont.systemScaled(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(shareable.summaryKey.achievementLocalized(params: shareable.summaryParams))
                    .font(AppFont.body())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !shareable.publicFields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(shareable.publicFields.prefix(4)) { field in
                        HStack {
                            Text(field.labelKey.localizedOrFallback(default: field.key))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(field.value)
                                .font(AppFont.bodyMedium())
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
            }

            Spacer()

            Text(L10n.Achievements.Share.privacyFooter.localized)
                .font(AppFont.captionSmall())
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 320, height: 420)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct AchievementSharePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareable: AchievementShareable
    let onShare: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AchievementShareCardView(shareable: shareable)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .padding(.top)

                    publicFieldsSection

                    Button {
                        if let image = renderCard() {
                            onShare(image)
                        }
                    } label: {
                        Label(L10n.Achievements.Share.action.localized, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Achievements.Share.previewTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close.localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var publicFieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Achievements.Share.publicFields.localized)
                .font(AppFont.headline())

            if shareable.publicFields.isEmpty {
                Text(L10n.Achievements.Share.defaultPublicFields.localized)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            } else {
                ForEach(shareable.publicFields) { field in
                    HStack {
                        Text(field.labelKey.localizedOrFallback(default: field.key))
                            .font(AppFont.bodySmall())
                        Spacer()
                        Text(field.value)
                            .font(AppFont.bodyMedium())
                    }
                }
            }

            Text(L10n.Achievements.Share.sensitiveExcluded.localized)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .cardStyle()
        .padding(.horizontal)
    }

    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content: AchievementShareCardView(shareable: shareable))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

private extension String {
    func localizedOrFallback(default fallback: String) -> String {
        let value = NSLocalizedString(self, comment: "")
        return value == self ? fallback : value
    }
}
