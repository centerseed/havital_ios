import SwiftUI

/// 力量訓練動作清單組件
/// 卡片式清單：序號 + 動作名稱 + 組數標籤 + 次數/時長，行間以分隔線區隔。
struct ExercisesListView: View {
    let exercises: [Exercise]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(exercises.indices, id: \.self) { index in
                ExerciseRowWrapperView(
                    exercise: exercises[index],
                    index: index + 1
                )
                if index < exercises.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 0.5)
        )
    }
}

/// 單個動作行視圖 (點擊彈出教學)
private struct ExerciseRowWrapperView: View {
    let exercise: Exercise
    let index: Int
    @State private var showInstructionSheet = false
    
    var body: some View {
        let mapped = ExerciseImageMapper.mappedImageAndKey(for: exercise.exerciseId, name: exercise.name)
        
        Button(action: {
            if mapped != nil {
                showInstructionSheet = true
            }
        }) {
            ExerciseRowView(exercise: exercise, index: index)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showInstructionSheet) {
            if let mapping = mapped {
                ExerciseInstructionView(
                    exerciseName: ExerciseImageMapper.localizedName(for: exercise.exerciseId, fallback: exercise.name),
                    imageName: mapping.image,
                    instructionDesc: mapping.key
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

/// 單個動作行視圖：序號 · 名稱 · 組數標籤 · 主要數值（時長/次數/重量）
private struct ExerciseRowView: View {
    let exercise: Exercise
    let index: Int

    /// 主要數值：優先時長（如棒式 45 秒），否則次數（如 12 次），否則重量。
    private var trailingValue: String? {
        if let d = exercise.durationSeconds {
            return "\(d) \(NSLocalizedString("training.seconds_unit", comment: ""))"
        }
        if let reps = exercise.reps, !reps.isEmpty {
            return "\(reps) \(NSLocalizedString("training.reps_unit", comment: ""))"
        }
        if let w = exercise.weightKg {
            return String(format: "%.0f kg", w)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(AppFont.caption().monospacedDigit())
                .foregroundColor(Color(.tertiaryLabel))

            Text(exercise.name)
                .font(AppFont.bodyStrong())
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let sets = exercise.sets {
                Text("\(sets) \(NSLocalizedString("training.sets_unit", comment: ""))")
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }

            if let value = trailingValue {
                Text(value)
                    .font(AppFont.bodyStrong().monospacedDigit())
                    .foregroundColor(.primary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

// MARK: - 預覽

#Preview("Core Stability Exercises") {
    ExercisesListView(
        exercises: [
            Exercise(
                exerciseId: nil,
                name: "棒式",
                sets: 3,
                reps: nil,
                durationSeconds: 60,
                weightKg: nil,
                restSeconds: 30,
                description: "保持核心穩定，身體呈一直線"
            ),
            Exercise(
                exerciseId: nil,
                name: "死蟲式",
                sets: 3,
                reps: "10-12",
                durationSeconds: nil,
                weightKg: nil,
                restSeconds: 30,
                description: "控制動作，避免下背離地"
            ),
            Exercise(
                exerciseId: nil,
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
                exerciseId: nil,
                name: "深蹲",
                sets: 4,
                reps: "8-10",
                durationSeconds: nil,
                weightKg: 40.0,
                restSeconds: 60,
                description: "膝蓋與腳尖方向一致"
            ),
            Exercise(
                exerciseId: nil,
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
                exerciseId: nil,
                name: "跳繩",
                sets: 5,
                reps: nil,
                durationSeconds: 120,
                weightKg: nil,
                restSeconds: 60,
                description: ""
            ),
            Exercise(
                exerciseId: nil,
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
