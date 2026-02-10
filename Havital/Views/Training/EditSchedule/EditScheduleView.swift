import SwiftUI
import Foundation

struct EditScheduleView: View {
    @ObservedObject var editViewModel: EditScheduleViewModel
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingUnsavedChangesAlert = false
    @State private var hasUnsavedChanges = false
    @State private var showingPaceTable = false
    // @State private var calculatedPaces: [PaceCalculator.PaceZone: String] = [:] // Removed, use viewModel.calculatedPaces or empty

    var body: some View {
        NavigationView {
            Group {
                if editViewModel.isEditingLoaded {
                    // 編輯模式：支持拖拽的 List
                    editModeView()
                } else {
                    ProgressView(NSLocalizedString("edit_schedule.loading_data", comment: "載入編輯資料..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(NSLocalizedString("edit_schedule.title", comment: "編輯週課表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 編輯模式的 toolbar
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        if hasUnsavedChanges {
                            showingUnsavedChangesAlert = true
                        } else {
                            cleanupAndDismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 配速表按鈕
                        if let vdot = editViewModel.currentVDOT, !viewModel.calculatedPaces.isEmpty {
                            Button {
                                showingPaceTable = true
                            } label: {
                                Image(systemName: "speedometer")
                                    .font(AppFont.body())
                            }
                        }

                        // 儲存按鈕
                        Button(NSLocalizedString("edit_schedule.save", comment: "儲存")) {
                            Task {
                                await saveChanges()
                            }.tracked(from: "EditScheduleView: saveChanges")
                        }
                        .disabled(!hasUnsavedChanges)
                    }
                }
            }
            .sheet(isPresented: $showingPaceTable) {
                if let vdot = editViewModel.currentVDOT {
                    PaceTableView(vdot: vdot, calculatedPaces: viewModel.calculatedPaces)
                }
            }
        }
        .alert(NSLocalizedString("edit_schedule.unsaved_changes", comment: "未儲存的變更"), isPresented: $showingUnsavedChangesAlert) {
            Button(NSLocalizedString("edit_schedule.discard_changes", comment: "放棄變更"), role: .destructive) {
                cleanupAndDismiss()
            }
            Button(NSLocalizedString("edit_schedule.cancel", comment: "取消"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("edit_schedule.unsaved_changes_message", comment: "您有未儲存的變更，確定要放棄嗎？"))
        }
        .onAppear {
            Logger.debug("[EditScheduleView] onAppear triggered - isEditingLoaded: \(editViewModel.isEditingLoaded), editingDays: \(editViewModel.editingDays.count)")
            // 數據已經在 ViewModel.init 中初始化，不需要額外操作
        }
    }

    private func cleanupAndDismiss() {
        Logger.debug("[EditScheduleView] cleanupAndDismiss - resetting state")
        editViewModel.isEditingLoaded = false
        editViewModel.editingDays = []
        dismiss()
    }

    // MARK: - Edit Mode View (List with Drag & Drop + Edit)
    // 編輯模式：支持拖拽排序和詳細編輯
    // - 數組位置代表「星期幾」（位置0=周一，位置1=周二...）
    // - 拖拽後，訓練內容移動到新的星期，dayIndex 會自動重新分配
    // - 點擊訓練類型 Menu 可切換訓練類型
    // - 點擊訓練詳情可進入詳細編輯頁面

    @ViewBuilder
    private func editModeView() -> some View {
        List {
            ForEach($editViewModel.editingDays) { $day in
                SimplifiedDailyCard(
                    day: $day,
                    isEditable: true,
                    editViewModel: editViewModel,
                    viewModel: viewModel,
                    arrayIndex: nil,
                    onDataChanged: {
                        hasUnsavedChanges = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .onMove { source, destination in
                editViewModel.editingDays.move(fromOffsets: source, toOffset: destination)
                for i in editViewModel.editingDays.indices {
                    editViewModel.editingDays[i].dayIndex = "\(i + 1)"
                }
                hasUnsavedChanges = true
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Private Methods

    private func setupEditableWeeklyPlan() {
        // 使用 EditScheduleViewModel 的 initializeEditing 方法
        editViewModel.initializeEditing()
    }

    private func canEditDay(_ dayIndex: Int) -> Bool {
        guard let dayDate = editViewModel.getDateForDay(dayIndex: dayIndex) else { return false }
        let today = Calendar.current.startOfDay(for: Date())

        return true
    }

    private func saveChanges() async {
        do {
            // 保存並獲取更新後的 plan
            let savedPlan = try await editViewModel.saveEdits()

            // ✅ 直接更新 state（無閃爍，因為 Repository 已更新緩存）
            Logger.debug("[EditScheduleView] 保存成功，直接更新 UI state")
            await MainActor.run {
                // 更新 WeeklyPlanVM state（單一數據源）
                viewModel.weeklyPlanVM.state = .loaded(savedPlan)
                // 同步更新 planStatus（向下兼容）
                viewModel.planStatus = .ready(savedPlan)
            }

            await MainActor.run {
                // 清理編輯狀態並關閉 sheet
                Logger.debug("[EditScheduleView] saveChanges success - resetting state")
                editViewModel.isEditingLoaded = false
                editViewModel.editingDays = []
                dismiss()
            }

        } catch {
            await MainActor.run {
                showError("\(L10n.EditSchedule.saveFailed.localized)：\(error.localizedDescription)")
            }
        }
    }

    private func showError(_ message: String) {
        // 顯示錯誤訊息的彈窗或通知
        // 可以根據需要實現具體的 UI
        print("錯誤: \(message)")
    }
}

// MARK: - Simplified Daily Card (for Edit Mode with Drag & Edit)

struct SimplifiedDailyCard: View {
    @Binding var day: MutableTrainingDay
    let isEditable: Bool
    let editViewModel: EditScheduleViewModel
    let viewModel: TrainingPlanViewModel
    var arrayIndex: Int? = nil
    var onDataChanged: (() -> Void)? = nil

    @State private var showingEditSheet = false
    @State private var showingInfoAlert = false
    @State private var showingDistancePicker = false
    @State private var showingPacePicker = false

    private var displayDayIndex: Int {
        if let index = arrayIndex {
            return index + 1
        }
        return day.dayIndexInt
    }

    private func getTypeColor() -> Color {
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return Color.green
        case .interval, .tempo, .progression, .threshold, .combination, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
            return Color.orange
        case .longRun, .hiking, .cycling, .fastFinish:
            return Color.blue
        case .race, .racePace:
            return Color.red
        case .rest:
            return Color.gray
        case .crossTraining, .strength, .fartlek, .swimming, .elliptical, .rowing:
            return Color.purple
        }
    }

    /// 是否為複雜訓練類型（需要進入詳細編輯）
    private var isComplexTraining: Bool {
        switch day.type {
        case .interval, .combination, .progression,
             .strides, .hillRepeats, .cruiseIntervals,
             .shortInterval, .longInterval, .norwegian4x4, .yasso800,
             .fartlek, .fastFinish:
            return true
        default:
            return false
        }
    }

    /// 複雜訓練的摘要文字
    private var complexTrainingSummary: String {
        guard let details = day.trainingDetails else { return "" }

        switch day.type {
        case .interval, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval:
            if let repeats = details.repeats, let work = details.work {
                let distanceText = work.distanceKm.map { String(format: "%.0fm", $0 * 1000) } ?? ""
                let paceText = work.pace ?? ""
                return "\(repeats) × \(distanceText)" + (paceText.isEmpty ? "" : " @ \(paceText)")
            }
        case .norwegian4x4:
            // 挪威4x4：時間制間歇（顯示時間 + 計算出的距離）
            if let repeats = details.repeats, let work = details.work {
                let timeText = work.timeMinutes.map { "\(Int($0))分鐘" } ?? ""
                // 顯示計算出的距離（約 XXXm）
                let distanceText: String
                if let distanceM = work.distanceM {
                    distanceText = " (約\(Int(distanceM))m)"
                } else {
                    distanceText = ""
                }
                let paceText = work.pace ?? ""
                return "🇳🇴 \(repeats) × \(timeText)\(distanceText)" + (paceText.isEmpty ? "" : " @ \(paceText)")
            }
        case .yasso800:
            // 亞索800：800m 間歇
            if let repeats = details.repeats, let work = details.work {
                let distanceText = work.distanceKm.map { String(format: "%.0fm", $0 * 1000) } ?? "800m"
                let paceText = work.pace ?? ""
                return "\(repeats) × \(distanceText)" + (paceText.isEmpty ? "" : " @ \(paceText)")
            }
        case .combination, .progression:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "\(segments.count) 段 · \(String(format: "%.1f", total)) km"
            }
        case .fartlek:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "法特雷克 · \(String(format: "%.1f", total)) km"
            }
        case .fastFinish:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "快結尾 · \(String(format: "%.1f", total)) km"
            }
        default:
            break
        }
        return ""
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(editViewModel.weekdayName(for: "\(displayDayIndex)"))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let date = editViewModel.getDateForDay(dayIndex: displayDayIndex) {
                    Text(editViewModel.formatShortDate(date))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, alignment: .leading)

            trainingTypeMenu

            Spacer()

            if day.isTrainingDay {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(AppFont.body())
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var detailsView: some View {
        Group {
            if day.isTrainingDay {
                Rectangle()
                    .fill(getTypeColor().opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                if isComplexTraining {
                    Text(complexTrainingSummary)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    simpleTrainingControls
                }
            }
        }
    }

    private var simpleTrainingControls: some View {
        HStack(spacing: 12) {
            if day.trainingDetails?.pace != nil {
                Button {
                    showingPacePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("配速:")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Text(day.trainingDetails?.pace ?? "")
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            if let distance = day.trainingDetails?.distanceKm ?? day.trainingDetails?.totalDistanceKm {
                Button {
                    showingDistancePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("距離:")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f km", distance))
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Training Type Menu

    @ViewBuilder
    private var trainingTypeMenu: some View {
        if isEditable {
            Menu {
                // 輕鬆訓練 🟢
                Section(header: Text(NSLocalizedString("edit_schedule.category_easy", comment: "輕鬆訓練"))) {
                    Button(L10n.EditSchedule.easyRun.localized) { updateTrainingType(.easyRun) }
                    Button(L10n.EditSchedule.recoveryRun.localized) { updateTrainingType(.recovery_run) }
                }
                // 強度訓練 🟠
                Section(header: Text(NSLocalizedString("edit_schedule.category_intensity", comment: "強度訓練"))) {
                    Button(L10n.EditSchedule.tempoRun.localized) { updateTrainingType(.tempo) }
                    Button(L10n.EditSchedule.thresholdRun.localized) { updateTrainingType(.threshold) }
                    Button(L10n.EditSchedule.intervalTraining.localized) { updateTrainingType(.interval) }
                    // 間歇訓練類型
                    Button(DayType.strides.localizedName) { updateTrainingType(.strides) }
                    Button(DayType.hillRepeats.localizedName) { updateTrainingType(.hillRepeats) }
                    Button(DayType.cruiseIntervals.localizedName) { updateTrainingType(.cruiseIntervals) }
                    Button(DayType.shortInterval.localizedName) { updateTrainingType(.shortInterval) }
                    Button(DayType.longInterval.localizedName) { updateTrainingType(.longInterval) }
                    Button(DayType.norwegian4x4.localizedName) { updateTrainingType(.norwegian4x4) }
                    Button(DayType.yasso800.localizedName) { updateTrainingType(.yasso800) }
                    // 組合訓練類型
                    Button(DayType.fartlek.localizedName) { updateTrainingType(.fartlek) }
                    // 比賽配速訓練
                    Button(DayType.racePace.localizedName) { updateTrainingType(.racePace) }
                    Button(L10n.EditSchedule.combinationRun.localized) { updateTrainingType(.combination) }
                }
                // 長距離訓練 🔵
                Section(header: Text(NSLocalizedString("edit_schedule.category_long", comment: "長距離訓練"))) {
                    Button(L10n.EditSchedule.longEasyRun.localized) { updateTrainingType(.lsd) }
                    Button(L10n.EditSchedule.longDistanceRun.localized) { updateTrainingType(.longRun) }
                    Button(DayType.progression.localizedName) { updateTrainingType(.progression) }
                    Button(DayType.fastFinish.localizedName) { updateTrainingType(.fastFinish) }
                }
                // 其他
                Section(header: Text(NSLocalizedString("edit_schedule.category_other", comment: "其他"))) {
                    Button(L10n.EditSchedule.rest.localized) { updateTrainingType(.rest) }
                    Button(DayType.crossTraining.localizedName) { updateTrainingType(.crossTraining) }
                    Button(DayType.strength.localizedName) { updateTrainingType(.strength) }
                    Button(DayType.yoga.localizedName) { updateTrainingType(.yoga) }
                    Button(DayType.hiking.localizedName) { updateTrainingType(.hiking) }
                    Button(DayType.cycling.localizedName) { updateTrainingType(.cycling) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(day.type.localizedName)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(AppFont.caption())
                }
                .foregroundColor(getTypeColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(getTypeColor().opacity(0.15))
                .cornerRadius(8)
            }
        } else {
            HStack(spacing: 4) {
                Text(day.type.localizedName)
                    .font(AppFont.bodySmall())
                Button(action: { showingInfoAlert = true }) {
                    Image(systemName: "info.circle")
                        .font(AppFont.caption())
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            detailsView
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getTypeColor().opacity(0.4), lineWidth: 1.5)
        )
        .sheet(isPresented: $showingEditSheet) {
            TrainingEditSheetV2(
                day: day,
                onSave: { updatedDay in
                    day = updatedDay
                    onDataChanged?()
                },
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showingDistancePicker) {
            DistanceWheelPicker(selectedDistance: Binding(
                get: { day.trainingDetails?.distanceKm ?? 5.0 },
                set: { newValue in
                    if var details = day.trainingDetails {
                        details.distanceKm = newValue
                        day.trainingDetails = details
                        onDataChanged?()
                    }
                }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingPacePicker) {
            PaceWheelPicker(
                selectedPace: Binding(
                    get: { day.trainingDetails?.pace ?? "5:00" },
                    set: { newValue in
                        if var details = day.trainingDetails {
                            details.pace = newValue
                            day.trainingDetails = details
                            onDataChanged?()
                        }
                    }
                ),
                referenceDistance: day.trainingDetails?.distanceKm
            )
            .presentationDetents([.height(380)])
        }
        .alert(L10n.EditSchedule.cannotEdit.localized, isPresented: $showingInfoAlert) {
            Button(L10n.EditSchedule.confirm.localized, role: .cancel) { }
        } message: {
            Text(getEditStatusMessage())
        }
    }
    
    private func getEditStatusMessage() -> String {
        return editViewModel.getEditStatusMessage(for: displayDayIndex)
    }

    private func updateTrainingType(_ newType: DayType) {
        day.trainingType = newType.rawValue
        let vdot = editViewModel.currentVDOT ?? PaceCalculator.defaultVDOT

        switch newType {
        case .rest:
            day.dayTarget = "休息日"
            day.trainingDetails = nil

        case .easyRun, .easy, .recovery_run:
            day.dayTarget = newType == .easyRun || newType == .easy ? "輕鬆跑：恢復和建立有氧基礎" : "恢復跑：低強度恢復訓練"
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 5.0, pace: suggestedPace)

        case .tempo, .threshold:
            day.dayTarget = newType == .tempo ? "節奏跑：乳酸閾值訓練" : "閾值跑：提升乳酸清除能力"
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 8.0, pace: suggestedPace)

        case .interval:
            day.dayTarget = "間歇訓練：提升VO2max和速度"
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.4,
                    distanceM: 400,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.2,
                    distanceM: 200,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: recoveryPace,
                    heartRateRange: nil
                ),
                repeats: 4
            )

        // 🏃‍♂️ 大步跑：短距離衝刺（如 6x100m），用於提升跑步經濟性
        case .strides:
            day.dayTarget = "大步跑：短距離衝刺，提升跑步經濟性"
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.1,
                    distanceM: 100,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "原地休息1分鐘",
                    distanceKm: nil,
                    distanceM: nil,
                    timeMinutes: 1.0,
                    pace: nil,
                    heartRateRange: nil
                ),
                repeats: 6
            )

        // ⛰️ 山坡重複跑：上坡衝刺，下坡恢復，訓練腿部力量
        case .hillRepeats:
            day.dayTarget = "山坡重複跑：上坡衝刺訓練腿部力量"
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            day.trainingDetails = MutableTrainingDetails(
                description: "找一個約 5-8% 坡度的山坡進行訓練",
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.2,
                    distanceM: 200,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "慢跑下坡恢復",
                    distanceKm: nil,
                    distanceM: nil,
                    timeMinutes: 2.0,
                    pace: nil,
                    heartRateRange: nil
                ),
                repeats: 6
            )

        // 🚢 巡航間歇：閾值配速間歇（如 4x1000m@T配速）
        case .cruiseIntervals:
            day.dayTarget = "巡航間歇：閾值配速間歇訓練"
            let thresholdPace = PaceCalculator.getSuggestedPace(for: "threshold", vdot: vdot) ?? "4:45"
            let recoveryPaceCruise = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            // 計算恢復段距離（1分鐘恢復跑）
            let recoveryDistanceM_Cruise = calculateDistanceMeters(pace: recoveryPaceCruise, timeMinutes: 1.0)
            let recoveryDistanceKm_Cruise = recoveryDistanceM_Cruise.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致
            day.trainingDetails = MutableTrainingDetails(
                description: "巡航間歇：閾值配速間歇，Jack Daniels 原則每5分鐘T配速需1分鐘恢復",
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 1.0,
                    distanceM: 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: thresholdPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "恢復跑1分鐘",
                    distanceKm: recoveryDistanceKm_Cruise,
                    distanceM: recoveryDistanceM_Cruise,
                    timeMinutes: 1.0,  // 改為時間基準，符合 Jack Daniels 原則
                    pace: recoveryPaceCruise,
                    heartRateRange: nil
                ),
                repeats: 4
            )

        case .longRun:
            day.dayTarget = "長距離跑：建立耐力基礎"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 15.0, pace: tempoPace)

        case .lsd:
            day.dayTarget = "LSD長距離慢跑：輕鬆配速建立有氧基礎"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 20.0, pace: easyPace)

        case .progression:
            day.dayTarget = "漸進配速跑：從慢到快逐漸加速"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 12.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 4.0, pace: easyPace, description: "輕鬆配速"),
                    MutableProgressionSegment(distanceKm: 4.0, pace: tempoPace, description: "節奏配速"),
                    MutableProgressionSegment(distanceKm: 4.0, pace: "4:30", description: "加速")
                ]
            )

        case .race:
            day.dayTarget = "比賽日"
            day.trainingDetails = nil

        case .combination:
            day.dayTarget = "組合訓練：多配速混合訓練"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 10.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 3.0, pace: easyPace, description: "輕鬆跑"),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: "節奏跑"),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "輕鬆跑")
                ]
            )

        // 🎲 法特雷克：變速跑，快慢交替，無固定結構
        case .fartlek:
            day.dayTarget = "法特雷克：變速跑訓練配速轉換能力"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            day.trainingDetails = MutableTrainingDetails(
                description: "變速跑：根據感覺自由切換快慢配速",
                totalDistanceKm: 8.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "熱身"),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: "快跑"),
                    MutableProgressionSegment(distanceKm: 0.5, pace: easyPace, description: "慢跑"),
                    MutableProgressionSegment(distanceKm: 0.5, pace: intervalPace, description: "衝刺"),
                    MutableProgressionSegment(distanceKm: 1.0, pace: easyPace, description: "恢復"),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: "快跑"),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "收操")
                ]
            )

        // 🚀 快結尾長跑：前 70% 輕鬆，後 30% 加速
        case .fastFinish:
            day.dayTarget = "快結尾長跑：後段加速訓練"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                description: "長跑後段加速，訓練疲勞狀態下的配速維持能力",
                totalDistanceKm: 16.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 11.0, pace: easyPace, description: "輕鬆跑 (70%)"),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: "節奏跑 (30%)")
                ]
            )

        // 🏁 比賽配速跑：以目標比賽配速進行的訓練（非正式比賽）
        case .racePace:
            day.dayTarget = "比賽配速跑：熟悉目標比賽節奏"
            // 使用馬拉松配速作為預設比賽配速
            let racePace = PaceCalculator.getSuggestedPace(for: "marathon", vdot: vdot) ?? "5:15"
            day.trainingDetails = MutableTrainingDetails(
                description: "以目標比賽配速進行訓練，熟悉比賽節奏",
                distanceKm: 10.0,
                pace: racePace
            )

        // 🏃 短間歇：200-400m 快跑，提升速度和無氧能力
        case .shortInterval:
            day.dayTarget = "短間歇：提升速度和無氧能力"
            let intervalPaceShort = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let recoveryPaceShort = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                description: "短距離高強度重複跑，提升速度、無氧能力和跑步經濟性（非主要有氧訓練）",
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.4,
                    distanceM: 400,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPaceShort,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "恢復跑",
                    distanceKm: 0.4,
                    distanceM: 400,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: recoveryPaceShort,
                    heartRateRange: nil
                ),
                repeats: 12
            )

        // 🏃‍♂️ 長間歇：800-1600m 間歇，增強速耐力
        case .longInterval:
            day.dayTarget = "長間歇：提升VO2max和速度耐力"
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:30"

            // 計算恢復段距離（2.5分鐘輕鬆跑）
            let recoveryDistanceM = calculateDistanceMeters(pace: easyPace, timeMinutes: 2.5)
            let recoveryDistanceKm = recoveryDistanceM.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致

            day.trainingDetails = MutableTrainingDetails(
                description: "長距離間歇訓練，提升 VO2max 和速度耐力",
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 1.0,
                    distanceM: 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: iPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "輕鬆跑恢復",
                    distanceKm: recoveryDistanceKm,
                    distanceM: recoveryDistanceM,
                    timeMinutes: 2.5,
                    pace: easyPace,
                    heartRateRange: nil
                ),
                repeats: 5
            )

        // 🇳🇴 挪威4x4訓練：4 x 4分鐘高強度間歇，提升VO2max
        case .norwegian4x4:
            // 更新 dayTarget 說明
            day.dayTarget = "挪威4x4：4組4分鐘高強度間歇（92% VO2max），組間恢復跑3分鐘"

            // 使用自訂 92% VO2max 配速（介於閾值88%和間歇95%之間）
            let norwegian4x4Pace = PaceCalculator.getPaceForPercentage(0.92, vdot: vdot)
            let recoveryPaceN4x4 = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"

            let workTimeMinutes = 4.0
            let recoveryTimeMinutes = 3.0

            // 計算工作段距離（基於4分鐘 × 配速）
            let workDistanceM = calculateDistanceMeters(pace: norwegian4x4Pace, timeMinutes: workTimeMinutes) ?? 900.0
            let workDistanceKm = workDistanceM / 1000.0  // 確保 distanceKm 與 distanceM 一致
            // 計算恢復段距離（基於3分鐘 × 恢復配速）
            let recoveryDistanceM_N4x4 = calculateDistanceMeters(pace: recoveryPaceN4x4, timeMinutes: recoveryTimeMinutes)
            let recoveryDistanceKm_N4x4 = recoveryDistanceM_N4x4.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致

            day.trainingDetails = MutableTrainingDetails(
                description: "挪威4x4訓練：4趟約4分鐘高強度間歇（92% VO2max）",
                work: MutableWorkoutSegment(
                    description: "高強度跑（92% VO2max）",
                    distanceKm: workDistanceKm,
                    distanceM: workDistanceM,
                    timeMinutes: workTimeMinutes,
                    pace: norwegian4x4Pace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "恢復跑3分鐘",
                    distanceKm: recoveryDistanceKm_N4x4,
                    distanceM: recoveryDistanceM_N4x4,
                    timeMinutes: recoveryTimeMinutes,
                    pace: recoveryPaceN4x4,
                    heartRateRange: nil
                ),
                repeats: 4
            )

        // 🎯 亞索800：800m 重複跑，VO2max 訓練
        // 亞索800 的配速接近間歇配速（你的 800m 時間對應馬拉松完賽時間）
        case .yasso800:
            day.dayTarget = "亞索800：800m重複跑，VO2max訓練"
            // 使用間歇配速（800m 配速比馬拉松配速快很多）
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"

            // 計算800m需要的時間（距離0.8km ÷ 配速）
            let timeForWorkSegment = calculateTimeForDistance(distanceKm: 0.8, pace: intervalPace)

            // 計算恢復段距離（恢復時間等於工作時間）
            let recoveryDistanceM = calculateDistanceMeters(pace: recoveryPace, timeMinutes: timeForWorkSegment ?? 4.0)
            let recoveryDistanceKm = recoveryDistanceM.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致

            day.trainingDetails = MutableTrainingDetails(
                description: "亞索800訓練：800m間歇配速重複跑。等時恢復可直接預測馬拉松成績：800m時間（分:秒）= 馬拉松完賽時間（時:分）",
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.8,
                    distanceM: 800,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: "恢復跑（等時恢復）",
                    distanceKm: recoveryDistanceKm,
                    distanceM: recoveryDistanceM,
                    timeMinutes: timeForWorkSegment,
                    pace: recoveryPace,
                    heartRateRange: nil
                ),
                repeats: 8
            )

        // 非跑步訓練類型
        case .crossTraining:
            day.dayTarget = "交叉訓練：非跑步運動訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .strength:
            day.dayTarget = "肌力訓練：增強肌肉力量"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .yoga:
            day.dayTarget = "瑜珈：柔軟度和恢復訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .hiking:
            day.dayTarget = "登山健行：有氧耐力訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .cycling:
            day.dayTarget = "騎車：低衝擊有氧訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        default:
            day.dayTarget = "自訂訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 6.0)
        }

        onDataChanged?()
    }

    /// 根據距離和配速計算所需時間（分鐘）
    /// - Parameters:
    ///   - distanceKm: 距離（公里）
    ///   - pace: 配速字串，格式為 "mm:ss" (例如 "5:15")
    /// - Returns: 時間（分鐘），或 nil 如果無法計算
    private func calculateTimeForDistance(distanceKm: Double, pace: String) -> Double? {
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        let paceMinutes = Double(components[0])
        let paceSeconds = Double(components[1])
        let paceMinutesPerKm = paceMinutes + paceSeconds / 60.0

        guard paceMinutesPerKm > 0 else { return nil }
        return distanceKm * paceMinutesPerKm
    }

    /// 根據配速和時間計算距離（公里）
    /// - Parameters:
    ///   - pace: 配速字串，格式為 "mm:ss" (例如 "5:15")
    ///   - timeMinutes: 時間（分鐘）
    /// - Returns: 距離（公里），或 nil 如果無法計算
    private func calculateDistanceFromPace(pace: String, timeMinutes: Double) -> Double? {
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        let paceMinutes = Double(components[0])
        let paceSeconds = Double(components[1])
        let paceMinutesPerKm = paceMinutes + paceSeconds / 60.0

        guard paceMinutesPerKm > 0 else { return nil }
        return timeMinutes / paceMinutesPerKm
    }

    /// 根據配速和時間計算距離（公尺），並四捨五入到100公尺
    /// - Parameters:
    ///   - pace: 配速字串，格式為 "mm:ss" (例如 "4:45")
    ///   - timeMinutes: 時間（分鐘）
    ///   - roundTo: 四捨五入的單位（預設 100 公尺）
    /// - Returns: 距離（公尺），或 nil 如果無法計算
    private func calculateDistanceMeters(pace: String, timeMinutes: Double, roundTo: Double = 100.0) -> Double? {
        guard let distanceKm = calculateDistanceFromPace(pace: pace, timeMinutes: timeMinutes) else {
            return nil
        }
        let meters = distanceKm * 1000.0
        return round(meters / roundTo) * roundTo
    }
}

