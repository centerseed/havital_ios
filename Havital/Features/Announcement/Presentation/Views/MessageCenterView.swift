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
                Text("目前沒有公告")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.allAnnouncements) { announcement in
                    AnnouncementRowView(announcement: announcement)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("訊息中心")
        .onAppear {
            viewModel.loadMessageCenter()
        }
    }
}

// MARK: - Row

private struct AnnouncementRowView: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(announcement.title)
                .font(.headline)
                .lineLimit(1)

            Text(announcement.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(announcement.publishedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
