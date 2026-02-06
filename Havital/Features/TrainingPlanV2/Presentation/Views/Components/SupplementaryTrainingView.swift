import SwiftUI

/// 補充訓練顯示組件
/// 用於顯示主訓練之後的補充訓練項目（如力量訓練）
struct SupplementaryTrainingView: View {
    let activities: [SupplementaryActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 標題
            HStack(spacing: 4) {
                Text("➕")
                    .font(.caption)
                Text("補充訓練")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            // 補充訓練項目
            ForEach(activities.indices, id: \.self) { index in
                SupplementaryActivityItemView(
                    activity: activities[index]
                )
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }
}

/// 單個補充訓練項目視圖
private struct SupplementaryActivityItemView: View {
    let activity: SupplementaryActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch activity {
            case .strength(let strengthActivity):
                StrengthActivityView(activity: strengthActivity)
            }
        }
    }
}

/// 力量訓練視圖
private struct StrengthActivityView: View {
    let activity: StrengthActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 力量訓練類型和時長
            HStack {
                Text(strengthTypeDisplayName(activity.strengthType))
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("\(activity.durationMinutes)分鐘")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 描述
            if !activity.description.isEmpty {
                Text(activity.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 動作清單
            if !activity.exercises.isEmpty {
                ExercisesListView(exercises: activity.exercises)
            }
        }
    }

    private func strengthTypeDisplayName(_ type: String) -> String {
        switch type {
        case "core_stability":
            return "核心穩定訓練"
        case "glutes_hip":
            return "臀部與髖部訓練"
        case "lower_strength":
            return "下肢力量訓練"
        case "upper_strength":
            return "上肢力量訓練"
        case "full_body":
            return "全身力量訓練"
        case "plyometric":
            return "增強式訓練"
        case "mobility":
            return "活動度訓練"
        default:
            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - 預覽

#Preview("Single Supplementary Strength") {
    SupplementaryTrainingView(
        activities: [
            .strength(
                StrengthActivity(
                    strengthType: "core_stability",
                    exercises: [
                        Exercise(
                            name: "棒式",
                            sets: 3,
                            reps: nil,
                            durationSeconds: 60,
                            weightKg: nil,
                            restSeconds: 30,
                            description: "保持核心穩定"
                        ),
                        Exercise(
                            name: "死蟲式",
                            sets: 3,
                            reps: "10-12",
                            durationSeconds: nil,
                            weightKg: nil,
                            restSeconds: 30,
                            description: "控制動作"
                        )
                    ],
                    durationMinutes: 15,
                    description: "跑後核心訓練"
                )
            )
        ]
    )
    .padding()
}

#Preview("Multiple Supplementary Activities") {
    SupplementaryTrainingView(
        activities: [
            .strength(
                StrengthActivity(
                    strengthType: "glutes_hip",
                    exercises: [
                        Exercise(
                            name: "臀橋",
                            sets: 3,
                            reps: "15",
                            durationSeconds: nil,
                            weightKg: nil,
                            restSeconds: 30,
                            description: "強化臀部肌群"
                        )
                    ],
                    durationMinutes: 10,
                    description: "臀部強化"
                )
            ),
            .strength(
                StrengthActivity(
                    strengthType: "core_stability",
                    exercises: [
                        Exercise(
                            name: "棒式",
                            sets: 2,
                            reps: nil,
                            durationSeconds: 45,
                            weightKg: nil,
                            restSeconds: 30,
                            description: ""
                        )
                    ],
                    durationMinutes: 8,
                    description: "核心穩定"
                )
            )
        ]
    )
    .padding()
}

#Preview("Supplementary with No Exercises") {
    SupplementaryTrainingView(
        activities: [
            .strength(
                StrengthActivity(
                    strengthType: "mobility",
                    exercises: [],
                    durationMinutes: 15,
                    description: "動態伸展與活動度訓練"
                )
            )
        ]
    )
    .padding()
}
