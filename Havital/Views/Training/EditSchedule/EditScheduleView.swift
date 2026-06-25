// [V1 DEPRECATED] V1 週課表編輯視圖，未來將隨 V1 移除。
// V2 對應: Features/TrainingPlanV2/Presentation/Views/EditScheduleViewV2.swift
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
                        if editViewModel.currentVDOT != nil {
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
                    PaceTableView(vdot: vdot, calculatedPaces: PaceCalculator.calculateTrainingPaces(vdot: vdot))
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
        case .interval, .tempo, .progression, .threshold, .combination, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .norwegianSingles, .yasso800:
            return Color.orange
        case .longRun, .hiking, .cycling, .fastFinish:
            return Color.blue
        case .race, .racePace:
            return Color.red
        case .benchmark:
            return Color.indigo
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
                let timeText = work.timeMinutes.map { String(format: NSLocalizedString("schedule_editor.minutes_format", comment: ""), Int($0)) } ?? ""
                // 顯示計算出的距離（約 XXXm）
                let distanceText: String
                if let distanceM = work.distanceM {
                    distanceText = String(format: NSLocalizedString("schedule_editor.approx_distance_format", comment: ""), Int(distanceM))
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
                return "\(segments.count) \(L10n.Training.segmentsUnit.localized) · \(String(format: "%.1f", total)) km"
            }
        case .fartlek:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "\(L10n.Training.TrainingType.fartlek.localized) · \(String(format: "%.1f", total)) km"
            }
        case .fastFinish:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "\(L10n.Training.TrainingType.fastFinish.localized) · \(String(format: "%.1f", total)) km"
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
                        Text(L10n.EditSchedule.paceLabel.localized)
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
                        Text(L10n.EditSchedule.distanceLabel.localized)
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
                paceHelper: PaceCalculationHelper(vdot: editViewModel.currentVDOT)
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.rest", comment: "")
            day.trainingDetails = nil

        case .easyRun, .easy, .recovery_run:
            day.dayTarget = newType == .easyRun || newType == .easy ? NSLocalizedString("schedule_editor.daytarget.easy_run", comment: "") : NSLocalizedString("schedule_editor.daytarget.recovery_run", comment: "")
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 5.0, pace: suggestedPace)

        case .tempo, .threshold:
            day.dayTarget = newType == .tempo ? NSLocalizedString("schedule_editor.daytarget.marathon_pace", comment: "") : NSLocalizedString("schedule_editor.daytarget.threshold", comment: "")
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 8.0, pace: suggestedPace)

        case .interval:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.interval", comment: "")
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.strides", comment: "")
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
                    description: String(format: NSLocalizedString("schedule_editor.segment.rest_in_place_minutes", comment: ""), 1),
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.hill_repeats", comment: "")
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.hill_repeats", comment: ""),
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.2,
                    distanceM: 200,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: NSLocalizedString("schedule_editor.segment.jog_downhill", comment: ""),
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.cruise_intervals", comment: "")
            let thresholdPace = PaceCalculator.getSuggestedPace(for: "threshold", vdot: vdot) ?? "4:45"
            let recoveryPaceCruise = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            // 計算恢復段距離（1分鐘恢復跑）
            let recoveryDistanceM_Cruise = calculateDistanceMeters(pace: recoveryPaceCruise, timeMinutes: 1.0)
            let recoveryDistanceKm_Cruise = recoveryDistanceM_Cruise.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致
            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.cruise_intervals", comment: ""),
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 1.0,
                    distanceM: 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: thresholdPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: String(format: NSLocalizedString("schedule_editor.segment.recovery_run_minutes", comment: ""), 1),
                    distanceKm: recoveryDistanceKm_Cruise,
                    distanceM: recoveryDistanceM_Cruise,
                    timeMinutes: 1.0,  // 改為時間基準，符合 Jack Daniels 原則
                    pace: recoveryPaceCruise,
                    heartRateRange: nil
                ),
                repeats: 4
            )

        case .longRun:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.long_run", comment: "")
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 15.0, pace: tempoPace)

        case .lsd:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.lsd", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 20.0, pace: easyPace)

        case .progression:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.progression", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 12.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 4.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.easy_pace", comment: "")),
                    MutableProgressionSegment(distanceKm: 4.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.marathon_pace", comment: "")),
                    MutableProgressionSegment(distanceKm: 4.0, pace: "4:30", description: NSLocalizedString("schedule_editor.segment.accelerate", comment: ""))
                ]
            )

        case .race:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.race_day", comment: "")
            day.trainingDetails = nil

        case .combination:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.combo", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 10.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 3.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.easy_run", comment: "")),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.marathon_pace", comment: "")),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.easy_run", comment: ""))
                ]
            )

        // 🎲 法特雷克：變速跑，快慢交替，無固定結構
        case .fartlek:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.fartlek", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.fartlek", comment: ""),
                totalDistanceKm: 8.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.warmup", comment: "")),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.fast_run", comment: "")),
                    MutableProgressionSegment(distanceKm: 0.5, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.jog", comment: "")),
                    MutableProgressionSegment(distanceKm: 0.5, pace: intervalPace, description: NSLocalizedString("schedule_editor.segment.sprint", comment: "")),
                    MutableProgressionSegment(distanceKm: 1.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.recovery", comment: "")),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.fast_run", comment: "")),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.cooldown", comment: ""))
                ]
            )

        // 🚀 快結尾長跑：前 70% 輕鬆，後 30% 加速
        case .fastFinish:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.fast_finish", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.fast_finish", comment: ""),
                totalDistanceKm: 16.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 11.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.easy_run_70", comment: "")),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.marathon_pace_30", comment: ""))
                ]
            )

        // 🏁 比賽配速跑：以目標比賽配速進行的訓練（非正式比賽）
        case .racePace:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.race_pace", comment: "")
            // 使用馬拉松配速作為預設比賽配速
            let racePace = PaceCalculator.getSuggestedPace(for: "marathon", vdot: vdot) ?? "5:15"
            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.race_pace", comment: ""),
                distanceKm: 10.0,
                pace: racePace
            )

        // 🏃 短間歇：200-400m 快跑，提升速度和無氧能力
        case .shortInterval:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.short_interval", comment: "")
            let intervalPaceShort = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let recoveryPaceShort = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.short_interval", comment: ""),
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.4,
                    distanceM: 400,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPaceShort,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: NSLocalizedString("schedule_editor.segment.recovery_run", comment: ""),
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.long_interval", comment: "")
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:30"

            // 計算恢復段距離（2.5分鐘輕鬆跑）
            let recoveryDistanceM = calculateDistanceMeters(pace: easyPace, timeMinutes: 2.5)
            let recoveryDistanceKm = recoveryDistanceM.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致

            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.long_interval", comment: ""),
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 1.0,
                    distanceM: 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: iPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: NSLocalizedString("schedule_editor.segment.easy_jog_recovery", comment: ""),
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.norwegian_4x4", comment: "")

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
                description: NSLocalizedString("schedule_editor.detail.norwegian_4x4", comment: ""),
                work: MutableWorkoutSegment(
                    description: NSLocalizedString("schedule_editor.segment.hard_run_vo2", comment: ""),
                    distanceKm: workDistanceKm,
                    distanceM: workDistanceM,
                    timeMinutes: workTimeMinutes,
                    pace: norwegian4x4Pace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: String(format: NSLocalizedString("schedule_editor.segment.recovery_run_minutes", comment: ""), 3),
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.yasso_800", comment: "")
            // 使用間歇配速（800m 配速比馬拉松配速快很多）
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"

            // 計算800m需要的時間（距離0.8km ÷ 配速）
            let timeForWorkSegment = calculateTimeForDistance(distanceKm: 0.8, pace: intervalPace)

            // 計算恢復段距離（恢復時間等於工作時間）
            let recoveryDistanceM = calculateDistanceMeters(pace: recoveryPace, timeMinutes: timeForWorkSegment ?? 4.0)
            let recoveryDistanceKm = recoveryDistanceM.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致

            day.trainingDetails = MutableTrainingDetails(
                description: NSLocalizedString("schedule_editor.detail.yasso_800", comment: ""),
                work: MutableWorkoutSegment(
                    description: nil,
                    distanceKm: 0.8,
                    distanceM: 800,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: intervalPace,
                    heartRateRange: nil
                ),
                recovery: MutableWorkoutSegment(
                    description: NSLocalizedString("schedule_editor.segment.recovery_run_equal", comment: ""),
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
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.cross_training", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .strength:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.strength", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .yoga:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.yoga", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .hiking:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.hiking", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        case .cycling:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.cycling", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)

        default:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.custom", comment: "")
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
