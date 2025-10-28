import SwiftUI

struct TrainingPlanOverviewDetailView: View {
    @State private var overview: TrainingPlanOverview
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // 🆕 使用 TargetManager（雙軌緩存架構）
    @StateObject private var targetManager = TargetManager.shared

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
    
    // 給支援賽事排序 - 按照日期由近到遠（最快要比的在上面）
    private var sortedSupportingTargets: [Target] {
        return targetManager.supportingTargets.sorted { $0.raceDate < $1.raceDate }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Target Race Card - 使用 TargetManager
                    if let target = targetManager.mainTarget {
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
                            SectionHeader(title: NSLocalizedString("training.goal_assessment", comment: "Goal Assessment"), systemImage: "target")
                            
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
                            SectionHeader(title: NSLocalizedString("training.plan_highlights", comment: "Plan Highlights"), systemImage: "sparkles")
                            
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
                            SectionHeader(title: NSLocalizedString("training.training_stages", comment: "Training Stages"), systemImage: "chart.bar.fill")
                            
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
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(overview.trainingPlanName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text(String(format: NSLocalizedString("training.total_weeks", comment: "Total weeks: %d weeks"), overview.totalWeeks))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
            .presentationDetents([.large])
            .onAppear {
                // 🆕 使用 TargetManager 的雙軌緩存載入
                Task {
                    await targetManager.loadTargets()
                    Logger.debug("TrainingPlanOverviewDetailView: 已透過 TargetManager 載入賽事資料")
                }
            }
            .sheet(isPresented: $showEditSheet, onDismiss: {
                // 編輯視圖關閉後的處理邏輯會在通知中處理
                // 這裡不需要做任何事情，避免重複處理
            }) {
                if let target = targetManager.mainTarget {
                    EditTargetView(target: target)
                }
            }
            .sheet(isPresented: $showEditSupportingSheet, onDismiss: {
                // 🆕 編輯支援賽事關閉後使用 TargetManager 強制刷新
                Task {
                    await targetManager.forceRefresh()
                    Logger.debug("編輯支援賽事後已刷新資料")
                }
            }) {
                if let target = selectedSupportingTarget {
                    EditSupportingTargetView(target: target)
                }
            }
            .sheet(isPresented: $showAddSupportingSheet, onDismiss: {
                // 🆕 添加支援賽事關閉後使用 TargetManager 強制刷新
                Task {
                    await targetManager.forceRefresh()
                    Logger.debug("添加支援賽事後已刷新資料")
                }
            }) {
                AddSupportingTargetView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .targetUpdated)) { notification in
                // 只處理來自 EditTargetView 且包含變更資訊的通知
                if let userInfo = notification.userInfo,
                   let hasSignificantChange = userInfo["hasSignificantChange"] as? Bool {
                    Logger.debug("接收到賽事編輯通知，重要變更: \(hasSignificantChange)")

                    // 🆕 使用 TargetManager 重新載入賽事資料以顯示最新名稱
                    Task {
                        await targetManager.forceRefresh()
                    }

                    // 只有在有重要變更時才更新訓練計劃概覽
                    if hasSignificantChange {
                        updateTrainingPlanOverview()
                    }
                } else {
                    // 忽略來自其他地方（如 TargetStorage）的通知，避免不必要的 overview 更新
                    Logger.debug("忽略來自 TargetStorage 的 targetUpdated 通知")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .supportingTargetUpdated)) { _ in
                // 🆕 當支援賽事更新時，使用 TargetManager 重新載入
                Task {
                    await targetManager.forceRefresh()
                    Logger.debug("支援賽事更新後已刷新資料")
                }
            }
            
            
            // 加入更新中狀態提示
            if isUpdatingOverview {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(NSLocalizedString("training.updating_plan", comment: "Updating training plan..."))
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

    // ❌ 已移除 loadTargetRace() - 現在使用 TargetManager.loadTargets()
    // ❌ 已移除 loadSupportingTargets() - 現在使用 TargetManager.loadTargets()

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
                    self.updateStatusMessage = NSLocalizedString("training.plan_regenerated", comment: "Training plan has been regenerated based on latest goals")
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
                    self.updateStatusMessage = String(format: NSLocalizedString("training.update_failed", comment: "Failed to update training plan: %@"), error.localizedDescription)
                    self.isUpdateSuccessful = false
                }
                print("更新訓練計劃概覽失敗: \(error)")
            }
        }
    }

    // ❌ 已移除 fetchAndSyncTargets() - 現在使用 TargetManager.forceRefresh()
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
