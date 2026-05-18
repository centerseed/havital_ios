import SwiftUI

/// 訊息中心——顯示全部公告列表（AC-ANN-03）
struct MessageCenterView: View {
    @ObservedObject var viewModel: AnnouncementViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingCenter && viewModel.allAnnouncements.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.allAnnouncements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(AppFont.systemScaled(size: 44))
                        .foregroundColor(.secondary)
                    Text(L10n.MessageCenter.empty.localized)
                        .font(AppFont.subheadline())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.allAnnouncements) { announcement in
                            Button {
                                viewModel.openMessageCenterAnnouncement(announcement)
                            } label: {
                                AnnouncementCardView(announcement: announcement)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("MessageCenter_AnnouncementCard_\(announcement.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle(L10n.MessageCenter.title.localized)
        .onAppear {
            viewModel.loadMessageCenter()
        }
        .sheet(item: $viewModel.selectedMessageCenterAnnouncement) { announcement in
            AnnouncementPopupView(
                announcement: announcement,
                onCTA: {
                    viewModel.handlePopupCTA(announcement)
                },
                onDismiss: {
                    viewModel.dismissSelectedMessageCenterAnnouncement()
                }
            )
        }
    }
}

// MARK: - Card

private struct AnnouncementCardView: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if !announcement.isSeen {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }

                Text(announcement.title)
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            Text(announcement.body)
                .font(AppFont.subheadline())
                .foregroundColor(.secondary)
                .lineLimit(3)

            Text(announcement.publishedAt, style: .relative)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}
