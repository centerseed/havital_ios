import SwiftUI

struct IntensityProgressView: View {
    let title: String
    let current: Double // 實際完成的分鐘數
    let target: Int     // 目標分鐘數
    let originalColor: Color // 原本的進度條顏色

    // MARK: - Computed Properties for PDD Logic

    private var displayState: (mainText: String, annotationText: String?, showIcon: Bool, progressValue: Double, barColor: Color, valueColor: Color) {
        let currentMinutes = Int(round(current))

        if target == 0 {
            if currentMinutes > 0 {
                // 狀況: 目標為 0，實際 > 0（未排課但有訓練）
                return (
                    mainText: String(format: NSLocalizedString("intensity.minutes", comment: "Minutes"), currentMinutes),
                    annotationText: NSLocalizedString("intensity.unscheduled", comment: "(Unscheduled)"),
                    showIcon: false,
                    progressValue: 1.0, // 顯示完整進度條以表示活動量
                    barColor: .gray.opacity(0.5),     // 灰色半透明，更加柔和
                    valueColor: .secondary // 提示文字顏色
                )
            } else {
                // 狀況: 目標為 0，實際 = 0（未排課且無訓練）
                return (
                    mainText: NSLocalizedString("intensity.not_scheduled", comment: "Not scheduled"),
                    annotationText: nil,
                    showIcon: false,
                    progressValue: 0.0,
                    barColor: .gray.opacity(0.3), // 更淺的灰色，表示空白狀態
                    valueColor: .secondary.opacity(0.7) // 更淡的文字顏色
                )
            }
        } else {
            // 目標 > 0
            if currentMinutes == 0 {
                // 狀況: 實際 = 0 (目標 > 0)
                return (
                    mainText: String(format: NSLocalizedString("intensity.minutes_progress", comment: "Minutes progress"), 0, target),
                    annotationText: nil,
                    showIcon: false,
                    progressValue: 0.0,
                    barColor: originalColor,
                    valueColor: .secondary
                )
            } else if current > Double(target) {
                // 狀況: 進度 > 100%
                return (
                    mainText: String(format: NSLocalizedString("intensity.minutes_progress", comment: "Minutes progress"), currentMinutes, target),
                    annotationText: nil,
                    showIcon: true, // 顯示 ⓘ 圖示
                    progressValue: 1.0, // 顯示至 100%
                    barColor: originalColor,
                    valueColor: .primary
                )
            } else {
                // 狀況: 實際 < 目標 (或等於目標)
                return (
                    mainText: String(format: NSLocalizedString("intensity.minutes_progress", comment: "Minutes progress"), currentMinutes, target),
                    annotationText: nil,
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                HStack(spacing: 4) { // A small spacing between main text and annotation
                    Text(state.mainText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(state.valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1) // Give priority to mainText

                    if let annotation = state.annotationText {
                        Text(annotation)
                            .font(.system(size: 11, weight: .regular)) // Slightly smaller and regular weight
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true) // Allow annotation to shrink
                    }
                }
                .layoutPriority(1) // Give this whole group priority in the outer HStack
                
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
            title: NSLocalizedString("intensity.low", comment: "Low Intensity"),
            current: 120,
            target: 180,
            originalColor: .blue
        )
        
        IntensityProgressView(
            title: NSLocalizedString("intensity.medium", comment: "Medium Intensity"),
            current: 45,
            target: 30,
            originalColor: .green
        )
        
        IntensityProgressView(
            title: NSLocalizedString("intensity.high", comment: "High Intensity"),
            current: 15,
            target: 0,
            originalColor: .orange
        )
    }
    .padding()
}
