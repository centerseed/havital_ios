import Foundation
import SwiftUI

// MARK: - EditScheduleV2ViewModel
/// V2 週課表編輯 ViewModel
/// 使用 WeeklyPlanV2 和 TrainingPlanV2Repository
@MainActor
final class EditScheduleV2ViewModel: ObservableObject, TaskManageable {

    // MARK: - Published State

    @Published var isEditingLoaded: Bool = false
    @Published var editingDays: [MutableTrainingDay] = []
    @Published var currentVDOT: Double?
    @Published var isSaving: Bool = false
    @Published var saveError: Error?

    // MARK: - Dependencies

    let weeklyPlan: WeeklyPlanV2
    private let startDate: Date
    private let repository: TrainingPlanV2Repository

    // MARK: - TaskManageable

    nonisolated let taskRegistry = TaskRegistry()

    // MARK: - Init

    init(
        weeklyPlan: WeeklyPlanV2,
        startDate: Date = Date(),
        repository: TrainingPlanV2Repository
    ) {
        self.weeklyPlan = weeklyPlan
        self.startDate = startDate
        self.repository = repository

        // 從 V2 DayDetail 初始化編輯天（使用 V1 兼容層）
        self.editingDays = weeklyPlan.days
            .sorted { $0.dayIndexInt < $1.dayIndexInt }
            .map { MutableTrainingDay(from: $0) }
        self.isEditingLoaded = true

        loadVDOT()
        Logger.debug("[EditScheduleV2VM] init - editingDays: \(editingDays.count)")
    }

    /// 便利初始化器（使用 DI Container）
    convenience init(weeklyPlan: WeeklyPlanV2, startDate: Date = Date()) {
        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        self.init(
            weeklyPlan: weeklyPlan,
            startDate: startDate,
            repository: container.resolve()
        )
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Public Methods

    func loadVDOT() {
        VDOTManager.shared.loadLocalCacheSync()
        let vdot = VDOTManager.shared.currentVDOT
        currentVDOT = vdot > 0 ? vdot : PaceCalculator.defaultVDOT
    }

    func getDateForDay(dayIndex: Int) -> Date? {
        Calendar.current.date(byAdding: .day, value: dayIndex - 1, to: startDate)
    }

    func weekdayName(for dayIndex: String) -> String {
        guard let index = Int(dayIndex) else { return "" }
        return DateFormatterHelper.weekdayName(for: index)
    }

    func formatShortDate(_ date: Date) -> String {
        DateFormatterHelper.formatShortDate(date)
    }

    func getEditStatusMessage(for dayIndex: Int) -> String {
        guard let dayDate = getDateForDay(dayIndex: dayIndex) else { return "" }
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

    /// 保存編輯（轉換為 DayDetailDTO 並呼叫 V2 API）
    func saveEdits() async throws -> WeeklyPlanV2 {
        Logger.debug("[EditScheduleV2VM] Saving \(editingDays.count) days")

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            let dayDTOs = editingDays.map { buildDayDetailDTO(from: $0) }
            let totalDistance = editingDays.reduce(0.0) {
                $0 + ($1.trainingDetails?.totalDistanceKm ?? $1.trainingDetails?.distanceKm ?? 0.0)
            }

            let request = UpdateWeeklyPlanRequest(
                days: dayDTOs,
                purpose: nil,
                totalDistanceKm: totalDistance > 0 ? totalDistance : nil
            )

            let savedPlan = try await repository.updateWeeklyPlan(
                planId: weeklyPlan.effectivePlanId,
                updates: request
            )

            // 注意：updateWeeklyPlan 已將最新課表存入快取，不在此清除快取或發送 CacheEventBus
            // 避免 race condition：saveChanges() 會直接更新 planViewModel.planStatus

            Logger.debug("[EditScheduleV2VM] ✅ Saved plan: \(savedPlan.effectivePlanId)")
            return savedPlan

        } catch {
            saveError = error
            Logger.error("[EditScheduleV2VM] ❌ Save failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private: MutableTrainingDay → DayDetailDTO

    private func buildDayDetailDTO(from day: MutableTrainingDay) -> DayDetailDTO {
        let dayType = DayType(rawValue: day.trainingType) ?? .rest
        let category: String?
        let primary: PrimaryActivityDTO?

        if dayType == .rest {
            category = "rest"
            primary = nil
        } else if dayType == .strength {
            category = "strength"
            primary = .strength(StrengthActivityDTO(
                strengthType: "general",
                exercises: [],
                durationMinutes: day.trainingDetails?.timeMinutes.map { Int($0) },
                description: day.dayTarget
            ))
        } else if [DayType.crossTraining, .hiking, .yoga, .cycling].contains(dayType) {
            category = "cross"
            let crossType: String
            switch dayType {
            case .hiking: crossType = "hiking"
            case .yoga: crossType = "yoga"
            case .cycling: crossType = "cycling"
            default: crossType = "cross_training"
            }
            primary = .cross(CrossActivityDTO(
                crossType: crossType,
                durationMinutes: day.trainingDetails?.timeMinutes.map { Int($0) } ?? 60,
                distanceKm: day.trainingDetails?.distanceKm,
                distanceDisplay: nil,
                distanceUnit: nil,
                intensity: nil,
                description: day.dayTarget
            ))
        } else {
            // 跑步類型
            category = "run"
            primary = .run(buildRunActivityDTO(from: day, dayType: dayType))
        }

        return DayDetailDTO(
            dayIndex: day.dayIndexInt,
            dayTarget: day.dayTarget,
            reason: day.reason ?? "",
            tips: day.tips,
            category: category,
            primary: primary,
            warmup: nil,
            cooldown: nil,
            supplementary: nil
        )
    }

    private func buildRunActivityDTO(from day: MutableTrainingDay, dayType: DayType) -> RunActivityDTO {
        let runType = dayType.apiRunType
        guard let details = day.trainingDetails else {
            return RunActivityDTO(
                runType: runType,
                distanceKm: nil,
                distanceDisplay: nil,
                distanceUnit: nil,
                paceUnit: nil,
                durationMinutes: nil,
                durationSeconds: nil,
                pace: nil,
                heartRateRange: nil,
                interval: nil,
                segments: nil,
                description: day.dayTarget,
                targetIntensity: nil
            )
        }

        // 間歇訓練
        if let work = details.work, let recovery = details.recovery, let repeats = details.repeats {
            let intervalDTO = IntervalBlockDTO(
                repeats: repeats,
                workDistanceKm: work.distanceKm,
                workDistanceM: work.distanceM.map { Int($0) },
                workDistanceDisplay: nil,
                workDistanceUnit: nil,
                workPaceUnit: nil,
                workDurationMinutes: work.timeMinutes.map { Int($0) },
                workPace: work.pace,
                workDescription: work.description,
                recoveryDistanceKm: recovery.distanceKm,
                recoveryDistanceM: recovery.distanceM.map { Int($0) },
                recoveryDurationMinutes: recovery.timeMinutes.map { Int($0) },
                recoveryPace: recovery.pace,
                recoveryDescription: recovery.description,
                recoveryDurationSeconds: nil,
                variant: nil
            )
            return RunActivityDTO(
                runType: runType,
                distanceKm: details.totalDistanceKm ?? details.distanceKm,
                distanceDisplay: nil,
                distanceUnit: nil,
                paceUnit: nil,
                durationMinutes: details.timeMinutes.map { Int($0) },
                durationSeconds: nil,
                pace: details.pace,
                heartRateRange: nil,
                interval: intervalDTO,
                segments: nil,
                description: details.description ?? day.dayTarget,
                targetIntensity: nil
            )
        }

        // 分段訓練（progression, combination, fartlek, fastFinish）
        if let segs = details.segments, !segs.isEmpty {
            let segDTOs = segs.map { seg in
                RunSegmentDTO(
                    distanceKm: seg.distanceKm,
                    distanceM: nil,
                    distanceDisplay: nil,
                    distanceUnit: nil,
                    durationMinutes: nil,
                    durationSeconds: nil,
                    pace: seg.pace,
                    heartRateRange: nil,
                    intensity: nil,
                    description: seg.description
                )
            }
            return RunActivityDTO(
                runType: runType,
                distanceKm: details.totalDistanceKm,
                distanceDisplay: nil,
                distanceUnit: nil,
                paceUnit: nil,
                durationMinutes: details.timeMinutes.map { Int($0) },
                durationSeconds: nil,
                pace: details.pace,
                heartRateRange: nil,
                interval: nil,
                segments: segDTOs,
                description: details.description ?? day.dayTarget,
                targetIntensity: nil
            )
        }

        // 一般跑步
        return RunActivityDTO(
            runType: runType,
            distanceKm: details.distanceKm,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: details.timeMinutes.map { Int($0) },
            durationSeconds: nil,
            pace: details.pace,
            heartRateRange: nil,
            interval: nil,
            segments: nil,
            description: details.description ?? day.dayTarget,
            targetIntensity: nil
        )
    }
}

// MARK: - DayType → API runType mapping

private extension DayType {
    var apiRunType: String {
        switch self {
        case .easyRun: return "easy_run"
        case .easy: return "easy"
        case .recovery_run: return "recovery_run"
        case .tempo: return "tempo"
        case .threshold: return "threshold"
        case .interval: return "interval"
        case .lsd: return "lsd"
        case .longRun: return "long_run"
        case .progression: return "progression"
        case .race: return "race"
        case .racePace: return "race_pace"
        case .strides: return "strides"
        case .hillRepeats: return "hill_repeats"
        case .cruiseIntervals: return "cruise_intervals"
        case .shortInterval: return "short_interval"
        case .longInterval: return "long_interval"
        case .norwegian4x4: return "norwegian_4x4"
        case .yasso800: return "yasso_800"
        case .fartlek: return "fartlek"
        case .fastFinish: return "fast_finish"
        case .combination: return "combination"
        default: return rawValue
        }
    }
}
