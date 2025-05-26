import SwiftUI

struct IntensityProgressView: View {
    let title: String
    let current: Double // 實際完成的分鐘數
    let target: Int     // 目標分鐘數
    let originalColor: Color // 原本的進度條顏色

    // MARK: - Computed Properties for PDD Logic

    private var displayState: (text: String, showIcon: Bool, progressValue: Double, barColor: Color, valueColor: Color) {
        let currentMinutes = Int(round(current))

        if target == 0 {
            if currentMinutes > 0 {
                // 狀況: 目標為 0，實際 > 0
                return (
                    text: "本週未安排，已完成 \(currentMinutes) 分鐘",
                    showIcon: false, // PDD 建議直接文字提示
                    progressValue: 0.05, // 顯示 5% 進度條
                    barColor: .gray,     // 灰底
                    valueColor: .secondary // 提示文字顏色
                )
            } else {
                // 狀況: 目標為 0，實際 = 0
                return (
                    text: "未安排", // 或 "無預計訓練"
                    showIcon: false,
                    progressValue: 0.0,
                    barColor: .gray, // 維持與「目標0，實際>0」時一致的灰色背景提示
                    valueColor: .secondary
                )
            }
        } else {
            // 目標 > 0
            if currentMinutes == 0 {
                // 狀況: 實際 = 0 (目標 > 0)
                return (
                    text: "0 / \(target) 分鐘",
                    showIcon: false,
                    progressValue: 0.0,
                    barColor: originalColor,
                    valueColor: .secondary
                )
            } else if current > Double(target) {
                // 狀況: 進度 > 100%
                return (
                    text: "\(currentMinutes) / \(target) 分鐘",
                    showIcon: true, // 顯示 ⓘ 圖示
                    progressValue: 1.0, // 顯示至 100%
                    barColor: originalColor,
                    valueColor: .primary // PDD 未指定顏色，暫用 primary，或可選 .green
                )
            } else {
                // 狀況: 實際 < 目標 (或等於目標)
                return (
                    text: "\(currentMinutes) / \(target) 分鐘",
                    showIcon: false,
                    progressValue: current / Double(target),
                    barColor: originalColor,
                    valueColor: .primary
                )
            }
        }
    }

    var body: some View {
        let state = displayState
        VStack(spacing: 4) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(state.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(state.valueColor)
                
                if state.showIcon {
                    Image(systemName: "info.circle.fill") // 使用 fill 版本更明顯
                        .font(.system(size: 12))
                        .foregroundColor(.gray) // PDD 建議中性提示
                }
            }
            
            HorizontalProgressBar(
                progress: state.progressValue,
                color: state.barColor,
                showDashed: false // PDD 中「細灰進度條」由 color 和 progress 控制，不再需要 dashed
            )
        }
    }
}

#Preview {
    VStack {
        IntensityProgressView(
            title: "低強度",
            current: 120,
            target: 180,
            originalColor: .blue
        )
        
        IntensityProgressView(
            title: "中強度",
            current: 45,
            target: 30,
            originalColor: .green
        )
        
        IntensityProgressView(
            title: "高強度",
            current: 15,
            target: 0,
            originalColor: .orange
        )
    }
    .padding()
}
