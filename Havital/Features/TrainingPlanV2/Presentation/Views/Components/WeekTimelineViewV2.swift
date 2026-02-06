import SwiftUI

/// V2 週訓練時間軸視圖 - 顯示本週所有訓練的時間軸
/// 基於 V1 WeekTimelineView，適配 V2 ViewModel 和 WeeklyPlanV2
struct WeekTimelineViewV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    let plan: WeeklyPlanV2
    @State private var selectedWorkout: WorkoutV2?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(AppFont.headline())
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)

            // 時間軸列表（按 dayIndex 排序確保日期順序正確）
            VStack(spacing: 12) {
                ForEach(plan.days.sorted { $0.dayIndexInt < $1.dayIndexInt }) { day in
                    TimelineItemViewV2(
                        viewModel: viewModel,
                        day: day,
                        onWorkoutSelect: { workout in
                            selectedWorkout = workout
                        }
                    )
                }
            }
            .background(
                // 在整個列表背景繪製完整的垂直連接線
                GeometryReader { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .offset(x: 7)
                }
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailViewV2(workout: workout)
            }
        }
    }
}

/// V2 時間軸單項視圖
struct TimelineItemViewV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    let day: DayDetail
    let onWorkoutSelect: (WorkoutV2) -> Void

    @State private var isExpanded = false
    @State private var showTrainingTypeInfo = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isToday = viewModel.isToday(dayIndex: day.dayIndexInt)
        let workouts = viewModel.workoutsByDay[day.dayIndexInt] ?? []

        // 判斷是否為過去的日期
        let isPast: Bool = {
            guard let dayDate = viewModel.getDate(for: day.dayIndexInt) else {
                return false
            }
            let today = Calendar.current.startOfDay(for: Date())
            let targetDay = Calendar.current.startOfDay(for: dayDate)
            return targetDay < today
        }()

        // 休息日只有在當天或已過去時才標記為已完成
        let isCompletedRest = day.type == .rest && (isToday || isPast)
        let isCompleted = isCompletedRest || !workouts.isEmpty

        HStack(alignment: .top, spacing: 12) {
            // 左側時間軸狀態點
            ZStack {
                Circle()
                    .fill(getStatusColor(isCompleted: isCompleted, isToday: isToday, isPast: isPast))
                    .frame(width: 16, height: 16)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(AppFont.captionSmall())
                        .foregroundColor(.white)
                } else if isToday {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 16, height: 16)

            // 右側內容卡片
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    if !isToday {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 第一行：日期 + 訓練類型標籤 + 收折按鈕
                        HStack(alignment: .center, spacing: 8) {
                            // 日期
                            HStack(spacing: 6) {
                                Text(DateFormatterHelper.weekdayName(for: day.dayIndexInt))
                                    .font(AppFont.bodySmall())
                                    .fontWeight(isToday ? .semibold : .regular)
                                    .foregroundColor(isToday ? .blue : .primary)

                                if let date = viewModel.getDate(for: day.dayIndexInt) {
                                    Text(DateFormatterHelper.formatShortDate(date))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)
                                }

                                if isToday {
                                    Text(NSLocalizedString("training_plan.today", comment: "Today"))
                                        .font(AppFont.caption())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                }
                            }

                            Spacer()

                            // 訓練類型標籤
                            if TrainingTypeInfo.info(for: day.type) != nil {
                                Button(action: {
                                    showTrainingTypeInfo = true
                                }) {
                                    Text(day.type.localizedName)
                                        .font(AppFont.bodySmall())
                                        .fontWeight(.medium)
                                        .foregroundColor(getTypeColor())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(getTypeColor().opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Text(day.type.localizedName)
                                    .font(AppFont.bodySmall())
                                    .fontWeight(.medium)
                                    .foregroundColor(getTypeColor())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(getTypeColor().opacity(0.15))
                                    .cornerRadius(8)
                            }

                            // 展開/收起圖示
                            if !isToday {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(AppFont.bodySmall())
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 訓練內容區域（只在展開或今日時顯示）
                if isExpanded || isToday {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        // 訓練目標描述
                        if let desc = day.trainingDetails?.description, !desc.isEmpty {
                            Text(desc)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(day.dayTarget)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 訓練詳情
                        if let details = day.trainingDetails {
                            TrainingDetailsViewV2(day: day, details: details)
                        }

                        // 已完成的訓練記錄
                        if !workouts.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("已完成訓練")
                                    .font(AppFont.captionSmall())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                    .padding(.bottom, 2)

                                ForEach(workouts.prefix(2), id: \.id) { workout in
                                    Button {
                                        onWorkoutSelect(workout)
                                    } label: {
                                        HStack {
                                            Image(systemName: "figure.run")
                                                .foregroundColor(.green)
                                                .font(AppFont.captionSmall())

                                            Text(String(format: "%.2f km", (workout.distance ?? 0.0) / 1000.0))
                                                .font(AppFont.caption())
                                                .foregroundColor(.primary)

                                            Text("·")
                                                .foregroundColor(.secondary)

                                            Text(formatDuration(workout.duration))
                                                .font(AppFont.caption())
                                                .foregroundColor(.secondary)

                                            Spacer()
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                if workouts.count > 2 {
                                    Text("+ \(workouts.count - 2) \(NSLocalizedString("training.more_workouts", comment: "more"))")
                                        .font(AppFont.captionSmall())
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                // 折疊時也顯示已完成訓練
                if !isExpanded && !isToday && !workouts.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                            .padding(.vertical, 4)

                        ForEach(workouts.prefix(2), id: \.id) { workout in
                            Button {
                                onWorkoutSelect(workout)
                            } label: {
                                HStack {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(.green)
                                        .font(AppFont.captionSmall())

                                    Text(String(format: "%.2f km", (workout.distance ?? 0.0) / 1000.0))
                                        .font(AppFont.caption())
                                        .foregroundColor(.primary)

                                    Text("·")
                                        .foregroundColor(.secondary)

                                    Text(formatDuration(workout.duration))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if workouts.count > 2 {
                            Text("+ \(workouts.count - 2) \(NSLocalizedString("training.more_workouts", comment: "more"))")
                                .font(AppFont.captionSmall())
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(getCardBackgroundColor(isToday: isToday, isCompleted: isCompleted))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(getCardBorderColor(isToday: isToday, isCompleted: isCompleted, isPast: isPast), lineWidth: isToday ? 1.5 : 1.0)
            )
            .shadow(
                color: getShadowColor(isToday: isToday, isCompleted: isCompleted),
                radius: isToday ? 8 : 3,
                x: 0,
                y: isToday ? 4 : 1
            )
        }
        .sheet(isPresented: $showTrainingTypeInfo) {
            if let trainingTypeInfo = TrainingTypeInfo.info(for: day.type) {
                TrainingTypeInfoView(trainingTypeInfo: trainingTypeInfo)
            }
        }
    }

    // MARK: - Helper Functions

    private func getStatusColor(isCompleted: Bool, isToday: Bool, isPast: Bool) -> Color {
        if isCompleted {
            return .mint
        } else if isToday {
            return .blue
        } else if isPast {
            return .gray
        } else {
            return .orange
        }
    }

    private func getTypeColor() -> Color {
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .mint
        case .interval, .tempo, .progression, .threshold, .combination, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
            return .orange
        case .longRun, .hiking, .cycling, .fastFinish:
            return .blue
        case .race, .racePace:
            return .red
        case .rest:
            return .gray
        case .crossTraining, .strength, .fartlek:
            return .purple
        }
    }

    private func getCardBackgroundColor(isToday: Bool, isCompleted: Bool) -> Color {
        if isToday {
            return colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.08)
        } else {
            return Color(.secondarySystemGroupedBackground)
        }
    }

    private func getCardBorderColor(isToday: Bool, isCompleted: Bool, isPast: Bool) -> Color {
        if isToday {
            return colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2)
        } else if !isCompleted && !isPast {
            return Color.orange.opacity(0.3)
        } else {
            return Color.clear
        }
    }

    private func getShadowColor(isToday: Bool, isCompleted: Bool) -> Color {
        if isToday {
            return Color.blue.opacity(0.2)
        } else if isCompleted {
            return Color.green.opacity(0.15)
        } else {
            return Color.black.opacity(0.05)
        }
    }

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

/// 訓練詳情視圖
private struct TrainingDetailsViewV2: View {
    let day: DayDetail
    let details: TrainingDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ✨ 暖身段（V2 新功能）
            if let warmup = details.warmup {
                WarmupCooldownView(
                    segment: warmup,
                    type: .warmup
                )
            }

            // 主訓練詳情
            HStack(spacing: 6) {
                // 距離
                if let distance = details.distanceKm {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.run")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.white)
                        Text(String(format: "%.1fkm", distance))
                            .font(AppFont.caption())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .cornerRadius(4)
                } else if let totalDistance = details.totalDistanceKm {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.run")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.white)
                        Text(String(format: "%.1fkm", totalDistance))
                            .font(AppFont.caption())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .cornerRadius(4)
                }

                // 配速（根據訓練類型決定是否顯示）
                if let pace = details.pace, !shouldHidePace() {
                    HStack(spacing: 2) {
                        Image(systemName: "speedometer")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.white)
                        Text(pace)
                            .font(AppFont.caption())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .cornerRadius(4)
                }

                // 心率區間
                if let hr = details.heartRateRange, let displayText = hr.displayText {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.white)
                        Text(displayText)
                            .font(AppFont.caption())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .cornerRadius(4)
                }

                Spacer()
            }

            // ✨ 力量訓練動作清單（V2 新功能）
            if let exercises = details.exercises, !exercises.isEmpty {
                ExercisesListView(exercises: exercises)
            }

            // ✨ 緩和段（V2 新功能）
            if let cooldown = details.cooldown {
                WarmupCooldownView(
                    segment: cooldown,
                    type: .cooldown
                )
            }

            // ✨ 補充訓練（V2 新功能）
            if let supplementary = details.supplementary, !supplementary.isEmpty {
                SupplementaryTrainingView(activities: supplementary)
            }
        }
        .padding(.top, 4)
    }

    private func shouldHidePace() -> Bool {
        return day.type == .easyRun || day.type == .easy || day.type == .recovery_run || day.type == .lsd
    }
}
