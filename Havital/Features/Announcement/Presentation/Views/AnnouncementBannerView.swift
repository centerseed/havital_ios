import SwiftUI

/// 首頁公告 Banner（AC-ANN-01）
/// 有 imageUrl 才渲染圖片區域；有 ctaLabel + ctaUrl 才渲染 CTA 按鈕（AC-ANN-06, AC-ANN-07）
struct AnnouncementBannerView: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 圖片（可選，AC-ANN-07）
            if let imageUrl = announcement.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 160)
                            .clipped()
                    case .failure:
                        EmptyView()
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity, maxHeight: 160)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(announcement.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(announcement.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, hasCTA ? 8 : 16)

            // CTA 按鈕（可選，AC-ANN-06）
            if let ctaLabel = announcement.ctaLabel, let ctaUrl = announcement.ctaUrl {
                Button(ctaLabel) {
                    openCTA(url: ctaUrl)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var hasCTA: Bool {
        announcement.ctaLabel != nil && announcement.ctaUrl != nil
    }

    private func openCTA(url: String) {
        guard let destination = URL(string: url) else { return }
        UIApplication.shared.open(destination)
    }
}
