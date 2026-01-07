import Foundation
import SwiftUI

// MARK: - EditSchedule ViewModel
/// 負責訓練課表編輯的 UI 狀態管理
@MainActor
final class EditScheduleViewModel: ObservableObject, @preconcurrency TaskManageable {

    // MARK: - Published State

    /// 編輯狀態是否已載入
    @Published var isEditingLoaded: Bool = false

    /// 正在編輯的訓練日
    @Published var editingDays: [MutableTrainingDay] = []

    /// 當前 VDOT 數值
    @Published var currentVDOT: Double?

    /// 展開的日期索引
    @Published var expandedDayIndices: Set<Int> = []

    /// 保存進行中狀態
    @Published var isSaving: Bool = false

    /// 保存錯誤
    @Published var saveError: DomainError?

    /// 保存成功訊息
    @Published var saveSuccessMessage: String?

    // MARK: - Dependencies

    let weeklyPlan: WeeklyPlan  // 改為 public 讓 View 可以訪問
    private let startDate: Date
    private let repository: TrainingPlanRepository

    // MARK: - TaskManageable
    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Initialization

    init(
        weeklyPlan: WeeklyPlan,
        startDate: Date = Date(),
        repository: TrainingPlanRepository
    ) {
        self.weeklyPlan = weeklyPlan
        self.startDate = startDate
        self.repository = repository
        loadVDOT()
    }

    /// 便利初始化器（使用 DI Container）
    convenience init(weeklyPlan: WeeklyPlan, startDate: Date = Date()) {
        // 確保 TrainingPlan 模組已註冊
        if !DependencyContainer.shared.isRegistered(TrainingPlanRepository.self) {
            DependencyContainer.shared.registerTrainingPlanModule()
        }
        self.init(
            weeklyPlan: weeklyPlan,
            startDate: startDate,
            repository: DependencyContainer.shared.resolve()
        )
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Public Methods

    /// 載入 VDOT 數值
    func loadVDOT() {
        // TODO: 從 VDOTManager 載入
        currentVDOT = PaceCalculator.defaultVDOT
    }

    /// 初始化編輯狀態
    func initializeEditing() {
        guard !isEditingLoaded else { return }

        editingDays = weeklyPlan.days.map { day in
            MutableTrainingDay(from: day)
        }

        isEditingLoaded = true
    }

    /// 添加新的訓練日
    func addNewDay() {
        let newDay = MutableTrainingDay.createEmpty(dayIndex: editingDays.count)
        editingDays.append(newDay)
    }

    /// 刪除訓練日
    func removeDay(at index: Int) {
        guard index < editingDays.count else { return }
        editingDays.remove(at: index)
    }

    /// 獲取指定日期索引的日期
    func getDateForDay(dayIndex: Int) -> Date? {
        let calendar = Calendar.current
        // dayIndex 是 1-7 代表週一到週日，所以要減 1
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: startDate)
    }

    /// 獲取星期名稱
    func weekdayName(for dayIndex: String) -> String {
        guard let index = Int(dayIndex) else { return "" }
        return DateFormatterHelper.weekdayName(for: index)
    }

    /// 獲取建議配速
    func getSuggestedPace(for trainingType: String) -> String? {
        guard let vdot = currentVDOT else { return nil }
        return PaceFormatterHelper.getSuggestedPace(for: trainingType, vdot: vdot)
    }

    /// 獲取編輯狀態訊息
    func getEditStatusMessage(for dayIndex: Int) -> String {
        guard let dayDate = getDateForDay(dayIndex: dayIndex) else {
            return ""
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: dayDate)

        if targetDay < today {
            return NSLocalizedString("edit.past_day", comment: "Past day")
        } else if targetDay == today {
            return NSLocalizedString("edit.today", comment: "Today")
        } else {
            return NSLocalizedString("edit.future_day", comment: "Future day")
        }
    }

    /// 檢查是否為今天
    func isToday(dayIndex: String) -> Bool {
        guard let index = Int(dayIndex),
              let dayDate = getDateForDay(dayIndex: index) else {
            return false
        }

        return DateFormatterHelper.isToday(dayDate)
    }

    /// 切換展開狀態
    func toggleExpanded(dayIndex: Int) {
        if expandedDayIndices.contains(dayIndex) {
            expandedDayIndices.remove(dayIndex)
        } else {
            expandedDayIndices.insert(dayIndex)
        }
    }

    /// 格式化短日期
    func formatShortDate(_ date: Date) -> String {
        return DateFormatterHelper.formatShortDate(date)
    }

    /// 保存編輯
    func saveEdits() async throws {
        Logger.debug("[EditScheduleVM] Saving edits for \(editingDays.count) days")

        await executeTask(id: TaskID("save_edits_\(weeklyPlan.id)")) { [weak self] in
            guard let self = self else { return }

            // 1. 清除上次的狀態
            await MainActor.run {
                self.isSaving = true
                self.saveError = nil
                self.saveSuccessMessage = nil
            }

            do {
                // 2. 驗證計畫
                try await MainActor.run {
                    try self.validatePlan()
                }

                // 3. 構建更新後的 WeeklyPlan
                let updatedPlan = try await MainActor.run {
                    try self.buildUpdatedPlan()
                }

                // 4. 調用 Repository 保存
                let savedPlan = try await self.repository.modifyWeeklyPlan(
                    planId: self.weeklyPlan.id,
                    updatedPlan: updatedPlan
                )

                // 5. 更新 UI 狀態
                await MainActor.run {
                    self.isSaving = false
                    self.saveSuccessMessage = NSLocalizedString(
                        "edit_schedule.save_success",
                        value: "訓練計畫已成功保存",
                        comment: "Save success message"
                    )
                }

                // 6. 發布事件通知其他模組
                CacheEventBus.shared.publish(.dataChanged(.trainingPlan))

                Logger.debug("[EditScheduleVM] Successfully saved plan: \(savedPlan.id)")

            } catch let error as DomainError {
                // 處理領域錯誤
                await MainActor.run {
                    self.isSaving = false
                    self.saveError = error
                }
                Logger.error("[EditScheduleVM] Save failed: \(error.localizedDescription ?? "Unknown error")")
                throw error

            } catch {
                // 處理其他錯誤
                let domainError = error.toDomainError()

                // 取消錯誤不更新 UI
                if case .cancellation = domainError {
                    Logger.debug("[EditScheduleVM] Task cancelled, ignoring")
                    await MainActor.run { self.isSaving = false }
                    return
                }

                await MainActor.run {
                    self.isSaving = false
                    self.saveError = domainError
                }
                Logger.error("[EditScheduleVM] Unexpected error: \(error.localizedDescription)")
                throw domainError
            }
        }
    }

    // MARK: - Private Helper Methods

    /// 驗證訓練計畫
    private func validatePlan() throws {
        // 檢查是否有編輯數據
        guard !editingDays.isEmpty else {
            throw DomainError.validationFailure(
                NSLocalizedString(
                    "edit_schedule.error.empty_plan",
                    value: "訓練計畫不能為空",
                    comment: "Empty plan error"
                )
            )
        }

        // 檢查每個訓練日的合法性
        for (index, day) in editingDays.enumerated() {
            // 驗證 dayIndex 範圍
            guard let dayIndex = Int(day.dayIndex), dayIndex >= 1 && dayIndex <= 7 else {
                throw DomainError.validationFailure(
                    NSLocalizedString(
                        "edit_schedule.error.invalid_day_index",
                        value: "第 \(index + 1) 天的日期索引無效",
                        comment: "Invalid day index error"
                    )
                )
            }

            // 驗證訓練類型不為空
            if !day.trainingType.isEmpty && day.trainingType.trimmingCharacters(in: .whitespaces).isEmpty {
                throw DomainError.validationFailure(
                    NSLocalizedString(
                        "edit_schedule.error.invalid_training_type",
                        value: "第 \(index + 1) 天的訓練類型無效",
                        comment: "Invalid training type error"
                    )
                )
            }
        }

        Logger.debug("[EditScheduleVM] Validation passed for \(editingDays.count) days")
    }

    /// 構建更新後的 WeeklyPlan
    private func buildUpdatedPlan() throws -> WeeklyPlan {
        // 將 MutableTrainingDay 轉換回 TrainingDay
        let updatedDays = editingDays.map { mutableDay in
            mutableDay.toTrainingDay()
        }

        // 創建新的 WeeklyPlan（保留原有的 metadata）
        let updatedPlan = WeeklyPlan(
            id: weeklyPlan.id,
            purpose: weeklyPlan.purpose,
            weekOfPlan: weeklyPlan.weekOfPlan,
            totalWeeks: weeklyPlan.totalWeeks,
            totalDistance: calculateTotalDistance(from: updatedDays),
            totalDistanceReason: weeklyPlan.totalDistanceReason,
            designReason: weeklyPlan.designReason,
            days: updatedDays,
            intensityTotalMinutes: weeklyPlan.intensityTotalMinutes
        )

        Logger.debug("[EditScheduleVM] Built updated plan with \(updatedDays.count) days")
        return updatedPlan
    }

    /// 計算總距離
    private func calculateTotalDistance(from days: [TrainingDay]) -> Double {
        return days.reduce(0.0) { total, day in
            // 提取距離：優先使用 totalDistanceKm（用於分段訓練），其次使用 distanceKm
            let dayDistance = day.trainingDetails?.totalDistanceKm ??
                            day.trainingDetails?.distanceKm ??
                            0.0
            return total + dayDistance
        }
    }
}

// MARK: - PaceCalculator Helper


