import SwiftUI
import Foundation

struct EditScheduleView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editableWeeklyPlan: MutableWeeklyPlan?
    @State private var showingUnsavedChangesAlert = false
    @State private var hasUnsavedChanges = false
    @State private var showingPaceTable = false
    @State private var isReorderMode = false  // 是否在排序模式

    var body: some View {
        NavigationView {
            Group {
                if let editablePlan = Binding($editableWeeklyPlan) {
                    if isReorderMode {
                        // 排序模式：使用 List + onMove
                        reorderModeView(editablePlan: editablePlan)
                    } else {
                        // 編輯模式：顯示完整卡片
                        editModeView(editablePlan: editablePlan.wrappedValue)
                    }
                } else {
                    ProgressView(NSLocalizedString("edit_schedule.loading_data", comment: "載入編輯資料..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(isReorderMode
                ? NSLocalizedString("edit_schedule.reorder_title", comment: "調整順序")
                : NSLocalizedString("edit_schedule.title", comment: "編輯週課表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isReorderMode {
                    // 排序模式的 toolbar
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                            // 取消排序，恢復原始順序
                            setupEditableWeeklyPlan()
                            withAnimation(.spring(response: 0.3)) {
                                isReorderMode = false
                            }
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("edit_schedule.done", comment: "完成")) {
                            withAnimation(.spring(response: 0.3)) {
                                isReorderMode = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    // 編輯模式的 toolbar
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                            if hasUnsavedChanges {
                                showingUnsavedChangesAlert = true
                            } else {
                                dismiss()
                            }
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            // 排序按鈕
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    isReorderMode = true
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.body)
                            }

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
            }
            .sheet(isPresented: $showingPaceTable) {
                if let vdot = viewModel.currentVDOT {
                    PaceTableView(vdot: vdot, calculatedPaces: viewModel.calculatedPaces)
                }
            }
        }
        .alert(NSLocalizedString("edit_schedule.unsaved_changes", comment: "未儲存的變更"), isPresented: $showingUnsavedChangesAlert) {
            Button(NSLocalizedString("edit_schedule.discard_changes", comment: "放棄變更"), role: .destructive) {
                dismiss()
            }
            Button(NSLocalizedString("edit_schedule.cancel", comment: "取消"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("edit_schedule.unsaved_changes_message", comment: "您有未儲存的變更，確定要放棄嗎？"))
        }
        .onAppear {
            setupEditableWeeklyPlan()
        }
    }

    // MARK: - Reorder Mode View (List + onMove)

    @ViewBuilder
    private func reorderModeView(editablePlan: Binding<MutableWeeklyPlan>) -> some View {
        List {
            ForEach(Array(editablePlan.wrappedValue.days.enumerated()), id: \.element.id) { arrayIndex, day in
                ReorderableRowView(
                    day: day,
                    arrayIndex: arrayIndex,
                    viewModel: viewModel
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .onMove { source, destination in
                moveDay(from: source, to: destination, in: editablePlan)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Edit Mode View (Cards)

    @ViewBuilder
    private func editModeView(editablePlan: MutableWeeklyPlan) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 訓練日卡片
                ForEach(Array(editablePlan.days.enumerated()), id: \.element.id) { arrayIndex, day in
                    SimplifiedDailyCard(
                        day: day,
                        dayIndex: arrayIndex,
                        isEditable: canEditDay(day.dayIndexInt),
                        viewModel: viewModel,
                        onEdit: updateDay
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Private Methods

    private func setupEditableWeeklyPlan() {
        guard let weeklyPlan = viewModel.weeklyPlan else { return }
        var mutablePlan = MutableWeeklyPlan(from: weeklyPlan)
        // 初始化時按 dayIndex 排序，確保顯示順序正確
        mutablePlan.days.sort { $0.dayIndexInt < $1.dayIndexInt }
        editableWeeklyPlan = mutablePlan
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
        if let editablePlan = editableWeeklyPlan,
           dayIndex < editablePlan.days.count {
            let dayType = editablePlan.days[dayIndex].type
            if dayType == .race {
                return false
            }
        }

        // 檢查是否已有訓練記錄
        let hasWorkouts = !(viewModel.workoutsByDayV2[dayIndex]?.isEmpty ?? true)
        return !hasWorkouts
    }

    private func updateDay(_ updatedDay: MutableTrainingDay) {
        // 找到對應的 day 並替換，而不是用 dayIndex 作為數組索引
        guard let editablePlan = editableWeeklyPlan else { return }

        for (index, day) in editablePlan.days.enumerated() {
            if day.dayIndex == updatedDay.dayIndex {
                editableWeeklyPlan?.days[index] = updatedDay
                hasUnsavedChanges = true
                return
            }
        }
    }

    private func moveDay(from source: IndexSet, to destination: Int, in editablePlan: Binding<MutableWeeklyPlan>) {
        // 使用 SwiftUI 原生的 move 方法
        editablePlan.wrappedValue.days.move(fromOffsets: source, toOffset: destination)

        // 重新分配 dayIndex (1-7) 根據新的順序
        reassignDayIndices(in: editablePlan)

        hasUnsavedChanges = true

        // 觸發震動回饋
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func reassignDayIndices(in editablePlan: Binding<MutableWeeklyPlan>) {
        // 重新分配 dayIndex：根據陣列位置分配 1-7
        for index in editablePlan.wrappedValue.days.indices {
            editablePlan.wrappedValue.days[index].dayIndex = "\(index + 1)"
        }
    }

    private func saveChanges() async {
        guard let editablePlan = editableWeeklyPlan,
              let originalPlan = viewModel.weeklyPlan else { return }

        do {
            // 將編輯後的計劃轉換為 WeeklyPlan
            var updatedPlan = editablePlan.toWeeklyPlan()

            // 保持原有的計劃資訊
            updatedPlan = WeeklyPlan(
                id: originalPlan.id,
                purpose: originalPlan.purpose,
                weekOfPlan: originalPlan.weekOfPlan,
                totalWeeks: originalPlan.totalWeeks,
                totalDistance: originalPlan.totalDistance,
                totalDistanceReason: originalPlan.totalDistanceReason,
                designReason: originalPlan.designReason,
                days: updatedPlan.days,
                intensityTotalMinutes: originalPlan.intensityTotalMinutes
            )

            // 調用 API 保存到後端
            let updatedPlanFromAPI = try await TrainingPlanService.shared.modifyWeeklyPlan(
                planId: originalPlan.id,
                updatedPlan: updatedPlan
            )

            await MainActor.run {
                // 使用 API 直接回傳的更新後資料，確保與後端一致
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

// MARK: - Reorderable Row View (for List + onMove)

struct ReorderableRowView: View {
    let day: MutableTrainingDay
    let arrayIndex: Int  // 使用陣列索引來顯示星期幾
    let viewModel: TrainingPlanViewModel

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

    var body: some View {
        HStack(spacing: 12) {
            // 日期資訊 - 使用 arrayIndex + 1 作為 dayIndex
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.weekdayName(for: arrayIndex + 1))
                    .font(.headline)
                    .foregroundColor(.primary)

                if let date = viewModel.getDateForDay(dayIndex: arrayIndex + 1) {
                    Text(viewModel.formatShortDate(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            // 訓練類型標籤
            Text(day.type.localizedName)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(getTypeColor())
                .background(getTypeColor().opacity(0.15))
                .cornerRadius(8)

            // 距離（如果有）
            if let details = day.trainingDetails,
               let distance = details.distanceKm ?? details.totalDistanceKm {
                Text(String(format: "%.1f km", distance))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Simplified Daily Card (for Edit Mode, no drag)

struct SimplifiedDailyCard: View {
    let day: MutableTrainingDay
    let dayIndex: Int
    let isEditable: Bool
    let viewModel: TrainingPlanViewModel
    let onEdit: (MutableTrainingDay) -> Void

    @State private var showingEditSheet = false
    @State private var showingInfoAlert = false

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

    /// 取得主要指標顯示（距離或重複次數）
    private var primaryMetric: String? {
        guard let details = day.trainingDetails else { return nil }
        if let distance = details.distanceKm ?? details.totalDistanceKm {
            return String(format: "%.1f km", distance)
        }
        if let repeats = details.repeats, let work = details.work {
            let distanceText = work.distanceKm.map { String(format: "%.0fm", $0 * 1000) } ?? ""
            return "\(repeats) × \(distanceText)"
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 頂部區塊：日期 + 訓練類型
            HStack(alignment: .center) {
                // 左側：日期資訊
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.weekdayName(for: day.dayIndexInt))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isEditable ? .primary : .secondary)

                    if let date = viewModel.getDateForDay(dayIndex: day.dayIndexInt) {
                        Text(viewModel.formatShortDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(minWidth: 60, alignment: .leading)

                Spacer()

                // 中間：主要指標（距離/重複次數）
                if let metric = primaryMetric {
                    Text(metric)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(getTypeColor())
                }

                Spacer()

                // 右側：訓練類型標籤
                trainingTypeLabel
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 分隔線
            if day.isTrainingDay {
                Rectangle()
                    .fill(getTypeColor().opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                // 底部區塊：訓練詳情
                VStack(alignment: .leading, spacing: 8) {
                    TrainingDetailsEditView(
                        day: day,
                        isEditable: isEditable,
                        onEdit: { updatedDay in
                            onEdit(updatedDay)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEditable
                      ? Color(.tertiarySystemBackground)
                      : Color(.secondarySystemBackground))
                .shadow(color: isEditable ? getTypeColor().opacity(0.15) : .clear, radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEditable ? getTypeColor().opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable {
                showingEditSheet = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TrainingEditSheet(
                day: day,
                onSave: onEdit,
                viewModel: viewModel
            )
        }
        .alert(L10n.EditSchedule.cannotEdit.localized, isPresented: $showingInfoAlert) {
            Button(L10n.EditSchedule.confirm.localized, role: .cancel) { }
        } message: {
            Text(getEditStatusMessage())
        }
    }

    // MARK: - Training Type Label with Categorized Menu

    @ViewBuilder
    private var trainingTypeLabel: some View {
        HStack(spacing: 4) {
            if isEditable {
                Menu {
                    // 輕鬆類
                    Section(header: Text(NSLocalizedString("edit_schedule.category_easy", comment: "輕鬆訓練"))) {
                        Button(L10n.EditSchedule.easyRun.localized) { updateTrainingType(.easyRun) }
                        Button(L10n.EditSchedule.recoveryRun.localized) { updateTrainingType(.recovery_run) }
                        Button(L10n.EditSchedule.longEasyRun.localized) { updateTrainingType(.lsd) }
                    }

                    // 強度類
                    Section(header: Text(NSLocalizedString("edit_schedule.category_intensity", comment: "強度訓練"))) {
                        Button(L10n.EditSchedule.tempoRun.localized) { updateTrainingType(.tempo) }
                        Button(L10n.EditSchedule.thresholdRun.localized) { updateTrainingType(.threshold) }
                        Button(L10n.EditSchedule.intervalTraining.localized) { updateTrainingType(.interval) }
                        Button(L10n.EditSchedule.combinationRun.localized) { updateTrainingType(.combination) }
                        Button(L10n.EditSchedule.longDistanceRun.localized) { updateTrainingType(.longRun) }
                    }

                    // 休息
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
                    .padding(.horizontal, 10)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    private func getEditStatusMessage() -> String {
        return viewModel.getEditStatusMessage(for: dayIndex)
    }

    private func updateTrainingType(_ newType: DayType) {
        var updatedDay = day
        updatedDay.trainingType = newType.rawValue

        // 從 ViewModel 獲取當前 VDOT 並計算建議配速
        let vdot = viewModel.currentVDOT ?? PaceCalculator.defaultVDOT

        // 根據訓練類型重置訓練詳情，並使用 PaceCalculator 計算配速
        switch newType {
        case .rest:
            updatedDay.trainingDetails = nil

        case .easyRun, .recovery_run:
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "6:00"
            updatedDay.trainingDetails = MutableTrainingDetails(
                distanceKm: 5.0,
                pace: suggestedPace
            )

        case .tempo, .threshold:
            let suggestedPace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "5:00"
            updatedDay.trainingDetails = MutableTrainingDetails(
                distanceKm: 8.0,
                pace: suggestedPace
            )

        case .interval:
            let intervalPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:00"
            updatedDay.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(distanceKm: 0.4, pace: intervalPace),
                recovery: MutableWorkoutSegment(pace: recoveryPace),
                repeats: 4
            )

        case .longRun:
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            updatedDay.trainingDetails = MutableTrainingDetails(
                distanceKm: 15.0,
                pace: tempoPace
            )

        case .lsd:
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            updatedDay.trainingDetails = MutableTrainingDetails(
                distanceKm: 20.0,
                pace: easyPace
            )

        case .combination:
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            updatedDay.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 10.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 3.0, pace: easyPace, description: "輕鬆跑"),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: "節奏跑"),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "輕鬆跑")
                ]
            )

        default:
            updatedDay.trainingDetails = MutableTrainingDetails(distanceKm: 6.0)
        }

        onEdit(updatedDay)
    }
}

// MARK: - Supporting Data Structures

struct MutableWeeklyPlan {
    var days: [MutableTrainingDay]

    init(from weeklyPlan: WeeklyPlan) {
        self.days = weeklyPlan.days.map { MutableTrainingDay(from: $0) }
    }

    mutating func swapDays(_ day1: Int, _ day2: Int) {
        guard day1 < days.count && day2 < days.count else { return }

        // 交換兩個day的內容，包括 dayIndex
        let temp = days[day1].dayIndex
        days[day1].dayIndex = days[day2].dayIndex
        days[day2].dayIndex = temp

        // 交換數組位置
        days.swapAt(day1, day2)
    }

    func toWeeklyPlan() -> WeeklyPlan {
        // 將 MutableTrainingDay 轉換為 TrainingDay
        let trainingDays = days.map { mutableDay in
            TrainingDay(
                dayIndex: mutableDay.dayIndex,
                dayTarget: mutableDay.dayTarget,
                reason: mutableDay.reason,
                tips: mutableDay.tips,
                trainingType: mutableDay.trainingType,
                trainingDetails: mutableDay.trainingDetails?.toTrainingDetails()
            )
        }

        // 假設我們需要保持原有的 WeeklyPlan 其他屬性
        // 這裡需要從原始的 WeeklyPlan 獲取這些資訊
        return WeeklyPlan(
            id: "", // 這個會由 API 返回
            purpose: "",
            weekOfPlan: 1,
            totalWeeks: 12,
            totalDistance: 0.0,
            totalDistanceReason: nil,
            designReason: nil,
            days: trainingDays,
            intensityTotalMinutes: nil
        )
    }
}

struct MutableTrainingDay: Identifiable, Equatable {
    let id: UUID  // 穩定的 ID，不隨排序改變
    var dayIndex: String
    var dayTarget: String
    var reason: String?
    var tips: String?
    var trainingType: String
    var trainingDetails: MutableTrainingDetails?

    init(from trainingDay: TrainingDay) {
        self.id = UUID()
        self.dayIndex = trainingDay.dayIndex
        self.dayTarget = trainingDay.dayTarget
        self.reason = trainingDay.reason
        self.tips = trainingDay.tips
        self.trainingType = trainingDay.trainingType
        self.trainingDetails = trainingDay.trainingDetails != nil ? MutableTrainingDetails(from: trainingDay.trainingDetails!) : nil
    }

    init(id: UUID = UUID(), dayIndex: String, dayTarget: String, reason: String? = nil, tips: String? = nil, trainingType: String, trainingDetails: MutableTrainingDetails? = nil) {
        self.id = id
        self.dayIndex = dayIndex
        self.dayTarget = dayTarget
        self.reason = reason
        self.tips = tips
        self.trainingType = trainingType
        self.trainingDetails = trainingDetails
    }

    var type: DayType {
        return DayType(rawValue: trainingType) ?? .rest
    }

    var isTrainingDay: Bool {
        return type != .rest
    }

    var dayIndexInt: Int {
        return Int(dayIndex) ?? 0
    }

    static func == (lhs: MutableTrainingDay, rhs: MutableTrainingDay) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MutableTrainingDetails: Equatable {
    var description: String?
    var distanceKm: Double?
    var totalDistanceKm: Double?
    var timeMinutes: Double?
    var pace: String?
    var work: MutableWorkoutSegment?
    var recovery: MutableWorkoutSegment?
    var repeats: Int?
    var heartRateRange: HeartRateRange?
    var segments: [MutableProgressionSegment]?

    init(from trainingDetails: TrainingDetails) {
        self.description = trainingDetails.description
        self.distanceKm = trainingDetails.distanceKm
        self.totalDistanceKm = trainingDetails.totalDistanceKm
        self.timeMinutes = trainingDetails.timeMinutes
        self.pace = trainingDetails.pace
        self.work = trainingDetails.work != nil ? MutableWorkoutSegment(from: trainingDetails.work!) : nil
        self.recovery = trainingDetails.recovery != nil ? MutableWorkoutSegment(from: trainingDetails.recovery!) : nil
        self.repeats = trainingDetails.repeats
        self.heartRateRange = trainingDetails.heartRateRange
        self.segments = trainingDetails.segments?.map { MutableProgressionSegment(from: $0) }
    }

    init(description: String? = nil, distanceKm: Double? = nil, totalDistanceKm: Double? = nil, timeMinutes: Double? = nil, pace: String? = nil, work: MutableWorkoutSegment? = nil, recovery: MutableWorkoutSegment? = nil, repeats: Int? = nil, heartRateRange: HeartRateRange? = nil, segments: [MutableProgressionSegment]? = nil) {
        self.description = description
        self.distanceKm = distanceKm
        self.totalDistanceKm = totalDistanceKm
        self.timeMinutes = timeMinutes
        self.pace = pace
        self.work = work
        self.recovery = recovery
        self.repeats = repeats
        self.heartRateRange = heartRateRange
        self.segments = segments
    }

    func toTrainingDetails() -> TrainingDetails {
        return TrainingDetails(
            description: description,
            distanceKm: distanceKm,
            totalDistanceKm: totalDistanceKm,
            timeMinutes: timeMinutes,
            pace: pace,
            work: work?.toWorkoutSegment(),
            recovery: recovery?.toWorkoutSegment(),
            repeats: repeats,
            heartRateRange: heartRateRange,
            segments: segments?.map { $0.toProgressionSegment() }
        )
    }
}

struct MutableWorkoutSegment: Equatable {
    var description: String?
    var distanceKm: Double?
    var distanceM: Double?
    var timeMinutes: Double?
    var pace: String?
    var heartRateRange: HeartRateRange?

    init(from workoutSegment: WorkoutSegment) {
        self.description = workoutSegment.description
        self.distanceKm = workoutSegment.distanceKm
        self.distanceM = workoutSegment.distanceM
        self.timeMinutes = workoutSegment.timeMinutes
        self.pace = workoutSegment.pace
        self.heartRateRange = workoutSegment.heartRateRange
    }

    init(description: String? = nil, distanceKm: Double? = nil, distanceM: Double? = nil, timeMinutes: Double? = nil, pace: String? = nil, heartRateRange: HeartRateRange? = nil) {
        self.description = description
        self.distanceKm = distanceKm
        self.distanceM = distanceM
        self.timeMinutes = timeMinutes
        self.pace = pace
        self.heartRateRange = heartRateRange
    }

    func toWorkoutSegment() -> WorkoutSegment {
        return WorkoutSegment(
            description: description,
            distanceKm: distanceKm,
            distanceM: distanceM,
            timeMinutes: timeMinutes,
            pace: pace,
            heartRateRange: heartRateRange
        )
    }
}

struct MutableProgressionSegment: Equatable {
    var distanceKm: Double?
    var pace: String?
    var description: String?
    var heartRateRange: HeartRateRange?

    init(from progressionSegment: ProgressionSegment) {
        self.distanceKm = progressionSegment.distanceKm
        self.pace = progressionSegment.pace
        self.description = progressionSegment.description
        self.heartRateRange = progressionSegment.heartRateRange
    }

    init(distanceKm: Double? = nil, pace: String? = nil, description: String? = nil, heartRateRange: HeartRateRange? = nil) {
        self.distanceKm = distanceKm
        self.pace = pace
        self.description = description
        self.heartRateRange = heartRateRange
    }

    func toProgressionSegment() -> ProgressionSegment {
        return ProgressionSegment(
            distanceKm: distanceKm,
            pace: pace,
            description: description,
            heartRateRange: heartRateRange
        )
    }
}
