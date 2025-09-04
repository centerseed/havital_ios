import SwiftUI

struct TrainingStageCard: View {
    let stage: TrainingStage
    let index: Int
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
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading) {
                    Text(stage.stageName)
                        .font(.headline)
                        .foregroundColor(stageColors.0)
                    
                    if let weekEnd = stage.weekEnd {
                        Text(L10n.TrainingStageCard.weekRange.localized(with: stage.weekStart, weekEnd))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(L10n.TrainingStageCard.weekStart.localized(with: stage.weekStart))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 階段描述，確保文字可以根據內容動態調整高度
            Text(stage.stageDescription)
                .font(.body)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true) // 確保文字可以根據內容動態調整高度
            
            // 重點訓練部分
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(stageColors.0)
                    Text(L10n.TrainingStageCard.trainingFocus.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(stage.trainingFocus)
                    .font(.subheadline)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 確保佔據最大寬度
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
        )
        .padding(.vertical, 4)
    }
}
