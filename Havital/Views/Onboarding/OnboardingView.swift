import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Dependencies (Clean Architecture)
    private let targetRepository: TargetRepository

    // MARK: - Published Properties
    @Published var raceName = ""
    @Published var raceDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()  // 預設為一個月後
    @Published var selectedDistance = "42.195" // 預設全馬
    @Published var targetHours = 4
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    // @Published var navigateToTrainingDays = false // 這個狀態似乎沒有直接在這個 View 中使用來導航，而是 createTarget 成功後，間接觸發 showPersonalBest

    // 起始階段選擇相關狀態
    @Published var selectedStartStage: TrainingStagePhase? = nil
    @Published var shouldShowStageSelection: Bool = false

    // 未來目標選擇相關狀態
    @Published var availableTargets: [Target] = [] // 從 API 載入的未來目標列表
    @Published var selectedTargetKey: String? // 選擇的目標 ID
    @Published var isLoadingTargets = false // 載入目標中

    var availableDistances: [String: String] {
        [
            "5": NSLocalizedString("distance.5k", comment: "5K"),
            "10": NSLocalizedString("distance.10k", comment: "10K"),
            "21.0975": NSLocalizedString("distance.half_marathon", comment: "Half Marathon"),
            "42.195": NSLocalizedString("distance.full_marathon", comment: "Full Marathon")
        ]
    }

    // MARK: - Initialization

    init(targetRepository: TargetRepository = DependencyContainer.shared.resolve()) {
        self.targetRepository = targetRepository
    }
    
    /// 使用「週邊界」演算法計算訓練週數（與後端一致）
    /// 注意：此計算方式與簡單的日期差不同，詳見 Docs/TRAINING_WEEKS_CALCULATION.md
    var trainingWeeks: Int {
        return TrainingWeeksCalculator.calculateTrainingWeeks(
            startDate: Date(),
            raceDate: raceDate
        )
    }

    /// 保留舊的計算方式用於對比（僅供參考）
    var actualWeeksRemaining: Double {
        let (_, weeks) = TrainingWeeksCalculator.calculateActualDateDifference(
            startDate: Date(),
            raceDate: raceDate
        )
        return weeks
    }
    
    var targetPace: String {
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 42.195
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    /// 檢查選擇的目標是否被修改
    private func hasSelectedTargetBeenModified() -> Bool {
        guard let selectedTargetId = selectedTargetKey else { return false }

        // 在 availableTargets 中找到選擇的目標
        guard let selectedTarget = availableTargets.first(where: { $0.id == selectedTargetId }) else {
            return false
        }

        // 比較是否有改動
        let nameChanged = raceName != selectedTarget.name
        let distanceChanged = Int(Double(selectedDistance) ?? 42.195) != selectedTarget.distanceKm
        let timeChanged = (targetHours * 3600 + targetMinutes * 60) != selectedTarget.targetTime
        let dateChanged = Int(raceDate.timeIntervalSince1970) != selectedTarget.raceDate

        return nameChanged || distanceChanged || timeChanged || dateChanged
    }

    @MainActor
    func createTarget() async -> Bool { // 返回 Bool 表示是否成功
        isLoading = true
        error = nil

        do {
            // 如果選擇了先前的目標且有改動，則更新；否則創建新目標
            if let selectedTargetId = selectedTargetKey, hasSelectedTargetBeenModified() {
                // 更新已選擇的目標
                let updatedTarget = Target(
                    id: selectedTargetId,
                    type: "race_run",
                    name: raceName.isEmpty ? NSLocalizedString("onboarding.my_training_goal", comment: "My Training Goal") : raceName,
                    distanceKm: Int(Double(selectedDistance) ?? 42.195),
                    targetTime: targetHours * 3600 + targetMinutes * 60,
                    targetPace: targetPace,
                    raceDate: Int(raceDate.timeIntervalSince1970),
                    isMainRace: true,
                    trainingWeeks: trainingWeeks
                )

                _ = try await targetRepository.updateTarget(id: selectedTargetId, target: updatedTarget)
                print("✅ 目標已更新: \(updatedTarget.name)")
            } else if selectedTargetKey == nil {
                // 創建新的主要目標
                let target = Target(
                    id: UUID().uuidString,
                    type: "race_run",
                    name: raceName.isEmpty ? NSLocalizedString("onboarding.my_training_goal", comment: "My Training Goal") : raceName,
                    distanceKm: Int(Double(selectedDistance) ?? 42.195),
                    targetTime: targetHours * 3600 + targetMinutes * 60,
                    targetPace: targetPace,
                    raceDate: Int(raceDate.timeIntervalSince1970),
                    isMainRace: true,
                    trainingWeeks: trainingWeeks
                )

                let createdTarget = try await targetRepository.createTarget(target)
                selectedTargetKey = createdTarget.id
                print("✅ 新目標創建成功: \(createdTarget.name), id: \(createdTarget.id)")
            } else {
                // 選擇了目標但沒有改動，直接跳過
                print("✅ 使用先前的目標賽事，不需要創建或更新")
            }

            // ⚠️ TEMPORARILY DISABLED: 自動刪除舊賽事功能已暫時停用
            // TODO: 後端應該處理主要賽事的唯一性，前端不應該手動刪除
            /*
            // 如果是重新設定目標模式，創建成功後再刪除舊的主要目標
            if AuthenticationService.shared.isReonboardingMode {
                print("🔄 重新設定目標模式：開始刪除舊的主要目標")

                do {
                    // 獲取所有目標
                    let existingTargets = try await TargetService.shared.getTargets()

                    // 找到舊的主要賽事目標（排除剛創建的新目標）
                    if let oldMainTarget = existingTargets.first(where: { $0.isMainRace && $0.id != target.id }) {
                        print("🗑️ 找到舊的主要目標: \(oldMainTarget.name) (ID: \(oldMainTarget.id))")

                        // 刪除舊的主要目標
                        try await TargetService.shared.deleteTarget(id: oldMainTarget.id)
                        print("✅ 成功刪除舊的主要目標")
                    } else {
                        print("ℹ️ 未找到舊的主要目標（可能已被刪除）")
                    }
                } catch {
                    print("⚠️ 刪除舊目標時發生錯誤: \(error.localizedDescription)")
                    // 刪除失敗不影響整體流程，因為新目標已經創建成功
                }
            }
            */

            print(NSLocalizedString("onboarding.target_created", comment: "Training goal created"))
            isLoading = false
            return true
        } catch is CancellationError {
            isLoading = false
            return false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    /// 從後端載入用戶的所有未來目標（只載入主要賽事 isMainRace=true）
    func loadAvailableTargets() async {
        isLoadingTargets = true

        do {
            let allTargets = try await targetRepository.getTargets()

            // 篩選出日期在未來且為主要賽事的目標
            let now = Date()
            let futureMainTargets = allTargets.filter { target in
                let targetDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
                return targetDate > now && target.isMainRace
            }

            await MainActor.run {
                self.availableTargets = futureMainTargets
                print("[OnboardingViewModel] 成功載入 \(futureMainTargets.count) 個未來主要目標")
            }
        } catch is CancellationError {
            // Ignore cancellation
        } catch {
            print("[OnboardingViewModel] 載入目標失敗: \(error.localizedDescription)")
            // 不顯示錯誤，因為新用戶可能沒有目標
        }

        isLoadingTargets = false
    }

    /// 將整數距離轉換為精確的距離字符串（用於匹配 availableDistances 字典鍵）
    private func normalizeDistanceForPicker(_ distanceKm: Int) -> String {
        switch distanceKm {
        case 5:
            return "5"
        case 10:
            return "10"
        case 21:
            return "21.0975"  // 半馬
        case 42:
            return "42.195"   // 全馬
        default:
            return String(distanceKm)
        }
    }

    /// 當用戶選擇已有的目標時
    func selectTarget(_ target: Target) {
        selectedTargetKey = target.id
        raceName = target.name

        // 將目標資料填入表單
        raceDate = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        selectedDistance = normalizeDistanceForPicker(target.distanceKm)

        // 從目標時間計算小時和分鐘
        let totalSeconds = target.targetTime
        targetHours = totalSeconds / 3600
        targetMinutes = (totalSeconds % 3600) / 60

        print("[OnboardingViewModel] 選擇已有目標: \(target.name), 距離: \(target.distanceKm)km -> \(selectedDistance)")
    }
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    @State private var showTimeWarning = false
    @State private var showDistanceTimeEditor = false
    // @StateObject private var authService = AuthenticationService.shared // authService 在此 View 未直接使用

    var body: some View {
        VStack {
            Form {
                Section(header: Text(NSLocalizedString("onboarding.your_running_goal", comment: "Your Running Goal")), footer: Text(NSLocalizedString("onboarding.goal_description", comment: "Goal description"))) {
                    // 如果有已存的未來目標，顯示快速選擇列表
                    if !viewModel.availableTargets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("onboarding.or_select_existing_target", comment: "或選擇已設定的未來賽事"))
                                .font(AppFont.bodySmall())
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availableTargets.sorted { a, b in
                                        Date(timeIntervalSince1970: TimeInterval(a.raceDate)) < Date(timeIntervalSince1970: TimeInterval(b.raceDate))
                                    }, id: \.id) { target in
                                        Button(action: {
                                            viewModel.selectTarget(target)
                                        }) {
                                            VStack(spacing: 4) {
                                                Text(target.name)
                                                    .font(AppFont.caption())
                                                    .fontWeight(.semibold)
                                                    .lineLimit(1)
                                                Text("\(target.distanceKm)km")
                                                    .font(AppFont.captionSmall())
                                            }
                                            .frame(minWidth: 80)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(viewModel.selectedTargetKey == target.id ? Color.accentColor : Color(.systemGray6))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(viewModel.selectedTargetKey == target.id ? Color.accentColor : Color(.systemGray3), lineWidth: 1.5)
                                            )
                                            .foregroundColor(viewModel.selectedTargetKey == target.id ? .white : .primary)
                                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    TextField(NSLocalizedString("onboarding.target_race_example", comment: "Target race example"), text: $viewModel.raceName)
                        .textContentType(.name)

                    DatePicker(NSLocalizedString("onboarding.goal_date", comment: "Goal Date"),
                              selection: $viewModel.raceDate,
                              in: Date()...,
                              displayedComponents: .date)
                    
                    Text(String(format: NSLocalizedString("onboarding.weeks_until_race", comment: "Weeks until race"), viewModel.trainingWeeks))
                        .foregroundColor(.secondary)
                }

                // 距離與目標時間（合併為單一卡片，點擊編輯）
                Section(
                    header: Text(NSLocalizedString("onboarding.distance_and_target_time", comment: "距離與目標時間"))
                ) {
                    Button(action: {
                        showDistanceTimeEditor = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                // 距離
                                HStack(spacing: 8) {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("onboarding.race_distance", comment: "Race Distance"))
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Text(viewModel.availableDistances[viewModel.selectedDistance] ?? viewModel.selectedDistance)
                                            .font(AppFont.headline())
                                            .foregroundColor(.primary)
                                    }
                                }

                                Divider()
                                    .padding(.leading, 32)

                                // 目標完賽時間
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("onboarding.target_finish_time", comment: "Target Finish Time"))
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%d:%02d:00", viewModel.targetHours, viewModel.targetMinutes))
                                            .font(AppFont.headline())
                                            .foregroundColor(.primary)
                                    }
                                }

                                Divider()
                                    .padding(.leading, 32)

                                // 配速
                                HStack(spacing: 8) {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("common.pace", comment: "Pace"))
                                            .font(AppFont.caption())
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%@ /km", viewModel.targetPace))
                                            .font(AppFont.headline())
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)

                            Spacer()

                            // 明顯的編輯按鈕
                            VStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.accentColor)
                                Text(NSLocalizedString("common.edit", comment: "Edit"))
                                    .font(AppFont.captionSmall())
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // 底部按鈕
            VStack {
                Button(action: {
                    Task {
                        if await viewModel.createTarget() {
                            handleNavigationAfterTargetCreation()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("RaceSetup_SaveButton")
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            
            Spacer()
        }
        .navigationTitle(NSLocalizedString("onboarding.set_training_goal", comment: "Set Training Goal"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(NSLocalizedString("start_stage.time_too_short_title", comment: "時間較為緊迫"),
               isPresented: $showTimeWarning) {
            Button(NSLocalizedString("common.ok", comment: "確定"), role: .cancel) {
                showTimeWarning = false
            }
        } message: {
            Text(NSLocalizedString("start_stage.time_too_short_message",
                                  comment: "距離賽事不足 2 週，可能無法達到預期的訓練效果。建議選擇更晚的賽事日期。"))
        }
        .toolbar {
            // 右上角「下一步」按鈕
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        if await viewModel.createTarget() {
                            handleNavigationAfterTargetCreation()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("onboarding.next_step", comment: "Next Step"))
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $showDistanceTimeEditor) {
            RaceDistanceTimeEditorSheet(
                selectedDistance: $viewModel.selectedDistance,
                targetHours: $viewModel.targetHours,
                targetMinutes: $viewModel.targetMinutes,
                availableDistances: viewModel.availableDistances
            )
        }
        .onAppear {
            // 載入用戶已設定的未來目標
            Task {
                await viewModel.loadAvailableTargets()
            }
        }
    }

    // MARK: - 導航邏輯處理
    /// 根據訓練週數判斷導航目標
    private func handleNavigationAfterTargetCreation() {
        let targetDistance = Double(viewModel.selectedDistance) ?? 42.195
        let standardWeeks = TrainingPlanCalculator.getStandardTrainingWeeks(for: targetDistance)
        let trainingWeeks = viewModel.trainingWeeks
        let isRaceV2Flow = coordinator.selectedTargetTypeId == "race_run"

        // 將 target ID 傳遞給 coordinator，供 V2 流程使用
        coordinator.selectedTargetId = viewModel.selectedTargetKey

        print("[OnboardingView] 🧭 Navigation Decision: trainingWeeks=\(trainingWeeks), standardWeeks=\(standardWeeks), targetId=\(viewModel.selectedTargetKey ?? "nil")")

        if trainingWeeks < 2 {
            // 時間過短（<2週），顯示警告
            showTimeWarning = true
        } else if trainingWeeks >= standardWeeks {
            // 時間充足
            coordinator.selectedStartStage = nil
            UserDefaults.standard.removeObject(forKey: OnboardingCoordinator.startStageUserDefaultsKey)
            coordinator.shouldNavigateToStartStageAfterMethodology = false
            if isRaceV2Flow {
                coordinator.navigate(to: .methodologySelection)
            } else {
                coordinator.navigate(to: .trainingDays)
            }
        } else {
            // 時間緊張
            coordinator.weeksRemaining = trainingWeeks
            coordinator.targetDistance = targetDistance
            coordinator.shouldNavigateToStartStageAfterMethodology = true
            if isRaceV2Flow {
                coordinator.navigate(to: .methodologySelection)
            } else {
                coordinator.navigate(to: .startStage)
            }
        }
    }

}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        // 若要在預覽中測試，需要包裝在 NavigationView 中
        NavigationView {
            OnboardingView()
        }
    }
}
