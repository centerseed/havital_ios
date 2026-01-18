import SwiftUI

struct TrainingStageCard: View {
    let stage: TrainingStage
    let index: Int
    @State private var isDescriptionExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var stageColors: (Color, Color) {
        let colors: [(Color, Color)] = [
            (Color.blue, Color.blue.opacity(0.15)),
            (Color.green, Color.green.opacity(0.15)),
            (Color.orange, Color.orange.opacity(0.15)),
            (Color.purple, Color.purple.opacity(0.15))
        ]

        return colors[index % colors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 階段標題和週數
            HStack {
                Circle()
                    .fill(stageColors.0)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(index + 1)")
                            .font(AppFont.headline())
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.stageName)
                        .font(AppFont.headline())
                        .foregroundColor(stageColors.0)

                    if let weekEnd = stage.weekEnd {
                        Text(L10n.TrainingStageCard.weekRange.localized(with: stage.weekStart, weekEnd))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    } else {
                        Text(L10n.TrainingStageCard.weekStart.localized(with: stage.weekStart))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 訓練重點（始終顯示）
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(stageColors.0)
                    Text(L10n.TrainingStageCard.trainingFocus.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                }

                Text(stage.trainingFocus)
                    .font(AppFont.bodySmall())
                    .foregroundColor(stageColors.0)
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(stageColors.1)
            )

            // 可收折的階段描述
            VStack(alignment: .leading, spacing: 0) {
                // 展開/收起按鈕
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDescriptionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(NSLocalizedString("training.stage_description", comment: "階段說明"))
                            .font(AppFont.bodySmall())
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // 階段描述內容（可收折）
                if isDescriptionExpanded {
                    Text(stage.stageDescription)
                        .font(AppFont.body())
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
        )
        .padding(.vertical, 4)
    }
}
