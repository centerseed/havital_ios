import SwiftUI

/// 首頁進入時彈出的公告 popup
struct AnnouncementPopupView: View {
    let announcement: Announcement
    let onCTA: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageUrl = announcement.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .empty:
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .overlay(ProgressView())
                        case .failure:
                            Rectangle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text(announcement.title)
                    .font(AppFont.title2())
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text(announcement.body)
                    .font(AppFont.body())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    if let ctaLabel = announcement.ctaLabel, !ctaLabel.isEmpty {
                        Button(action: onCTA) {
                            Text(ctaLabel)
                                .font(AppFont.headline())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityIdentifier("AnnouncementPopup_CTAButton")
                    }

                    Button(action: onDismiss) {
                        Text(NSLocalizedString("common.close", comment: "Close"))
                            .font(AppFont.headline())
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("AnnouncementPopup_CloseButton")
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("AnnouncementPopup_Screen")
    }
}

struct AnnouncementPopupView_Previews: PreviewProvider {
    static var previews: some View {
        AnnouncementPopupView(
            announcement: Announcement(
                id: "preview",
                title: "新版本上線",
                body: "這是公告內容，描述新功能與使用方式。可以是一段較長的文字來測試版面。",
                imageUrl: nil,
                ctaLabel: "查看詳情",
                ctaUrl: "https://example.com",
                publishedAt: Date(),
                expiresAt: nil,
                isSeen: false
            ),
            onCTA: {},
            onDismiss: {}
        )
    }
}
