import SwiftUI

struct TrainingPlanOverviewDetailView: View {
    @State private var overview: TrainingPlanOverview
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var targetRace: Target? = nil
    @State private var supportingTargets: [Target] = []
    @State private var showEditSheet = false
    @State private var showEditSupportingSheet = false
    @State private var showAddSupportingSheet = false
    @State private var selectedSupportingTarget: Target? = nil
    @State private var hasTargetSaved = false
    
    @State private var isUpdatingOverview = false
    @State private var showUpdateStatus = false
    @State private var updateStatusMessage = ""
    @State private var isUpdateSuccessful = false
    @State private var updatedOverview: TrainingPlanOverview?
    
    init(overview: TrainingPlanOverview) {
        _overview = State(initialValue: overview)
    }
    
    // 給支援賽事排序 - 按照日期從新到舊，並限制最多五筆
    private var sortedSupportingTargets: [Target] {
        return Array(supportingTargets.sorted { $0.raceDate > $1.raceDate }
                       .prefix(5))
    }
    
    var body: some View {
        ZStack {
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
                    
                    // Supporting Races Card - 使用新到舊且最多五筆的支援賽事
                    SupportingRacesCard(
                        supportingTargets: sortedSupportingTargets,
                        onAddTap: {
                            showAddSupportingSheet = true
                        },
                        onEditTap: { target in
                            selectedSupportingTarget = target
                            showEditSupportingSheet = true
                        }
                    )
                    
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
                // 從 overview.mainRaceId 載入主要賽事
                loadTargetRace()
                print("從 Overview mainRaceId 獲取主要賽事: \(overview.mainRaceId)")
                
                // 載入支援賽事
                self.supportingTargets = TargetStorage.shared.getSupportingTargets()
                print("已載入 \(supportingTargets.count) 個支援賽事")
                
                // 雲端同步所有賽事並更新本地與 UI
                fetchAndSyncTargets()
            }
            .sheet(isPresented: $showEditSheet, onDismiss: {
                // 當編輯視圖關閉時重新載入目標賽事
                loadTargetRace()
                
                // 只有在保存了目標後才更新overview
                if hasTargetSaved {
                    updateTrainingPlanOverview()
                    // hasTargetSaved 的重置移到 updateTrainingPlanOverview 完成後
                }
            }) {
                if let target = targetRace {
                    EditTargetView(target: target)
                }
            }
            .sheet(isPresented: $showEditSupportingSheet, onDismiss: {
                // 編輯支援賽事關閉後同步雲端與本地資料
                fetchAndSyncTargets()
            }) {
                if let target = selectedSupportingTarget {
                    EditSupportingTargetView(target: target)
                }
            }
            .sheet(isPresented: $showAddSupportingSheet, onDismiss: {
                // 添加支援賽事關閉後同步雲端與本地資料
                fetchAndSyncTargets()
            }) {
                AddSupportingTargetView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .targetUpdated)) { _ in
                hasTargetSaved = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .supportingTargetUpdated)) { _ in
                // 當支援賽事更新時，只重新載入支援賽事列表，不更新主要訓練計劃
                loadSupportingTargets()
            }
            
            
            // 加入更新中狀態提示
            if isUpdatingOverview {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("正在更新訓練計劃...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(12)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: isUpdatingOverview)
            }
            
            // 加入更新完成狀態提示
            if showUpdateStatus {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: isUpdateSuccessful ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(isUpdateSuccessful ? .green : .red)
                            .font(.title2)
                        
                        Text(updateStatusMessage)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            showUpdateStatus = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.2), radius: 5)
                    )
                    .padding()
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: showUpdateStatus)
                .zIndex(100)
            }
        }
    }
    
    private func loadTargetRace() {
        // 從 API 獲取主要賽事
        Task {
            do {
                let fetched = try await TargetService.shared.getTarget(id: overview.mainRaceId)
                await MainActor.run {
                    self.targetRace = fetched
                }
                print("Loaded main target via mainRaceId: \(fetched)")
            } catch {
                print("從 API 獲取主要賽事失敗: \(error)")
            }
        }
    }
    
    private func loadSupportingTargets() {
        // 從本地儲存獲取支援賽事
        self.supportingTargets = TargetStorage.shared.getSupportingTargets()
        print("已重新載入 \(supportingTargets.count) 個支援賽事")
    }
    
    private func updateTrainingPlanOverview() {
        // 顯示更新中狀態
        isUpdatingOverview = true
        showUpdateStatus = false
        
        Task {
            do {
                // 更新訓練計劃概覽
                let updatedOverview = try await TrainingPlanService.shared.updateTrainingPlanOverview(overviewId: overview.id)
                
                // 保存更新後的概覽到本地存儲
                TrainingPlanStorage.saveTrainingPlanOverview(updatedOverview)
                
                await MainActor.run {
                    self.overview = updatedOverview
                    self.isUpdatingOverview = false
                    self.showUpdateStatus = true
                    self.updateStatusMessage = "訓練計劃已根據最新目標重新產生"
                    self.isUpdateSuccessful = true
                    self.hasTargetSaved = false  // 在更新完成後重置狀態
                    
                    // 發送通知通知主畫面重新載入
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TrainingOverviewUpdated"),
                        object: updatedOverview
                    )
                    
                    // 5秒後自動隱藏成功提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if self.isUpdateSuccessful {
                            self.showUpdateStatus = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingOverview = false
                    self.showUpdateStatus = true
                    self.updateStatusMessage = "更新訓練計劃失敗：\(error.localizedDescription)"
                    self.isUpdateSuccessful = false
                }
                print("更新訓練計劃概覽失敗: \(error)")
            }
        }
    }
    
    // 雲端同步所有賽事並更新狀態
    private func fetchAndSyncTargets() {
        Task {
            do {
                let allTargets = try await TargetService.shared.getTargets()
                TargetStorage.shared.saveTargets(allTargets)
                let main = allTargets.first { $0.isMainRace }
                let supporting = allTargets.filter { !$0.isMainRace }
                await MainActor.run {
                    self.targetRace = main
                    self.supportingTargets = supporting.sorted { $0.raceDate < $1.raceDate }
                }
                print("同步完成：主賽事\(String(describing: main))，支援賽事\(supporting.count)")
            } catch {
                print("fetchAndSyncTargets 失敗: \(error)")
            }
        }
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


// MARK: - Preview

struct TrainingPlanOverviewDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingPlanOverviewDetailView(overview: TrainingPlanOverview(
            id: "",
            mainRaceId: "",
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
