import SwiftUI

// MARK: - RizoChatView
//
// 卡片=Rizo hub 詳細頁下半的多輪聊天 UI（可重用）。
// Presentation Layer — 只渲染，業務邏輯在 StateRizoChatViewModel。
//
// 視覺對齊 mockup `2026-06-07-card-rizo-detail.html` 的 .chat-area 區塊：
//   - chat header：Rizo 漸層頭像 + 名稱 + 副標 + 「教練」徽章
//   - 教練泡泡：左、含小頭像、淺藍底、左上直角圓角
//   - 用戶泡泡：右、藍底白字、右下直角圓角
//   - typing indicator：三點脈動
//   - input bar：圓角輸入框 + 圓形送出鈕（draft 空或回覆中時 disabled）
struct RizoChatView: View {
    @ObservedObject var viewModel: StateRizoChatViewModel
    /// 是否畫自己的 chat header。2.0 首頁的 Rizo sheet（設計 frame-00d）已經有
    /// sheet 自己的頭（R 頭像＋名稱＋關閉鈕），再畫一次會有兩排 Rizo。
    var showsHeader: Bool = true
    /// 是否畫自己的卡面（底色＋圓角＋內距）。嵌在 2.0 sheet 裡時由 sheet 提供背景。
    var showsSurface: Bool = true
    /// 輸入框焦點 — 用於提供「收起鍵盤」能力(原本鍵盤無法收起,難以截圖)。
    @FocusState private var inputFocused: Bool
    /// 歷史對話清單 sheet 開關。
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                chatHeader
            }

            ForEach(viewModel.messages) { message in
                bubble(message)
            }

            if viewModel.isReplying {
                typingIndicator
            }

            if let pending = viewModel.pendingPlanChange, !viewModel.isReplying {
                planChangeCard(pending)
            }

            inputBar
        }
        .padding(showsSurface ? 14 : 0)
        .background(showsSurface ? Color(UIColor.secondarySystemGroupedBackground) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: showsSurface ? PacerizRadius.card : 0, style: .continuous))
        .sheet(item: $viewModel.paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
        .sheet(isPresented: $showHistory) {
            RizoHistoryView { fork in
                viewModel.resumeFromHistory(fork)
            }
        }
    }

    // MARK: - Plan Change Card

    /// 教練提出改課表 → 顯示摘要 + 「接受 / 繼續討論」。
    /// 接受 → 確認套用(免費用戶走付費牆);繼續討論 → 收起、繼續聊。
    private func planChangeCard(_ pending: PendingPlanChange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PacerizColor.blue)
                Text(NSLocalizedString("rizo.plan_change.title", comment: "課表調整"))
                    .font(AppFont.captionMedium())
                    .foregroundColor(.primary)
            }
            if let diffDays = pending.diffDays, !diffDays.isEmpty {
                Text(PlanChangeDiffFormatter.text(for: diffDays))
                    .font(AppFont.bodyRegular())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let summary = pending.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppFont.bodyRegular())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button {
                    viewModel.dismissPlanChange()
                } label: {
                    Text(NSLocalizedString("rizo.plan_change.discuss", comment: "繼續討論"))
                        .font(AppFont.captionMedium())
                        .foregroundColor(PacerizColor.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PacerizColor.blue12, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isConfirmingPlanChange)
                .accessibilityIdentifier("rizo_plan_change_discuss")

                Button {
                    Task { await viewModel.acceptPlanChange() }
                } label: {
                    Group {
                        if viewModel.isConfirmingPlanChange {
                            ProgressView().tint(.white)
                        } else {
                            Text(NSLocalizedString("rizo.plan_change.accept", comment: "接受"))
                                .font(AppFont.captionMedium())
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(PacerizColor.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isConfirmingPlanChange)
                .accessibilityIdentifier("rizo_plan_change_accept")
            }
        }
        .padding(12)
        .background(PacerizColor.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PacerizColor.blue.opacity(0.18), lineWidth: 1)
        )
        .accessibilityIdentifier("rizo_plan_change_card")
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack(spacing: 8) {
            rizoAvatar(size: 28, fontSize: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text("Rizo")
                    .font(AppFont.captionMedium())
                    .foregroundColor(.primary)
                Text(NSLocalizedString("rizo.chat.subtitle", comment: "你的 AI 跑步教練"))
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PacerizColor.blue)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("rizo_chat_history")
            .accessibilityLabel(Text(NSLocalizedString("rizo.history.entry",
                                                       comment: "Open past conversations")))
            PRChip(
                text: NSLocalizedString("rizo.chat.coachBadge", comment: "教練"),
                fg: PacerizColor.blue,
                bg: PacerizColor.blue12
            )
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityIdentifier("rizo_chat_header")
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubble(_ message: StateRizoChatViewModel.Message) -> some View {
        switch message.role {
        case .coach:
            coachBubble(text: message.text)
        case .user:
            userBubble(text: message.text)
        }
    }

    private func coachBubble(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            rizoAvatar(size: 24, fontSize: 11)
                .padding(.top, 2)
            Text(Self.markdown(text))
                .font(AppFont.bodyRegular())
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PacerizColor.blue12)
                .clipShape(coachBubbleShape)
            Spacer(minLength: 40)
        }
        .accessibilityIdentifier("rizo_chat_bubble_coach")
    }

    /// Rizo 的回覆本來就是 Markdown（`**粗體**`／`*斜體*`），以前直接丟給 `Text` 會把
    /// 星號原樣顯示。用 `.inlineOnlyPreservingWhitespace` 解析：只吃行內語法，
    /// **換行與空白照原樣保留**（預設的 `.full` 會把段落內的換行吃掉）。
    /// 解析失敗就退回純文字，不讓一則訊息炸掉整個對話。
    static func markdown(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private func userBubble(text: String) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 40)
            Text(text)
                .font(AppFont.bodyRegular())
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(PacerizColor.blue)
                .clipShape(userBubbleShape)
        }
        .accessibilityIdentifier("rizo_chat_bubble_user")
    }

    /// 教練泡泡：左上直角、其餘圓角（對齊 mockup `border-radius: 0 14 14 14`）。
    private var coachBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 14,
            bottomTrailingRadius: 14,
            topTrailingRadius: 14,
            style: .continuous
        )
    }

    /// 用戶泡泡：右下直角、其餘圓角（對齊 mockup `border-radius: 14 14 0 14`）。
    private var userBubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 14,
            bottomLeadingRadius: 14,
            bottomTrailingRadius: 0,
            topTrailingRadius: 14,
            style: .continuous
        )
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            rizoAvatar(size: 24, fontSize: 11)
                .padding(.top, 2)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(PacerizColor.blue.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PacerizColor.blue12)
            .clipShape(coachBubbleShape)
            Spacer(minLength: 40)
        }
        .accessibilityIdentifier("rizo_chat_typing")
    }

    // MARK: - Quick Replies

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(
                NSLocalizedString("rizo.chat.inputPlaceholder", comment: "跟 Rizo 說說今天的感受…"),
                text: $viewModel.draft,
                axis: .vertical
            )
            .font(AppFont.bodyRegular())
            .lineLimit(1...4)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(UIColor.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .disabled(viewModel.isReplying)
            .focused($inputFocused)
            .accessibilityIdentifier("rizo_chat_input")
            // 鍵盤上方常駐「完成」鈕 — axis:.vertical 的 TextField 沒有 return 收鍵盤,
            // 必須補這顆,否則鍵盤收不起來、無法看完整回應或截圖。
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(NSLocalizedString("common.done", comment: "收起鍵盤")) {
                        inputFocused = false
                    }
                    .accessibilityIdentifier("rizo_chat_keyboard_done")
                }
            }

            Button {
                let text = viewModel.draft
                inputFocused = false // 送出後收鍵盤,直接看 Rizo 回應 / 方便截圖
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(canSend ? PacerizColor.blue : Color(UIColor.tertiaryLabel), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityIdentifier("rizo_chat_send")
        }
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var canSend: Bool {
        !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isReplying
    }

    // MARK: - Shared Avatar

    /// Rizo 漸層圓形頭像（藍），中央白字「R」。最終可換 mascot 圖示。
    ///
    /// 2026-08-30（8/28 盤點 V2）：原本是藍→綠，於是同一個 Rizo sheet 裡 header 那顆
    /// （`App2Avatar`，藍漸層）與訊息旁這顆（青綠）長得不一樣。R 頭像是同一個身分，
    /// 一律藍圓；雙平台同色。
    private func rizoAvatar(size: CGFloat, fontSize: CGFloat) -> some View {
        Text("R")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [PacerizColor.blue, PacerizColor.blueDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
    }
}

#if DEBUG
// MARK: - Preview Support

/// 預覽用假 repository（不連後端，回固定 reply）。
private final class _RizoChatPreviewRepo: RizoRepository {
    func sendJournalChat(workoutId: String, message: String, presetSelections: [String], sessionId: String?) async throws -> RizoReply {
        throw NSError(domain: "preview", code: 0)
    }
    func sendChat(scenario: String, message: String, sessionId: String?) async throws -> RizoReply {
        RizoReply(
            reply: "今天天氣很熱，你跑得很紮實！心率偏高是體溫調節造成的，不用擔心。有沒有哪段特別感覺到壓力？",
            sessionId: "preview",
            quota: RizoQuota(allowed: true, used: 1, limit: 3, remaining: 2, resetsAt: nil, reserved: true),
            safety: RizoSafety(dangerClass: "none", canned: false),
            pendingPlanChange: PendingPlanChange(
                proposalId: "preview",
                summary: "週日 長距離慢跑 19km → 輕鬆跑 19km",
                safetyLevel: "none",
                requiresSubscription: true,
                diffDays: [
                    PlanChangeDiffDay(
                        dayIndex: 7,
                        from: PlanChangeDayFace(category: "run", runType: "lsd", distanceKm: 19),
                        to: PlanChangeDayFace(category: "run", runType: "easy", distanceKm: 19)
                    )
                ]
            )
        )
    }
    func getPresets(scenario: String) async throws -> [RizoPreset] { [] }
    func getHistory() async throws -> (
        items: [RizoHistoryItem],
        pendingPlanChanges: [String: PendingPlanChange]
    ) { ([], [:]) }
    func confirmPlanChange(proposalId: String) async throws -> PlanChangeConfirmResult {
        PlanChangeConfirmResult(applied: true, status: "applied")
    }
}

@MainActor
private func _previewViewModel() -> StateRizoChatViewModel {
    let vm = StateRizoChatViewModel(scenario: "post_run", repository: _RizoChatPreviewRepo())
    Task { await vm.startOpening() }
    return vm
}

#Preview("Rizo Chat") {
    ScrollView {
        RizoChatView(
            viewModel: _previewViewModel()
        )
        .padding(16)
    }
    .background(Color(UIColor.systemGroupedBackground))
}
#endif
