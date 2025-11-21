import SwiftUI

/// 週訓練時間軸視圖 - 顯示本週所有訓練的時間軸
struct WeekTimelineView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let plan: WeeklyPlan
    @State private var selectedWorkout: WorkoutV2?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.headline)
                Text(NSLocalizedString("training.this_week_training", comment: "This Week's Training"))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)

            // 時間軸列表
            VStack(spacing: 12) {
                ForEach(plan.days) { day in
                    TimelineItemView(
                        viewModel: viewModel,
                        day: day,
                        planWeek: plan.weekOfPlan,
                        onWorkoutSelect: { workout in
                            selectedWorkout = workout
                        }
                    )
                }
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailViewV2(workout: workout)
            }
        }
    }
}

/// 時間軸單項視圖
struct TimelineItemView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let day: TrainingDay
    let planWeek: Int
    let onWorkoutSelect: (WorkoutV2) -> Void

    @State private var isExpanded = false

    // 計算屬性
    private var isToday: Bool {
        viewModel.isToday(dayIndex: day.dayIndexInt, planWeek: planWeek)
    }

    private var isPast: Bool {
        viewModel.isPastDay(dayIndex: day.dayIndexInt, planWeek: planWeek)
    }

    private var workouts: [WorkoutV2] {
        viewModel.workoutsByDayV2[day.dayIndexInt] ?? []
    }

    private var isCompleted: Bool {
        !workouts.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左側時間軸線和狀態點
            VStack(spacing: 0) {
                // 上方連接線
                if day.dayIndexInt > 0 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 20)
                }

                // 狀態圓點
                ZStack {
                    Circle()
                        .fill(getStatusColor())
                        .frame(width: 16, height: 16)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    } else if isToday {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                }

                // 下方連接線
                if day.dayIndexInt < 6 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }
            .frame(width: 16)

            // 右側內容卡片
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    if !isToday {  // 今日訓練不在這裡展開
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                }) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            // 日期和星期
                            HStack(spacing: 6) {
                                Text(viewModel.weekdayName(for: day.dayIndexInt))
                                    .font(.subheadline)
                                    .fontWeight(isToday ? .semibold : .regular)
                                    .foregroundColor(isToday ? .blue : .primary)

                                if let date = viewModel.getDateForDay(dayIndex: day.dayIndexInt) {
                                    Text(viewModel.formatShortDate(date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if isToday {
                                    Text(NSLocalizedString("training_plan.today", comment: "Today"))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                } else if !isPast {
                                    Text(NSLocalizedString("training.upcoming", comment: "Upcoming"))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }

                            // 訓練類型和距離摘要
                            HStack(spacing: 8) {
                                Text(day.type.localizedName)
                                    .font(.caption)
                                    .foregroundColor(getTypeColor())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(getTypeColor().opacity(0.15))
                                    .cornerRadius(6)

                                if let distance = day.trainingDetails?.totalDistanceKm {
                                    Text(String(format: "%.1f km", distance))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if isCompleted {
                                    Text("✓ \(NSLocalizedString("training.completed", comment: "Completed"))")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        Spacer()

                        // 展開/收起圖示（今日訓練不顯示）
                        if !isToday {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 展開內容（今日訓練始終展開）
                if isExpanded || isToday {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        // 訓練目標
                        Text(day.dayTarget)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // 已完成的訓練記錄
                        if !workouts.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(workouts.prefix(2), id: \.id) { workout in
                                    Button {
                                        onWorkoutSelect(workout)
                                    } label: {
                                        HStack {
                                            Image(systemName: "figure.run")
                                                .foregroundColor(.green)
                                                .font(.caption2)

                                            Text(String(format: "%.2f km", (workout.distance ?? 0.0) / 1000.0))
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

                                if workouts.count > 2 {
                                    Text("+ \(workouts.count - 2) \(NSLocalizedString("training.more_workouts", comment: "more"))")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isToday ? Color.blue.opacity(0.08) : Color(UIColor.secondarySystemBackground))
            )
        }
    }

    // 獲取狀態顏色
    private func getStatusColor() -> Color {
        if isCompleted {
            return .green
        } else if isToday {
            return .blue
        } else if isPast {
            return .gray
        } else {
            return .orange
        }
    }

    // 獲取訓練類型顏色
    private func getTypeColor() -> Color {
        switch day.type {
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
    let mockPlan = WeeklyPlan(
        id: "preview",
        purpose: "預覽測試",
        weekOfPlan: 35,
        totalWeeks: 39,
        totalDistance: 43.0,
        designReason: ["測試用"],
        days: [
            TrainingDay(dayIndex: "0", dayTarget: "恢復跑", reason: nil, tips: nil, trainingType: "recovery_run",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 6.19, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil)),
            TrainingDay(dayIndex: "1", dayTarget: "間歇訓練", reason: nil, tips: nil, trainingType: "interval",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 4.42, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil)),
            TrainingDay(dayIndex: "4", dayTarget: "組合訓練", reason: nil, tips: nil, trainingType: "combination",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: nil, totalDistanceKm: 10.0, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil)),
            TrainingDay(dayIndex: "2", dayTarget: "輕鬆跑", reason: nil, tips: nil, trainingType: "easy",
                       trainingDetails: TrainingDetails(description: nil, distanceKm: 8.0, totalDistanceKm: nil, timeMinutes: nil, pace: nil, work: nil, recovery: nil, repeats: nil, heartRateRange: nil, segments: nil))
        ],
        intensityTotalMinutes: WeeklyPlan.IntensityTotalMinutes(low: 120, medium: 45, high: 15)
    )

    WeekTimelineView(viewModel: viewModel, plan: mockPlan)
        .padding()
}
