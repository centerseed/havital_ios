import Foundation

// MARK: - WorkoutRecapContent
//
// 訓練完成 Recap 時刻消費的資料模型，與視覺完全解耦。
// claude design 設計 WorkoutRecapView 時只需綁這些欄位即可，不必碰單位換算 / DTO。
//
// 數據欄位皆為「已格式化字串」（依 UnitManager 設定），design 直接顯示。
// AI 目前後端僅回純文字（AISummary.analysis）；rich 化（分段 / chip）由 design 決定呈現方式，
// 資料來源不變。celebration* 欄位來自 ShareCardContent（若後端有提供）。

struct WorkoutRecapContent: Identifiable, Equatable {
    /// workoutId — 同時作為去重 / 已讀鍵。
    let id: String
    let date: Date

    // 數據摘要（已格式化）
    let trainingTypeName: String?
    let distanceText: String        // e.g. "6.4 公里"
    let paceText: String            // e.g. "5:58 /km"
    let durationText: String        // e.g. "38:29"
    let vdot: Double?
    let rpe: Double?                 // 主觀強度（有才顯示）

    // AI 分析（plain text；nil/空 = 無分析）
    let aiAnalysis: String?

    // 慶祝文案（來自 ShareCardContent，可能為 nil）
    let celebrationTitle: String?
    let encouragement: String?
    let streakDays: Int?

    /// 付費 gating：false → WorkoutRecapView 顯示 AI teaser + 升級提示。
    let isPremium: Bool

    /// 是否有值得展示的 AI 內容。
    var hasAIAnalysis: Bool {
        !(aiAnalysis ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Build from WorkoutV2

extension WorkoutRecapContent {
    /// 從 WorkoutV2 建構 recap 內容。需在 MainActor 執行（UnitManager 為 MainActor）。
    /// list endpoint 通常不帶 AI，故由 caller 補抓 detail 後以 aiAnalysisOverride 傳入。
    @MainActor
    static func make(
        from workout: WorkoutV2,
        isPremium: Bool,
        aiAnalysisOverride: String? = nil,
        rpeOverride: Double? = nil
    ) -> WorkoutRecapContent {
        let unit = UnitManager.shared

        // 距離
        let distanceText: String
        if let meters = workout.distanceMeters, meters > 0 {
            let km = meters / 1000.0
            let converted = unit.convertedDistance(km)
            distanceText = String(format: "%.1f %@", converted, unit.currentUnitSystem.distanceSuffix)
        } else {
            distanceText = "-"
        }

        // 配速
        let paceText: String
        if let pace = workout.displayPaceSecondsPerKm {
            paceText = unit.formatPace(secondsPerKm: pace)
        } else {
            paceText = "--:--"
        }

        // 時間
        let durationText = Self.formatDuration(workout.duration)

        // 訓練類型名稱（複用 WorkoutV2RowView 的對照）
        let typeName = workout.trainingType.map { WorkoutV2RowView.displayNameForTrainingType($0) }

        return WorkoutRecapContent(
            id: workout.id,
            date: workout.startDate,
            trainingTypeName: typeName,
            distanceText: distanceText,
            paceText: paceText,
            durationText: durationText,
            vdot: workout.dynamicVdot,
            rpe: rpeOverride ?? workout.advancedMetrics?.rpe,
            aiAnalysis: aiAnalysisOverride ?? workout.aiSummary?.analysis,
            celebrationTitle: workout.shareCardContent?.achievementTitle,
            encouragement: workout.shareCardContent?.encouragementText,
            streakDays: workout.shareCardContent?.streakDays,
            isPremium: isPremium
        )
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
