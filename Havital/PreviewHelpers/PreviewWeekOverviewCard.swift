import SwiftUI

// 預覽專用的簡化版 WeekOverviewCard
struct PreviewWeekOverviewCard: View {
    let weekPlan: WeeklyPlan
    let weeklySummaries: [WeeklySummaryItem]
    let currentWeekDistance: Double
    
    // 簡化的格式函數
    private func formatDistance(_ distance: Double, unit: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        let distanceString = formatter.string(from: NSNumber(value: distance)) ?? "0.0"
        return unit != nil ? "\(distanceString) \(unit!)" : distanceString
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本週概覽")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    // 顯示週次和跑量
                    VStack(spacing: 8) {
                        Text("第\(weekPlan.weekOfPlan)週")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("本週跑量: \(formatDistance(currentWeekDistance)) 公里")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // 顯示訓練目的
                    if let reasons = weekPlan.designReason, !reasons.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("訓練目的")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(reasons, id: \.self) { reason in
                                Text("• \(reason)")
                                    .font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 3)
        }
        .padding()
    }
}

// 預覽提供者
struct PreviewWeekOverviewCard_Previews: PreviewProvider {
    static var previews: some View {
        let dateFormatter = ISO8601DateFormatter()
        let today = Date()
        
        let weeklyPlan = WeeklyPlan(
            id: "preview_1",
            purpose: "預覽用訓練計劃",
            weekOfPlan: 1,
            totalWeeks: 8,
            totalDistance: 30.0,
            designReason: ["提升耐力", "改善跑步姿勢"],
            days: [],
            intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 60, high: 30)
        )
        
        let weeklySummaries = [
            WeeklySummaryItem(
                weekIndex: 1,
                weekStart: dateFormatter.string(from: today),
                distanceKm: 25.5,
                weekPlan: "week_1_plan",
                weekSummary: "week_1_summary",
                completionPercentage: 75
            )
        ]
        
        return Group {
            PreviewWeekOverviewCard(
                weekPlan: weeklyPlan,
                weeklySummaries: weeklySummaries,
                currentWeekDistance: 18.5
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Light Mode")
            
            PreviewWeekOverviewCard(
                weekPlan: weeklyPlan,
                weeklySummaries: weeklySummaries,
                currentWeekDistance: 18.5
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
