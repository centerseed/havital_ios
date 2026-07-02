import SwiftUI

// MARK: - RizoHistoryDetailView
/// 單段 Rizo 對話唯讀逐字稿。無輸入框、無改課表卡、無任何寫入動作。
struct RizoHistoryDetailView: View {
    let conversation: RizoConversationSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                ForEach(Array(conversation.turns.enumerated()), id: \.offset) { _, turn in
                    if !turn.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        userBubble(text: turn.userInput)
                    }
                    if !turn.rizoResponse.isEmpty {
                        coachBubble(text: turn.rizoResponse)
                    }
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
