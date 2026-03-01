import SwiftUI
import Charts

struct WorkoutDetailViewV2: View {
    @StateObject private var viewModel: WorkoutDetailViewModelV2
    @Environment(\.dismiss) private var dismiss
    @State private var showHRZoneInfo = false
    @State private var selectedZoneTab: ZoneTab = .heartRate
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    @State private var isReuploadingWorkout = false
    @State private var showReuploadAlert = false
    @State private var showInsufficientHeartRateAlert = false
    @State private var reuploadErrorMessage: String?
    @State private var heartRateCount = 0

    // 分享卡相關狀態
    @State private var showShareCardSheet = false
    @State private var showPhotoPickersheet = false
    @State private var showShareMenu = false  // 分享選單狀態

    // 刪除相關狀態
    @State private var showDeleteConfirmation = false
    @State private var isDeletingWorkout = false
    @State private var deleteResultMessage: String?
    @State private var showDeleteResult = false

    // 訓練心得相關狀態
    @State private var showTrainingNotesEditor = false
    @State private var displayedTrainingNotes: String? = nil  // 用於樂觀 UI 更新

    enum ZoneTab: CaseIterable {
        case heartRate, pace
        
        var title: String {
            switch self {
            case .heartRate: return L10n.Training.heartRateZone.localized
            case .pace: return L10n.Training.paceZone.localized
            }
        }
    }
    
    init(workout: WorkoutV2) {
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModelV2(workout: workout))

        // 調試：檢查 workout 的 shareCardContent
        print("📋 [WorkoutDetailViewV2] Init with workout.id: \(workout.id)")
        print("   - shareCardContent 是否為 nil: \(workout.shareCardContent == nil)")
        if let content = workout.shareCardContent {
            print("   - achievementTitle: \(content.achievementTitle ?? "nil")")
            print("   - encouragementText: \(content.encouragementText ?? "nil")")
            print("   - streakDays: \(content.streakDays?.description ?? "nil")")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 基本資訊卡片（始終顯示）
                basicInfoCard

                // 高級指標卡片
                if viewModel.workout.advancedMetrics != nil {
                    advancedMetricsCard
                }

                // 課表資訊和AI分析卡片
                if viewModel.workoutDetail?.dailyPlanSummary != nil || viewModel.workoutDetail?.aiSummary != nil {
                    TrainingPlanInfoCard(
                        workoutDetail: viewModel.workoutDetail,
                        dataProvider: viewModel.workout.provider
                    )
                }

                // 訓練心得卡片（優先顯示本地更新的內容）
                TrainingNotesCard(
                    notes: displayedTrainingNotes ?? viewModel.workoutDetail?.trainingNotes,
                    onEdit: {
                        showTrainingNotesEditor = true
                    }
                )

                // 載入狀態或錯誤訊息
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    // 只有在非載入狀態且無錯誤時顯示圖表
                    LazyVStack(spacing: 16) {
                        // 心率變化圖表
                        heartRateChartSection

                        // 配速變化圖表
                        if !viewModel.paces.isEmpty {
                            paceChartSection
                        }

                        // 步態分析圖表
                        if !viewModel.stanceTimes.isEmpty || !viewModel.verticalRatios.isEmpty || !viewModel.cadences.isEmpty {
                            gaitAnalysisChartSection
                        }

                        // 區間分佈卡片（合併顯示）
                        if let hrZones = viewModel.workout.advancedMetrics?.hrZoneDistribution,
                           let paceZones = viewModel.workout.advancedMetrics?.paceZoneDistribution {
                            combinedZoneDistributionCard(hrZones: convertToV2ZoneDistribution(hrZones), paceZones: convertToV2ZoneDistribution(paceZones))
                        } else if let hrZones = viewModel.workout.advancedMetrics?.hrZoneDistribution {
                            heartRateZoneCard(convertToV2ZoneDistribution(hrZones))
                        } else if let paceZones = viewModel.workout.advancedMetrics?.paceZoneDistribution {
                            paceZoneCard(convertToV2ZoneDistribution(paceZones))
                        }

                        // 圈速分析卡片 (在區間分佈後，數據來源前)
                        if let laps = viewModel.workoutDetail?.laps, !laps.isEmpty {
                            LapAnalysisView(
                                laps: laps,
                                dataProvider: viewModel.workout.provider,
                                deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName
                            )
                        }
                    }
                }

                // 數據來源和設備信息卡片（移到最底下）
                sourceInfoCardWithAlerts

                // 刪除運動記錄卡片
                deleteWorkoutCard
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .refreshable {
            await viewModel.refreshWorkoutDetail()
        }
        .navigationTitle(L10n.Workout.details.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L10n.Common.close.localized) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                // 分享按鈕 - 點擊彈出選單
                Menu {
                    // 分享訓練成果（照片分享卡）
                    Button {
                        showShareCardSheet = true
                    } label: {
                        Label(L10n.Workout.shareCard.localized,
                              systemImage: "photo.on.rectangle.angled")
                    }

                    // 分享長截圖
                    Button {
                        shareWorkout()
                    } label: {
                        Label(L10n.Workout.shareScreenshot.localized,
                              systemImage: "camera.viewfinder")
                    }
                    .disabled(isGeneratingScreenshot)
                } label: {
                    if isGeneratingScreenshot {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await TrackedTask("WorkoutDetailViewV2: loadWorkoutDetail") {
                await viewModel.loadWorkoutDetail()
            }.value
        }
        .onDisappear {
            // 確保在 View 消失時取消任務
            viewModel.cancelLoadingTasks()
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage = shareImage {
                ActivityViewController(activityItems: [shareImage])
            }
        }
        .sheet(isPresented: $showShareCardSheet) {
            WorkoutShareCardSheetView(
                workout: viewModel.workout,
                workoutDetail: viewModel.workoutDetail
            )
        }
        .sheet(isPresented: $showTrainingNotesEditor) {
            TrainingNotesEditorView(
                workoutId: viewModel.workout.id,
                initialNotes: displayedTrainingNotes ?? viewModel.workoutDetail?.trainingNotes,
                onSave: { notes in
                    // 使用 Task.tracked 進行 API 追蹤（符合 CLAUDE.md Section 7 規範）
                    return await Task {
                        let success = await viewModel.updateTrainingNotes(notes)
                        if success {
                            // 樂觀 UI 更新：立即更新顯示的內容
                            displayedTrainingNotes = notes
                        }
                        return success
                    }.tracked(from: "WorkoutDetailViewV2: updateTrainingNotes").value
                }
            )
        }
        .onChange(of: viewModel.workoutDetail?.trainingNotes) { newNotes in
            // 當從 API 刷新後，同步更新本地狀態
            if displayedTrainingNotes == nil {
                displayedTrainingNotes = newNotes
            }
        }
    }

    // MARK: - 基本資訊卡片
    
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.workoutType.workoutTypeDisplayName())
                        .font(AppFont.title2())
                        .fontWeight(.semibold)
                }
                
                if let trainingType = viewModel.trainingType {
                    Text(trainingType)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }

                Spacer()

                // Strava/Garmin Attribution badges
                attributionBadges
            }
            
            // 運動數據網格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                DataItem(title: L10n.Record.distance.localized, value: viewModel.distance ?? "-", icon: "location")
                DataItem(title: L10n.Record.duration.localized, value: viewModel.duration, icon: "clock")
                DataItem(title: L10n.Record.calories.localized, value: viewModel.calories ?? "-", icon: "flame")
                
                if let pace = viewModel.pace {
                    DataItem(title: L10n.Record.pace.localized, value: pace, icon: "speedometer")
                }
                
                if let avgHR = viewModel.averageHeartRate {
                    DataItem(title: L10n.Record.avgHeartRate.localized, value: avgHR, icon: "heart")
                }
                
                if let maxHR = viewModel.maxHeartRate {
                    DataItem(title: L10n.Record.maxHeartRate.localized, value: maxHR, icon: "heart.fill")
                }
            }
            
            // 日期時間
            Text(L10n.Workout.startTime.localized + ": \(formatDate(viewModel.workout.startDate))")
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    // MARK: - 計算屬性

    @ViewBuilder
    private var attributionBadges: some View {
        let isStravaProvider = viewModel.workout.provider.lowercased() == "strava"
        let isGarminProvider = viewModel.workout.provider.lowercased() == "garmin"
        let isGarminDevice = viewModel.workoutDetail?.deviceInfo?.deviceManufacturer?.lowercased() == "garmin"

        if isStravaProvider || isGarminProvider || isGarminDevice {
            HStack(spacing: 6) {
                // Strava badge
                if isStravaProvider {
                    ConditionalStravaAttributionView(
                        dataProvider: viewModel.workout.provider,
                        displayStyle: .compact
                    )
                }

                // Garmin badge (if provider is Garmin OR device manufacturer is Garmin)
                if isGarminProvider || isGarminDevice {
                    GarminAttributionView(
                        deviceModel: nil,  // 不顯示型號，只顯示 badge
                        displayStyle: .compact
                    )
                }
            }
        }
    }

    private var isAppleHealthSource: Bool {
        let provider = viewModel.workout.provider.lowercased()
        return provider.contains("apple") || provider.contains("health") || provider == "apple_health"
    }
    
    // MARK: - 重新上傳功能
    
    private func reuploadWorkout() async {
        // 只有 Apple Health 資料才能重新上傳
        guard isAppleHealthSource else { return }
        
        isReuploadingWorkout = true
        reuploadErrorMessage = nil
        
        do {
            // 呼叫 ViewModel 的重新上傳方法，包含心率數據檢查
            let result = await viewModel.reuploadWorkoutWithHeartRateCheck()
            
            await MainActor.run {
                isReuploadingWorkout = false
                
                switch result {
                case .success(let hasHeartRate):
                    reuploadErrorMessage = hasHeartRate ? L10n.Workout.reuploadSuccess.localized : L10n.Workout.uploadSuccessInsufficientHr.localized
                    // 重新載入詳細資料
                    Task {
                        await viewModel.refreshWorkoutDetail()
                    }.tracked(from: "WorkoutDetailViewV2: reuploadWorkout_refreshAfterSuccess")
                    
                case .insufficientHeartRate(let count):
                    // 心率數據不足，顯示警告
                    heartRateCount = count
                    showInsufficientHeartRateAlert = true
                    
                case .failure(let message):
                    reuploadErrorMessage = message
                }
            }
        } catch {
            await MainActor.run {
                isReuploadingWorkout = false
                reuploadErrorMessage = L10n.Workout.reuploadError.localized + " \(error.localizedDescription)"
            }
        }
    }
    
    private func forceReuploadWithInsufficientHeartRate() async {
        isReuploadingWorkout = true
        reuploadErrorMessage = nil
        
        let result = await viewModel.forceReuploadWorkout()
        
        await MainActor.run {
            isReuploadingWorkout = false
            if result {
                reuploadErrorMessage = L10n.Workout.uploadSuccessInsufficientHr.localized
                Task {
                    await viewModel.refreshWorkoutDetail()
                }.tracked(from: "WorkoutDetailViewV2: forceReupload_refreshAfterSuccess")
            } else {
                reuploadErrorMessage = L10n.Workout.reuploadFailed.localized
            }
        }
    }
    
    // MARK: - 數據來源信息卡片

    private var sourceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Profile.dataSources.localized)
                .font(AppFont.headline())
                .fontWeight(.semibold)

            providerInfoRow

            // 只有 Apple Health 資料來源才顯示重新上傳按鈕
            if isAppleHealthSource {
                Divider()
                reuploadSection
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    private var providerInfoRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Workout.provider.localized)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                providerBadges
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(L10n.Workout.activityType.localized)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                Text(viewModel.workout.activityType.workoutTypeDisplayName())
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
            }
        }
    }

    @ViewBuilder
    private var providerBadges: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Show Strava attribution if data source is Strava (badge only, no device name)
            ConditionalStravaAttributionView(
                dataProvider: viewModel.workout.provider,
                displayStyle: .compact
            )

            // Show Garmin attribution if device is Garmin (badge only, no device name)
            if let deviceManufacturer = viewModel.workoutDetail?.deviceInfo?.deviceManufacturer,
               deviceManufacturer.lowercased() == "garmin" {
                GarminAttributionView(
                    deviceModel: nil,  // 不傳遞 deviceModel，只顯示 badge
                    displayStyle: .compact
                )
            }

            // Fallback: show provider name if neither Strava nor Garmin
            if viewModel.workout.provider.lowercased() != "strava" &&
               viewModel.workout.provider.lowercased() != "garmin" &&
               viewModel.workoutDetail?.deviceInfo?.deviceManufacturer?.lowercased() != "garmin" {
                Text(viewModel.workout.provider)
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
            }
        }
    }

    private var reuploadSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Workout.resyncData.localized)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                Text(L10n.Workout.forceReuploadDescription.localized)
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: {
                showReuploadAlert = true
            }) {
                if isReuploadingWorkout {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 60, height: 28)
                } else {
                    Label(L10n.WorkoutDetail.reupload.localized, systemImage: "arrow.triangle.2.circlepath")
                        .font(AppFont.caption())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            .disabled(isReuploadingWorkout)
        }
    }

    // MARK: - Alert Modifiers (attached to sourceInfoCard)

    private var sourceInfoCardWithAlerts: some View {
        sourceInfoCard
        .alert(L10n.WorkoutDetail.reuploadAlert.localized, isPresented: $showReuploadAlert) {
            Button(L10n.WorkoutDetail.cancel.localized, role: .cancel) { }
            Button(L10n.WorkoutDetail.confirmUpload.localized, role: .destructive) {
                Task {
                    await reuploadWorkout()
                }.tracked(from: "WorkoutDetailViewV2: reuploadAlert_confirm")
            }
        } message: {
            Text(L10n.WorkoutDetail.reuploadMessage.localized)
        }
        .alert(L10n.WorkoutDetail.reuploadResult.localized, isPresented: .constant(reuploadErrorMessage != nil)) {
            Button(L10n.WorkoutDetail.confirm.localized) {
                reuploadErrorMessage = nil
            }
        } message: {
            if let errorMessage = reuploadErrorMessage {
                Text(errorMessage)
            }
        }
        .alert(L10n.WorkoutDetail.insufficientHeartRate.localized, isPresented: $showInsufficientHeartRateAlert) {
            Button(L10n.WorkoutDetail.cancel.localized, role: .cancel) { 
                isReuploadingWorkout = false
            }
            Button(L10n.WorkoutDetail.stillUpload.localized, role: .destructive) {
                Task {
                    await forceReuploadWithInsufficientHeartRate()
                }.tracked(from: "WorkoutDetailViewV2: insufficientHeartRateAlert_forceUpload")
            }
        } message: {
            Text(String(format: L10n.WorkoutDetail.insufficientHeartRateMessage.localized, heartRateCount))
        }
    }

    // MARK: - 刪除運動記錄卡片

    private var deleteWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Common.delete.localized)
                .font(AppFont.headline())
                .fontWeight(.semibold)

            Text(L10n.WorkoutDetail.deleteConfirmMessage.localized)
                .font(AppFont.caption())
                .foregroundColor(.secondary)

            Button(action: {
                showDeleteConfirmation = true
            }) {
                if isDeletingWorkout {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(L10n.Common.loading.localized)
                            .font(AppFont.bodySmall())
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                } else {
                    HStack {
                        Image(systemName: "trash")
                        Text(L10n.WorkoutDetail.deleteWorkout.localized)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .disabled(isDeletingWorkout)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .confirmationDialog(
            L10n.WorkoutDetail.deleteConfirmTitle.localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.WorkoutDetail.deleteWorkout.localized, role: .destructive) {
                Task {
                    await deleteWorkout()
                }.tracked(from: "WorkoutDetailViewV2: deleteConfirmation")
            }
            Button(L10n.WorkoutDetail.cancel.localized, role: .cancel) {}
        } message: {
            Text(L10n.WorkoutDetail.deleteConfirmMessage.localized)
        }
        .alert(
            L10n.WorkoutDetail.deleteFailed.localized,
            isPresented: $showDeleteResult
        ) {
            Button(L10n.WorkoutDetail.confirm.localized) {
                deleteResultMessage = nil
            }
        } message: {
            if let message = deleteResultMessage {
                Text(message)
            }
        }
    }

    // MARK: - 刪除方法

    private func deleteWorkout() async {
        isDeletingWorkout = true

        let success = await viewModel.deleteWorkout()

        await MainActor.run {
            isDeletingWorkout = false
            if success {
                // 刪除成功，直接退出到列表頁
                dismiss()
            } else {
                // 刪除失敗，顯示錯誤提示
                deleteResultMessage = L10n.WorkoutDetail.deleteFailed.localized
                showDeleteResult = true
            }
        }
    }

    // MARK: - 圖表區塊
    
    private var heartRateChartSection: some View {
        Group {
            if !viewModel.heartRates.isEmpty {
                HeartRateChartView(
                    heartRates: viewModel.heartRates,
                    maxHeartRate: viewModel.maxHeartRateString,
                    averageHeartRate: viewModel.chartAverageHeartRate,
                    minHeartRate: viewModel.minHeartRateString,
                    yAxisRange: viewModel.yAxisRange,
                    isLoading: viewModel.isLoading,
                    error: viewModel.error,
                    dataProvider: viewModel.workout.provider,
                    deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName,
                    deviceManufacturer: viewModel.workoutDetail?.deviceInfo?.deviceManufacturer
                )
            } else {
                // 簡化的空狀態顯示
                VStack {
                    Text(L10n.WorkoutDetail.heartRateData.localized)
                        .font(AppFont.headline())
                    Text(L10n.WorkoutDetail.noHeartRateData.localized)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private var paceChartSection: some View {
        Group {
            if !viewModel.paces.isEmpty {
                PaceChartView(
                    paces: viewModel.paces,
                    isLoading: viewModel.isLoading,
                    error: viewModel.error,
                    dataProvider: viewModel.workout.provider,
                    deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName,
                    deviceManufacturer: viewModel.workoutDetail?.deviceInfo?.deviceManufacturer
                )
            }
        }
    }
    
    private var gaitAnalysisChartSection: some View {
        Group {
            if !viewModel.stanceTimes.isEmpty || !viewModel.verticalRatios.isEmpty || !viewModel.cadences.isEmpty {
                GaitAnalysisChartView(
                    stanceTimes: viewModel.stanceTimes,
                    verticalRatios: viewModel.verticalRatios,
                    cadences: viewModel.cadences,
                    isLoading: viewModel.isLoading,
                    error: viewModel.error,
                    dataProvider: viewModel.workout.provider,
                    deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName,
                    deviceManufacturer: viewModel.workoutDetail?.deviceInfo?.deviceManufacturer,
                    forceShowStanceTimeTab: viewModel.hasStanceTimeStream
                )
            } else {
                // 簡化的空狀態顯示
                VStack {
                    Text(L10n.WorkoutDetail.gaitAnalysis.localized)
                        .font(AppFont.headline())
                    Text(L10n.WorkoutDetail.noGaitData.localized)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 高級指標卡片
    
    private var advancedMetricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.WorkoutDetail.advancedMetrics.localized)
                .font(AppFont.headline())
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                if let dynamicVdot = viewModel.workout.advancedMetrics?.dynamicVdot {
                    DataItem(title: L10n.WorkoutDetail.dynamicVdot.localized, value: String(format: "%.1f", dynamicVdot), icon: "chart.line.uptrend.xyaxis")
                }

                if let tss = viewModel.workout.advancedMetrics?.tss {
                    DataItem(title: L10n.WorkoutDetail.trainingLoad.localized, value: String(format: "%.1f", tss), icon: "heart.circle")
                }

                // Effort Score (RPE) - iOS 18+ Apple Watch
                if #available(iOS 18.0, *) {
                    if let rpe = viewModel.workout.advancedMetrics?.rpe {
                        DataItem(title: L10n.WorkoutDetail.effortScore.localized, value: String(format: "%.1f/10", rpe), icon: "gauge.with.dots.needle.bottom.50percent")
                    }
                }

                if let avgVerticalRatio = viewModel.workout.advancedMetrics?.avgVerticalRatioPercent {
                    DataItem(title: L10n.WorkoutDetail.movementEfficiency.localized, value: String(format: "%.1f%%", avgVerticalRatio), icon: "arrow.up.and.down.circle")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    // MARK: - 心率區間分佈卡片
    
    private func heartRateZoneCard(_ hrZones: V2ZoneDistribution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.WorkoutDetail.heartRateZones.localized)
                    .font(AppFont.headline())
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showHRZoneInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 8) {
                if let recovery = hrZones.recovery {
                    ZoneRow(title: L10n.WorkoutDetail.recoveryZone.localized, percentage: recovery, color: .green)
                }
                if let easy = hrZones.easy {
                    ZoneRow(title: L10n.WorkoutDetail.aerobicZone.localized, percentage: easy, color: .blue)
                }
                if let marathon = hrZones.marathon {
                    ZoneRow(title: L10n.WorkoutDetail.marathonZone.localized, percentage: marathon, color: .yellow)
                }
                if let threshold = hrZones.threshold {
                    ZoneRow(title: L10n.WorkoutDetail.thresholdZone.localized, percentage: threshold, color: .orange)
                }
                if let anaerobic = hrZones.anaerobic {
                    ZoneRow(title: L10n.WorkoutDetail.anaerobicZone.localized, percentage: anaerobic, color: .purple)
                }
                if let interval = hrZones.interval {
                    ZoneRow(title: L10n.WorkoutDetail.intervalZone.localized, percentage: interval, color: .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .sheet(isPresented: $showHRZoneInfo) {
            NavigationStack {
                HeartRateZoneInfoView()
            }
        }
    }

    // MARK: - 配速區間分佈卡片
    
    private func paceZoneCard(_ paceZones: V2ZoneDistribution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.WorkoutDetail.paceZones.localized)
                .font(AppFont.headline())
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let recovery = paceZones.recovery {
                    ZoneRow(title: L10n.WorkoutDetail.recoveryPace.localized, percentage: recovery, color: .green)
                }
                if let easy = paceZones.easy {
                    ZoneRow(title: L10n.WorkoutDetail.easyPace.localized, percentage: easy, color: .blue)
                }
                if let marathon = paceZones.marathon {
                    ZoneRow(title: L10n.WorkoutDetail.marathonPace.localized, percentage: marathon, color: .yellow)
                }
                if let threshold = paceZones.threshold {
                    ZoneRow(title: L10n.WorkoutDetail.thresholdPace.localized, percentage: threshold, color: .orange)
                }
                if let anaerobic = paceZones.anaerobic {
                    ZoneRow(title: L10n.WorkoutDetail.anaerobicPace.localized, percentage: anaerobic, color: .purple)
                }
                if let interval = paceZones.interval {
                    ZoneRow(title: L10n.WorkoutDetail.intervalPace.localized, percentage: interval, color: .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    // MARK: - 合併區間分佈卡片
    
    private func combinedZoneDistributionCard(hrZones: V2ZoneDistribution, paceZones: V2ZoneDistribution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.WorkoutDetail.zoneDistribution.localized)
                    .font(AppFont.headline())
                    .fontWeight(.semibold)
                
                Spacer()
                
                if selectedZoneTab == .heartRate {
                    Button(action: { showHRZoneInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // 標籤選擇器
            Picker(L10n.WorkoutDetail.zoneType.localized, selection: $selectedZoneTab) {
                ForEach(ZoneTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 動態內容
            VStack(spacing: 8) {
                if selectedZoneTab == .heartRate {
                    zoneRows(for: hrZones, isHeartRate: true)
                } else {
                    zoneRows(for: paceZones, isHeartRate: false)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .sheet(isPresented: $showHRZoneInfo) {
            NavigationStack {
                HeartRateZoneInfoView()
            }
        }
    }

    @ViewBuilder
    private func zoneRows(for zones: V2ZoneDistribution, isHeartRate: Bool) -> some View {
        if let recovery = zones.recovery {
            ZoneRow(
                title: isHeartRate ? L10n.WorkoutDetail.recoveryZone.localized : L10n.WorkoutDetail.recoveryPace.localized,
                percentage: recovery,
                color: .green
            )
        }
        if let easy = zones.easy {
            ZoneRow(
                title: isHeartRate ? L10n.WorkoutDetail.aerobicZone.localized : L10n.WorkoutDetail.easyPace.localized,
                percentage: easy,
                color: .blue
            )
        }
        if let marathon = zones.marathon {
            ZoneRow(
                title: isHeartRate ? L10n.WorkoutDetail.marathonZone.localized : L10n.WorkoutDetail.marathonPace.localized,
                percentage: marathon,
                color: .yellow
            )
        }
        if let threshold = zones.threshold {
            ZoneRow(
                title: isHeartRate ? L10n.WorkoutDetail.thresholdZone.localized : L10n.WorkoutDetail.thresholdPace.localized,
                percentage: threshold,
                color: .orange
            )
        }
        if let anaerobic = zones.anaerobic {
            ZoneRow(
                title: isHeartRate ? L10n.WorkoutDetail.anaerobicZone.localized : L10n.WorkoutDetail.anaerobicPace.localized,
                percentage: anaerobic,
                color: .purple
            )
        }
        if let interval = zones.interval {
            ZoneRow(
                title: isHeartRate ? L10n.WorkoutDetail.intervalZone.localized : L10n.WorkoutDetail.intervalPace.localized,
                percentage: interval,
                color: .red
            )
        }
    }
    
    // MARK: - 載入和錯誤狀態
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(L10n.WorkoutDetail.loadingDetails.localized)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.title2())
                .foregroundColor(.red)
            
            Text(L10n.WorkoutDetail.loadFailed.localized)
                .font(AppFont.headline())
                .fontWeight(.semibold)
            
            Text(error)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - 類型轉換方法
    
    private func convertToV2ZoneDistribution(_ zones: ZoneDistribution) -> V2ZoneDistribution {
        return V2ZoneDistribution(from: zones)
    }
    
    private func convertToV2IntensityMinutes(_ intensity: APIIntensityMinutes) -> V2IntensityMinutes {
        return V2IntensityMinutes(from: intensity)
    }
    
    // MARK: - 輔助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    private func formatIntensityMinutes(_ intensityMinutes: V2IntensityMinutes) -> String {
        var parts: [String] = []
        
        if let low = intensityMinutes.low, low > 0 {
            parts.append("\(L10n.WorkoutDetail.low.localized): \(String(format: "%.0f", low))\(L10n.WorkoutDetail.minutes.localized)")
        }
        if let medium = intensityMinutes.medium, medium > 0 {
            parts.append("\(L10n.WorkoutDetail.medium.localized): \(String(format: "%.0f", medium))\(L10n.WorkoutDetail.minutes.localized)")
        }
        if let high = intensityMinutes.high, high > 0 {
            parts.append("\(L10n.WorkoutDetail.high.localized): \(String(format: "%.0f", high))\(L10n.WorkoutDetail.minutes.localized)")
        }
        
        return parts.isEmpty ? "-" : parts.joined(separator: "\n")
    }
    
    // MARK: - 分享功能
    
    private func shareWorkout() {
        isGeneratingScreenshot = true
        
        LongScreenshotCapture.captureView(
            VStack(spacing: 16) {
                basicInfoCard
                
                if viewModel.workout.advancedMetrics != nil {
                    advancedMetricsCard
                }
                
                // 課表資訊和AI分析卡片 (強制展開AI分析)
                if viewModel.workoutDetail?.dailyPlanSummary != nil || viewModel.workoutDetail?.aiSummary != nil {
                    TrainingPlanInfoCard(
                        workoutDetail: viewModel.workoutDetail,
                        dataProvider: viewModel.workout.provider,
                        forceExpandAnalysis: true
                    )
                }
                
                heartRateChartSection
                
                if !viewModel.paces.isEmpty {
                    paceChartSection
                }
                
                if !viewModel.stanceTimes.isEmpty || !viewModel.verticalRatios.isEmpty || !viewModel.cadences.isEmpty {
                    gaitAnalysisChartSection
                }
                
                if let hrZones = viewModel.workout.advancedMetrics?.hrZoneDistribution,
                   let paceZones = viewModel.workout.advancedMetrics?.paceZoneDistribution {
                    combinedZoneDistributionCard(hrZones: convertToV2ZoneDistribution(hrZones), paceZones: convertToV2ZoneDistribution(paceZones))
                } else if let hrZones = viewModel.workout.advancedMetrics?.hrZoneDistribution {
                    heartRateZoneCard(convertToV2ZoneDistribution(hrZones))
                } else if let paceZones = viewModel.workout.advancedMetrics?.paceZoneDistribution {
                    paceZoneCard(convertToV2ZoneDistribution(paceZones))
                }
                
                if let laps = viewModel.workoutDetail?.laps, !laps.isEmpty {
                    LapAnalysisView(
                        laps: laps,
                        dataProvider: viewModel.workout.provider,
                        deviceModel: viewModel.workoutDetail?.deviceInfo?.deviceName
                    )
                }
                
                sourceInfoCard
            }
            .padding()
            .background(Color(.systemBackground))
        ) { image in
            DispatchQueue.main.async {
                self.isGeneratingScreenshot = false
                
                // 優化圖片格式和大小以改善分享兼容性
                if let originalImage = image {
                    let optimizedImage = self.optimizeImageForSharing(originalImage)
                    self.shareImage = optimizedImage
                } else {
                    self.shareImage = image
                }
                
                self.showShareSheet = true
            }
        }
    }
    
    // MARK: - 圖片優化
    
    private func optimizeImageForSharing(_ image: UIImage) -> UIImage? {
        // 限制圖片的最大尺寸和文件大小
        let maxWidth: CGFloat = 1080
        let maxHeight: CGFloat = 6000
        let compressionQuality: CGFloat = 0.8
        
        let currentSize = image.size
        var newSize = currentSize
        
        // 如果圖片太大，按比例縮放
        if currentSize.width > maxWidth || currentSize.height > maxHeight {
            let widthRatio = maxWidth / currentSize.width
            let heightRatio = maxHeight / currentSize.height
            let ratio = min(widthRatio, heightRatio)
            
            newSize = CGSize(
                width: currentSize.width * ratio,
                height: currentSize.height * ratio
            )
        }
        
        // 如果需要縮放，創建新圖片
        if newSize != currentSize {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let resizedImage = resizedImage {
                // 轉換為JPEG格式以減小文件大小
                if let jpegData = resizedImage.jpegData(compressionQuality: compressionQuality),
                   let finalImage = UIImage(data: jpegData) {
                    print("圖片已優化：原始尺寸 \(currentSize) -> 新尺寸 \(newSize)")
                    return finalImage
                }
            }
        } else {
            // 即使尺寸沒變，也轉換為JPEG格式
            if let jpegData = image.jpegData(compressionQuality: compressionQuality),
               let finalImage = UIImage(data: jpegData) {
                print("圖片已轉換為JPEG格式")
                return finalImage
            }
        }
        
        return image
    }
    
}

// MARK: - 輔助 Views

struct DataItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppFont.title3())
                .foregroundColor(.blue)
            
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
            
            Text(value)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
    }
}

struct ZoneRow: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .frame(minWidth: 60, maxWidth: 120, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(percentage / 100.0))), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text(String(format: "%.1f%%", percentage))
                .font(AppFont.caption())
                .fontWeight(.medium)
                .frame(width: 50, alignment: .trailing)
        }
    }
}



#Preview {
    WorkoutDetailViewV2(workout: WorkoutV2(
        id: "preview-1",
        provider: "Garmin",
        activityType: "running",
        startTimeUtc: ISO8601DateFormatter().string(from: Date()),
        endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
        durationSeconds: 3600,
        distanceMeters: 5000,
        deviceName: "Garmin",
        basicMetrics: nil,
        advancedMetrics: nil,
        createdAt: nil,
        schemaVersion: nil,
        storagePath: nil,
        dailyPlanSummary: nil,
        aiSummary: nil,
        shareCardContent: nil
    ))
} 
