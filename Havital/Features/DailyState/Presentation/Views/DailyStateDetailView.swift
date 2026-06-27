import SwiftUI

// MARK: - DailyStateDetailView
//
// 卡片=Rizo hub 的今日狀態詳細頁（取代舊 DailyStateSheet bottom sheet）。
// Presentation Layer — 只渲染；對話業務邏輯在 StateRizoChatViewModel。
//
// 結構（對齊 mockup `2026-06-07-card-rizo-detail.html`）：
//   上半 = 狀態摘要卡（icon + lens tag + headline + chips + supporting narrative + action line）
//   下半 = 「與 Rizo 教練聊聊」區段標題 + RizoChatView 多輪對話
//
// 設計取捨：靜態 narrative 在詳細頁不再是主角（Rizo 開場對話才是互動主體），
// 僅作為狀態卡的輔助說明文字保留（與 mockup state-card 一致）。
// isLocked 時隱藏對話，改顯示升級塊（沿用舊 DailyStateSheet 邏輯）。
struct DailyStateDetailView: View {
    let card: DailyStateCard
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatVM: StateRizoChatViewModel

    init(card: DailyStateCard, onUpgrade: @escaping () -> Void) {
        self.card = card
        self.onUpgrade = onUpgrade
        _chatVM = StateObject(wrappedValue: StateRizoChatViewModel(
            scenario: card.rizoScenario ?? "body_status"
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stateSummary

                if card.isLocked {
                    lockedBlock
                } else {
                    chatSectionLabel
                    RizoChatView(viewModel: chatVM)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 拖曳對話內容即可收起鍵盤(方便看完整回應 / 截圖);搭配輸入框上方的「完成」鈕。
        .scrollDismissesKeyboard(.interactively)
        .background(Color(UIColor.systemGroupedBackground))
        // 明確的關閉鈕：edge-to-edge ScrollView 會吃掉下拉手勢，只剩頂部 grabber 能關（小、難命中、
        // 自動化也抓不到）。補一個常駐右上關閉鈕（不隨內容捲走），真實使用者與 UI 測試都能可靠關閉。
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
            }
            .padding(.trailing, 14)
            .padding(.top, 12)
            .accessibilityIdentifier("daily_state_close")
            .accessibilityLabel(Text(NSLocalizedString("daily_state.close",
                                                       comment: "Close the daily state detail sheet")))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            // 付費才開場對話；鎖住時不打後端（顯示升級塊）。
            if !card.isLocked {
                await chatVM.startOpening()
            }
        }
    }

    // MARK: - State Summary (上半)

    private var stateSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                stateIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(lensTag)
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(card.headline)
                        .font(AppFont.title3())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if card.hasChip || !card.causeChips.isEmpty {
                summaryChips
            }

            if let prog = card.mileageProgression {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    Text(prog)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 輔助 narrative：付費才有；非主角，僅補充說明（鎖住時用升級塊取代）。
            if let narrative = card.narrativeText, !card.isLocked {
                Divider()
                Text(narrative)
                    .font(AppFont.bodyRegular())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let action = card.actionLine {
                actionLine(action)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    /// 狀態圖示色塊：依 lens 著色（pre=藍、post=橘），對齊 mockup state-icon-wrap。
    private var stateIcon: some View {
        Image(systemName: lensSymbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(lensColor)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: PacerizRadius.inner, style: .continuous)
                    .fill(lensColor.opacity(0.12))
            )
    }

    private var summaryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(card.chips, id: \.self) { chip in
                    PRChip(text: chip, fg: PacerizColor.blue, bg: PacerizColor.blue12, fontSize: 12)
                }
                ForEach(card.causeChips, id: \.self) { chip in
                    PRChip(text: chip, fg: PacerizColor.orange, bg: PacerizColor.orange12, fontSize: 12)
                }
            }
        }
    }

    /// post（今天已跑）→ 綠勾「今日課表已完成 · 12K …」；pre（未跑）→ 藍箭頭待跑。
    /// 後端 post 已改回錨「今天那堂」(非下一堂)，所以這裡顯示的就是今天完成的那堂。
    private func actionLine(_ action: String) -> some View {
        let isDone = card.lens == .post
        let symbol = isDone ? "checkmark.circle.fill" : "arrow.right.circle.fill"
        let tint = isDone ? PacerizColor.green : PacerizColor.blue
        let bg = isDone ? PacerizColor.green12 : PacerizColor.blue12
        let label = isDone
            ? "\(NSLocalizedString("daily_state.completed_today", comment: "Today's session done prefix")) · \(action)"
            : action
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
            Text(label)
                .font(AppFont.micro())
                .foregroundColor(tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.inner, style: .continuous)
                .fill(bg)
        )
    }

    // MARK: - Chat Section Label

    private var chatSectionLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PacerizColor.blue)
            Text(NSLocalizedString("daily_state.chat_section_title",
                                   comment: "Rizo chat section title in detail page"))
                .font(AppFont.captionMedium())
                .foregroundColor(PacerizColor.blue)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: - Locked Block (沿用舊 DailyStateSheet 邏輯)

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PacerizRadius.card, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Lens-derived Styling

    private var lensTag: String {
        switch card.lens {
        case .pre:
            return NSLocalizedString("daily_state.title", comment: "Today's state")
        case .post:
            return NSLocalizedString("daily_state.evidence", comment: "Post-run analysis lens tag")
        }
    }

    private var lensSymbol: String {
        switch card.lens {
        case .pre:  return "sun.max.fill"
        case .post: return "chart.line.uptrend.xyaxis"
        }
    }

    private var lensColor: Color {
        switch card.lens {
        case .pre:  return PacerizColor.blue
        case .post: return PacerizColor.orange
        }
    }
}
