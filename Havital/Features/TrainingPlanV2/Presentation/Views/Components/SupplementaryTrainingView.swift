import SwiftUI

/// 補充訓練顯示組件
/// 用於顯示主訓練之後的補充訓練項目（如力量訓練）
struct SupplementaryTrainingView: View {
    let activities: [SupplementaryActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(activities.indices, id: \.self) { index in
                SupplementaryActivityItemView(
                    activity: activities[index]
                )
            }
        }
    }
}

/// 補充訓練區塊的卡片標頭：圖示方塊 + 標題（+副標）+ 時長膠囊。
private struct SupplementaryHeader: View {
    let title: String
    let subtitle: String?
    let durationMinutes: Int?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(PacerizColor.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "plus")
                    .font(AppFont.bodyStrong())
                    .foregroundColor(PacerizColor.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.bodyStrong())
                    .foregroundColor(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let mins = durationMinutes {
                Text("\(mins) \(NSLocalizedString("training.minutes_unit", comment: ""))")
                    .font(AppFont.micro())
                    .foregroundColor(PacerizColor.orangeDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(PacerizColor.orange.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
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
            case .cross(let crossActivity):
                CrossSupplementaryView(activity: crossActivity)
            }
        }
    }
}

/// 力量訓練視圖
private struct StrengthActivityView: View {
    let activity: StrengthActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SupplementaryHeader(
                title: strengthTypeDisplayName(activity.strengthType),
                subtitle: activity.description,
                durationMinutes: activity.durationMinutes
            )

            if !activity.exercises.isEmpty {
                ExercisesListView(exercises: activity.exercises)
            }
        }
    }

    private func strengthTypeDisplayName(_ type: String) -> String {
        switch type {
        case "core_stability":
            return NSLocalizedString("training.strength_type.core_stability", comment: "Core Stability")
        case "glutes_hip":
            return NSLocalizedString("training.strength_type.glutes_hip", comment: "Glutes Hip")
        case "lower_strength":
            return NSLocalizedString("training.strength_type.lower_strength", comment: "Lower Strength")
        case "upper_strength":
            return NSLocalizedString("training.strength_type.upper_strength", comment: "Upper Strength")
        case "full_body":
            return NSLocalizedString("training.strength_type.full_body", comment: "Full Body")
        case "plyometric":
            return NSLocalizedString("training.strength_type.plyometric", comment: "Plyometric")
        case "mobility":
            return NSLocalizedString("training.strength_type.mobility", comment: "Mobility")
        default:
            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// 交叉訓練補充視圖
private struct CrossSupplementaryView: View {
    let activity: CrossActivity

    var body: some View {
        SupplementaryHeader(
            title: crossTypeDisplayName(activity.crossType),
            subtitle: activity.description,
            durationMinutes: activity.durationMinutes
        )
    }

    private func crossTypeDisplayName(_ type: String) -> String {
        switch type {
        case "cycling":
            return NSLocalizedString("training.cross_type.cycling", comment: "Cycling")
        case "swimming":
            return NSLocalizedString("training.cross_type.swimming", comment: "Swimming")
        case "yoga":
            return NSLocalizedString("training.cross_type.yoga", comment: "Yoga")
        case "hiking":
            return NSLocalizedString("training.cross_type.hiking", comment: "Hiking")
        case "elliptical":
            return NSLocalizedString("training.cross_type.elliptical", comment: "Elliptical")
        case "rowing":
            return NSLocalizedString("training.cross_type.rowing", comment: "Rowing")
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
                            exerciseId: nil,
                            name: "棒式",
                            sets: 3,
                            reps: nil,
                            durationSeconds: 60,
                            weightKg: nil,
                            restSeconds: 30,
                            description: "保持核心穩定"
                        ),
                        Exercise(
                            exerciseId: nil,
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
                            exerciseId: nil,
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
                            exerciseId: nil,
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
