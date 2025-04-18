import SwiftUI
import HealthKit

struct DailyTrainingCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var healthKitManager: HealthKitManager
    let day: TrainingDay
    let isToday: Bool
    
    // 使用可選的HKWorkout作為sheet的item
    @State private var selectedWorkout: HKWorkout?
    @State private var heartRateData: [(Date, Double)] = []
    @State private var paceData: [(Date, Double)] = []
    @State private var isLoadingData = false
    
    var body: some View {
        let isExpanded = isToday || viewModel.expandedDayIndices.contains(day.dayIndex)
        
        VStack(alignment: .leading, spacing: 12) {
            // 點擊整個日期行可切換展開/摺疊狀態
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if viewModel.expandedDayIndices.contains(day.dayIndex) {
                        _ = viewModel.expandedDayIndices.remove(day.dayIndex)
                    } else {
                        _ = viewModel.expandedDayIndices.insert(day.dayIndex)
                    }
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(viewModel.weekdayName(for: day.dayIndex))
                                .font(.headline)
                            // 添加具體日期顯示
                            if let date = viewModel.getDateForDay(dayIndex: day.dayIndex) {
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
                    
                    // 訓練類型標籤 - 確保休息日也顯示標籤
                    Text({
                        switch day.type {
                        case .easyRun, .easy: return "輕鬆"
                        case .interval: return "間歇"
                        case .tempo: return "節奏"
                        case .longRun: return "長跑"
                        case .race: return "比賽"
                        case .rest: return "休息"
                        case .crossTraining: return "交叉訓練"
                        }
                    }())
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor({
                        switch day.type {
                        case .easyRun, .easy: return Color.green
                        case .interval, .tempo: return Color.orange
                        case .longRun: return Color.blue
                        case .race: return Color.red
                        case .rest: return Color.gray
                        case .crossTraining: return Color.purple
                        }
                    }())
                    .background({
                        switch day.type {
                        case .easyRun, .easy: return Color.green.opacity(0.2)
                        case .interval, .tempo: return Color.orange.opacity(0.2)
                        case .longRun: return Color.blue.opacity(0.2)
                        case .race: return Color.red.opacity(0.2)
                        case .rest: return Color.gray.opacity(0.2)
                        case .crossTraining: return Color.purple.opacity(0.2)
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
            
            // 顯示該天的訓練記錄
            if let workouts = viewModel.workoutsByDay[day.dayIndex], !workouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !isExpanded {
                        Divider()
                            .padding(.vertical, 2)
                    }
                    
                    if isExpanded {
                        ForEach(workouts, id: \.uuid) { workout in
                            Button {
                                loadWorkoutData(workout)
                            } label: {
                                WorkoutSummaryRow(workout: workout, viewModel: viewModel)
                                    .overlay(
                                        Group {
                                            if isLoadingData && selectedWorkout?.uuid == workout.uuid {
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
                                loadWorkoutData(workouts[0])
                            } else {
                                // 如果有多個訓練記錄，展開卡片
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    _ = viewModel.expandedDayIndices.insert(day.dayIndex)
                                }
                            }
                        } label: {
                            CollapsedWorkoutSummary(workouts: workouts, viewModel: viewModel)
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
                    
                    if day.isTrainingDay, let trainingItems = day.trainingItems {
                        // For interval training, show a special header with repeats info
                        if day.type == .interval, trainingItems.count > 0, let repeats = trainingItems[0].goals.times {
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
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(day.type == .interval ? .medium : .regular)
                                        .foregroundColor(day.type == .interval ? .orange : .blue)
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
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // 顯示提示
                        if let tips = day.tips {
                            Text("提示：\(tips)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                    }
                }
            } else if viewModel.workoutsByDay[day.dayIndex] == nil || viewModel.workoutsByDay[day.dayIndex]?.isEmpty == true {
                // 摺疊時只顯示簡短的訓練目標摘要（當天無訓練記錄時）
                Divider()
                    .padding(.vertical, 2)
                
                Text(day.dayTarget)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
        // 使用item參數而不是isPresented
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailView(
                    workout: workout,
                    healthKitManager: healthKitManager,
                    initialHeartRateData: heartRateData,
                    initialPaceData: paceData
                )
            }
        }
    }
    
    // 抽取數據加載邏輯到獨立函數
    private func loadWorkoutData(_ workout: HKWorkout) {
        // 先設置選中的訓練記錄為nil，避免使用舊的數據
        selectedWorkout = nil
        isLoadingData = true
        
        // 清空舊數據
        heartRateData = []
        paceData = []
        
        print("正在加載訓練記錄數據: \(workout.uuid)")
        
        Task {
            // 並行獲取心率和配速數據
            async let heartRateTask = loadHeartRateData(workout)
            async let paceTask = loadPaceData(workout)
            
            do {
                // 等待所有數據加載完成
                let (hr, pace) = try await (heartRateTask, paceTask)
                heartRateData = hr
                paceData = pace
                
                print("數據加載完成 - 心率數據: \(hr.count)個點, 配速數據: \(pace.count)個點")
                
                // 設置選中的訓練記錄，觸發sheet顯示
                await MainActor.run {
                    selectedWorkout = workout
                    isLoadingData = false
                }
            } catch {
                print("加載訓練記錄數據出錯: \(error)")
                await MainActor.run {
                    isLoadingData = false
                }
            }
        }
    }
    
    // 加載心率數據
    private func loadHeartRateData(_ workout: HKWorkout) async -> [(Date, Double)] {
        do {
            return try await healthKitManager.fetchHeartRateData(for: workout)
        } catch {
            print("加載心率數據時出錯: \(error)")
            return []
        }
    }
    
    // 加載配速數據
    private func loadPaceData(_ workout: HKWorkout) async -> [(Date, Double)] {
        do {
            return try await healthKitManager.fetchPaceData(for: workout)
        } catch {
            print("加載配速數據時出錯: \(error)")
            return []
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
