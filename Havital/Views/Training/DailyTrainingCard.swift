import SwiftUI
import HealthKit

struct DailyTrainingCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    let day: TrainingDay
    let isToday: Bool
    
    // 使用可選的WorkoutV2作為sheet的item
    @State private var selectedWorkout: WorkoutV2?
    @State private var isLoadingData = false
    
    var body: some View {
        let isExpanded = isToday || viewModel.expandedDayIndices.contains(day.dayIndexInt)
        
        VStack(alignment: .leading, spacing: 12) {
            // 點擊整個日期行可切換展開/摺疊狀態
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if viewModel.expandedDayIndices.contains(day.dayIndexInt) {
                        _ = viewModel.expandedDayIndices.remove(day.dayIndexInt)
                    } else {
                        _ = viewModel.expandedDayIndices.insert(day.dayIndexInt)
                    }
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(viewModel.weekdayName(for: day.dayIndexInt))
                                .font(.headline)
                            // 添加具體日期顯示
                            if let date = viewModel.getDateForDay(dayIndex: day.dayIndexInt) {
                                Text(viewModel.formatShortDate(date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if isToday {
                                Text("今天")
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
                    
                    // 訓練類型標籤 - 使用 DayType.chineseName
                    Text(day.type.chineseName)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor({
                        switch day.type {
                        case .easyRun, .easy, .recovery_run, .yoga: return Color.green
                        case .interval, .tempo: return Color.orange
                        case .longRun, .hiking, .cycling: return Color.blue
                        case .race: return Color.red
                        case .rest: return Color.gray
                        case .crossTraining, .strength: return Color.purple
                        case .lsd: return Color.green
                        case .progression, .threshold: return Color.orange
                        }
                    }())
                    .background({
                        switch day.type {
                        case .easyRun, .easy, .recovery_run, .yoga: return Color.green.opacity(0.2)
                        case .interval, .tempo: return Color.orange.opacity(0.2)
                        case .longRun, .hiking, .cycling: return Color.blue.opacity(0.2)
                        case .race: return Color.red.opacity(0.2)
                        case .rest: return Color.gray.opacity(0.2)
                        case .crossTraining, .strength: return Color.purple.opacity(0.2)
                        case .lsd: return Color.green.opacity(0.2)
                        case .progression, .threshold: return Color.orange.opacity(0.2)
                        }
                    }())
                    .cornerRadius(8)
                    
                    // 展開/摺疊指示器
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 顯示該天的訓練記錄（使用 V2 數據）
            if let workouts = viewModel.workoutsByDayV2[day.dayIndexInt], !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !isExpanded {
                        Divider()
                            .padding(.vertical, 2)
                    }
                    
                    if isExpanded {
                        ForEach(workouts, id: \.id) { workout in
                            Button {
                                selectedWorkout = workout
                            } label: {
                                WorkoutV2SummaryRow(workout: workout, viewModel: viewModel)
                                    .overlay(
                                        Group {
                                            if isLoadingData && selectedWorkout?.id == workout.id {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                    .background(Color.black.opacity(0.1))
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isLoadingData)
                        }
                    } else {
                        // 摺疊時保持原來的樣式，但還是可以點擊
                        Button {
                            if workouts.count == 1 {
                                // 如果只有一個訓練記錄，直接顯示詳情
                                selectedWorkout = workouts[0]
                            } else {
                                // 如果有多個訓練記錄，展開卡片
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    _ = viewModel.expandedDayIndices.insert(day.dayIndexInt)
                                }
                            }
                        } label: {
                            CollapsedWorkoutV2Summary(workouts: workouts, viewModel: viewModel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoadingData)
                    }
                }
            }
            
            // 條件性顯示額外的訓練詳情內容（只在展開時顯示）
            if isExpanded {
                // 完整顯示
                VStack(alignment: .leading, spacing: 12) {
                    // 分隔線
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text(day.dayTarget)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if day.isTrainingDay {
                        // 對於無trainingItems的非間歇課表，顯示trainingDetails詳情
                        if day.trainingItems == nil, let details = day.trainingDetails {
                            // 若定義了 segments，顯示各段落
                            if let segments = details.segments, !segments.isEmpty, let total = details.totalDistanceKm {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(day.type.chineseName)
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
                                            Text("區段 \(idx + 1)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(8)
                                            Spacer()
                                            Text(String(format: "%.1fkm", seg.distanceKm))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(8)
                                            Text(seg.pace)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            } else {
                                // 單一描述 + 心率 + 距離
                                if let desc = details.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.vertical, 4)
                                }
                                if let hr = details.heartRateRange {
                                    Text("心率區間：\(hr.min)-\(hr.max)")
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
                            }
                        }
                        
                        // For interval or progression training, show a special header
                        if let trainingItems = day.trainingItems, !trainingItems.isEmpty {
                            if (day.type == .progression || day.type == .threshold), let segments = day.trainingDetails?.segments {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(day.type.chineseName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        Spacer()
                                        if let total = day.trainingDetails?.totalDistanceKm {
                                            Text(String(format: "%.1fkm", total))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding(.top, 4)
                                    Divider()
                                        .background(Color.orange.opacity(0.3))
                                        .padding(.vertical, 2)
                                    ForEach(segments.indices, id: \.self) { idx in
                                        let seg = segments[idx]
                                        HStack(spacing: 8) {
                                            Text("區段 \(idx + 1)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(8)
                                            Spacer()
                                            Text(String(format: "%.1fkm", seg.distanceKm))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.1))
                                                .cornerRadius(8)
                                            Text(seg.pace)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            } else if day.type == .interval, let repeats = trainingItems[0].goals.times {
                                HStack {
                                    Text("間歇訓練")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text("\(repeats) × 重複")
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
                            
                            // Show each training item
                            ForEach(trainingItems) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    // 標題及重複次數
                                    HStack {
                                        if day.type == .interval, let times = item.goals.times {
                                            Text("× \(times)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                        
                                        if let pace = item.goals.pace {
                                            Text(pace)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(day.type == .interval ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                                                .cornerRadius(12)
                                        }
                                        
                                        if let hr = item.goals.heartRateRange {
                                            Text("心率區間： \(hr.min)-\(hr.max)")
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
                                                .background(day.type == .interval ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                                                .cornerRadius(12)
                                        }
                                        Spacer()
                                    }
                                    // 度量指標pills
                                    HStack(spacing: 2) {}
                                        
                                    // 說明文字
                                    Text(item.runDetails)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // 提示（所有訓練日均顯示）
                        if let tips = day.tips {
                            Text("提示：\(tips)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                    }
                }
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
                         ? Color(UIColor.systemBlue).opacity(0.2)
                         : Color(UIColor.systemBlue).opacity(0.1))
                      : Color(UIColor.tertiarySystemBackground))
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
