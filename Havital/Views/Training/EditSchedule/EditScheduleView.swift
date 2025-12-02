import SwiftUI
import Foundation

struct EditScheduleView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingUnsavedChangesAlert = false
    @State private var hasUnsavedChanges = false
    @State private var showingPaceTable = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isEditingLoaded {
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
                        if let vdot = viewModel.currentVDOT, !viewModel.calculatedPaces.isEmpty {
                            Button {
                                showingPaceTable = true
                            } label: {
                                Image(systemName: "speedometer")
                                    .font(.body)
                            }
                        }

                        // 儲存按鈕
                        Button(NSLocalizedString("edit_schedule.save", comment: "儲存")) {
                            Task {
                                await saveChanges()
                            }
                        }
                        .disabled(!hasUnsavedChanges)
                    }
                }
            }
            .sheet(isPresented: $showingPaceTable) {
                if let vdot = viewModel.currentVDOT {
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
            setupEditableWeeklyPlan()
        }
    }

    private func cleanupAndDismiss() {
        viewModel.isEditingLoaded = false
        viewModel.editingDays = []
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
            ForEach($viewModel.editingDays) { $day in
                SimplifiedDailyCard(
                    day: $day,
                    isEditable: true,
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
                viewModel.editingDays.move(fromOffsets: source, toOffset: destination)
                for i in viewModel.editingDays.indices {
                    viewModel.editingDays[i].dayIndex = "\(i + 1)"
                }
                hasUnsavedChanges = true
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Private Methods

    private func setupEditableWeeklyPlan() {
        guard let weeklyPlan = viewModel.weeklyPlan else { return }
        // 直接存到 ViewModel 中，確保不會因 View 重建而丟失
        viewModel.editingDays = weeklyPlan.days.map { MutableTrainingDay(from: $0) }
        viewModel.editingDays.sort(by: { $0.dayIndexInt < $1.dayIndexInt })
        viewModel.isEditingLoaded = true
    }

    private func canEditDay(_ dayIndex: Int) -> Bool {
        guard let dayDate = viewModel.getDateForDay(dayIndex: dayIndex) else { return false }
        let today = Calendar.current.startOfDay(for: Date())

        // TODO: 先設定為true，之後再設定為false
        return true

        // 只有今天以後的日期才能編輯
        guard dayDate >= today else {
            return false
        }

        // 檢查當天是否為比賽，比賽日不能編輯
        if dayIndex < viewModel.editingDays.count {
            let dayType = viewModel.editingDays[dayIndex].type
            if dayType == .race {
                return false
            }
        }

        // 檢查是否已有訓練記錄
        let hasWorkouts = !(viewModel.workoutsByDayV2[dayIndex]?.isEmpty ?? true)
        return !hasWorkouts
    }

    private func saveChanges() async {
        guard let originalPlan = viewModel.weeklyPlan else { return }

        do {
            let trainingDays = viewModel.editingDays.map { mutableDay in
                TrainingDay(
                    dayIndex: mutableDay.dayIndex,
                    dayTarget: mutableDay.dayTarget,
                    reason: mutableDay.reason,
                    tips: mutableDay.tips,
                    trainingType: mutableDay.trainingType,
                    trainingDetails: mutableDay.trainingDetails?.toTrainingDetails()
                )
            }

            let updatedPlan = WeeklyPlan(
                id: originalPlan.id,
                purpose: originalPlan.purpose,
                weekOfPlan: originalPlan.weekOfPlan,
                totalWeeks: originalPlan.totalWeeks,
                totalDistance: originalPlan.totalDistance,
                totalDistanceReason: originalPlan.totalDistanceReason,
                designReason: originalPlan.designReason,
                days: trainingDays,
                intensityTotalMinutes: originalPlan.intensityTotalMinutes
            )

            let updatedPlanFromAPI = try await TrainingPlanService.shared.modifyWeeklyPlan(
                planId: originalPlan.id,
                updatedPlan: updatedPlan
            )

            await MainActor.run {
                // 清理編輯狀態
                viewModel.isEditingLoaded = false
                viewModel.editingDays = []
                viewModel.updateWeeklyPlanFromEdit(updatedPlanFromAPI)
                dismiss()
            }

        } catch {
            await MainActor.run {
                showError("\(L10n.EditSchedule.saveFailed.localized)：\(error.localizedDescription)")
            }
        }
    }

    private func showIntensityWarning(_ warning: IntensityWarning) {
        // 顯示強度警告的彈窗或通知
        // 可以根據需要實現具體的 UI
        print("強度警告: \(warning.messages.joined(separator: ", "))")
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
    let viewModel: TrainingPlanViewModel
    var arrayIndex: Int? = nil
    var onDataChanged: (() -> Void)? = nil

    @State private var showingEditSheet = false
    @State private var showingInfoAlert = false

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
        case .interval, .tempo, .progression, .threshold, .combination:
            return Color.orange
        case .longRun, .hiking, .cycling:
            return Color.blue
        case .race:
            return Color.red
        case .rest:
            return Color.gray
        case .crossTraining, .strength:
            return Color.purple
        }
    }

    /// 是否為複雜訓練類型（需要進入詳細編輯）
    private var isComplexTraining: Bool {
        switch day.type {
        case .interval, .combination, .progression:
            return true
        default:
            return false
        }
    }

    /// 複雜訓練的摘要文字
    private var complexTrainingSummary: String {
        guard let details = day.trainingDetails else { return "" }

        switch day.type {
        case .interval:
            if let repeats = details.repeats, let work = details.work {
                let distanceText = work.distanceKm.map { String(format: "%.0fm", $0 * 1000) } ?? ""
                let paceText = work.pace ?? ""
                return "\(repeats) × \(distanceText)" + (paceText.isEmpty ? "" : " @ \(paceText)")
            }
        case .combination, .progression:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "\(segments.count) 段 · \(String(format: "%.1f", total)) km"
            }
        default:
            break
        }
        return ""
    }

    @State private var showingDistancePicker = false
    @State private var showingPacePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 頂部行：日期 + 訓練類型 + 編輯按鈕
            HStack(alignment: .center, spacing: 10) {
                // 日期
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.weekdayName(for: displayDayIndex))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let date = viewModel.getDateForDay(dayIndex: displayDayIndex) {
                        Text(viewModel.formatShortDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 50, alignment: .leading)

                // 訓練類型
                trainingTypeMenu

                Spacer()

                // 編輯按鈕（複雜訓練或需要詳細設定時顯示）
                if day.isTrainingDay {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
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

            // 底部：訓練詳情
            if day.isTrainingDay {
                Rectangle()
                    .fill(getTypeColor().opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                if isComplexTraining {
                    // 複雜訓練：顯示摘要文字
                    Text(complexTrainingSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    // 簡單訓練：可直接編輯的配速/距離
                    HStack(spacing: 12) {
                        // 配速（如果有）
                        if day.trainingDetails?.pace != nil {
                            Button {
                                showingPacePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("配速:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(day.trainingDetails?.pace ?? "")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        // 距離
                        if let distance = day.trainingDetails?.distanceKm ?? day.trainingDetails?.totalDistanceKm {
                            Button {
                                showingDistancePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("距離:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.1f km", distance))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8))
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
            }
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

    // MARK: - Training Type Menu

    @ViewBuilder
    private var trainingTypeMenu: some View {
        if isEditable {
            Menu {
                Section(header: Text(NSLocalizedString("edit_schedule.category_easy", comment: "輕鬆訓練"))) {
                    Button(L10n.EditSchedule.easyRun.localized) { updateTrainingType(.easyRun) }
                    Button(L10n.EditSchedule.recoveryRun.localized) { updateTrainingType(.recovery_run) }
                    Button(L10n.EditSchedule.longEasyRun.localized) { updateTrainingType(.lsd) }
                }
                Section(header: Text(NSLocalizedString("edit_schedule.category_intensity", comment: "強度訓練"))) {
                    Button(L10n.EditSchedule.tempoRun.localized) { updateTrainingType(.tempo) }
                    Button(L10n.EditSchedule.thresholdRun.localized) { updateTrainingType(.threshold) }
                    Button(L10n.EditSchedule.intervalTraining.localized) { updateTrainingType(.interval) }
                    Button(L10n.EditSchedule.combinationRun.localized) { updateTrainingType(.combination) }
                    Button(L10n.EditSchedule.longDistanceRun.localized) { updateTrainingType(.longRun) }
                }
                Section {
                    Button(L10n.EditSchedule.rest.localized) { updateTrainingType(.rest) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(day.type.localizedName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
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
                    .font(.subheadline)
                Button(action: { showingInfoAlert = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                }
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
        }
    }

    private func getEditStatusMessage() -> String {
        return viewModel.getEditStatusMessage(for: displayDayIndex)
    }

    private func updateTrainingType(_ newType: DayType) {
        day.trainingType = newType.rawValue
        let vdot = viewModel.currentVDOT ?? PaceCalculator.defaultVDOT

        switch newType {
        case .rest:
            day.trainingDetails = nil

        case .easyRun, .recovery_run:
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 5.0, pace: suggestedPace)

        case .tempo, .threshold:
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 8.0, pace: suggestedPace)

        case .interval:
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(distanceKm: 0.4, pace: intervalPace),
                recovery: MutableWorkoutSegment(pace: recoveryPace),
                repeats: 4
            )

        case .longRun:
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 15.0, pace: tempoPace)

        case .lsd:
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 20.0, pace: easyPace)

        case .combination:
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

        default:
            day.trainingDetails = MutableTrainingDetails(distanceKm: 6.0)
        }

        onDataChanged?()
    }
}

