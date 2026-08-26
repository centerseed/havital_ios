import Foundation

// MARK: - ScheduleTypeDefaults
/// 換課型時套用的**預設處方**：距離／配速／間歇結構／分段／暖身緩和。
///
/// 原本這一整段住在 `SimplifiedDailyCardV2.updateTrainingType`（1.4 的編輯卡片內），
/// 是 view 的 private method。2.0 的編輯週課表也要能換課型，抽成共用之後
/// **「換成間歇預設幾趟、暖身多長」只有一份答案**；留在 view 裡會變成兩份，
/// 而且沒有任何機制會讓它們一起改。
///
/// 這裡只決定「使用者把某天換成另一種課時，先填什麼進去」——不是課表生成規則
/// （那在後端），也不是儲存邏輯（那在 `EditScheduleV2ViewModel.saveEdits`）。
enum ScheduleTypeDefaults {

    // MARK: - 距離制間歇的快選模板
    /// 設計 frame-05 的 6 顆快選模板（`400m×8`…）。
    ///
    /// 原本這份清單住在 `IntervalEditorV2`（1.4 編輯 sheet）的 private `templates`。
    /// 2.0 的單日編輯頁也要同一組，抽成共用之後「快選模板有哪幾顆」只有一份答案。
    struct IntervalTemplate: Identifiable, Equatable {
        var id: String { "\(distanceM)x\(repeats)" }
        let repeats: Int
        let distanceM: Int
        /// 全部是數字與單位，不進 i18n。
        var name: String { "\(distanceM)m × \(repeats)" }
        var distanceKm: Double { Double(distanceM) / 1000.0 }
    }

    static let intervalQuickTemplates: [IntervalTemplate] = [
        IntervalTemplate(repeats: 8, distanceM: 400),
        IntervalTemplate(repeats: 10, distanceM: 400),
        IntervalTemplate(repeats: 5, distanceM: 800),
        IntervalTemplate(repeats: 6, distanceM: 800),
        IntervalTemplate(repeats: 4, distanceM: 1000),
        IntervalTemplate(repeats: 5, distanceM: 1000)
    ]

    // MARK: - Warmup/cooldown type classification

    static func typeNeedsWarmupCooldown(_ type: DayType) -> Bool {
        let noWarmupTypes: Set<DayType> = [
            .easyRun, .easy, .recovery_run, .lsd, .rest,
            .strength, .crossTraining, .yoga, .hiking, .cycling,
            .swimming, .elliptical, .rowing
        ]
        return !noWarmupTypes.contains(type)
    }

    static func defaultWarmupCooldown(vdot: Double) -> (warmup: RunSegment, cooldown: RunSegment) {
        let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:30"
        let warmup = RunSegment(
            distanceKm: 2.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
            durationMinutes: nil, durationSeconds: nil,
            pace: recoveryPace, basePace: nil, climateAdjustedPace: nil, climateMeta: nil, heartRateRange: nil,
            intensity: "easy", description: NSLocalizedString("schedule_editor.segment.warmup", comment: ""),
            kind: nil, repeats: nil, work: nil, recovery: nil
        )
        let cooldown = RunSegment(
            distanceKm: 1.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
            durationMinutes: nil, durationSeconds: nil,
            pace: recoveryPace, basePace: nil, climateAdjustedPace: nil, climateMeta: nil, heartRateRange: nil,
            intensity: "easy", description: NSLocalizedString("schedule_editor.segment.cooldown", comment: ""),
            kind: nil, repeats: nil, work: nil, recovery: nil
        )
        return (warmup, cooldown)
    }

    /// 把 `newType` 的預設處方套進 `day`。呼叫端負責標記「有未儲存的變更」。
    static func apply(_ newType: DayType, to day: inout MutableTrainingDay, vdot: Double) {
        day.trainingType = newType.rawValue

        switch newType {
        case .rest:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.rest", comment: "")
            day.trainingDetails = nil
            day.warmup = nil
            day.cooldown = nil

        case .easyRun, .easy, .recovery_run:
            day.dayTarget = newType == .recovery_run ? NSLocalizedString("schedule_editor.daytarget.recovery_run", comment: "") : NSLocalizedString("schedule_editor.daytarget.easy_run", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 5.0, pace: pace)
            day.warmup = nil
            day.cooldown = nil

        case .tempo, .threshold:
            // T-0036: tempo 正名為「馬拉松配速」(Z3, 中強度持續跑, 與後端 0.80 對齊);
            // 閾值跑為 LT2 (~0.85)。兩者為不同強度，分開框架。
            day.dayTarget = newType == .tempo ? NSLocalizedString("schedule_editor.daytarget.marathon_pace", comment: "") : NSLocalizedString("schedule_editor.daytarget.threshold", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 8.0, pace: pace)
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .interval:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.interval", comment: "")
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.4, distanceM: 400, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: nil, distanceKm: 0.2, distanceM: 200, timeMinutes: nil, pace: rPace, heartRateRange: nil),
                repeats: 4
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .longRun:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.long_run", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 15.0, pace: pace)
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .lsd:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.lsd", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 20.0, pace: pace)
            day.warmup = nil
            day.cooldown = nil

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
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

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
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .fartlek:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.fartlek", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 8.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.warmup", comment: "")),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.fast_run", comment: "")),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.recovery", comment: "")),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.fast_run", comment: "")),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.cooldown", comment: ""))
                ]
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .fastFinish:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.fast_finish", comment: "")
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 16.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 11.0, pace: easyPace, description: NSLocalizedString("schedule_editor.segment.easy_run", comment: "")),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: NSLocalizedString("schedule_editor.segment.marathon_pace", comment: ""))
                ]
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .racePace:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.race_pace", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: "marathon", vdot: vdot) ?? "5:15"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 10.0, pace: pace)
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .strides:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.strides", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.1, distanceM: 100, timeMinutes: nil, pace: pace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: String(format: NSLocalizedString("schedule_editor.segment.rest_in_place_minutes", comment: ""), 1), distanceKm: nil, distanceM: nil, timeMinutes: 1.0, pace: nil, heartRateRange: nil),
                repeats: 6
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .hillRepeats:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.hill_repeats", comment: "")
            let pace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.2, distanceM: 200, timeMinutes: nil, pace: pace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: NSLocalizedString("schedule_editor.segment.jog_downhill", comment: ""), distanceKm: nil, distanceM: nil, timeMinutes: 2.0, pace: nil, heartRateRange: nil),
                repeats: 6
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .cruiseIntervals:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.cruise_intervals", comment: "")
            let tPace = PaceCalculator.getSuggestedPace(for: "threshold", vdot: vdot) ?? "4:45"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 1.0, distanceM: 1000, timeMinutes: nil, pace: tPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: String(format: NSLocalizedString("schedule_editor.segment.recovery_run_minutes", comment: ""), 1), distanceKm: nil, distanceM: nil, timeMinutes: 1.0, pace: rPace, heartRateRange: nil),
                repeats: 4
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .shortInterval:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.short_interval", comment: "")
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.4, distanceM: 400, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: NSLocalizedString("schedule_editor.segment.recovery_run", comment: ""), distanceKm: 0.4, distanceM: 400, timeMinutes: nil, pace: rPace, heartRateRange: nil),
                repeats: 12
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .longInterval:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.long_interval", comment: "")
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let rPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:30"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 1.0, distanceM: 1000, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: NSLocalizedString("schedule_editor.segment.easy_jog_recovery", comment: ""), distanceKm: nil, distanceM: nil, timeMinutes: 2.5, pace: rPace, heartRateRange: nil),
                repeats: 5
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .norwegian4x4:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.norwegian_4x4", comment: "")
            let pace = PaceCalculator.getPaceForPercentage(0.92, vdot: vdot)
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: NSLocalizedString("schedule_editor.segment.hard_run", comment: ""), distanceKm: 0.9, distanceM: 900, timeMinutes: 4.0, pace: pace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: String(format: NSLocalizedString("schedule_editor.segment.recovery_run_minutes", comment: ""), 3), distanceKm: nil, distanceM: nil, timeMinutes: 3.0, pace: rPace, heartRateRange: nil),
                repeats: 4
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .yasso800:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.yasso_800", comment: "")
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.8, distanceM: 800, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: NSLocalizedString("schedule_editor.segment.equal_time_recovery", comment: ""), distanceKm: nil, distanceM: nil, timeMinutes: nil, pace: rPace, heartRateRange: nil),
                repeats: 8
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .crossTraining:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.cross_training", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .strength:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.strength", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .yoga:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.yoga", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .hiking:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.hiking", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .cycling:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.cycling", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        default:
            day.dayTarget = NSLocalizedString("schedule_editor.daytarget.custom", comment: "")
            day.trainingDetails = MutableTrainingDetails(distanceKm: 6.0)
            day.warmup = nil
            day.cooldown = nil
        }
    }
}
