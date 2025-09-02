import SwiftUI

struct IntensityProgressSection: View {
    let planIntensity: WeeklyPlan.IntensityTotalMinutes  // 計劃目標值
    let actualIntensity: TrainingIntensityManager.IntensityMinutes  // 實際計算出的值
    
    var body: some View {
        VStack(spacing: 12) {
            // 低強度
            IntensityProgressView(
                title: ViewModelUtils.isCurrentLanguageChinese() 
                    ? NSLocalizedString("intensity.low_zh", comment: "低強度")
                    : NSLocalizedString("intensity.low", comment: "Low Intensity"),
                current: actualIntensity.low,
                target: Int(planIntensity.low),
                originalColor: .blue
            )
            
            // 中強度
            IntensityProgressView(
                title: ViewModelUtils.isCurrentLanguageChinese() 
                    ? NSLocalizedString("intensity.medium_zh", comment: "中強度")
                    : NSLocalizedString("intensity.medium", comment: "Medium Intensity"),
                current: actualIntensity.medium,
                target: Int(planIntensity.medium),
                originalColor: .green
            )
            
            // 高強度
            IntensityProgressView(
                title: ViewModelUtils.isCurrentLanguageChinese() 
                    ? NSLocalizedString("intensity.high_zh", comment: "高強度")
                    : NSLocalizedString("intensity.high", comment: "High Intensity"),
                current: actualIntensity.high,
                target: Int(planIntensity.high),
                originalColor: .orange
            )
        }
    }
}

#Preview {
    let mockPlanIntensity = WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
    let mockActualIntensity = TrainingIntensityManager.IntensityMinutes(low: 90, medium: 30, high: 10)
    
    IntensityProgressSection(
        planIntensity: mockPlanIntensity,
        actualIntensity: mockActualIntensity
    )
    .padding()
}
