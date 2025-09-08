import SwiftUI
import HealthKit

// MARK: - Supporting Views
struct DayHeaderView: View {
    let day: TrainingDay
    let isToday: Bool
    let isExpanded: Bool
    let viewModel: TrainingPlanViewModel
    let onToggle: () -> Void
    
    private func getTypeColor() -> Color {
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return Color.green
        case .interval, .tempo, .progression, .threshold, .combination:
            return Color.orange
        case .longRun, .hiking, .cycling:
            return Color.blue
        case .race:
            return Color.red
        case .rest:
            return Color.gray
        case .crossTraining, .strength:
            return Color.purple
        }
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(viewModel.weekdayName(for: day.dayIndexInt))
                            .font(.headline)
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
                }
                
                Spacer()
                
                Text(day.type.localizedName)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(getTypeColor())
                    .background(getTypeColor().opacity(0.2))
                    .cornerRadius(8)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.leading, 4)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkoutListView: View {
    let workouts: [WorkoutV2]
    let day: TrainingDay
    let isExpanded: Bool
    let viewModel: TrainingPlanViewModel
    let onWorkoutSelect: (WorkoutV2) -> Void
    let onExpandToggle: () -> Void
    let isLoadingData: Bool
    let selectedWorkout: WorkoutV2?
    
    private var loadingOverlay: some View {
        ProgressView()
            .scaleEffect(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !isExpanded {
                Divider()
                    .padding(.vertical, 2)
            }
            
            if isExpanded {
                ForEach(workouts, id: \.id) { workout in
                    Button {
                        onWorkoutSelect(workout)
                    } label: {
                        let isSelected = selectedWorkout?.id == workout.id
                        let showLoading = isLoadingData && isSelected
                        
                        WorkoutV2SummaryRow(workout: workout, viewModel: viewModel, trainingType: day.type)
                            .overlay(
                                Group {
                                    if showLoading {
                                        loadingOverlay
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoadingData)
                }
            } else {
                Button {
                    if workouts.count == 1 {
                        onWorkoutSelect(workouts[0])
                    } else {
                        onExpandToggle()
                    }
                } label: {
                    CollapsedWorkoutV2Summary(workouts: workouts, viewModel: viewModel, trainingType: day.type)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoadingData)
            }
        }
    }
}

struct TrainingDetailsView: View {
    let day: TrainingDay
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.vertical, 4)
            
            Text(day.dayTarget)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            if day.isTrainingDay {
                if day.trainingItems == nil, let details = day.trainingDetails {
                    TrainingDetailsContentView(day: day, details: details)
                }
                
                if let trainingItems = day.trainingItems, !trainingItems.isEmpty {
                    TrainingItemsView(day: day, trainingItems: trainingItems)
                }
                
                if let tips = day.tips {
                    Text(String(format: NSLocalizedString("training_plan.tip", comment: "Tip: %@"), tips))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
            }
        }
    }
}

struct TrainingDetailsContentView: View {
    let day: TrainingDay
    let details: TrainingDetails
    
    var body: some View {
        if let segments = details.segments, !segments.isEmpty, let total = details.totalDistanceKm {
            SegmentedTrainingView(day: day, segments: segments, total: total)
        } else {
            SimpleTrainingView(day: day, details: details)
        }
    }
}

struct SegmentedTrainingView: View {
    let day: TrainingDay
    let segments: [ProgressionSegment]
    let total: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.type.localizedName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "%.1fkm", total))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
            }
            .padding(.top, 4)
            
            Divider()
                .background(Color.orange.opacity(0.3))
                .padding(.vertical, 2)
            
            ForEach(segments.indices, id: \.self) { idx in
                let seg = segments[idx]
                HStack(spacing: 8) {
                    Text(String(format: NSLocalizedString("training_plan.segment", comment: "Segment %d"), idx + 1))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    Spacer()
                    if let distance = seg.distanceKm {
                        Text(String(format: "%.1fkm", distance))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    if let pace = seg.pace {
                        Text(pace)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct SimpleTrainingView: View {
    let day: TrainingDay
    let details: TrainingDetails
    
    // 檢查是否應該隱藏配速資訊
    private var shouldHidePace: Bool {
        return day.type == .easyRun ||
               day.type == .easy ||
               day.type == .recovery_run ||
               day.type == .lsd
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let desc = details.description {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }
            HStack(spacing: 8) {
                // 只在非輕鬆跑/恢復跑時顯示配速
                if let pace = details.pace, !shouldHidePace {
                    Text(pace)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                }
                
                if let hr = details.heartRateRange, let displayText = hr.displayText {
                    Text(String(format: NSLocalizedString("training_plan.heart_rate_zone", comment: "Heart Rate Zone: %@"), displayText))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                }
                if let distance = details.distanceKm {
                    Text(String(format: "%.1fkm", distance))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(day.type == .interval ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                        .cornerRadius(12)
                }
                Spacer()
            }
        }
    }
}

struct TrainingItemsView: View {
    let day: TrainingDay
    let trainingItems: [WeeklyTrainingItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if (day.type == .progression || day.type == .threshold), let segments = day.trainingDetails?.segments {
                SegmentedTrainingView(day: day, segments: segments, total: day.trainingDetails?.totalDistanceKm ?? 0)
            } else if day.type == .interval, !trainingItems.isEmpty, let repeats = trainingItems[0].goals.times {
                IntervalTrainingHeaderView(repeats: repeats)
            }
            
            if day.type == .interval {
                IntervalTrainingItemsView(trainingItems: trainingItems)
            } else {
                RegularTrainingItemsView(trainingItems: trainingItems, day: day)
            }
        }
    }
}

struct IntervalTrainingHeaderView: View {
    let repeats: Int
    
    var body: some View {
        HStack {
            Text(NSLocalizedString("training_plan.interval_training", comment: "Interval Training"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            Spacer()
            Text(String(format: NSLocalizedString("training_plan.repeats", comment: "%d × Repeats"), repeats))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(12)
        }
        .padding(.top, 4)
    }
}

struct IntervalTrainingItemsView: View {
    let trainingItems: [WeeklyTrainingItem]
    
    var body: some View {
        ForEach(Array(stride(from: 0, to: trainingItems.count, by: 2)), id: \.self) { index in
            VStack(alignment: .leading, spacing: 4) {
                let sprintItem = trainingItems[index]
                let recoveryItem = index + 1 < trainingItems.count ? trainingItems[index + 1] : nil
                
                IntervalSegmentRow(title: NSLocalizedString("training_plan.sprint_segment", comment: "Sprint Segment"), item: sprintItem)
                
                if let recoveryItem = recoveryItem {
                    IntervalSegmentRow(title: NSLocalizedString("training_plan.recovery_segment", comment: "Recovery Segment"), item: recoveryItem)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

struct IntervalSegmentRow: View {
    let title: String
    let item: WeeklyTrainingItem
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            if let times = item.goals.times {
                Text("× \(times)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            // 如果是恢復段且沒有配速和距離，顯示"原地休息"
            if title == NSLocalizedString("training_plan.recovery_segment", comment: "Recovery Segment") && item.goals.pace == nil && item.goals.distanceKm == nil {
                Text(NSLocalizedString("training_plan.rest_in_place", comment: "Rest in place"))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
            } else {
                if let pace = item.goals.pace {
                    Text(pace)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                }
                
                if let distance = item.goals.distanceKm {
                    Text(String(format: "%.1fkm", distance))
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
    }
}

struct RegularTrainingItemsView: View {
    let trainingItems: [WeeklyTrainingItem]
    let day: TrainingDay
    
    // 檢查是否應該隱藏配速資訊
    private func shouldHidePace(for item: WeeklyTrainingItem) -> Bool {
        let itemName = item.name.lowercased()
        let easyRunName = L10n.Training.TrainingType.easy.localized.lowercased()
        let recoveryRunName = L10n.Training.TrainingType.recovery.localized.lowercased()
        let lsdRunName = L10n.Training.TrainingType.lsd.localized.lowercased()
        return itemName.contains(easyRunName) ||
               itemName.contains(recoveryRunName) ||
               itemName.contains(lsdRunName) ||
               day.type == .easyRun ||
               day.type == .easy ||
               day.type == .recovery_run ||
               day.type == .lsd
    }
    
    var body: some View {
        ForEach(trainingItems) { item in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // 只在非輕鬆跑/恢復跑時顯示配速
                    if let pace = item.goals.pace, !shouldHidePace(for: item) {
                        Text(pace)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                    }
                    
                    if let hr = item.goals.heartRateRange, let displayText = hr.displayText {
                        Text(String(format: NSLocalizedString("training_plan.heart_rate_zone", comment: "Heart Rate Zone: %@"), displayText))
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                    }
                    if let distance = item.goals.distanceKm {
                        Text(String(format: "%.1fkm", distance))
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                    }
                    Spacer()
                }
                
                Text(item.runDetails)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
    }
}

struct DailyTrainingCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let day: TrainingDay
    let isToday: Bool
    
    // 使用可選的WorkoutV2作為sheet的item
    @State private var selectedWorkout: WorkoutV2?
    @State private var isLoadingData = false
    
    private func getTypeColor() -> Color {
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return Color.green
        case .interval, .tempo, .progression, .threshold, .combination:
            return Color.orange
        case .longRun, .hiking, .cycling:
            return Color.blue
        case .race:
            return Color.red
        case .rest:
            return Color.gray
        case .crossTraining, .strength:
            return Color.purple
        }
    }
    
    var body: some View {
        let isExpanded = isToday || viewModel.expandedDayIndices.contains(day.dayIndexInt)
        
        VStack(alignment: .leading, spacing: 12) {
            // Use the new DayHeaderView
            DayHeaderView(
                day: day,
                isToday: isToday,
                isExpanded: isExpanded,
                viewModel: viewModel,
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if viewModel.expandedDayIndices.contains(day.dayIndexInt) {
                            _ = viewModel.expandedDayIndices.remove(day.dayIndexInt)
                        } else {
                            _ = viewModel.expandedDayIndices.insert(day.dayIndexInt)
                        }
                    }
                }
            )
            
            // 顯示該天的訓練記錄（使用 V2 數據）
            if let workouts = viewModel.workoutsByDayV2[day.dayIndexInt], !workouts.isEmpty {
                WorkoutListView(
                    workouts: workouts,
                    day: day,
                    isExpanded: isExpanded,
                    viewModel: viewModel,
                    onWorkoutSelect: { workout in
                        selectedWorkout = workout
                    },
                    onExpandToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = viewModel.expandedDayIndices.insert(day.dayIndexInt)
                        }
                    },
                    isLoadingData: isLoadingData,
                    selectedWorkout: selectedWorkout
                )
            }
            
            // 條件性顯示額外的訓練詳情內容（只在展開時顯示）
            if isExpanded {
                TrainingDetailsView(day: day)
            } else if viewModel.workoutsByDayV2[day.dayIndexInt] == nil || viewModel.workoutsByDayV2[day.dayIndexInt]?.isEmpty == true {
                // 摺疊時只顯示簡短的訓練目標摘要（當天無訓練記錄時）
                Divider()
                    .padding(.vertical, 2)
                
                Text(day.dayTarget)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday
                      ? (colorScheme == .dark
                         ? Color.blue.opacity(0.2)
                         : Color.blue.opacity(0.1))
                      : Color(.tertiarySystemBackground))
        )
        // 使用 WorkoutDetailViewV2 顯示 WorkoutV2 數據
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailViewV2(workout: workout)
            }
        }
    }

    
    // 格式化時間為簡短格式（只顯示時:分）
    private func formatShortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // 格式化距離（公里或米）
    private func formatDistance(_ distanceInMeters: Double) -> String {
        if distanceInMeters >= 1000 {
            return String(format: "%.2f km", distanceInMeters / 1000)
        } else {
            return String(format: "%.0f m", distanceInMeters)
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
