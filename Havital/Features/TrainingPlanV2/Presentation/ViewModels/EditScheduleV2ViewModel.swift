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

            // T-0239（havital_ios #10）：通知訂閱者課表已變更（成就頁 PersonalAchievementsViewModel
            // 等訂閱 .dataChanged(.trainingPlanV2)），否則手動改課表後不會刷新。
            // iOS 約束 #4：事件由 ViewModel 發布，非 Repository。
            CacheEventBus.shared.publish(.dataChanged(.trainingPlanV2))

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
        let originalDay = originalDay(for: day)
        let calendarDay = calendarDay(for: day)

        // 使用者沒動這天 → 直接用無損的 Domain→DTO mapper 回傳後端原本的 day，
        // 完整保留熱適應卡、心率區間、目標強度、顯示單位、segment 等編輯器沒有
        // 模型化的欄位。只有真的被改動的日子才進入下面從 MutableTrainingDay 重建
        // 的有損路徑（重建本身仍盡量從 original 帶回非編輯欄位）。
        // 比的是**內容**不是位置：純互換日期（onMove 只改 dayIndex）必須留在無損路徑，
        // 否則被搬動的天會白白掉一堆編輯器沒模型化的欄位。搬移後要把 DTO 的 dayIndex
        // 改寫成新位置，原始 DTO 帶的是舊位置。
        if let originalDay, MutableTrainingDay(from: originalDay).hasSameContent(as: day) {
            // 沒被編輯的那天最容易漏：直接回傳原始 DTO 會把舊 doc 殘留的 climate
            // 原封不動送回後端。氣候一律不上網路（T-0165）。
            return Self.renumber(
                Self.stripClimate(TrainingSessionMapper.toDTO(from: originalDay)),
                to: day.dayIndexInt
            )
        }

        let dayType = DayType(rawValue: day.trainingType) ?? .rest
        // T-0165：編輯送出不攜帶任何 climate 欄位。氣候綁日期不綁課表，
        // 後端寫入前一律 strip、讀取時依 day_index 重投影。
        let dayClimateMeta: ClimateMetaDTO? = nil
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
                    description: exercise.description,
                    seriesId: nil
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
            primary = .run(buildRunActivityDTO(
                from: day,
                dayType: dayType,
                calendarDay: calendarDay
            ))
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
                                    description: ex.description,
                                    seriesId: ex.seriesId
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

    private func buildRunActivityDTO(
        from day: MutableTrainingDay,
        dayType: DayType,
        calendarDay: DayDetail?
    ) -> RunActivityDTO {
        let runType = dayType.apiRunType
        let originalDay = originalDay(for: day)
        let originalRun = originalDay?.primaryRunActivity
        let sameRunType = originalRun.map { normalizedRunType($0.runType) == normalizedRunType(runType) } ?? false

        // 基底 overlay：runType 沒變就從原始 run 的**無損** DTO 出發，只覆寫編輯器真正
        // 擁有的欄位。方向性是關鍵 —— 舊版是逐欄重建、預設「沒寫到就變 nil」，於是心率
        // 區間、目標強度、segment 的 kind/work/recovery 一個一個被靜默洗掉，每補一個欄位
        // 就再漏下一個（24529353 → 72561b1a → f696f05e）。改成 overlay 之後，DTO 日後
        // 新增任何欄位預設就是被保留的，不需要有人記得回來補這裡。
        // runType 有變 = 換了一種課，處方本身要交給後端重算，故從空白基底出發。
        var base = sameRunType && originalRun != nil
            ? Self.stripRunClimate(TrainingSessionMapper.toDTO(from: originalRun!))
            : Self.emptyRunActivityDTO(runType: runType)
        base.runType = runType
        // MutableTrainingDay.isTrail 是非 optional Bool（nil 會被讀成 false），
        // 無條件寫回會把後端原本的 null 憑空變成 false —— 有損路徑不只會丟欄位，
        // 也會塞入原本不存在的值。只有使用者真的切換過才寫。
        if day.isTrail != (base.isTrail ?? false) {
            base.isTrail = day.isTrail
        }
        // 清空前先留一份快照，供 setDistanceKm 判斷距離有沒有真的改變。
        let baseline = base
        // 處方形狀由編輯器全權決定：先清空，再由下面各分支填回自己擁有的部分。
        // 沒被清掉的欄位（heart_rate_range / target_intensity / pace_unit …）就是
        // 「編輯器沒有模型化」的那一類，一律沿用基底。
        Self.clearPrescriptionShape(&base)

        guard let details = day.trainingDetails else {
            base.description = day.dayTarget
            return base
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
                recoveryDurationSeconds: recovery.timeSeconds,
                variant: nil
            )
            Self.setDistanceKm(&base, details.totalDistanceKm ?? details.distanceKm, base: baseline)
            base.durationMinutes = details.timeMinutes.map { Int($0) }
            base.pace = details.pace
            base.interval = intervalDTO
            base.description = details.description ?? day.dayTarget
            return base
        }

        // 分段訓練（progression, combination, fartlek, fastFinish）
        if let segs = details.segments, !segs.isEmpty {
            let originalSegments = (sameRunType ? originalRun?.segments : nil) ?? []
            let segDTOs: [RunSegmentDTO] = segs.enumerated().map { index, seg -> RunSegmentDTO in
                let originalSegment = index < originalSegments.count ? originalSegments[index] : nil
                // 同樣走 overlay：段落的基底是原始 segment，編輯器只覆寫距離 / 配速 / 描述。
                // kind / repeats / work / recovery 等段落結構就靠「沒被覆寫」而原樣留下 ——
                // 舊版把它們寫死 nil，於是只要編輯 fartlek 那天的配速，
                // 「6×400m 間歇」就會被打平成一段勻速跑（T-0149 / T-0245）。
                var out = originalSegment.map { Self.stripSegmentClimate(TrainingSessionMapper.toDTO(from: $0)) }
                    ?? Self.emptyRunSegmentDTO()
                out.distanceKm = seg.distanceKm
                // distance_m 與 distance_km 是同一個距離的兩種單位，只覆寫其一會自相矛盾。
                out.distanceM = nil
                out.pace = seg.pace
                out.description = seg.description
                    ?? originalSegment?.description
                    ?? String(format: NSLocalizedString("schedule_editor.segment.number_format", comment: ""), index + 1)
                return out
            }
            Self.setDistanceKm(&base, details.totalDistanceKm, base: baseline)
            base.durationMinutes = details.timeMinutes.map { Int($0) }
            base.pace = details.pace
            base.segments = segDTOs
            base.description = details.description ?? day.dayTarget
            return base
        }

        // 一般跑步
        Self.setDistanceKm(&base, details.distanceKm, base: baseline)
        base.durationMinutes = details.timeMinutes.map { Int($0) }
        base.pace = details.pace
        base.description = details.description ?? day.dayTarget
        return base
    }

    /// 把 DTO 搬到新的 day_index。內容原封不動，只換位置。
    static func renumber(_ dto: DayDetailDTO, to dayIndex: Int) -> DayDetailDTO {
        guard dto.dayIndex != dayIndex else { return dto }
        var out = dto
        out.dayIndex = dayIndex
        return out
    }

    /// 剝除 DayDetailDTO 上所有 climate 欄位。剝的是氣候，不是處方。
    ///
    /// 後端 `strip_climate` 也會擋，但沒理由把它送上網路 —— 而且靜默送回去會讓
    /// 「App 到底有沒有遵守新契約」變得無法用測試斷言。
    ///
    /// 實作刻意用 mutate 而非重建：**只列出要清掉的欄位，沒列到的一律原樣留著**。
    /// 這個方向性是關鍵 —— 舊版逐欄重建的預設是「沒寫到就變 nil」，於是每次 DTO 新增欄位
    /// 都會靜默掉資料（bd1e4d48 補了 climate、f696f05e 又漏掉 kind/work/recovery）。
    /// 改成 mutate 之後，新增欄位預設就是被保留的，不需要任何人記得回來補這裡。
    /// IntervalBlockDTO 不帶 climate 欄位，原樣帶過。
    static func stripClimate(_ dto: DayDetailDTO) -> DayDetailDTO {
        var out = dto
        out.climateMeta = nil
        if case .run(var run) = out.primary {
            run.basePace = nil
            run.climateAdjustedPace = nil
            run.climateMeta = nil
            run.segments = run.segments?.map(stripSegmentClimate)
            out.primary = .run(run)
        }
        return out
    }

    /// 剝除單一 segment 的 climate 欄位。SegmentEffortDTO 不含 climate，故無須遞迴。
    static func stripSegmentClimate(_ segment: RunSegmentDTO) -> RunSegmentDTO {
        var out = segment
        out.basePace = nil
        out.climateAdjustedPace = nil
        out.climateMeta = nil
        return out
    }

    /// 剝除 run 層（含其 segments）的 climate 欄位，不碰 DayDetail 層。
    static func stripRunClimate(_ run: RunActivityDTO) -> RunActivityDTO {
        var out = run
        out.basePace = nil
        out.climateAdjustedPace = nil
        out.climateMeta = nil
        out.segments = out.segments?.map(stripSegmentClimate)
        return out
    }

    /// 清空「處方形狀」欄位 —— 這些由編輯器全權決定，各分支會填回自己擁有的部分。
    ///
    /// 這是 overlay 寫法唯一需要小心的地方：保留是預設，所以**互斥的形狀必須明確清掉**，
    /// 否則把間歇改成一般跑步時，舊的 interval / segments 會殘留下來。
    /// distance_display / distance_unit 不在這裡清 —— 它們由 `setDistanceKm` 依「距離有沒有
    /// 真的改變」決定，否則使用者只改配速也會被洗掉顯示單位（純搬移那條路徑的已知 bug 形狀）。
    private static func clearPrescriptionShape(_ dto: inout RunActivityDTO) {
        dto.distanceKm = nil
        dto.durationMinutes = nil
        dto.durationSeconds = nil
        dto.pace = nil
        dto.interval = nil
        dto.segments = nil
    }

    /// 設定距離，並在距離**真的改變**時一併作廢其衍生顯示值。
    ///
    /// distance_display / distance_unit 是同一個距離的另一種單位表述（8 km ↔ 5 mi）。
    /// 距離變了卻留著舊的顯示值，UI 會出現「10 公里 / 5.0 mi」這種自相矛盾；
    /// 距離沒變卻清掉它們，則是白白丟失使用者的單位偏好。兩種都是實際出過的 bug。
    private static func setDistanceKm(_ dto: inout RunActivityDTO, _ km: Double?, base: RunActivityDTO) {
        dto.distanceKm = km
        if km != base.distanceKm {
            dto.distanceDisplay = nil
            dto.distanceUnit = nil
        }
    }

    /// runType 改變時的空白基底：處方交給後端重算，不從舊課帶任何欄位過來。
    private static func emptyRunActivityDTO(runType: String) -> RunActivityDTO {
        RunActivityDTO(
            runType: runType,
            distanceKm: nil,
            distanceDisplay: nil,
            distanceUnit: nil,
            paceUnit: nil,
            durationMinutes: nil,
            durationSeconds: nil,
            pace: nil,
            basePace: nil,
            climateAdjustedPace: nil,
            heartRateRange: nil,
            interval: nil,
            segments: nil,
            description: nil,
            targetIntensity: nil,
            climateMeta: nil,
            isTrail: nil
        )
    }

    /// 新增的段落（原始課表沒有對應 index）用的空白基底。
    private static func emptyRunSegmentDTO() -> RunSegmentDTO {
        RunSegmentDTO(
            distanceKm: nil,
            distanceM: nil,
            distanceDisplay: nil,
            distanceUnit: nil,
            durationMinutes: nil,
            durationSeconds: nil,
            pace: nil,
            basePace: nil,
            climateAdjustedPace: nil,
            climateMeta: nil,
            heartRateRange: nil,
            intensity: nil,
            description: nil,
            kind: nil,
            repeats: nil,
            work: nil,
            recovery: nil
        )
    }

    private func originalDay(for day: MutableTrainingDay) -> DayDetail? {
        let sourceDayIndex = day.originalDayIndex ?? day.dayIndexInt
        return weeklyPlan.days.first { $0.dayIndex == sourceDayIndex }
    }

    private func calendarDay(for day: MutableTrainingDay) -> DayDetail? {
        weeklyPlan.days.first { $0.dayIndex == day.dayIndexInt }
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

#if DEBUG
extension EditScheduleV2ViewModel {
    func debug_buildDayDetailDTO(from day: MutableTrainingDay) -> DayDetailDTO {
        buildDayDetailDTO(from: day)
    }
}
#endif

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
