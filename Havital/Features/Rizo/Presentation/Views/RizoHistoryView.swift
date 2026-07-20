import SwiftUI

// MARK: - RizoHistoryView
/// Rizo 過去對話清單（唯讀）。由 RizoChatView header 歷史 icon 以 .sheet 呈現。
/// 自帶 NavigationStack（宿主 RizoChatView 不在 NavigationStack 內）。
struct RizoHistoryView: View {
    @StateObject private var viewModel = RizoHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    var onResume: ((RizoHistoryFork) -> Void)?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(NSLocalizedString("rizo.history.title",
                                                   comment: "Rizo conversation history"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(NSLocalizedString("common.done", comment: "Done")) { dismiss() }
                            .accessibilityIdentifier("rizo_history_close")
                    }
                }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            emptyState
        case .error:
            errorState
        case .loaded(let conversations):
            listView(conversations)
        }
    }

    private func listView(_ conversations: [RizoConversationSummary]) -> some View {
        List(conversations) { convo in
            NavigationLink {
                RizoHistoryDetailView(conversation: convo) { turnIndex in
                    do {
                        let fork = try await viewModel.fork(convo, throughTurnIndex: turnIndex)
                        onResume?(fork)
                        dismiss()
                        return true
                    } catch {
                        return false
                    }
                }
            } label: {
                row(convo)
            }
        }
        .listStyle(.plain)
    }

    private func row(_ convo: RizoConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                PRChip(text: RizoScenarioLabel.text(convo.scenario),
                       fg: PacerizColor.blue, bg: PacerizColor.blue12, fontSize: 11)
                Spacer(minLength: 0)
                if let date = RizoHistoryDateFormatter.medium(convo.updatedAt) {
                    Text(date).font(AppFont.micro()).foregroundColor(.secondary)
                }
            }
            Text(displayTitle(convo))
                .font(AppFont.captionMedium())
                .foregroundColor(.primary)
                .lineLimit(1)
            if !convo.lastResponse.isEmpty {
                Text(convo.lastResponse)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("rizo_history_row_\(convo.id)")
    }

    /// 標題：優先用 titleSeed；純開場 session fallback = 情境標籤 · 日期。
    private func displayTitle(_ convo: RizoConversationSummary) -> String {
        if let seed = convo.titleSeed, !seed.isEmpty { return seed }
        let label = RizoScenarioLabel.text(convo.scenario)
        if let date = RizoHistoryDateFormatter.medium(convo.updatedAt) {
            return "\(label) · \(date)"
        }
        return label
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("rizo.history.empty", comment: "Empty history"))
                .font(AppFont.bodyRegular())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityIdentifier("rizo_history_empty")
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("rizo.history.error", comment: "History load error"))
                .font(AppFont.bodyRegular())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(NSLocalizedString("rizo.history.retry", comment: "Retry")) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityIdentifier("rizo_history_error")
    }
}
