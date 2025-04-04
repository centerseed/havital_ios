import SwiftUI

struct TrainingPlanOverviewDetailView: View {
    let overview: TrainingPlanOverview
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var targetRace: Target? = nil
    @State private var showEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with Plan Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(overview.trainingPlanName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("總週數: \(overview.totalWeeks)週")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Target Race Card
                if let target = targetRace {
                    TargetRaceCard(target: target, onEditTap: {
                        showEditSheet = true
                    })
                }
                
                // Goal Evaluation Section
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "目標評估", systemImage: "target")
                        
                        Text(overview.targetEvaluate)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Training Highlight Section
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "計劃亮點", systemImage: "sparkles")
                        
                        Text(overview.trainingHighlight)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Training Stages
                SectionCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "訓練階段", systemImage: "chart.bar.fill")
                        
                        ForEach(overview.trainingStageDescription.indices, id: \.self) { index in
                            let stage = overview.trainingStageDescription[index]
                            TrainingStageCard(stage: stage, index: index)
                        }
                    }
                }
            }
            .padding(.vertical)
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        }
        .overlay(alignment: .topTrailing) {
            Button("完成") {
                dismiss()
            }
            .foregroundColor(.blue)
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .onAppear {
            // 同步部分保持不變
            self.targetRace = TargetStorage.shared.getMainTarget()
            print("Get Main Target: \(String(describing: targetRace))")
                
            // 如果需要，啟動異步任務
            if self.targetRace == nil {
                Task {
                    do {
                        _ = try await TargetService.shared.getTargets()
                        // 在主線程更新 UI
                        await MainActor.run {
                            self.targetRace = TargetStorage.shared.getMainTarget()
                            print("再次獲取主要目標: \(String(describing: targetRace))")
                        }
                    } catch {
                        print("從網路加載目標賽事失敗: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
                    // 當編輯視圖關閉時重新載入目標賽事
                    loadTargetRace()
                }) {
                    if let target = targetRace {
                        EditTargetView(target: target)
                    }
                }
    }
    
    private func loadTargetRace() {
        // 從本地儲存獲取主要目標賽事
        self.targetRace = TargetStorage.shared.getMainTarget()
        print("Get Main Target: \(String(describing: targetRace))")
    }
}

struct TargetRaceCard: View {
    let target: Target
    let onEditTap: () -> Void  // 添加一個回調函數
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // 標題與編輯按鈕
                HStack {
                    SectionHeader(title: "目標賽事", systemImage: "flag.filled.and.flag.crossed")
                    
                    Spacer()
                    
                    Button(action: {
                        onEditTap()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }
                
                // 賽事基本資訊
                VStack(alignment: .leading, spacing: 10) {
                    // 名稱
                    HStack(alignment: .center, spacing: 12) {
                        Text(target.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // 計算賽事日期距今天數
                        let daysRemaining = calculateDaysRemaining(raceDate: target.raceDate)
                        Text("\(daysRemaining)天")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                            )
                    }
                    
                    // 日期、距離和倒數天數在同一行
                    HStack(alignment: .center, spacing: 12) {
                        // 日期
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            
                            Text(formatDate(target.raceDate))
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        // 距離
                        Text("\(target.distanceKm) 公里")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.15))
                            )
                        
                    }
                    
                    // 目標完賽時間與配速
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目標完賽時間")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTime(target.targetTime))
                                .font(.headline)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("目標配速")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(target.targetPace) /公里")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
                    )
                }
            }
        }
    }
    
    // 格式化日期
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // 格式化時間
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    
    // 計算賽事日期距今天數
    private func calculateDaysRemaining(raceDate: Int) -> Int {
        let raceDay = Date(timeIntervalSince1970: TimeInterval(raceDate))
        let today = Date()
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: today, to: raceDay)
        
        return max(components.day ?? 0, 0) // 確保不為負數
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        Label {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
        } icon: {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
                .imageScale(.large)
        }
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 確保佔據最大寬度
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}

struct TrainingStageCard: View {
    let stage: TrainingStage
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    
    private var stageColors: (Color, Color) {
        let colors: [(Color, Color)] = [
            (Color.blue, Color.blue.opacity(0.15)),
            (Color.green, Color.green.opacity(0.15)),
            (Color.orange, Color.orange.opacity(0.15)),
            (Color.purple, Color.purple.opacity(0.15))
        ]
        
        return colors[index % colors.count]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 階段標題和週數
            HStack {
                Circle()
                    .fill(stageColors.0)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading) {
                    Text(stage.stageName)
                        .font(.headline)
                        .foregroundColor(stageColors.0)
                    
                    if let weekEnd = stage.weekEnd {
                        Text("第\(stage.weekStart)-\(weekEnd)週")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("第\(stage.weekStart)週開始")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 階段描述，確保文字可以根據內容動態調整高度
            Text(stage.stageDescription)
                .font(.body)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true) // 確保文字可以根據內容動態調整高度
            
            // 重點訓練部分
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(stageColors.0)
                    Text("重點訓練:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(stage.trainingFocus)
                    .font(.subheadline)
                    .foregroundColor(stageColors.0)
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(stageColors.1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 確保佔據最大寬度
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
        )
        .padding(.vertical, 4)
    }
}


// MARK: - Preview

struct TrainingPlanOverviewDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingPlanOverviewDetailView(overview: TrainingPlanOverview(
            targetEvaluate: "根據您的目標和現況，這個計劃將幫助您安全且有效地達成目標。本計劃充分考慮了您的當前健康狀況和跑步經驗，精心設計了漸進式的訓練課程。",
            totalWeeks: 16,
            trainingHighlight: "本計劃的亮點在於其結合了長跑、間歇跑和恢復跑等多樣化訓練方式，並根據您的進展逐步調整強度。特別注重恢復和節奏控制，幫助您在提升成績的同時降低受傷風險。",
            trainingPlanName: "半馬訓練計劃",
            trainingStageDescription: [
                TrainingStage(
                    stageName: "基礎建立期",
                    stageId: "1",
                    stageDescription: "本階段的訓練重點在於提升耐力基礎和適應性，以及建立穩定的訓練習慣。以較低強度的有氧訓練為主，逐步增加每週里程。",
                    trainingFocus: "耐力訓練",
                    weekStart: 1,
                    weekEnd: 4
                ),
                TrainingStage(
                    stageName: "強度發展期",
                    stageId: "2",
                    stageDescription: "本階段的訓練重點在於提升速度與節奏感，通過各種間歇訓練，提升心肺功能和乳酸閾值。",
                    trainingFocus: "速度和節奏訓練",
                    weekStart: 5,
                    weekEnd: 8
                ),
                TrainingStage(
                    stageName: "比賽準備期",
                    stageId: "3",
                    stageDescription: "本階段的訓練重點在於模擬比賽條件，熟悉比賽配速，以及精神和身體狀態的調整優化。",
                    trainingFocus: "配速穩定性與耐力",
                    weekStart: 9,
                    weekEnd: 14
                ),
                TrainingStage(
                    stageName: "賽前調整期",
                    stageId: "4",
                    stageDescription: "本階段的訓練重點在於保持狀態，同時降低訓練量，讓身體充分恢復以應對比賽。",
                    trainingFocus: "保持狀態與恢復",
                    weekStart: 15,
                    weekEnd: 16
                )
            ], createdAt: ""
        ))
    }
}
