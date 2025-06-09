import SwiftUI

struct IntensityProgressSection: View {
    let planIntensity: WeeklyPlan.IntensityTotalMinutes  // 計劃目標值
    let actualIntensity: TrainingIntensityManager.IntensityMinutes  // 實際計算出的值
    
    var body: some View {
        VStack(spacing: 12) {
            // 低強度
            IntensityProgressView(
                title: "低強度",
                current: actualIntensity.low,
                target: Int(planIntensity.low),
                originalColor: .blue
            )
            
            // 中強度
            IntensityProgressView(
                title: "中強度",
                current: actualIntensity.medium,
                target: Int(planIntensity.medium),
                originalColor: .green
            )
            
            // 高強度
            IntensityProgressView(
                title: "高強度",
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
