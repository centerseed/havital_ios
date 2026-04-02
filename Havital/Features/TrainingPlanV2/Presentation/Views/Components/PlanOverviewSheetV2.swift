import SwiftUI

/// V2 訓練計畫概覽 Sheet
/// 使用 Tab 顯示不同資訊：賽事資訊 & 訓練計畫概覽
struct PlanOverviewSheetV2: View {
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    @StateObject private var targetViewModel = TargetFeatureViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    // Sheet 狀態
    @State private var showEditMainTarget = false
    @State private var showEditSupportingTarget = false
    @State private var showAddSupportingTarget = false
    @State private var selectedSupportingTarget: Target? = nil
    @State private var isUpdatingOverview = false
    @State private var showStageSelection = false
    @State private var pendingWeeksRemaining: Int = 12
    @State private var pendingDistanceKm: Double = 42.195

    var body: some View {
        NavigationStack {
            ZStack {
                // 主要內容
                VStack(spacing: 0) {
                    // Tab 選擇器
                    Picker("", selection: $selectedTab) {
                        Text(viewModel.planOverview?.isRaceRunTarget == true
                            ? NSLocalizedString("training.race_info", comment: "Race Info")
                            : NSLocalizedString("training.target_info", comment: "Target Info"))
                            .tag(0)
                        Text(NSLocalizedString("training.training_plan", comment: "Training Plan"))
                            .tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Tab 內容
                    TabView(selection: $selectedTab) {
                        // Tab 1: 賽事/目標資訊
                        if let overview = viewModel.planOverview {
                            TargetInfoTabV2(
                                overview: overview,
                                targetViewModel: targetViewModel,
                                showEditMainTarget: $showEditMainTarget,
                                showEditSupportingTarget: $showEditSupportingTarget,
                                showAddSupportingTarget: $showAddSupportingTarget,
                                selectedSupportingTarget: $selectedSupportingTarget
                            )
                            .tag(0)
                        } else {
                            ProgressView()
                                .tag(0)
                        }

                        // Tab 2: 訓練計畫概覽
                        if let overview = viewModel.planOverview {
                            TrainingOverviewTabV2(overview: overview, viewModel: viewModel)
                                .tag(1)
                        } else {
                            ProgressView()
                                .tag(1)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }

                // 更新中 overlay
                if isUpdatingOverview {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text(NSLocalizedString("training.updating_overview", comment: "Updating overview"))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .padding(28)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                }
            }
            .navigationTitle(viewModel.trainingPlanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .task {
                // 載入賽事資料
                await targetViewModel.loadTargets()
            }
            .onReceive(NotificationCenter.default.publisher(for: .targetUpdated)) { notification in
                // 🔍 總是記錄接收到通知
                Logger.debug("[🐛 TARGET_UPDATE] ③ PlanOverviewSheetV2 接收到通知")
                Logger.debug("[🐛 TARGET_UPDATE]    userInfo = \(String(describing: notification.userInfo))")

                // 檢查是否有重要變更
                if let userInfo = notification.userInfo,
                   let hasSignificantChange = userInfo["hasSignificantChange"] as? Bool {
                    Logger.debug("[🐛 TARGET_UPDATE]    解析成功: hasSignificantChange = \(hasSignificantChange)")

                    if hasSignificantChange {
                        let weeks = userInfo["remainingWeeks"] as? Int ?? 12
                        let distance = userInfo["distanceKm"] as? Double ?? 42.195
                        showEditMainTarget = false
                        Task {
                            // 等待 EditTargetView sheet dismiss 動畫完成
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            await targetViewModel.forceRefresh()
                            // Only show stage selection for race_run plans
                            if viewModel.planOverview?.isRaceRunTarget == true {
                                Logger.debug("[🐛 TARGET_UPDATE] ④ 顯示起始階段選擇")
                                pendingWeeksRemaining = weeks
                                pendingDistanceKm = distance
                                showStageSelection = true
                            } else {
                                Logger.debug("[🐛 TARGET_UPDATE] ④ 非 race plan，跳過起始階段選擇，直接更新 overview")
                                await viewModel.updateOverview(startFromStage: nil)
                            }
                        }
                    } else {
                        Logger.debug("[🐛 TARGET_UPDATE]    無重要變更，僅重新載入賽事資料")
                        Task {
                            await targetViewModel.forceRefresh()
                        }
                    }
                } else {
                    Logger.error("[🐛 TARGET_UPDATE] ❌ 無法解析 userInfo！")
                }
            }
            .sheet(isPresented: $showEditMainTarget) {
                if let target = targetViewModel.mainTarget {
                    EditTargetView(target: target)
                }
            }
            .sheet(isPresented: $showEditSupportingTarget) {
                if let target = selectedSupportingTarget {
                    EditSupportingTargetView(target: target)
                }
            }
            .sheet(isPresented: $showAddSupportingTarget) {
                AddSupportingTargetView()
            }
            .sheet(isPresented: $showStageSelection) {
                EditTargetStageSelectionView(
                    weeksRemaining: pendingWeeksRemaining,
                    targetDistanceKm: pendingDistanceKm
                ) { selectedStageApiIdentifier in
                    showStageSelection = false
                    Task {
                        withAnimation { isUpdatingOverview = true }
                        await viewModel.updateOverview(startFromStage: selectedStageApiIdentifier)
                        withAnimation { isUpdatingOverview = false }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 1: 賽事/目標資訊

private struct TargetInfoTabV2: View {
    let overview: PlanOverviewV2
    @ObservedObject var targetViewModel: TargetFeatureViewModel
    @Binding var showEditMainTarget: Bool
    @Binding var showEditSupportingTarget: Bool
    @Binding var showAddSupportingTarget: Bool
    @Binding var selectedSupportingTarget: Target?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 🎯 使用 V1 的 TargetRaceCard（如果有主要賽事）
                if overview.isRaceRunTarget, let mainTarget = targetViewModel.mainTarget {
                    TargetRaceCard(target: mainTarget) {
                        showEditMainTarget = true
                    }
                } else {
                    // 非賽事目標：顯示簡化的目標資訊卡片（含編輯按鈕）
                    targetCard
                        .overlay(alignment: .topTrailing) {
                            if targetViewModel.mainTarget != nil {
                                Button {
                                    showEditMainTarget = true
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                        .background(Circle().fill(Color(UIColor.systemBackground)))
                                }
                                .padding(12)
                            }
                        }
                }

                // 🏁 支援賽事卡片（使用 V1 的 SupportingRacesCard）
                if overview.isRaceRunTarget {
                    SupportingRacesCard(
                        supportingTargets: targetViewModel.sortedSupportingTargets,
                        onAddTap: {
                            showAddSupportingTarget = true
                        },
                        onEditTap: { target in
                            selectedSupportingTarget = target
                            showEditSupportingTarget = true
                        }
                    )
                }

                // 目標評估卡片
                evaluationCard
            }
            .padding()
        }
    }

    // 賽事/目標資訊卡片
    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(overview.isRaceRunTarget
                ? NSLocalizedString("training.target_race", comment: "Target Race")
                : NSLocalizedString("training.training_target", comment: "Training Target"))
                .font(AppFont.headline())

            VStack(alignment: .leading, spacing: 8) {
                // 目標名稱
                Text(overview.targetName ?? NSLocalizedString("training.my_training_target", comment: "My Training Target"))
                    .font(AppFont.title3())
                    .fontWeight(.semibold)

                // 賽事專屬資訊
                if overview.isRaceRunTarget {
                    Divider()

                    // 賽事日期
                    if let raceDate = overview.raceDateValue {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("training.race_date", comment: "Race Date"))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(raceDate, style: .date)
                                .font(AppFont.bodySmall())
                                .fontWeight(.medium)
                        }
                    }

                    // 賽事距離
                    if let distance = overview.distanceKm {
                        HStack {
                            Image(systemName: "figure.run")
                                .foregroundColor(.green)
                            Text(NSLocalizedString("training.race_distance", comment: "Race Distance"))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f 公里", distance))
                                .font(AppFont.bodySmall())
                                .fontWeight(.medium)
                        }
                    }

                    // 目標配速
                    if let pace = overview.targetPace {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("training.target_pace", comment: "Target Pace"))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(pace)/km")
                                .font(AppFont.bodySmall())
                                .fontWeight(.medium)
                        }
                    }

                    // 預計時間
                    if let targetTime = overview.targetTime {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.purple)
                            Text(NSLocalizedString("training.target_time", comment: "Target Time"))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTime(seconds: targetTime))
                                .font(AppFont.bodySmall())
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    // 非賽事目標
                    Divider()

                    if let description = overview.targetDescription {
                        Text(description)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }
                }

                // 訓練週數
                Divider()
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text(NSLocalizedString("training.training_weeks", comment: "Training Weeks"))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(overview.totalWeeks) 週")
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // 目標評估卡片
    private var evaluationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(overview.isRaceRunTarget
                ? NSLocalizedString("training.race_evaluation", comment: "Race Evaluation")
                : NSLocalizedString("training.target_evaluation", comment: "Target Evaluation"))
                .font(AppFont.headline())

            Text(overview.targetEvaluate ?? "")
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // 格式化時間（秒 -> HH:MM:SS）
    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Tab 2: 訓練計畫概覽

private struct TrainingOverviewTabV2: View {
    let overview: PlanOverviewV2
    @ObservedObject var viewModel: TrainingPlanV2ViewModel
    @State private var selectedStageIndex: Int? = nil
    @State private var showMethodologySheet = false
    @State private var isChangingMethodology = false
    @State private var showStageSelectionForMethodology = false
    @State private var pendingMethodologyId: String? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 方法論卡片
                    if let methodology = overview.methodologyOverview {
                        methodologyCard(methodology)
                    }

                    // 訓練策略卡片
                    approachCard

                    // 訓練階段 section（無外層卡片，每個 stage 各自為卡）
                    if !overview.trainingStages.isEmpty {
                        trainingStagesSection
                    }

                    // 里程碑 section（無外層卡片，每個 milestone 各自為卡）
                    if !overview.milestones.isEmpty {
                        if overview.milestoneBasis == "no_prior_target" {
                            Text("⚠️ 里程碑距離以你的歷史跑步資料為準，開始訓練後將持續優化")
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        milestonesSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // 切換方法論中 overlay
            if isChangingMethodology {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text(NSLocalizedString("training.updating_overview", comment: "Updating overview"))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .padding(28)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
            }
        }
        .onAppear {
            expandCurrentStage()
        }
        .sheet(isPresented: $showMethodologySheet) {
            methodologySelectionSheet
        }
        .sheet(isPresented: $showStageSelectionForMethodology) {
            let weeksRemaining = max(1, overview.totalWeeks - viewModel.currentWeek + 1)
            let distanceKm = overview.distanceKm ?? 42.195
            EditTargetStageSelectionView(
                weeksRemaining: weeksRemaining,
                targetDistanceKm: distanceKm
            ) { selectedStageApiIdentifier in
                showStageSelectionForMethodology = false
                if let methodologyId = pendingMethodologyId {
                    Task {
                        withAnimation { isChangingMethodology = true }
                        await viewModel.changeMethodology(
                            methodologyId: methodologyId,
                            startFromStage: selectedStageApiIdentifier
                        )
                        withAnimation { isChangingMethodology = false }
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    // MARK: - 方法論卡片

    private func methodologyCard(_ methodology: MethodologyOverviewV2) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題列
            HStack {
                Text(NSLocalizedString("training.methodology", comment: "Training Methodology"))
                    .font(AppFont.headline())
                Spacer()
                Button {
                    Task {
                        await viewModel.loadMethodologies()
                        showMethodologySheet = true
                    }
                } label: {
                    Text(NSLocalizedString("training.change_methodology", comment: "Change Methodology"))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 16)

            // 方法論名稱 + 哲學
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(methodology.name)
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                    Text(methodology.philosophy)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .padding(.horizontal, 16)

            // 強度分配
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("training.intensity_distribution", comment: "Intensity Distribution"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                Spacer()
                Text(methodology.intensityDescription)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 方法論選擇 Sheet

    private var methodologySelectionSheet: some View {
        NavigationStack {
            Group {
                if viewModel.availableMethodologies.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(NSLocalizedString("common.loading", comment: "Loading"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.availableMethodologies, id: \.id) { methodology in
                                methodologyOptionCard(methodology)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("training.select_methodology", comment: "Select Methodology"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "Close")) {
                        showMethodologySheet = false
                    }
                }
            }
        }
    }

    private func methodologyOptionCard(_ methodology: MethodologyV2) -> some View {
        let isSelected = overview.methodologyOverview?.name == methodology.name

        return Button {
            pendingMethodologyId = methodology.id
            showMethodologySheet = false
            Task {
                // 等待方法論 sheet dismiss 動畫完成
                try? await Task.sleep(nanoseconds: 400_000_000)
                if overview.isRaceRunTarget {
                    showStageSelectionForMethodology = true
                } else {
                    // Non-race plan: change methodology directly without stage selection
                    withAnimation { isChangingMethodology = true }
                    await viewModel.changeMethodology(
                        methodologyId: methodology.id,
                        startFromStage: nil
                    )
                    withAnimation { isChangingMethodology = false }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // 頂部：圖示 + 名稱 + 勾選
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: methodologyIcon(for: methodology.id))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }

                    Text(methodology.name)
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .blue : Color.secondary.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 16)

                // 描述
                Text(methodology.description)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, methodology.crossTrainingEnabled ? 8 : 14)

                // 標籤列
                if !methodology.phases.isEmpty || methodology.crossTrainingEnabled {
                    HStack(spacing: 10) {
                        if !methodology.phases.isEmpty {
                            Label("\(methodology.phases.count) 個階段", systemImage: "flag.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if methodology.crossTrainingEnabled {
                            Label("交叉訓練", systemImage: "figure.cross.training")
                                .font(.caption2)
                                .foregroundColor(.teal)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func methodologyIcon(for id: String) -> String {
        switch id {
        case "paceriz":         return "sparkles"
        case "polarized":       return "chart.bar.xaxis"
        case "hansons":         return "figure.run"
        case "norwegian":       return "mountain.2.fill"
        case "complete_10k":    return "flag.checkered"
        case "balanced_fitness": return "heart.circle.fill"
        case "aerobic_endurance": return "wind"
        default:                return "bolt.circle.fill"
        }
    }

    // MARK: - 訓練策略卡片

    private var approachCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題列
            Text(NSLocalizedString("training.training_strategy", comment: "Training Strategy"))
                .font(AppFont.headline())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 16)

            // 策略內容
            Text(overview.approachSummary ?? "")
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - 訓練階段 Section（單一卡片，標題在卡片內）

    private var trainingStagesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題列
            Text(NSLocalizedString("training.training_stages", comment: "Training Stages"))
                .font(AppFont.headline())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 16)

            // 各 stage row（不帶獨立卡片，共用外層卡片）
            ForEach(overview.trainingStages.indices, id: \.self) { index in
                let stage = overview.trainingStages[index]
                let isCurrentStage = viewModel.currentWeek >= stage.weekStart && viewModel.currentWeek <= stage.weekEnd
                stageRow(stage: stage, index: index, isCurrentStage: isCurrentStage)
                if index < overview.trainingStages.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // 訓練階段列（在父卡片內，不帶自己的背景）
    private func stageRow(stage: TrainingStageV2, index: Int, isCurrentStage: Bool) -> some View {
        let stageColor = getStageColor(stageIndex: index)
        let isExpanded = selectedStageIndex == index

        return VStack(alignment: .leading, spacing: 0) {
            // 標題列按鈕
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedStageIndex = isExpanded ? nil : index
                }
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isCurrentStage ? stageColor : stageColor.opacity(0.4))
                        .frame(width: 10, height: 10)

                    Text(stage.stageName)
                        .font(AppFont.bodySmall())
                        .fontWeight(isCurrentStage ? .semibold : .regular)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("第 \(stage.weekStart)-\(stage.weekEnd) 週")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(PlainButtonStyle())
            .background(isCurrentStage ? stageColor.opacity(0.06) : Color.clear)

            // 展開詳細資訊
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    // 階段描述
                    Text(stage.stageDescription)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    // 指標列：訓練重點 | 週跑量
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text(NSLocalizedString("training.training_focus", comment: "Training Focus"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "target")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            Text(stage.trainingFocus)
                                .font(AppFont.caption())
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()
                            .frame(height: 40)
                            .padding(.horizontal, 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text(NSLocalizedString("training.weekly_km_target", comment: "Weekly KM Target"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            Text(String(format: "%.0f–%.0f 公里",
                                        stage.targetWeeklyKmRange.low,
                                        stage.targetWeeklyKmRange.high))
                                .font(AppFont.caption())
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 關鍵訓練類型 tags
                    if let keyWorkouts = stage.keyWorkouts, !keyWorkouts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text(NSLocalizedString("training.key_workouts", comment: "Key Workouts"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }

                            FlowLayout(spacing: 6) {
                                ForEach(keyWorkouts, id: \.self) { workout in
                                    Text(formatWorkoutType(workout))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(stageColor.opacity(0.12))
                                        .foregroundColor(stageColor)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 里程碑 Section（單一卡片，標題在卡片內）

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題列
            Text(NSLocalizedString("training.key_milestones", comment: "Key Milestones"))
                .font(AppFont.headline())
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 16)

            // 各里程碑列
            ForEach(Array(overview.milestones.enumerated()), id: \.element.week) { idx, milestone in
                milestoneRow(milestone)
                if idx < overview.milestones.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    // 里程碑列（在父卡片內，不帶自己的背景）
    private func milestoneRow(_ milestone: MilestoneV2) -> some View {
        HStack(spacing: 14) {
            // 週數徽章
            ZStack {
                Circle()
                    .fill(milestone.isKeyMilestone ? Color.orange : Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text("W\(milestone.week)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(milestone.isKeyMilestone ? .white : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(milestone.title)
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)

                    if milestone.isKeyMilestone {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Text(milestone.description)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func getStageColor(stageIndex: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return colors[stageIndex % colors.count]
    }

    private func expandCurrentStage() {
        for (index, stage) in overview.trainingStages.enumerated() {
            if stage.contains(week: viewModel.currentWeek) {
                selectedStageIndex = index
                break
            }
        }
    }

    private func formatWorkoutType(_ type: String) -> String {
        switch type {
        case "short_interval":
            return NSLocalizedString("training.workout_type.short_interval", comment: "Short Interval")
        case "long_interval":
            return NSLocalizedString("training.workout_type.long_interval", comment: "Long Interval")
        case "threshold":
            return NSLocalizedString("training.workout_type.threshold", comment: "Threshold")
        case "tempo":
            return NSLocalizedString("training.workout_type.tempo", comment: "Tempo")
        case "fartlek":
            return NSLocalizedString("training.workout_type.fartlek", comment: "Fartlek")
        case "norwegian_4x4":
            return NSLocalizedString("training.workout_type.norwegian_4x4", comment: "Norwegian 4x4")
        case "race_pace":
            return NSLocalizedString("training.workout_type.race_pace", comment: "Race Pace")
        case "long_run":
            return NSLocalizedString("training.workout_type.long_run", comment: "Long Run")
        default:
            return type
        }
    }
}

// MARK: - FlowLayout（用於顯示關鍵訓練類型的標籤）

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = computeLayout(proposal: proposal, subviews: subviews)

        for (index, frame) in layout.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // 換行
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = currentY + lineHeight
        let totalWidth = maxWidth

        return (CGSize(width: totalWidth, height: totalHeight), frames)
    }
}

// MARK: - EditTargetStageSelectionView

/// 修改目標後的起始階段選擇 Sheet（不依賴 OnboardingCoordinator）
private struct EditTargetStageSelectionView: View {
    let weeksRemaining: Int
    let targetDistanceKm: Double
    let onConfirm: (String?) -> Void

    @State private var selectedStage: TrainingStagePhase?
    @State private var recommendation: StartStageRecommendation
    @Environment(\.dismiss) private var dismiss

    init(weeksRemaining: Int, targetDistanceKm: Double, onConfirm: @escaping (String?) -> Void) {
        self.weeksRemaining = weeksRemaining
        self.targetDistanceKm = targetDistanceKm
        self.onConfirm = onConfirm

        let rec = TrainingPlanCalculator.recommendStartStage(
            weeksRemaining: weeksRemaining,
            targetDistanceKm: targetDistanceKm
        )
        _recommendation = State(initialValue: rec)
        _selectedStage = State(initialValue: rec.recommendedStage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // 時間提示區塊
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text(NSLocalizedString("start_stage.time_notice_title", comment: "訓練時間提醒"))
                                    .font(AppFont.headline())
                            }

                            Text(String(format: NSLocalizedString("start_stage.time_notice", comment: "你的賽事在 %d 週後"),
                                       weeksRemaining))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)

                            if hasBaseStageOption {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(AppFont.bodySmall())

                                    Text(NSLocalizedString("start_stage.training_habit_reminder", comment: "建議有規律訓練習慣的跑者選擇跳過基礎期"))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // 推薦階段
                    Section {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text(NSLocalizedString("start_stage.recommendation", comment: "推薦起始階段"))
                                    .font(AppFont.caption())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor)
                                    .cornerRadius(12)
                                Spacer()
                            }
                            .padding(.bottom, 12)

                            StageOptionCard(
                                stageName: recommendation.stageName,
                                reason: recommendation.reason,
                                riskLevel: recommendation.riskLevel,
                                isRecommended: true,
                                isSelected: selectedStage == recommendation.recommendedStage
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStage = recommendation.recommendedStage
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // 其他選項
                    if !recommendation.alternatives.isEmpty {
                        Section(header: Text(NSLocalizedString("start_stage.other_options", comment: "其他選項"))) {
                            ForEach(recommendation.alternatives) { alternative in
                                StageAlternativeCard(
                                    alternative: alternative,
                                    isSelected: selectedStage == alternative.stage
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedStage = alternative.stage
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // 週數分配預覽
                    Section(header: Text(NSLocalizedString("start_stage.training_distribution", comment: "訓練週數分配"))) {
                        if let stage = selectedStage {
                            let distribution = TrainingPlanCalculator.calculateTrainingPeriods(
                                trainingWeeks: weeksRemaining,
                                targetDistanceKm: targetDistanceKm,
                                startFromStage: stage
                            )
                            TrainingDistributionView(distribution: distribution, totalWeeks: weeksRemaining)
                        }
                    }
                }

                // 底部確認按鈕
                VStack {
                    Button(action: {
                        onConfirm(selectedStage?.apiIdentifier)
                    }) {
                        Text(NSLocalizedString("common.confirm", comment: "確認"))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle(NSLocalizedString("start_stage.title", comment: "訓練計劃起始階段"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.close", comment: "關閉")) {
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private var hasBaseStageOption: Bool {
        recommendation.alternatives.contains { $0.stage == .base }
    }
}

// MARK: - Preview

#Preview {
    PlanOverviewSheetV2(viewModel: DependencyContainer.shared.makeTrainingPlanV2ViewModel())
}
