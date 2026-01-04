import SwiftUI
import HealthKit

/// DataSync 顯示模式
enum DataSyncMode {
    case settings      // Settings 模式：完成後 dismiss
    case onboarding    // Onboarding 模式：完成後導航到下一步
}

struct DataSyncView: View {
    @StateObject private var viewModel: DataSyncViewModel
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var coordinator = OnboardingCoordinator.shared
    let dataSource: DataSourceType
    let mode: DataSyncMode
    let onboardingTargetDistance: Double?

    // Onboarding 導航狀態
    @State private var navigateToPersonalBest = false

    // 超時警告
    @State private var showTimeoutWarning = false
    @State private var syncDuration: TimeInterval = 0
    private var timeoutTimer: Timer?

    // MARK: - Initialization

    init(dataSource: DataSourceType, mode: DataSyncMode = .settings, onboardingTargetDistance: Double? = nil) {
        self.dataSource = dataSource
        self.mode = mode
        self.onboardingTargetDistance = onboardingTargetDistance
        _viewModel = StateObject(wrappedValue: DataSyncViewModel(mode: mode))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // 標題和圖標
                VStack(spacing: 16) {
                    // 數據源圖標
                    Image(systemName: dataSource == .appleHealth ? "heart.fill" : "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(dataSource == .appleHealth ? .red : .blue)

                    VStack(spacing: 8) {
                        Text(L10n.Sync.syncData.localized(with: dataSource.displayName))
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(L10n.Sync.syncingRecords.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // 超時警告（30 秒後顯示）
                if showTimeoutWarning && viewModel.isProcessing {
                    timeoutWarningBanner
                }

                // 進度指示器
            VStack(spacing: 16) {
                if viewModel.isProcessing {
                    // 顯示進度條（如果有總數信息）
                    if viewModel.totalCount > 0 && dataSource == .garmin {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.progressPercentage, total: 100.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 8)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            
                            HStack {
                                Text("\(viewModel.processedCount)/\(viewModel.totalCount)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(Int(viewModel.progressPercentage))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                            
                            if let currentItem = viewModel.currentItem, !currentItem.isEmpty {
                                Text(currentItem)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    
                    Text(viewModel.currentStep)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else if viewModel.isCompleted {
                    // 完成狀態
                    completedView
                } else if viewModel.hasError {
                    // 錯誤狀態
                    errorView
                }
            }
            
            Spacer()
            
                // 底部按鈕
                bottomButtons
            }
            .padding(24)
            .navigationTitle(L10n.Sync.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(viewModel.isProcessing)
            .onAppear {
                // 開始同步並防止螢幕熄滅
                UIApplication.shared.isIdleTimerDisabled = true
                startSync()
                startTimeoutMonitoring()
            }
            .onDisappear {
                // 恢復系統自動鎖定設定
                UIApplication.shared.isIdleTimerDisabled = false
            }

            Spacer()
        }
    }
    
    @ViewBuilder
    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text(L10n.Sync.complete.localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let results = viewModel.syncResults {
                    if results.errorCount > 0 {
                        Text(L10n.Sync.errorRecordsFailed.localized(with: results.errorCount))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text(L10n.Sync.failed.localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let error = viewModel.syncError {
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isProcessing {
                // 處理中：顯示取消/跳過按鈕
                Button(mode == .onboarding ? L10n.Sync.skip.localized : L10n.Common.cancel.localized) {
                    viewModel.cancelSync()
                    handleCompletion()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing && !viewModel.canCancel)
            } else if viewModel.isCompleted {
                // 完成：根據模式決定行為
                Button(L10n.Common.done.localized) {
                    handleCompletion()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else if viewModel.hasError {
                // 錯誤：提供重試和跳過選項
                VStack(spacing: 8) {
                    Button(L10n.Sync.retry.localized) {
                        startSync()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button(L10n.Sync.skip.localized) {
                        handleCompletion()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// 超時警告 Banner
    @ViewBuilder
    private var timeoutWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Sync.timeoutWarningTitle.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(L10n.Sync.timeoutWarningMessage.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private func startSync() {
        viewModel.startSync(for: dataSource)
    }

    /// 處理完成/跳過/取消
    private func handleCompletion() {
        switch mode {
        case .settings:
            // Settings 模式：關閉畫面
            dismiss()

        case .onboarding:
            // Onboarding 模式：標記完成並導航到下一步
            if viewModel.isCompleted {
                OnboardingBackfillCoordinator.shared.markBackfillCompleted()
            } else {
                // 用戶跳過或取消
                OnboardingBackfillCoordinator.shared.markSkippedByUser()
            }

            // 導航到 PersonalBestView
            coordinator.navigate(to: .personalBest)
        }
    }

    /// 開始超時監控（30 秒後顯示警告）
    private func startTimeoutMonitoring() {
        let startTime = Date()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard viewModel.isProcessing else {
                timer.invalidate()
                return
            }

            syncDuration = Date().timeIntervalSince(startTime)

            if syncDuration >= 30 && !showTimeoutWarning {
                withAnimation {
                    showTimeoutWarning = true
                }

                Logger.firebase("Sync timeout warning displayed", level: .info, labels: [
                    "module": "DataSyncView",
                    "action": "timeout_warning",
                    "duration": "\(Int(syncDuration))s"
                ])
            }
        }
    }
}

// MARK: - Data Sync View Model

class DataSyncViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var isCompleted = false
    @Published var hasError = false
    @Published var currentStep = ""
    @Published var syncError: String?
    @Published var syncResults: SyncResults?
    @Published var canCancel = true

    // 新增進度追蹤屬性
    @Published var processedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var progressPercentage: Double = 0.0
    @Published var currentItem: String?

    // 顯示模式
    let mode: DataSyncMode

    private var syncTask: Task<Void, Never>?

    private let workoutV2Service = WorkoutV2Service.shared
    private let healthKitManager = HealthKitManager()
    private let unifiedWorkoutManager = UnifiedWorkoutManager.shared

    // MARK: - Initialization

    init(mode: DataSyncMode = .settings) {
        self.mode = mode
    }
    
    func startSync(for dataSource: DataSourceType) {
        // 重置狀態
        isProcessing = true
        isCompleted = false
        hasError = false
        syncError = nil
        syncResults = nil
        canCancel = true
        
        // 重置進度狀態
        processedCount = 0
        totalCount = 0
        progressPercentage = 0.0
        currentItem = nil
        
        syncTask = Task {
            await performSync(for: dataSource)
        }
    }
    
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        isProcessing = false
        canCancel = false
    }
    
    @MainActor
    private func performSync(for dataSource: DataSourceType) async {
        do {
            switch dataSource {
            case .appleHealth:
                await syncAppleHealthData()
            case .garmin:
                await syncGarminData()
            case .strava:
                await syncStravaData()
            case .unbound:
                print("DataSyncViewModel: 尚未綁定數據源")
            }
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isProcessing = false
                self.syncError = error.localizedDescription
            }
        }
    }
    
    private func syncAppleHealthData() async {
        do {
            // 步驟1: 檢查 HealthKit 授權
            await MainActor.run {
                self.currentStep = L10n.Sync.checkingHealthAuth.localized
            }
            
            try await healthKitManager.requestAuthorization()
            
            // 步驟2: 獲取近30天的運動記錄
            await MainActor.run {
                self.currentStep = L10n.Sync.getting30DayRecords.localized
            }
            
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            let workouts = try await healthKitManager.fetchWorkoutsForDateRange(start: startDate, end: endDate)
            
            // 檢查是否有運動記錄
            if workouts.isEmpty {
                await MainActor.run {
                    self.hasError = true
                    self.isProcessing = false
                    self.syncError = L10n.Sync.noHealthRecords.localized
                }
                return
            }
            
            // 步驟3: 上傳運動記錄
            await MainActor.run {
                self.currentStep = L10n.Sync.uploadingRecords.localized(with: workouts.count)
            }
            
            var processedCount = 0
            var errorCount = 0
            var lastError: Error?
            
            for (index, workout) in workouts.enumerated() {
                do {
                    // 更新進度
                    await MainActor.run {
                        self.currentStep = L10n.Sync.uploadingRecordProgress.localized(with: index + 1, workouts.count)
                    }
                    
                    try await workoutV2Service.uploadWorkout(workout)
                    processedCount += 1
                } catch {
                    errorCount += 1
                    lastError = error
                    print("上傳運動記錄失敗: \(error.localizedDescription)")
                }
            }
            
            // 如果所有記錄都上傳失敗，顯示錯誤
            if processedCount == 0 && errorCount > 0 {
                await MainActor.run {
                    self.hasError = true
                    self.isProcessing = false
                    self.syncError = L10n.Sync.allRecordsFailed.localized(with: lastError?.localizedDescription ?? "Unknown error")
                }
                return
            }
            
            // 步驟4: 重新載入數據
            await MainActor.run {
                self.currentStep = L10n.Sync.reloadData.localized
            }
            
            await unifiedWorkoutManager.refreshWorkouts()
            
            // 完成
            await MainActor.run {
                self.isProcessing = false
                self.isCompleted = true
                self.syncResults = SyncResults(
                    processedCount: processedCount,
                    errorCount: errorCount,
                    totalFiles: workouts.count
                )
            }
            
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isProcessing = false
                self.syncError = L10n.Sync.appleHealthFailed.localized(with: error.localizedDescription)
            }
        }
    }
    
    private func syncGarminData() async {
        do {
            // 步驟1: 先檢查是否已經有處理在進行中
            await MainActor.run {
                self.currentStep = L10n.Sync.checkingGarminStatus.localized
            }
            
            let initialStatusResponse = try await workoutV2Service.getGarminProcessingStatus()
            
            // 如果已經在處理中，直接進入輪詢模式
            if initialStatusResponse.data.processingStatus.inProgress {
                await MainActor.run {
                    self.currentStep = L10n.Sync.garminProcessingDetected.localized
                    self.canCancel = false
                }
                
                Logger.firebase(
                    L10n.Sync.garminProcessingContinue.localized,
                    level: .info,
                    labels: ["module": "DataSyncView", "action": "sync_garmin_ongoing"]
                )
                
                // 直接跳到輪詢階段
                try await startPollingGarminStatus()
                
            } else {
                // 沒有處理在進行中，觸發新的歷史數據處理
                await MainActor.run {
                    self.currentStep = L10n.Sync.startGarminHistorical.localized
                }
                
                let historicalResponse = try await workoutV2Service.triggerGarminHistoricalDataProcessing(daysBack: 14)
                
                await MainActor.run {
                    self.currentStep = L10n.Sync.processingGarminData.localized(with: historicalResponse.data.estimatedDuration)
                    self.canCancel = false
                }
                
                Logger.firebase(
                    L10n.Sync.garminHistoricalSuccess.localized,
                    level: .info,
                    labels: ["module": "DataSyncView", "action": "sync_garmin_triggered"],
                    jsonPayload: ["estimated_duration": historicalResponse.data.estimatedDuration]
                )
                
                // 開始輪詢
                try await startPollingGarminStatus()
            }
            
        } catch is CancellationError {
            await MainActor.run {
                self.isProcessing = false
                self.hasError = true
                self.syncError = L10n.Common.cancel.localized
            }
        } catch {
            // 特別處理 429 錯誤（處理正在進行中）
            if error.localizedDescription.contains("429") || error.localizedDescription.contains("歷史數據處理正在進行中") {
                Logger.firebase(
                    "Detected processing in progress error, attempting to enter polling mode directly",
                    level: .info,
                    labels: ["module": "DataSyncView", "action": "sync_garmin_429_retry"]
                )
                
                // 嘗試直接進入輪詢模式
                do {
                    await MainActor.run {
                        self.currentStep = L10n.Sync.processingInProgress.localized
                        self.canCancel = false
                    }
                    
                    try await startPollingGarminStatus()
                } catch {
                    await MainActor.run {
                        self.hasError = true
                        self.isProcessing = false
                        self.syncError = L10n.Sync.cannotConnectGarmin.localized(with: error.localizedDescription)
                    }
                }
            } else {
                await MainActor.run {
                    self.hasError = true
                    self.isProcessing = false
                    self.syncError = L10n.Sync.garminSyncFailed.localized(with: error.localizedDescription)
                }
            }
        }
    }
    
    // 將輪詢邏輯抽取為獨立方法
    private func startPollingGarminStatus() async throws {
        // 輪詢狀態
        var isProcessing = true
        var processedCount = 0
        var errorCount = 0
        var totalFiles = 0
        
        while isProcessing {
            // 檢查是否被取消
            try Task.checkCancellation()
            
            // 等待5秒再檢查
            try await Task.sleep(nanoseconds: 5_000_000_000)
            
            let statusResponse = try await workoutV2Service.getGarminProcessingStatus()
            
            print("🔍 當前狀態: \(statusResponse.data.processingStatus.inProgress)")
            print("🔍 處理進度: \(statusResponse.data.processingStatus)")
            
            // 更新進度信息
            await MainActor.run {
                // 直接使用 processing_status 中的進度字段
                if let processed = statusResponse.data.processingStatus.processedCount {
                    self.processedCount = processed
                }
                if let total = statusResponse.data.processingStatus.totalCount {
                    self.totalCount = total
                }
                if let percentage = statusResponse.data.processingStatus.progressPercentage {
                    self.progressPercentage = percentage
                }
                if let current = statusResponse.data.processingStatus.currentItem {
                    self.currentItem = current
                }
                
                // 更新進度顯示文字
                if self.totalCount > 0 {
                    self.currentStep = L10n.Sync.processingGarminProgress.localized(with: self.processedCount, self.totalCount, Int(self.progressPercentage))
                } else {
                    self.currentStep = L10n.Sync.processingGarminInitializing.localized
                }
            }
            
            if !statusResponse.data.processingStatus.inProgress {
                isProcessing = false
                
                // 獲取最新的處理結果
                if let latestResult = statusResponse.data.recentResults.first,
                   let summary = latestResult.summary {
                    processedCount = summary.processedCount
                    errorCount = summary.errorCount
                    totalFiles = summary.totalFiles
                } else {
                    // 如果沒有 summary，使用 processing_status 中的數據
                    processedCount = statusResponse.data.processingStatus.processedCount ?? 0
                    errorCount = 0
                    totalFiles = statusResponse.data.processingStatus.totalCount ?? 0
                }
            }
        }
        
        // 步驟3: 重新載入數據
        await MainActor.run {
            self.currentStep = L10n.Sync.reloadData.localized
        }
        
        await unifiedWorkoutManager.refreshWorkouts()
        
        // 完成
        await MainActor.run {
            self.isProcessing = false
            self.isCompleted = true
            self.syncResults = SyncResults(
                processedCount: processedCount,
                errorCount: errorCount,
                totalFiles: totalFiles
            )
        }
    }
    
    private func syncStravaData() async {
        do {
            // 步驟1: 準備開始同步
            await MainActor.run {
                self.currentStep = L10n.Sync.preparingStrava.localized
            }
            
            Logger.firebase(
                "開始 Strava 數據同步 (主動觸發模式)",
                level: .info,
                labels: ["module": "DataSyncView", "action": "sync_strava_start"]
            )
            
            // 步驟2: 觸發 Backfill (近 14 天)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            let startDateString = dateFormatter.string(from: startDate)
            
            let response = try await StravaService.shared.triggerBackfill(startDate: startDateString, days: 14)
            
            await MainActor.run {
                self.currentStep = L10n.Sync.stravaTriggered.localized
                self.canCancel = false
            }
            
            // 步驟3: 開始輪詢狀態
            try await startPollingStravaStatus(backfillId: response.backfillId)
            
        } catch is CancellationError {
            await MainActor.run {
                self.isProcessing = false
                self.hasError = true
                self.syncError = L10n.Common.cancel.localized
            }
        } catch {
            await MainActor.run {
                self.hasError = true
                self.isProcessing = false
                self.syncError = L10n.Sync.stravaSyncFailed.localized(with: error.localizedDescription)
            }
        }
    }
    
    private func startPollingStravaStatus(backfillId: String) async throws {
        var isSyncing = true
        var processedCount = 0
        var totalFiles = 0
        
        while isSyncing {
            // 檢查是否被取消
            try Task.checkCancellation()
            
            // 等待 3 秒再檢查 (Strava 通常比 Garmin 快)
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            let statusResponse = try await StravaService.shared.getBackfillStatus(backfillId: backfillId)
            
            print("🔍 Strava Backfill 狀態: \(statusResponse.status)")
            
            // 更新進度
            await MainActor.run {
                self.processedCount = statusResponse.progress.newWorkouts
                // Strava API 目前可能不提供精確總數，我們用 newWorkouts 作為參考
                self.currentStep = L10n.Sync.processingStravaProgress.localized(with: self.processedCount)
            }
            
            if statusResponse.status == "completed" || statusResponse.status == "failed" {
                isSyncing = false
                processedCount = statusResponse.progress.newWorkouts
                
                if statusResponse.status == "failed" {
                    throw WorkoutV2Error.networkError(statusResponse.error ?? "Unknown Strava backfill error")
                }
            }
        }
        
        // 步驟4: 重新載入數據
        await MainActor.run {
            self.currentStep = L10n.Sync.reloadData.localized
        }
        
        await unifiedWorkoutManager.refreshWorkouts()
        
        // 完成
        await MainActor.run {
            self.isProcessing = false
            self.isCompleted = true
            self.syncResults = SyncResults(
                processedCount: processedCount,
                errorCount: 0,
                totalFiles: processedCount
            )
        }
        
        Logger.firebase(
            "Strava 數據同步完成 (主動觸發模式)",
            level: .info,
            labels: ["module": "DataSyncView", "action": "sync_strava_complete"]
        )
    }
}

// MARK: - Supporting Types

struct SyncResults {
    let processedCount: Int
    let errorCount: Int
    let totalFiles: Int
}

#Preview {
    Group {
        // Settings 模式
        NavigationStack {
            DataSyncView(dataSource: .garmin, mode: .settings)
        }
        .previewDisplayName("Settings Mode")

        // Onboarding 模式
        NavigationStack {
            DataSyncView(dataSource: .garmin, mode: .onboarding, onboardingTargetDistance: 21.0975)
        }
        .previewDisplayName("Onboarding Mode")
    }
} 
