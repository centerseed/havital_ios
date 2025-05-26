import SwiftUI

struct WeekProgressHeader: View {
    let plan: WeeklyPlan
    @Binding var showWeekSelector: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("訓練進度")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(plan.weekOfPlan) / \(plan.totalWeeks) 週")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            WeekProgressBar(progress: Double(plan.weekOfPlan) / Double(plan.totalWeeks))
                .frame(height: 12)
                .onTapGesture { showWeekSelector = true }
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
        showWeekSelector: .constant(false)
    )
}
