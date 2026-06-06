import SwiftUI

// MARK: - DailyStateSheet
/// Presentation Layer — 今日狀態展開 bottom sheet。
/// 顯示：headline、完整 narrative（或鎖 + 升級）、佐證 chips、可能因素 chips、今日行動、divergence 軟標記。
/// 本版 divergence 僅顯示文字（無 Rizo standalone 入口 → 不導航）。
struct DailyStateSheet: View {
    let card: DailyStateCard
    let onUpgrade: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(card.headline)
                    .font(AppFont.title2())
                    .fontWeight(.bold)

                if let narrative = card.narrativeText {
                    Text(narrative)
                        .font(AppFont.body())
                        .foregroundColor(.primary)
                } else if card.isLocked {
                    lockedBlock
                }

                if !card.chips.isEmpty || !card.causeChips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !card.chips.isEmpty {
                            Text(NSLocalizedString("daily_state.evidence", comment: "Evidence section title"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            chipRow(items: card.chips, fg: .accentColor, bg: Color.accentColor.opacity(0.12))
                        }
                        if !card.causeChips.isEmpty {
                            Text(NSLocalizedString("daily_state.causes", comment: "Possible causes section title"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            chipRow(items: card.causeChips, fg: .orange, bg: Color.orange.opacity(0.12))
                        }
                    }
                }

                if let action = card.actionLine {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("daily_state.action", comment: "Today's action section title"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Label(action, systemImage: "arrow.right.circle.fill")
                            .font(AppFont.body())
                    }
                }

                if let flag = card.divergenceFlagText {
                    // 本版不導向 Rizo（無 standalone 入口）；僅顯示軟標記文字。
                    Text(flag)
                        .font(AppFont.caption())
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var lockedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                NSLocalizedString("daily_state.locked", comment: "Locked full read message"),
                systemImage: "lock.fill"
            )
            .font(AppFont.body())
            .foregroundColor(.secondary)
            Button(action: onUpgrade) {
                Text(NSLocalizedString("daily_state.upgrade_cta", comment: "Upgrade CTA button"))
                    .font(AppFont.button())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// 簡單橫向 chip 列（專案無共用 flow-layout 元件，用 horizontal ScrollView 包 PRChip）。
    private func chipRow(items: [String], fg: Color, bg: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    PRChip(text: item, fg: fg, bg: bg)
                }
            }
        }
    }
}
