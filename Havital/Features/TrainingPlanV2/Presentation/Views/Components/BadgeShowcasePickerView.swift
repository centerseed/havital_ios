import SwiftUI

// MARK: - BadgeShowcasePickerView
//
// 課表首頁展示徽章選擇器：列出所有「已解鎖」徽章，使用者點一顆即設為首頁展示徽章。
// 徽章圖透過 AchievementBadgeArtwork → AchievementBadgeImage 渲染，與徽章收藏完全一致。
// onSelect(nil) = 恢復預設（自動挑選最近解鎖）。

struct BadgeShowcasePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let badges: [AchievementBadge]
    let selectedBadgeId: String?
    /// 傳 badgeId 設為展示徽章；傳 nil 恢復預設。
    let onSelect: (String?) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if badges.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("選擇展示徽章")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("恢復預設") {
                        onSelect(nil)
                        dismiss()
                    }
                    .font(AppFont.label())
                    .foregroundColor(.secondary)
                    .disabled(selectedBadgeId == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(AppFont.label())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("點選一顆已解鎖徽章，放到課表首頁展示。")
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(badges) { badge in
                        tile(badge: badge)
                            .onTapGesture {
                                onSelect(badge.badgeId)
                                dismiss()
                            }
                    }
                }
            }
            .padding(16)
        }
    }

    private func tile(badge: AchievementBadge) -> some View {
        let isSelected = badge.badgeId == selectedBadgeId
        return VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                AchievementBadgeImage(
                    assetName: AchievementBadgeArtwork.assetName(for: badge),
                    status: badge.status,
                    size: 68
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? PacerizColor.blue : Color.clear,
                            lineWidth: 2.5
                        )
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppFont.titleM())
                        .foregroundColor(PacerizColor.blue)
                        .background(Circle().fill(Color(UIColor.systemBackground)))
                        .offset(x: 4, y: -4)
                }
            }

            Text(NSLocalizedString(badge.nameKey, comment: ""))
                .font(AppFont.micro())
                .foregroundColor(isSelected ? PacerizColor.blueDeep : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(AppFont.numberLarge())
                .foregroundColor(.secondary)
            Text("還沒有已解鎖徽章")
                .font(AppFont.label())
            Text("完成訓練解鎖徽章後，就能選一顆放到課表首頁展示。")
                .font(AppFont.micro())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
