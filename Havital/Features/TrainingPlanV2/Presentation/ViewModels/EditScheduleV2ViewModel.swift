import Foundation
import SwiftUI

// MARK: - EditScheduleV2ViewModel
/// V2 週課表編輯 ViewModel
/// 使用 WeeklyPlanV2 和 TrainingPlanV2Repository
@MainActor
final class EditScheduleV2ViewModel: ObservableObject, Identifiable, TaskManageable {

    let id = UUID()

    // MARK: - Published State

    @Published var isEditingLoaded: Bool = false
    @Published var editingDays: [MutableTrainingDay] = []
    @Published var currentVDOT: Double?
    @Published var isSaving: Bool = false
    @Published var saveError: Error?
    /// 儲存成功後的課表，供父 view 在 onDismiss 時讀取
    @Published var savedPlan: WeeklyPlanV2?

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
        if let planVdot = weeklyPlan.currentVdot, planVdot > 0 {
            currentVDOT = planVdot
            Logger.debug("[EditScheduleV2VM] loadVDOT - using weekly plan VDOT: \(planVdot)")
            return
        }

        VDOTManager.shared.loadLocalCacheSync()
        let vdot = VDOTManager.shared.currentVDOT
        currentVDOT = vdot > 0 ? vdot : PaceCalculator.defaultVDOT
        Logger.debug("[EditScheduleV2VM] loadVDOT - fallback VDOTManager/current default: \(currentVDOT ?? 0)")
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
            let request = UpdateWeeklyPlanRequest(
                days: dayDTOs,
                purpose: nil,
                totalDistanceKm: nil
            )

            let savedPlan = try await repository.updateWeeklyPlan(
                planId: weeklyPlan.effectivePlanId,
                updates: request
            )

            // 注意：updateWeeklyPlan 已將最新課表存入快取
            // savedPlan 供父 view 在 sheet onDismiss 時讀取更新
            self.savedPlan = savedPlan

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
        let originalDay = originalDay(for: day)
        let dayClimateMeta = dayType.isRunningActivity
            ? originalDay?.effectiveClimateMeta.map { TrainingSessionMapper.toDTO(from: $0) }
            : nil
        let category: String?
        let primary: PrimaryActivityDTO?

        if dayType == .rest {
            category = "rest"
            primary = nil
        } else if dayType == .strength {
            category = "strength"
            let exerciseDTOs = (day.strengthExercises ?? []).map { exercise in
                ExerciseDTO(
                    exerciseId: exercise.exerciseId,
                    name: exercise.name,
                    sets: exercise.sets,
                    reps: exercise.reps.flatMap { Int($0) },
                    repsRange: exercise.reps,
                    durationSeconds: exercise.durationSeconds,
                    weightKg: exercise.weightKg,
                    restSeconds: exercise.restSeconds,
                    description: exercise.description
                )
            }
            primary = .strength(StrengthActivityDTO(
                strengthType: day.strengthType ?? "general",
                exercises: exerciseDTOs,
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

        // Convert warmup/cooldown to DTOs for run category only
        let warmupDTO: RunSegmentDTO?
        let cooldownDTO: RunSegmentDTO?
        if category == "run" {
            warmupDTO = day.warmup.map { segment -> RunSegmentDTO in
                TrainingSessionMapper.toDTO(from: segment)
            }
            cooldownDTO = day.cooldown.map { segment -> RunSegmentDTO in
                TrainingSessionMapper.toDTO(from: segment)
            }
        } else {
            warmupDTO = nil
            cooldownDTO = nil
        }

        return DayDetailDTO(
            dayIndex: day.dayIndexInt,
            dayTarget: day.dayTarget,
            reason: day.reason ?? "",
            tips: day.tips,
            category: category,
            climateMeta: dayClimateMeta,
            primary: primary,
            warmup: warmupDTO,
            cooldown: cooldownDTO,
            supplementary: day.supplementaryActivities?.map { activity in
                switch activity {
                case .strength(let strengthActivity):
                    return .strength(
                        StrengthActivityDTO(
                            strengthType: strengthActivity.strengthType,
                            exercises: strengthActivity.exercises.map { ex in
                                ExerciseDTO(
                                    exerciseId: ex.exerciseId,
                                    name: ex.name,
                                    sets: ex.sets,
                                    reps: ex.reps.flatMap { Int($0) },
                                    repsRange: Int(ex.reps ?? "") == nil ? ex.reps : nil,
                                    durationSeconds: ex.durationSeconds,
                                    weightKg: ex.weightKg,
                                    restSeconds: ex.restSeconds,
                                    description: ex.description
                                )
                            },
                            durationMinutes: strengthActivity.durationMinutes,
                            description: strengthActivity.description
                        )
                    )
                case .cross(let crossActivity):
                    return .cross(
                        CrossActivityDTO(
                            crossType: crossActivity.crossType,
                            durationMinutes: crossActivity.durationMinutes,
                            distanceKm: crossActivity.distanceKm,
                            distanceDisplay: crossActivity.distanceDisplay,
                            distanceUnit: crossActivity.distanceUnit,
                            intensity: crossActivity.intensity,
                            description: crossActivity.description
                        )
                    )
                }
            }
        )
    }

    private func buildRunActivityDTO(from day: MutableTrainingDay, dayType: DayType) -> RunActivityDTO {
        let runType = dayType.apiRunType
        let originalDay = originalDay(for: day)
        let originalRun = originalDay?.primaryRunActivity
        let runClimateMeta = originalRun?.climateMeta ?? originalDay?.effectiveClimateMeta
        let preserveRunClimate = shouldPreserveRunClimate(day: day, runType: runType, originalRun: originalRun)
        guard let details = day.trainingDetails else {
            let climatePace = climatePaceValues(
                currentPace: nil,
                climateMeta: runClimateMeta,
                fallbackRun: originalRun,
                shouldUseFallback: preserveRunClimate
            )
            return RunActivityDTO(
                runType: runType,
                distanceKm: nil,
                distanceDisplay: nil,
                distanceUnit: nil,
                paceUnit: nil,
                durationMinutes: nil,
                durationSeconds: nil,
                pace: nil,
                basePace: climatePace.basePace,
                climateAdjustedPace: climatePace.adjustedPace,
                heartRateRange: nil,
                interval: nil,
                segments: nil,
                description: day.dayTarget,
                targetIntensity: nil,
                climateMeta: runClimateMeta.map { TrainingSessionMapper.toDTO(from: $0) }
            )
        }

        let climatePace = climatePaceValues(
            currentPace: details.pace,
            climateMeta: runClimateMeta,
            fallbackRun: originalRun,
            shouldUseFallback: preserveRunClimate
        )

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
                recoveryDurationSeconds: recovery.timeSeconds,
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
                basePace: climatePace.basePace,
                climateAdjustedPace: climatePace.adjustedPace,
                heartRateRange: nil,
                interval: intervalDTO,
                segments: nil,
                description: details.description ?? day.dayTarget,
                targetIntensity: nil,
                climateMeta: runClimateMeta.map { TrainingSessionMapper.toDTO(from: $0) }
            )
        }

        // 分段訓練（progression, combination, fartlek, fastFinish）
        if let segs = details.segments, !segs.isEmpty {
            let originalSegments = originalRun?.segments ?? []
            let segDTOs: [RunSegmentDTO] = segs.enumerated().map { index, seg -> RunSegmentDTO in
                let originalSegment = index < originalSegments.count ? originalSegments[index] : nil
                let preserveSegmentClimate = preserveRunClimate && seg.pace == originalSegment?.pace
                let segmentClimateMeta = originalSegment?.climateMeta ?? runClimateMeta
                let segmentClimatePace = climatePaceValues(
                    currentPace: seg.pace,
                    climateMeta: segmentClimateMeta,
                    fallbackSegment: originalSegment,
                    shouldUseFallback: preserveSegmentClimate
                )
                return RunSegmentDTO(
                    distanceKm: seg.distanceKm,
                    distanceM: nil,
                    distanceDisplay: nil,
                    distanceUnit: nil,
                    durationMinutes: nil,
                    durationSeconds: nil,
                    pace: seg.pace,
                    basePace: segmentClimatePace.basePace,
                    climateAdjustedPace: segmentClimatePace.adjustedPace,
                    climateMeta: segmentClimateMeta.map { TrainingSessionMapper.toDTO(from: $0) },
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
                basePace: climatePace.basePace,
                climateAdjustedPace: climatePace.adjustedPace,
                heartRateRange: nil,
                interval: nil,
                segments: segDTOs,
                description: details.description ?? day.dayTarget,
                targetIntensity: nil,
                climateMeta: runClimateMeta.map { TrainingSessionMapper.toDTO(from: $0) }
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
            basePace: climatePace.basePace,
            climateAdjustedPace: climatePace.adjustedPace,
            heartRateRange: nil,
            interval: nil,
            segments: nil,
            description: details.description ?? day.dayTarget,
            targetIntensity: nil,
            climateMeta: runClimateMeta.map { TrainingSessionMapper.toDTO(from: $0) }
        )
    }

    private func originalDay(for day: MutableTrainingDay) -> DayDetail? {
        weeklyPlan.days.first { $0.dayIndex == day.dayIndexInt }
    }

    private func shouldPreserveRunClimate(
        day: MutableTrainingDay,
        runType: String,
        originalRun: RunActivity?
    ) -> Bool {
        guard let details = day.trainingDetails, let originalRun else { return false }
        guard normalizedRunType(originalRun.runType) == normalizedRunType(runType) else { return false }
        guard details.pace == originalRun.pace else { return false }
        guard details.distanceKm == originalRun.distanceKm || details.totalDistanceKm == originalRun.distanceKm else { return false }
        return true
    }

    private func normalizedRunType(_ runType: String) -> String {
        switch runType.lowercased() {
        case "easy_run":
            return "easy"
        case "recovery_run":
            return "recovery"
        case "long_run", "long_slow_distance":
            return "lsd"
        default:
            return runType.lowercased()
        }
    }

    private func climatePaceValues(
        currentPace: String?,
        climateMeta: ClimateMeta?,
        fallbackRun: RunActivity?,
        shouldUseFallback: Bool
    ) -> (basePace: String?, adjustedPace: String?) {
        if currentPace == fallbackRun?.climateAdjustedPace {
            return (fallbackRun?.basePace, fallbackRun?.climateAdjustedPace)
        }
        if let calculated = adjustedPace(currentPace, climateMeta: climateMeta) {
            return (currentPace, calculated)
        }
        guard shouldUseFallback else { return (nil, nil) }
        return (fallbackRun?.basePace, fallbackRun?.climateAdjustedPace)
    }

    private func climatePaceValues(
        currentPace: String?,
        climateMeta: ClimateMeta?,
        fallbackSegment: RunSegment?,
        shouldUseFallback: Bool
    ) -> (basePace: String?, adjustedPace: String?) {
        if currentPace == fallbackSegment?.climateAdjustedPace {
            return (fallbackSegment?.basePace, fallbackSegment?.climateAdjustedPace)
        }
        if let calculated = adjustedPace(currentPace, climateMeta: climateMeta) {
            return (currentPace, calculated)
        }
        guard shouldUseFallback else { return (nil, nil) }
        return (fallbackSegment?.basePace, fallbackSegment?.climateAdjustedPace)
    }

    private func adjustedPace(_ pace: String?, climateMeta: ClimateMeta?) -> String? {
        guard let pace,
              let adjustmentPct = climateMeta?.paceAdjustmentPct,
              let seconds = paceSeconds(from: pace) else {
            return nil
        }
        let adjustedSeconds = seconds * (1 + adjustmentPct / 100)
        return formatPace(seconds: adjustedSeconds)
    }

    private func paceSeconds(from pace: String) -> Double? {
        let paceOnly = pace
            .split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? pace
        let components = paceOnly.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return Double(components[0] * 60 + components[1])
    }

    private func formatPace(seconds: Double) -> String {
        let roundedSeconds = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", roundedSeconds / 60, roundedSeconds % 60)
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
