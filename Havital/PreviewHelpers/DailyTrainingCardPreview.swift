import SwiftUI

// 依據 WeeklyPlan.swift 的實際結構進行 mock
import Foundation

struct DailyTrainingCardPreview: View {
    @StateObject private var viewModel = TrainingPlanViewModel()

    // Sample plan JSON provided by user for preview
    private let samplePlanJSON = """
    {
      "id": "preview_plan",
      "purpose": "逐步增加跑量，引入中高強度刺激，提升耐力與速度閾值",
      "week_of_plan": 1,
      "total_weeks": 5,
      "total_distance_km": 39.0,
      "days": [
        {"day_index": 1, "training_type": "easy_run", "day_target": "輕鬆恢復，為後續訓練做準備", "reason": "作為一週的開始，輕鬆跑有助於身體恢復，並為接下來的訓練打下基礎。", "training_details": {"distance_km": 6, "time_minutes": 36, "pace": "5:30", "heart_rate_range": {"min": 141, "max": 159}, "description": "輕鬆跑，注意保持輕鬆的心情和呼吸。"}},
        {"day_index": 2, "training_type": "threshold", "day_target": "提升乳酸閾值，增強耐力", "reason": "閾值跑是提高耐力的有效方法，可以幫助您在更高強度下維持更長時間。", "training_details": {"segments": [{"distance_km": 3, "pace": "5:30", "description": "輕鬆跑熱身"}, {"distance_km": 3, "pace": "4:45", "description": "閾值跑"}], "total_distance_km": 6, "description": "組合訓練，包含輕鬆跑熱身和閾值跑。"}},
        {"day_index": 3, "training_type": "rest", "day_target": "讓身體充分休息，恢復體力", "reason": "休息是訓練的重要組成部分，有助於肌肉修復和恢復。", "training_details": {"description": "充分休息，可以進行一些輕微的伸展運動。"}},
        {"day_index": 4, "training_type": "recovery_run", "day_target": "促進血液循環，加速恢復", "reason": "恢復跑有助於清除乳酸，減輕肌肉酸痛。", "training_details": {"distance_km": 4, "time_minutes": 26, "pace": "6:30", "heart_rate_range": {"min": 124, "max": 141}, "description": "恢復跑，保持輕鬆的步伐。"}},
        {"day_index": 5, "training_type": "tempo", "day_target": "提高速度耐力，增強比賽能力", "reason": "節奏跑可以提高您在比賽配速下的耐力。", "training_details": {"segments": [{"distance_km": 3, "pace": "5:30", "description": "輕鬆跑熱身"}, {"distance_km": 3, "pace": "5:00", "description": "節奏跑"}], "total_distance_km": 6, "description": "組合訓練，包含輕鬆跑熱身和節奏跑。"}},
        {"day_index": 6, "training_type": "long_run", "day_target": "增強耐力，為長距離比賽做準備", "reason": "長跑是提高耐力的關鍵訓練，可以幫助您適應長時間的運動。", "training_details": {"distance_km": 12, "time_minutes": 72, "pace": "6:00", "heart_rate_range": {"min": 141, "max": 159}, "description": "長跑，注意補水和能量。"}},
        {"day_index": 7, "training_type": "easy_run", "day_target": "輕鬆恢復，為下週訓練做準備", "reason": "週末的輕鬆跑有助於身體恢復，並為下週的訓練做好準備。", "training_details": {"distance_km": 5, "time_minutes": 30, "pace": "6:00", "heart_rate_range": {"min": 141, "max": 159}, "description": "輕鬆跑，享受跑步的樂趣。"}}
      ]
    }
    """

    private var samplePlan: WeeklyPlan {
        guard let data = samplePlanJSON.data(using: .utf8) else { fatalError("Invalid samplePlanJSON") }
        do { return try JSONDecoder().decode(WeeklyPlan.self, from: data) }
        catch { fatalError("Failed to decode samplePlan: \(error)") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(samplePlan.days) { day in
                    DailyTrainingCard(
                        viewModel: viewModel,
                        day: day,
                        isToday: day.dayIndexInt == 1
                    )
                }
            }
            .padding()
        }
    }
}

struct DailyTrainingCardPreview_Previews: PreviewProvider {
    static var previews: some View {
        DailyTrainingCardPreview()
            .environmentObject(HealthKitManager())
    }
}
