import SwiftUI
import HealthKit

struct DailyTrainingCard: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    let day: TrainingDay
    let isToday: Bool
    
    var body: some View {
        let isExpanded = isToday || viewModel.expandedDayIndices.contains(day.dayIndex)
        
        VStack(alignment: .leading, spacing: 12) {
            // 點擊標題欄可切換展開/摺疊狀態
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if viewModel.expandedDayIndices.contains(day.dayIndex) {
                        viewModel.expandedDayIndices.remove(day.dayIndex)
                    } else {
                        viewModel.expandedDayIndices.insert(day.dayIndex)
                    }
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(viewModel.weekdayName(for: day.dayIndex))
                                .font(.headline)
                                .foregroundColor(.white)
                            // 添加具體日期顯示
                            if let date = viewModel.getDateForDay(dayIndex: day.dayIndex) {
                                Text(viewModel.formatShortDate(date))
                                    .font(.caption)
                                    .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
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
                            .background(Color.gray.opacity(0.3))
                            .padding(.vertical, 2)
                    }
                    
                    HStack {
                        Text("今日運動記錄")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                    }
                    .padding(.top, 4)
                    
                    if isExpanded {
                        ForEach(workouts, id: \.uuid) { workout in
                            WorkoutSummaryRow(workout: workout, viewModel: viewModel)
                        }
                    } else {
                        // 摺疊時顯示簡要訓練資訊
                        CollapsedWorkoutSummary(workouts: workouts, viewModel: viewModel)
                    }
                }
            }
            
            // 條件性顯示詳細內容
            if isExpanded {
                // 完整顯示
                VStack(alignment: .leading, spacing: 12) {
                    // 分隔線
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    Text(day.dayTarget)
                        .font(.body)
                        .foregroundColor(.white)
                    
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
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .fontWeight(day.type == .interval ? .medium : .regular)
                                        .foregroundColor(day.type == .interval ? .orange : .blue)
                                    
                                    if day.type == .interval, let times = item.goals.times {
                                        Text("× \(times)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding(.leading, -4)
                                    }
                                    
                                    Spacer()
                                    
                                    // Show the pace and distance in a pill for all training types
                                    HStack(spacing: 2) {
                                        if let pace = item.goals.pace {
                                            Text(pace)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(day.type == .interval ? .orange : .blue)
                                        }
                                        if let distance = item.goals.distanceKm {
                                            Text("/ \(String(format: "%.1f", distance)) km")
                                                .font(.caption)
                                                .foregroundColor(day.type == .interval ? .orange : .blue)
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(day.type == .interval ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                                    .cornerRadius(12)
                                    .opacity((item.goals.pace != nil || item.goals.distanceKm != nil) ? 1 : 0)
                                }
                            }
                            
                            Text(item.runDetails)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            } else if viewModel.workoutsByDay[day.dayIndex] == nil || viewModel.workoutsByDay[day.dayIndex]?.isEmpty == true {
                // 摺疊時只顯示簡短摘要（當天無訓練記錄時）
                Text(day.dayTarget)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(isToday ? Color(red: 0.15, green: 0.2, blue: 0.25) : Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(12)
    }
}
