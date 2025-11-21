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
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
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
            .background(
                // 在整個列表背景繪製完整的垂直連接線
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .offset(x: 7)  // 對齊到左側時間軸中心位置
                }
            )
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
    @State private var showTrainingTypeInfo = false

    var body: some View {
        // 在 body 內部計算這些值
        let isToday = viewModel.isToday(dayIndex: day.dayIndexInt, planWeek: planWeek)
        let workouts = viewModel.workoutsByDayV2[day.dayIndexInt] ?? []
        let isCompleted = !workouts.isEmpty
        // 簡單判斷：如果不是今天且沒有訓練記錄，認為是未來或過去
        let isPast = !isToday && day.dayIndexInt < Calendar.current.component(.weekday, from: Date()) - 1

        HStack(alignment: .top, spacing: 12) {
            // 左側時間軸狀態點（只有圓點，連接線在外層背景繪製）
            ZStack {
                Circle()
                    .fill(getStatusColor(isCompleted: isCompleted, isToday: isToday, isPast: isPast))
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
            .frame(width: 16, height: 16)

            // 右側內容卡片
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    if !isToday {  // 今日訓練不在這裡展開
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
                                }
                            }

                            Spacer()

                            // 訓練類型標籤（右上角）
                            if let trainingTypeInfo = TrainingTypeInfo.info(for: day.type) {
                                Button(action: {
                                    showTrainingTypeInfo = true
                                }) {
                                    Text(day.type.localizedName)
                                        .font(.subheadline)
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
                                    .font(.subheadline)
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
                                    .font(.system(size: 14))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }

                        // 第二行：距離
                        if let distance = day.trainingDetails?.totalDistanceKm {
                            Text(String(format: "%.1f km", distance))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 訓練內容區域（只在展開或今日時顯示）
                if isExpanded || isToday {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        // 課表區域
                        VStack(alignment: .leading, spacing: 8) {
                            // 訓練目標
                            Text(day.dayTarget)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            // 顯示間歇訓練的 trainingItems 詳情
                            if day.type == .interval, let trainingItems = day.trainingItems, !trainingItems.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let repeats = trainingItems[0].goals.times {
                                        HStack {
                                            Text("間歇訓練")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                            Spacer()
                                            Text("\(repeats) × 組")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                        }
                                    }

                                    ForEach(Array(stride(from: 0, to: trainingItems.count, by: 2)), id: \.self) { index in
                                        let sprintItem = trainingItems[index]
                                        let recoveryItem = index + 1 < trainingItems.count ? trainingItems[index + 1] : nil

                                        VStack(alignment: .leading, spacing: 4) {
                                            // 衝刺段
                                            HStack(spacing: 6) {
                                                Text("衝刺段")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.orange)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.orange.opacity(0.15))
                                                    .cornerRadius(4)

                                                if let pace = sprintItem.goals.pace {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "speedometer")
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.blue)
                                                        Text(pace)
                                                            .font(.system(size: 10, weight: .medium))
                                                            .foregroundColor(.blue)
                                                    }
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 3)
                                                    .background(Color.blue.opacity(0.15))
                                                    .cornerRadius(4)
                                                }

                                                if let distance = sprintItem.goals.distanceKm {
                                                    Text(String(format: "%.1fkm", distance))
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 3)
                                                        .background(Color.purple.opacity(0.8))
                                                        .cornerRadius(4)
                                                }

                                                Spacer()
                                            }

                                            // 恢復段
                                            if let recoveryItem = recoveryItem {
                                                HStack(spacing: 6) {
                                                    Text("恢復段")
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Color.green.opacity(0.15))
                                                        .cornerRadius(4)

                                                    if recoveryItem.goals.pace == nil && recoveryItem.goals.distanceKm == nil {
                                                        Text("原地休息")
                                                            .font(.system(size: 10, weight: .medium))
                                                            .foregroundColor(.secondary)
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 3)
                                                            .background(Color.gray.opacity(0.15))
                                                            .cornerRadius(4)
                                                    } else {
                                                        if let pace = recoveryItem.goals.pace {
                                                            HStack(spacing: 2) {
                                                                Image(systemName: "speedometer")
                                                                    .font(.system(size: 8))
                                                                    .foregroundColor(.blue)
                                                                Text(pace)
                                                                    .font(.system(size: 10, weight: .medium))
                                                                    .foregroundColor(.blue)
                                                            }
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 3)
                                                            .background(Color.blue.opacity(0.15))
                                                            .cornerRadius(4)
                                                        }

                                                        if let distance = recoveryItem.goals.distanceKm {
                                                            Text(String(format: "%.1fkm", distance))
                                                                .font(.system(size: 10, weight: .medium))
                                                                .foregroundColor(.white)
                                                                .padding(.horizontal, 5)
                                                                .padding(.vertical, 3)
                                                                .background(Color.purple.opacity(0.8))
                                                                .cornerRadius(4)
                                                        }
                                                    }

                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            } else if let details = day.trainingDetails, let segments = details.segments, !segments.isEmpty {
                                // 顯示分段訓練詳情（針對組合跑、漸進跑等）
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                                        // 檢查是否應該隱藏配速
                                        let shouldHidePace = shouldHidePaceForSegment(segment)

                                        HStack(spacing: 6) {
                                            // 段落標籤
                                            Text("第\(index + 1)段")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(4)

                                            // 配速（根據訓練類型決定是否顯示）
                                            if let pace = segment.pace, !shouldHidePace {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "speedometer")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.blue)
                                                    Text(pace)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(.blue)
                                                }
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 3)
                                                .background(Color.blue.opacity(0.15))
                                                .cornerRadius(4)
                                            }

                                            // 距離
                                            if let distance = segment.distanceKm {
                                                Text(String(format: "%.1fkm", distance))
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 3)
                                                    .background(Color.purple.opacity(0.8))
                                                    .cornerRadius(4)
                                            }

                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            } else if let details = day.trainingDetails {
                                // 顯示非分段訓練的基本信息（輕鬆跑等）
                                HStack(spacing: 6) {
                                    // 距離
                                    if let distance = details.distanceKm {
                                        HStack(spacing: 2) {
                                            Image(systemName: "figure.run")
                                                .font(.system(size: 8))
                                                .foregroundColor(.blue)
                                            Text(String(format: "%.1fkm", distance))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.15))
                                        .cornerRadius(4)
                                    }

                                    // 配速（根據訓練類型決定是否顯示）
                                    if let pace = details.pace, !shouldHidePaceForTrainingType() {
                                        HStack(spacing: 2) {
                                            Image(systemName: "speedometer")
                                                .font(.system(size: 8))
                                                .foregroundColor(.orange)
                                            Text(pace)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(4)
                                    }

                                    // 心率區間
                                    if let hr = details.heartRateRange, let displayText = hr.displayText {
                                        HStack(spacing: 2) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(.red)
                                            Text(displayText)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.red)
                                        }
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.15))
                                        .cornerRadius(4)
                                    }

                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                        }

                        // 已完成的訓練記錄（展開時添加視覺分隔）
                        if !workouts.isEmpty {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("已完成訓練")
                                    .font(.caption2)
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
                                        .padding(.vertical, 2)
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

                // 折疊時也顯示已完成訓練（不顯示標題和分隔線）
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(getCardBackgroundColor(isToday: isToday, isCompleted: isCompleted, isPast: isPast))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(getCardBorderColor(isToday: isToday, isCompleted: isCompleted, isPast: isPast), lineWidth: getCardBorderWidth(isToday: isToday, isCompleted: isCompleted))
            )
            .shadow(
                color: getShadowColor(isToday: isToday, isCompleted: isCompleted),
                radius: getShadowRadius(isToday: isToday, isCompleted: isCompleted),
                x: 0,
                y: getShadowY(isToday: isToday, isCompleted: isCompleted)
            )
        }
        .sheet(isPresented: $showTrainingTypeInfo) {
            if let trainingTypeInfo = TrainingTypeInfo.info(for: day.type) {
                TrainingTypeInfoView(trainingTypeInfo: trainingTypeInfo)
            }
        }
    }

    // 獲取卡片背景色
    private func getCardBackgroundColor(isToday: Bool, isCompleted: Bool, isPast: Bool) -> Color {
        if isToday {
            return Color.blue.opacity(0.2)  // 當日：更顯眼的藍色
        } else {
            return Color(UIColor.systemBackground)  // 其他：使用 systemBackground 提升對比度（在 Light Mode 為白色）
        }
    }

    // 獲取卡片邊框顏色
    private func getCardBorderColor(isToday: Bool, isCompleted: Bool, isPast: Bool) -> Color {
        if isToday {
            return Color.blue.opacity(0.3)  // 當日：藍色邊框
        } else if !isCompleted && !isPast {
            return Color.orange.opacity(0.3)  // 未來未完成：橙色邊框
        } else {
            return Color.clear  // 其他：無邊框
        }
    }

    // 獲取卡片邊框寬度
    private func getCardBorderWidth(isToday: Bool, isCompleted: Bool) -> CGFloat {
        if isToday {
            return 1.5  // 當日：較粗邊框
        } else if !isCompleted {
            return 1.0  // 未完成：細邊框
        } else {
            return 0  // 已完成：無邊框
        }
    }

    // 獲取陰影顏色
    private func getShadowColor(isToday: Bool, isCompleted: Bool) -> Color {
        if isToday {
            return Color.blue.opacity(0.2)  // 當日：藍色陰影
        } else if isCompleted {
            return Color.green.opacity(0.15)  // 已完成：綠色陰影
        } else {
            return Color.black.opacity(0.05)  // 其他：淡黑色陰影
        }
    }

    // 獲取陰影半徑
    private func getShadowRadius(isToday: Bool, isCompleted: Bool) -> CGFloat {
        if isToday {
            return 8  // 當日：較大陰影
        } else if isCompleted {
            return 5  // 已完成：中等陰影
        } else {
            return 3  // 其他：小陰影
        }
    }

    // 獲取陰影 Y 偏移
    private func getShadowY(isToday: Bool, isCompleted: Bool) -> CGFloat {
        if isToday {
            return 4  // 當日：較大偏移
        } else if isCompleted {
            return 2  // 已完成：中等偏移
        } else {
            return 1  // 其他：小偏移
        }
    }

    // 獲取狀態顏色
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

    // 獲取訓練類型顏色
    private func getTypeColor() -> Color {
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .mint
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

    // 檢查分段是否應該隱藏配速
    private func shouldHidePaceForSegment(_ segment: ProgressionSegment) -> Bool {
        guard let description = segment.description else { return false }
        let desc = description.lowercased()
        return desc.contains("輕鬆") || desc.contains("恢復") || desc.contains("easy") || desc.contains("recovery") || desc.contains("lsd")
    }

    // 檢查訓練類型是否應該隱藏配速
    private func shouldHidePaceForTrainingType() -> Bool {
        return day.type == .easyRun || day.type == .easy || day.type == .recovery_run || day.type == .lsd
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
