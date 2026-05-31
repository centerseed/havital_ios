import SwiftUI
import UIKit

struct CelebrationSharePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: CelebrationShareCardView.ShareData
    @State private var showSystemShare = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CelebrationShareCardView(data: data)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .padding(.top, 16)

                    privacyHint

                    Button {
                        renderedImage = CelebrationShareCardView.render(data: data)
                        showSystemShare = (renderedImage != nil)
                    } label: {
                        Label(L10n.Achievements.Share.action.localized,
                              systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .accessibilityIdentifier("celebration.share.action")
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Achievements.Share.previewTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close.localized) { dismiss() }
                }
            }
            .sheet(isPresented: $showSystemShare) {
                if let image = renderedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
        }
    }

    private var privacyHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.Achievements.Share.privacyTitle.localized, systemImage: "lock.shield.fill")
                .font(AppFont.captionMedium())
                .foregroundStyle(PacerizTokens.color.brand.primary)
            Text(L10n.Achievements.Share.privacyBody.localized)
                .font(AppFont.captionSmall())
                .foregroundStyle(PacerizTokens.color.text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.tertiarySystemBackground)))
        .padding(.horizontal)
    }
}
