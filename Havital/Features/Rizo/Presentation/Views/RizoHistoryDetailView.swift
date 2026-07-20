import SwiftUI

// MARK: - RizoHistoryDetailView
/// 單段 Rizo 對話唯讀逐字稿。無輸入框、無改課表卡、無任何寫入動作。
struct RizoHistoryDetailView: View {
    let conversation: RizoConversationSummary
    let onResume: (Int) async -> Bool
    @State private var resumingTurnIndex: Int?
    @State private var resumeFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                ForEach(Array(conversation.turns.enumerated()), id: \.offset) { index, turn in
                    VStack(alignment: .leading, spacing: 8) {
                        if !turn.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            userBubble(text: turn.userInput)
                        }
                        if !turn.rizoResponse.isEmpty {
                            coachBubble(text: turn.rizoResponse)
                        }
                        if canResume(from: turn) {
                            resumeButton(turnIndex: index)
                        }
                    }
                }
                if resumeFailed {
                    Text(NSLocalizedString("rizo.history.resume.error",
                                           comment: "Could not continue history"))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.red)
                        .accessibilityIdentifier("rizo_history_resume_error")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(RizoScenarioLabel.text(conversation.scenario))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("rizo_history_detail")
    }

    private func canResume(from turn: RizoHistoryItem) -> Bool {
        !turn.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !turn.rizoResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !RizoConversationSummary.isErrorResponse(turn.rizoResponse)
    }

    private func resumeButton(turnIndex: Int) -> some View {
        Button {
            guard resumingTurnIndex == nil else { return }
            resumeFailed = false
            resumingTurnIndex = turnIndex
            Task {
                let succeeded = await onResume(turnIndex)
                if !succeeded {
                    resumeFailed = true
                    resumingTurnIndex = nil
                }
            }
        } label: {
            HStack(spacing: 6) {
                if resumingTurnIndex == turnIndex {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.uturn.forward.circle")
                }
                Text(NSLocalizedString("rizo.history.resume", comment: "Continue from here"))
            }
            .font(AppFont.captionMedium())
            .foregroundColor(PacerizColor.blue)
        }
        .buttonStyle(.plain)
        .disabled(resumingTurnIndex != nil)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityIdentifier("rizo_history_resume_\(turnIndex)")
    }

    private var header: some View {
        HStack(spacing: 6) {
            PRChip(text: RizoScenarioLabel.text(conversation.scenario),
                   fg: PacerizColor.blue, bg: PacerizColor.blue12, fontSize: 12)
            if let date = RizoHistoryDateFormatter.medium(conversation.updatedAt) {
                Text(date).font(AppFont.micro()).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private func coachBubble(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            rizoAvatar(size: 24, fontSize: 11).padding(.top, 2)
            Text(text)
                .font(AppFont.bodyRegular())
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(PacerizColor.blue12)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 14,
                    bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous))
            Spacer(minLength: 40)
        }
    }

    private func userBubble(text: String) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 40)
            Text(text)
                .font(AppFont.bodyRegular())
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(PacerizColor.blue)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 14, bottomLeadingRadius: 14,
                    bottomTrailingRadius: 0, topTrailingRadius: 14, style: .continuous))
        }
    }

    private func rizoAvatar(size: CGFloat, fontSize: CGFloat) -> some View {
        Text("R")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [PacerizColor.blue, PacerizColor.green],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle())
    }
}
