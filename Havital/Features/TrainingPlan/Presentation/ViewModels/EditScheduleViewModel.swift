import Foundation
import SwiftUI

// MARK: - EditSchedule ViewModel
/// 負責訓練課表編輯的 UI 狀態管理
@MainActor
final class EditScheduleViewModel: ObservableObject {

    // MARK: - Published State

    /// 編輯狀態是否已載入
    @Published var isEditingLoaded: Bool = false

    /// 正在編輯的訓練日
    @Published var editingDays: [MutableTrainingDay] = []

    /// 當前 VDOT 數值
    @Published var currentVDOT: Double?

    /// 展開的日期索引
    @Published var expandedDayIndices: Set<Int> = []

    // MARK: - Dependencies

    let weeklyPlan: WeeklyPlan  // 改為 public 讓 View 可以訪問
    private let startDate: Date

    // MARK: - Initialization

    init(weeklyPlan: WeeklyPlan, startDate: Date = Date()) {
        self.weeklyPlan = weeklyPlan
        self.startDate = startDate
        loadVDOT()
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
        // TODO: 實作保存邏輯，調用 Repository
        Logger.debug("[EditScheduleVM] Saving edits for \(editingDays.count) days")
    }
}

// MARK: - PaceCalculator Helper


