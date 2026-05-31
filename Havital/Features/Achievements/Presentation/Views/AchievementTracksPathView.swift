import SwiftUI

// MARK: - AchievementTracksPathView
//
// 三條主線（rhythm 節奏 / plan 課表 / results 成果）的路徑總覽。
// 每條主線一張卡：標題 + 進度 + 里程碑徽章橫向路徑（已解鎖／進行中／鎖定）。
// 從「下一個目標」點開進入。

struct AchievementTracksPathView: View {
    @Environment(\.dismiss) private var dismiss
    let tracks: [AchievementTrack]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(tracks) { track in
                        AchievementTrackCard(track: track)
                    }
                    if tracks.isEmpty {
                        Text(L10n.Achievements.Tracks.empty.localized)
                            .font(AppFont.bodyRegular())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L10n.Achievements.Tracks.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.done.localized) { dismiss() }
                        .font(AppFont.bodyStrong())
                }
            }
        }
        .presentationDetents([.large])
    }
}
