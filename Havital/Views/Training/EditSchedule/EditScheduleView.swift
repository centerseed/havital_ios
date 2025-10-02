import SwiftUI
import Foundation

struct EditScheduleView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editableWeeklyPlan: MutableWeeklyPlan?
    @State private var draggedDay: Int?
    @State private var showingUnsavedChangesAlert = false
    @State private var hasUnsavedChanges = false
    @State private var showingPaceTable = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let editablePlan = editableWeeklyPlan {
                    LazyVStack(spacing: 16) {
                        ForEach(0..<7) { dayIndex in
                            if dayIndex < editablePlan.days.count {
                                EditableDailyCard(
                                    day: editablePlan.days[dayIndex],
                                    dayIndex: dayIndex,
                                    isEditable: canEditDay(editablePlan.days[dayIndex].dayIndexInt),
                                    viewModel: viewModel,
                                    onEdit: updateDay,
                                    onDragStarted: { draggedDay = $0 },
                                    onDropped: handleDrop
                                )
                            }
                        }
                    }
                    .padding()
                } else {
                    ProgressView(NSLocalizedString("edit_schedule.loading_data", comment: "載入編輯資料..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(NSLocalizedString("edit_schedule.title", comment: "編輯週課表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    HStack(spacing: 12) {
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
    
    // MARK: - Private Methods
    
    private func setupEditableWeeklyPlan() {
        guard let weeklyPlan = viewModel.weeklyPlan else { return }
        editableWeeklyPlan = MutableWeeklyPlan(from: weeklyPlan)
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
    
    private func handleDrop(from sourceDayIndex: Int, to targetDayIndex: Int) -> Bool {
        // 驗證兩天都可以編輯
        let canEditSource = canEditDay(sourceDayIndex)
        let canEditTarget = canEditDay(targetDayIndex)
        
        guard var editablePlan = editableWeeklyPlan else { return false }
        
        let success = DragDropHandler.handleDrop(
            from: sourceDayIndex,
            to: targetDayIndex,
            in: &editablePlan,
            canEditSource: canEditSource,
            canEditTarget: canEditTarget
        )
        
        if success {
            editableWeeklyPlan = editablePlan
            hasUnsavedChanges = true
            draggedDay = nil
        }
        
        return success
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
                showError("保存失敗：\(error.localizedDescription)")
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

struct MutableTrainingDay: Identifiable {
    var id: String { dayIndex }
    var dayIndex: String
    var dayTarget: String
    var reason: String?
    var tips: String?
    var trainingType: String
    var trainingDetails: MutableTrainingDetails?
    
    init(from trainingDay: TrainingDay) {
        self.dayIndex = trainingDay.dayIndex
        self.dayTarget = trainingDay.dayTarget
        self.reason = trainingDay.reason
        self.tips = trainingDay.tips
        self.trainingType = trainingDay.trainingType
        self.trainingDetails = trainingDay.trainingDetails != nil ? MutableTrainingDetails(from: trainingDay.trainingDetails!) : nil
    }
    
    init(dayIndex: String, dayTarget: String, reason: String? = nil, tips: String? = nil, trainingType: String, trainingDetails: MutableTrainingDetails? = nil) {
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
}

struct MutableTrainingDetails {
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

struct MutableWorkoutSegment {
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

struct MutableProgressionSegment {
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