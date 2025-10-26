import SwiftUI

struct WeekProgressHeader: View {
    let plan: WeeklyPlan
    let overview: TrainingPlanOverview?
    @Binding var showWeekSelector: Bool
    @Binding var showTrainingProgress: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(NSLocalizedString("training.progress", comment: "Training Progress"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()

                // 週數按鈕（可點擊開啟週選擇器）
                Button {
                    showWeekSelector = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(plan.weekOfPlan) / \(overview?.totalWeeks ?? plan.totalWeeks) 週")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            WeekProgressBar(progress: Double(plan.weekOfPlan) / Double(overview?.totalWeeks ?? plan.totalWeeks))
                .frame(height: 12)
                .onTapGesture { showTrainingProgress = true }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

#Preview {
    let mockPlan = WeeklyPlan(
        id: "preview",
        purpose: "預覽測試",
        weekOfPlan: 1,
        totalWeeks: 12,
        totalDistance: 50.0,
        designReason: ["測試用"],
        days: [],
        intensityTotalMinutes: nil
    )
    
    return WeekProgressHeader(
        plan: mockPlan,
        overview: nil,
        showWeekSelector: .constant(false),
        showTrainingProgress: .constant(false)
    )
}
