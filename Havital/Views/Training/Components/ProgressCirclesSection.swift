import SwiftUI

struct ProgressCirclesSection: View {
    let plan: WeeklyPlan
    let overview: TrainingPlanOverview?
    let currentWeekDistance: Double
    let formatDistance: (Double) -> String
    @Binding var showWeekSelector: Bool
    @Binding var showTrainingProgress: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                // 左側週進度環 (50%)
                VStack(spacing: 8) {
                    CircleProgressView(
                        progress: Double(plan.weekOfPlan) / Double(overview?.totalWeeks ?? plan.totalWeeks),
                        distanceInfo: "\(plan.weekOfPlan)/\(overview?.totalWeeks ?? plan.totalWeeks)",
                        title: NSLocalizedString("progress.training_progress", comment: "Training Progress"),
                        unit: NSLocalizedString("progress.week_unit", comment: "Week")
                    )
                    .frame(width: 100, height: 100)
                    .onTapGesture { showTrainingProgress = true }
                }
                .frame(width: geometry.size.width * 0.45, alignment: .center)
                
                // 右側跑量環 (50%)
                VStack(spacing: 8) {
                    CircleProgressView(
                        progress: min(currentWeekDistance / max(plan.totalDistance, 1.0), 1.0),
                        distanceInfo: "\(formatDistance(currentWeekDistance))/\(formatDistance(plan.totalDistance))",
                        title: ViewModelUtils.isCurrentLanguageChinese() 
                            ? NSLocalizedString("progress.weekly_volume_zh", comment: "週跑量")
                            : NSLocalizedString("progress.weekly_volume", comment: "Weekly Volume")
                    )
                    .frame(width: 100, height: 100)
                }
                .frame(width: geometry.size.width * 0.5, alignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}

struct ProgressWithIntensitySection: View {
    let plan: WeeklyPlan
    let planIntensity: WeeklyPlan.IntensityTotalMinutes  // 計劃目標值
    let actualIntensity: TrainingIntensityManager.IntensityMinutes  // 實際計算出的值
    let currentWeekDistance: Double
    let formatDistance: (Double) -> String
    @Binding var showTrainingProgress: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                // 左側跑量環 (40%)
                VStack(spacing: 16) {
                    CircleProgressView(
                        progress: min(currentWeekDistance / max(plan.totalDistance, 1.0), 1.0),
                        distanceInfo: "\(formatDistance(currentWeekDistance))/\(formatDistance(plan.totalDistance))",
                        title: ViewModelUtils.isCurrentLanguageChinese() 
                            ? NSLocalizedString("progress.weekly_volume_zh", comment: "週跑量")
                            : NSLocalizedString("progress.weekly_volume", comment: "Weekly Volume")
                    )
                    .frame(width: 100, height: 100)
                    .onTapGesture { showTrainingProgress = true }
                }
                .frame(width: geometry.size.width * 0.45, alignment: .center)
                
                // 右側強度進度條 (60%)
                VStack(spacing: 10) {
                    IntensityProgressSection(
                        planIntensity: planIntensity,
                        actualIntensity: actualIntensity
                    )
                }
                .frame(width: geometry.size.width * 0.5 - 16, alignment: .leading)
                .padding(.trailing, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}

#Preview {
    VStack {
        let mockIntensity = WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
        let mockPlan = WeeklyPlan(
            id: "preview",
            purpose: "預覽測試",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 50.0,
            designReason: ["測試用"],
            days: [],
            intensityTotalMinutes: mockIntensity
        )
        
        ProgressCirclesSection(
            plan: mockPlan,
            overview: nil,
            currentWeekDistance: 25.5,
            formatDistance: { String(format: "%.1f km", $0) },
            showWeekSelector: .constant(false),
            showTrainingProgress: .constant(false)
        )
        .padding()
        
        ProgressWithIntensitySection(
            plan: mockPlan,
            planIntensity: mockIntensity,
            actualIntensity: TrainingIntensityManager.IntensityMinutes(low: 90, medium: 30, high: 10),
            currentWeekDistance: 25.5,
            formatDistance: { String(format: "%.1f km", $0) },
            showTrainingProgress: .constant(false)
        )
        .padding()
    }
}
