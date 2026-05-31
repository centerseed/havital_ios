import SwiftUI

/// 訊息中心——顯示全部公告列表（AC-ANN-03）
struct MessageCenterView: View {
    @ObservedObject var viewModel: AnnouncementViewModel
    @State private var expandedAnnouncementIDs: Set<String> = []

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
                            AnnouncementCardView(
                                announcement: announcement,
                                isExpanded: expandedAnnouncementIDs.contains(announcement.id),
                                onToggle: {
                                    toggleExpansion(for: announcement)
                                },
                                onCTA: { announcement in
                                    viewModel.handlePopupCTA(announcement)
                                }
                            )
                            .accessibilityIdentifier("MessageCenter_AnnouncementCard_\(announcement.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle(L10n.MessageCenter.title.localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMessageCenter()
        }
    }

    private func toggleExpansion(for announcement: Announcement) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedAnnouncementIDs.contains(announcement.id) {
                expandedAnnouncementIDs.remove(announcement.id)
            } else {
                expandedAnnouncementIDs.insert(announcement.id)
            }
        }
    }
}

// MARK: - Card

private struct AnnouncementCardView: View {
    let announcement: Announcement
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCTA: (Announcement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 10) {
                        if !announcement.isSeen {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                                .padding(.top, 7)
                        }

                        Text(announcement.title)
                            .font(AppFont.systemScaled(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? 3 : 2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppFont.systemScaled(size: 14, weight: .semibold))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 3)
                    }

                    metaRow
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(announcement.body)
                    .font(AppFont.systemScaled(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(announcement.publishedAt, style: .relative)
                .font(AppFont.systemScaled(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if isExpanded {
                Text(NSLocalizedString("message_center.full_text", comment: "Full text label"))
                    .font(AppFont.systemScaled(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        Divider()
            .padding(.vertical, 2)

        Text(announcement.body)
            .font(AppFont.systemScaled(size: 15))
            .foregroundColor(.primary.opacity(0.78))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)

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
            .frame(height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 4)
        }

        if let ctaLabel = announcement.ctaLabel, !ctaLabel.isEmpty {
            Button {
                onCTA(announcement)
            } label: {
                Text(ctaLabel)
                    .font(AppFont.systemScaled(size: 15, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 4)
            .accessibilityIdentifier("MessageCenter_AnnouncementCTA_\(announcement.id)")
        }
    }
}
