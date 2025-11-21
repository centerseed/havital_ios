import SwiftUI

/// 今日焦點訓練卡片 - 方案二的核心組件
struct TodayFocusCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let todayTraining: TrainingDay?
    @State private var selectedWorkout: WorkoutV2?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(NSLocalizedString("training.today_training", comment: "Today's Training"))
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }

            if let today = todayTraining {
                VStack(alignment: .leading, spacing: 16) {
                    // 訓練類型和距離
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(today.type.localizedName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            if let distance = today.trainingDetails?.totalDistanceKm {
                                Text(String(format: "%.1f km", distance))
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }

                        Spacer()

                        // 訓練類型標籤
                        Text(today.type.localizedName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundColor(getTypeColor(for: today.type))
                            .background(getTypeColor(for: today.type).opacity(0.2))
                            .cornerRadius(8)
                    }

                    // 進度圓環
                    if let totalDistance = today.trainingDetails?.totalDistanceKm {
                        let todayWorkouts = viewModel.workoutsByDayV2[today.dayIndexInt] ?? []
                        let completedDistance = todayWorkouts.reduce(0.0) { $0 + ($1.distance / 1000.0) }
                        let progress = min(completedDistance / totalDistance, 1.0)

                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                    .frame(width: 120, height: 120)

                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut, value: progress)

                                VStack(spacing: 2) {
                                    Text(String(format: "%.1f", completedDistance))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(String(format: "/ %.1f km", totalDistance))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // 訓練分段摘要（如果是組合訓練）
                    if let segments = today.trainingDetails?.segments, !segments.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                                HStack(spacing: 8) {
                                    // 狀態圖示
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)

                                    // 分段描述
                                    if let description = segment.description {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // 距離
                                    if let distance = segment.distanceKm {
                                        Text(String(format: "%.1fkm", distance))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } else {
                        // 簡單訓練顯示目標
                        Divider()

                        Text(today.dayTarget)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // 如果有完成的訓練記錄，顯示列表
                    if let workouts = viewModel.workoutsByDayV2[today.dayIndexInt], !workouts.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("training.completed_workouts", comment: "Completed Workouts"))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(workouts.prefix(2), id: \.id) { workout in
                                Button {
                                    selectedWorkout = workout
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)

                                        Text(String(format: "%.2f km", workout.distance / 1000.0))
                                            .font(.caption)
                                            .foregroundColor(.primary)

                                        Text("·")
                                            .foregroundColor(.secondary)

                                        Text(formatDuration(workout.duration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            } else {
                // 今天沒有訓練
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text(NSLocalizedString("training.no_training_today", comment: "No training scheduled for today"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 2)
                )
        )
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailViewV2(workout: workout)
            }
        }
    }

    // 獲取訓練類型顏色
    private func getTypeColor(for type: DayType) -> Color {
        switch type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .green
        case .interval, .tempo, .progression, .threshold, .combination:
            return .orange
        case .longRun, .hiking, .cycling:
            return .blue
        case .race:
            return .red
        case .rest:
            return .gray
        case .crossTraining, .strength:
            return .purple
        }
    }

    // 格式化持續時間
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    let viewModel = TrainingPlanViewModel()
    let mockDay = TrainingDay(
        dayIndex: "0",
        type: .combination,
        dayTarget: "結合多種配速與強度訓練整體能力",
        trainingDetails: TrainingDetails(
            description: "組合訓練",
            pace: nil,
            distanceKm: 10.0,
            heartRateRange: nil,
            totalDistanceKm: 10.0,
            segments: [
                ProgressionSegment(description: "輕鬆開始", pace: nil, distanceKm: 3.0, heartRateRange: HeartRateRange(min: 141, max: 162)),
                ProgressionSegment(description: "提速", pace: "5:25", distanceKm: 4.0, heartRateRange: HeartRateRange(min: 162, max: 176)),
                ProgressionSegment(description: "放鬆結束", pace: nil, distanceKm: 3.0, heartRateRange: HeartRateRange(min: 141, max: 162))
            ]
        ),
        tips: nil
    )

    TodayFocusCard(viewModel: viewModel, todayTraining: mockDay)
        .padding()
}
