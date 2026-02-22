import SwiftUI

/// 力量訓練動作清單組件
/// 顯示力量訓練的具體動作、組數、次數、時長等資訊
struct ExercisesListView: View {
    let exercises: [Exercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 標題
            HStack(spacing: 4) {
                Text("💪")
                    .font(.caption)
                Text(NSLocalizedString("training.exercises", comment: "Exercises"))
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            // 動作清單
            ForEach(exercises.indices, id: \.self) { index in
                ExerciseRowView(
                    exercise: exercises[index],
                    index: index + 1
                )
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(8)
    }
}

/// 單個動作行視圖
private struct ExerciseRowView: View {
    let exercise: Exercise
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // 序號
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)

            // 動作名稱
            Text(exercise.name)
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            // 組數/次數/時長/重量
            HStack(spacing: 6) {
                if let sets = exercise.sets {
                    Text("\(sets)" + NSLocalizedString("training.sets_unit", comment: "Sets"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let reps = exercise.reps, !reps.isEmpty {
                    Text("\(reps)" + NSLocalizedString("training.reps_unit", comment: "Reps"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let duration = exercise.durationSeconds {
                    Text("\(duration)" + NSLocalizedString("training.seconds_unit", comment: "Seconds"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let weight = exercise.weightKg {
                    Text(String(format: "%.1fkg", weight))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)

        // 動作描述（如果有）
        if let desc = exercise.description, !desc.isEmpty {
            Text(desc)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 26)
        }
    }
}

// MARK: - 預覽

#Preview("Core Stability Exercises") {
    ExercisesListView(
        exercises: [
            Exercise(
                name: "棒式",
                sets: 3,
                reps: nil,
                durationSeconds: 60,
                weightKg: nil,
                restSeconds: 30,
                description: "保持核心穩定，身體呈一直線"
            ),
            Exercise(
                name: "死蟲式",
                sets: 3,
                reps: "10-12",
                durationSeconds: nil,
                weightKg: nil,
                restSeconds: 30,
                description: "控制動作，避免下背離地"
            ),
            Exercise(
                name: "側棒式",
                sets: 3,
                reps: nil,
                durationSeconds: 45,
                weightKg: nil,
                restSeconds: 30,
                description: "左右各做一組"
            )
        ]
    )
    .padding()
}

#Preview("Strength Exercises with Weights") {
    ExercisesListView(
        exercises: [
            Exercise(
                name: "深蹲",
                sets: 4,
                reps: "8-10",
                durationSeconds: nil,
                weightKg: 40.0,
                restSeconds: 60,
                description: "膝蓋與腳尖方向一致"
            ),
            Exercise(
                name: "硬舉",
                sets: 4,
                reps: "6-8",
                durationSeconds: nil,
                weightKg: 60.0,
                restSeconds: 90,
                description: "保持背部平直"
            )
        ]
    )
    .padding()
}

#Preview("Simple Exercise List") {
    ExercisesListView(
        exercises: [
            Exercise(
                name: "跳繩",
                sets: 5,
                reps: nil,
                durationSeconds: 120,
                weightKg: nil,
                restSeconds: 60,
                description: ""
            ),
            Exercise(
                name: "登山式",
                sets: 3,
                reps: "20",
                durationSeconds: nil,
                weightKg: nil,
                restSeconds: 45,
                description: ""
            )
        ]
    )
    .padding()
}
