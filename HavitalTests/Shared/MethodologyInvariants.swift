import Foundation
@testable import paceriz_dev

/// Single Source of Truth for methodology × phase invariant rules.
///
/// Used by:
/// - HavitalTests/SpecCompliance/TrainingPlan/*ACTests.swift (fixture-based, non-LLM)
/// - HavitalLLMTests/*LLMTests.swift (real API, nightly)
/// - HavitalUITests/E2E/Helpers/PlanVerificationHelper.swift (E2E XCUITest)
///
/// Rules derive from SPEC-ios-test-parity-methodology-invariants AC-IOS-TESTPARITY-INV-01..06.
/// Extending a methodology's behavior? Update here first; all three layers re-validate automatically.

enum Methodology: String {
    case paceriz
    case hansons
    case norwegian
    case polarized
    case balancedFitness = "balanced_fitness"
    case aerobicEndurance = "aerobic_endurance"
    case complete10k = "complete_10k"

    init?(id: String) { self.init(rawValue: id) }
}

enum TrainingPhase: String {
    case conversion, base, build, peak, taper
    init?(stageId: String) { self.init(rawValue: stageId) }
}

struct UserPlanConfig {
    let trainingDays: Set<Int>   // 1...7
    let longRunDay: Int?         // 1...7, nil = not enforced
    /// Backend default is 2; Norwegian may legitimately exceed if 4x4 counts as 1.
    var maxHardSessions: Int = 2
}

struct InvariantViolation: Equatable, CustomStringConvertible {
    let ruleId: String
    let message: String
    var description: String { "[\(ruleId)] \(message)" }
}

enum MethodologyInvariants {

    /// Hard training types — MUST stay in sync with backend
    /// `cloud/api_service/domains/training_plan/weekly_plan_validator.py` HARD_TYPES.
    /// Counted via RunActivity.runType OR RunActivity.interval.variant.
    static let hardTypes: Set<String> = [
        "interval", "short_interval", "long_interval",
        "tempo", "threshold", "fartlek",
        "norwegian_4x4", "yasso_800", "mile_repeats",
        "hill_repeats", "cruise_intervals", "race_pace",
        "strides",
    ]

    // MARK: - Public API

    /// Full validation; returns all violations (empty = pass).
    static func validate(
        plan: WeeklyPlanV2,
        methodology: Methodology,
        phase: TrainingPhase,
        config: UserPlanConfig? = nil
    ) -> [InvariantViolation] {
        var violations: [InvariantViolation] = []
        // Norwegian legitimately exceeds the default 2-hard-session cap (4x4 counts as a 3rd).
        let effectiveMaxHard = config?.maxHardSessions ?? (methodology == .norwegian ? 3 : 2)
        violations.append(contentsOf: validateStructure(plan: plan, phase: phase, maxHardSessions: effectiveMaxHard))
        violations.append(contentsOf: validateGeneral(plan: plan, config: config))
        switch methodology {
        case .paceriz:          violations.append(contentsOf: validatePaceriz(plan: plan, phase: phase))
        case .hansons:          violations.append(contentsOf: validateHansons(plan: plan))
        case .norwegian:        violations.append(contentsOf: validateNorwegian(plan: plan))
        case .polarized:        violations.append(contentsOf: validatePolarized(plan: plan))
        case .balancedFitness,
             .aerobicEndurance,
             .complete10k:      break // beginner/maintenance: general rules only
        }
        return violations
    }

    // MARK: - Group G: Structural Invariants (parity with backend weekly_plan_validator)

    /// AC-IOS-TESTPARITY-STRUCT-01..09
    static func validateStructure(
        plan: WeeklyPlanV2,
        phase: TrainingPhase,
        maxHardSessions: Int = 2
    ) -> [InvariantViolation] {
        var v: [InvariantViolation] = []

        // STRUCT-01: exactly 7 days, day_index 1–7 unique
        if plan.days.count != 7 {
            v.append(.init(ruleId: "STRUCT-01.seven_days", message: "Plan must have 7 days, got \(plan.days.count)"))
        }
        let indices = plan.days.map { $0.dayIndex }
        if Set(indices) != Set(1...7) {
            v.append(.init(ruleId: "STRUCT-01.day_index_range", message: "day_index must cover 1–7 uniquely, got \(indices.sorted())"))
        }

        // STRUCT-02: at least one rest day
        let restCount = plan.days.filter { $0.session == nil || $0.category == .rest }.count
        if restCount == 0 {
            v.append(.init(ruleId: "STRUCT-02.rest_day_required", message: "Plan must have at least 1 rest day"))
        }

        // STRUCT-03: non-rest day has primary
        for day in plan.days where day.category != nil && day.category != .rest {
            if day.session == nil {
                v.append(.init(ruleId: "STRUCT-03.non_rest_has_primary",
                               message: "Day \(day.dayIndex) category=\(day.category?.rawValue ?? "nil") missing session"))
            }
        }

        // STRUCT-04, 05, 06 (run-specific)
        for day in plan.days {
            guard case let .run(activity)? = day.session?.primary else { continue }

            // STRUCT-04: workload presence
            let hasDistance = activity.distanceKm != nil
            let hasDuration = activity.durationMinutes != nil
            let hasSegments = (activity.segments?.isEmpty == false)
            let hasInterval = activity.interval != nil
            if !(hasDistance || hasDuration || hasSegments || hasInterval) {
                v.append(.init(ruleId: "STRUCT-04.run_must_have_workload",
                               message: "Day \(day.dayIndex) run (\(activity.runType)) lacks distance/duration/segments/interval"))
            }

            // STRUCT-05: hr_range required except interval/fartlek
            let rt = activity.runType.lowercased()
            if rt != "interval" && rt != "fartlek" && activity.heartRateRange == nil {
                v.append(.init(ruleId: "STRUCT-05.hr_range_required",
                               message: "Day \(day.dayIndex) runType=\(rt) missing heartRateRange"))
            }

            // STRUCT-06: interval integrity
            if let interval = activity.interval {
                if interval.repeats <= 0 {
                    v.append(.init(ruleId: "STRUCT-06.interval_repeats",
                                   message: "Day \(day.dayIndex) interval.repeats must be > 0, got \(interval.repeats)"))
                }
                let hasWorkSpec = interval.workPace != nil || interval.workDistanceKm != nil || interval.workDistanceM != nil
                if !hasWorkSpec {
                    v.append(.init(ruleId: "STRUCT-06.interval_incomplete",
                                   message: "Day \(day.dayIndex) interval missing work_pace / work_distance_km / work_distance_m"))
                }
            }
        }

        // STRUCT-07: intensity_total_minutes
        if let minutes = plan.intensityTotalMinutes {
            if minutes.low < 0 || minutes.medium < 0 || minutes.high < 0 {
                v.append(.init(ruleId: "STRUCT-07.intensity_invalid",
                               message: "intensityTotalMinutes has negative field: low=\(minutes.low), medium=\(minutes.medium), high=\(minutes.high)"))
            }
        } else {
            v.append(.init(ruleId: "STRUCT-07.intensity_required",
                           message: "intensityTotalMinutes must be present"))
        }

        // STRUCT-08: hard session count
        let maxHard = maxHardSessions
        let hardCount = plan.days.reduce(0) { acc, day in
            guard case let .run(activity)? = day.session?.primary else { return acc }
            let primaryType = activity.runType.lowercased()
            let variant = activity.interval?.variant?.lowercased() ?? ""
            return acc + (hardTypes.contains(primaryType) || hardTypes.contains(variant) ? 1 : 0)
        }
        if hardCount > maxHard {
            v.append(.init(ruleId: "STRUCT-08.too_many_hard_sessions",
                           message: "Hard sessions \(hardCount) > max \(maxHard)"))
        }

        // STRUCT-09: supplementary strength forbidden in conversion/peak/taper
        if phase == .conversion || phase == .peak || phase == .taper {
            for day in plan.days {
                guard let supp = day.session?.supplementary else { continue }
                for item in supp {
                    if case .strength = item {
                        v.append(.init(ruleId: "STRUCT-09.no_strength_in_gated_stage",
                                       message: "Day \(day.dayIndex) has supplementary strength in \(phase.rawValue) phase"))
                        break
                    }
                }
            }
        }

        return v
    }

    // MARK: - AC-IOS-TESTPARITY-INV-06 (general)

    static func validateGeneral(plan: WeeklyPlanV2, config: UserPlanConfig?) -> [InvariantViolation] {
        var v: [InvariantViolation] = []

        // Pace range
        for day in plan.days {
            guard let pace = primaryPace(day), let minutes = parsePaceMinutes(pace) else { continue }
            let runType = primaryRunType(day) ?? ""
            let upperBound = (runType == "recovery" || runType == "recovery_run") ? 9.5 : 9.0
            if minutes < 2.5 || minutes > upperBound {
                v.append(.init(ruleId: "INV-06.pace_range",
                               message: "Day \(day.dayIndex) pace \(pace) out of range for runType=\(runType)"))
            }
        }

        // No back-to-back high intensity
        let highTypes: Set<String> = ["interval", "threshold", "tempo"]
        let sortedDays = plan.days.sorted { $0.dayIndex < $1.dayIndex }
        for i in 1..<sortedDays.count {
            let prev = primaryRunType(sortedDays[i-1]) ?? ""
            let curr = primaryRunType(sortedDays[i]) ?? ""
            if highTypes.contains(prev) && highTypes.contains(curr) && sortedDays[i].dayIndex == sortedDays[i-1].dayIndex + 1 {
                v.append(.init(ruleId: "INV-06.no_back_to_back_high",
                               message: "Day \(sortedDays[i-1].dayIndex) (\(prev)) and Day \(sortedDays[i].dayIndex) (\(curr)) are consecutive high intensity"))
            }
        }

        // Training days match config
        if let config = config {
            let actualTrainingDays = Set(plan.days.filter { $0.session != nil }.map { $0.dayIndex })
            if actualTrainingDays != config.trainingDays {
                v.append(.init(ruleId: "INV-06.training_days_match",
                               message: "Expected training days \(config.trainingDays.sorted()), got \(actualTrainingDays.sorted())"))
            }
            // Long run day
            if let longDay = config.longRunDay {
                let longRunDays = plan.days.filter { primaryRunType($0) == "long_run" || primaryRunType($0) == "lsd" }.map { $0.dayIndex }
                if !longRunDays.isEmpty && !longRunDays.contains(longDay) {
                    v.append(.init(ruleId: "INV-06.long_run_day",
                                   message: "Long run should be on day \(longDay); actual days: \(longRunDays)"))
                }
            }
        }

        return v
    }

    // MARK: - AC-IOS-TESTPARITY-INV-02 (paceriz)

    static func validatePaceriz(plan: WeeklyPlanV2, phase: TrainingPhase) -> [InvariantViolation] {
        var v: [InvariantViolation] = []
        let runTypes = plan.days.compactMap { primaryRunType($0) }
        let hasTempo = runTypes.contains("tempo")
        let hasThreshold = runTypes.contains("threshold")
        let hasInterval = runTypes.contains("interval")
        let hasRacePace = runTypes.contains("race_pace") || runTypes.contains("race")

        switch phase {
        case .base:
            if !hasTempo { v.append(.init(ruleId: "INV-02.paceriz.base.tempo_required", message: "Base phase must include tempo")) }
            if hasInterval { v.append(.init(ruleId: "INV-02.paceriz.base.no_interval", message: "Base phase must not include interval")) }
            let easyRatio = ratioEasyByMinutes(plan)
            if let r = easyRatio, r < 0.70 {
                v.append(.init(ruleId: "INV-02.paceriz.base.easy_ratio", message: "Easy ratio \(r) < 0.70 in base phase"))
            }
        case .build:
            if !(hasTempo || hasThreshold) { v.append(.init(ruleId: "INV-02.paceriz.build.moderate_required", message: "Build phase must include tempo or threshold")) }
            if let minutes = plan.intensityTotalMinutes, minutes.medium == 0 {
                v.append(.init(ruleId: "INV-02.paceriz.build.medium_positive", message: "Build phase medium intensity must be > 0")) }
        case .peak:
            if !hasInterval { v.append(.init(ruleId: "INV-02.paceriz.peak.interval_required", message: "Peak phase must include interval")) }
            if !hasThreshold { v.append(.init(ruleId: "INV-02.paceriz.peak.threshold_required", message: "Peak phase must include threshold")) }
            if !hasRacePace { v.append(.init(ruleId: "INV-02.paceriz.peak.race_pace_required", message: "Peak phase must include at least one race-pace-style session")) }
        case .taper:
            if hasInterval { v.append(.init(ruleId: "INV-02.paceriz.taper.no_new_high", message: "Taper must not include interval")) }
        case .conversion:
            break
        }
        return v
    }

    // MARK: - AC-IOS-TESTPARITY-INV-03 (hansons)

    static func validateHansons(plan: WeeklyPlanV2) -> [InvariantViolation] {
        var v: [InvariantViolation] = []
        let total = plan.totalDistance
        let longRunDays = plan.days.filter { primaryRunType($0) == "long_run" || primaryRunType($0) == "lsd" }
        for day in longRunDays {
            guard case let .run(activity)? = day.session?.primary, let dist = activity.distanceKm else { continue }
            if total > 0 && dist / total > 0.30 {
                v.append(.init(ruleId: "INV-03.hansons.long_run_30pct",
                               message: "Hansons long run \(dist)km > 30% of week total \(total)km"))
            }
        }

        let runTypes = plan.days.compactMap { primaryRunType($0) }
        let tempoCount = runTypes.filter { $0 == "tempo" || $0 == "threshold" }.count
        let speedCount = runTypes.filter { $0 == "interval" || $0 == "strides" }.count
        let hasStrength = plan.days.contains(where: { day in
            if case .strength? = day.session?.primary { return true } else { return false }
        })
        if tempoCount < 1 {
            v.append(.init(ruleId: "INV-03.hansons.tempo_weekly", message: "Hansons week should include at least one tempo/threshold")) }
        if speedCount < 1 && !hasStrength {
            v.append(.init(ruleId: "INV-03.hansons.speed_or_strength", message: "Hansons week should include one speed session or strength session")) }

        // 24h after long run no high intensity
        let highTypes: Set<String> = ["interval", "threshold", "tempo"]
        for day in longRunDays {
            let next = plan.days.first { $0.dayIndex == day.dayIndex + 1 }
            if let next = next, let nextType = primaryRunType(next), highTypes.contains(nextType) {
                v.append(.init(ruleId: "INV-03.hansons.post_long_rest",
                               message: "Day \(next.dayIndex) (\(nextType)) is high intensity the day after long run"))
            }
        }
        return v
    }

    // MARK: - AC-IOS-TESTPARITY-INV-04 (norwegian)

    static func validateNorwegian(plan: WeeklyPlanV2) -> [InvariantViolation] {
        var v: [InvariantViolation] = []
        let hasNorwegian4x4 = plan.days.contains { day in
            guard case let .run(activity)? = day.session?.primary else { return false }
            let variant = activity.interval?.variant?.lowercased() ?? ""
            return activity.runType.lowercased() == "norwegian_4x4" || variant == "norwegian_4x4" ||
                   activity.runType.lowercased() == "cruise_intervals" || variant == "cruise_intervals"
        }
        if !hasNorwegian4x4 {
            v.append(.init(ruleId: "INV-04.norwegian.signature_session", message: "Norwegian week must include norwegian_4x4 or cruise_intervals session"))
        }
        let thresholdIntervalCount = plan.days.compactMap { primaryRunType($0) }
            .filter { $0 == "threshold" || $0 == "interval" }.count
        if thresholdIntervalCount < 2 {
            v.append(.init(ruleId: "INV-04.norwegian.quality_count", message: "Norwegian week should have >= 2 threshold/interval sessions, got \(thresholdIntervalCount)"))
        }
        return v
    }

    // MARK: - AC-IOS-TESTPARITY-INV-05 (polarized)

    static func validatePolarized(plan: WeeklyPlanV2) -> [InvariantViolation] {
        var v: [InvariantViolation] = []
        if let minutes = plan.intensityTotalMinutes {
            if minutes.medium != 0 {
                v.append(.init(ruleId: "INV-05.polarized.medium_zero", message: "Polarized medium minutes must be 0, got \(minutes.medium)"))
            }
            let denom = minutes.low + minutes.high
            if denom > 0 {
                let lowRatio = minutes.low / denom
                if lowRatio < 0.78 {
                    v.append(.init(ruleId: "INV-05.polarized.low_ratio", message: "Polarized low/(low+high) ratio \(lowRatio) < 0.78"))
                }
            }
        } else {
            v.append(.init(ruleId: "INV-05.polarized.intensity_required", message: "Polarized plan must provide intensityTotalMinutes"))
        }
        let moderateRunTypes: Set<String> = ["tempo", "threshold"]
        for day in plan.days {
            guard let rt = primaryRunType(day) else { continue }
            if moderateRunTypes.contains(rt) {
                v.append(.init(ruleId: "INV-05.polarized.no_moderate_runtype", message: "Polarized must not include \(rt) (day \(day.dayIndex))"))
            }
        }
        return v
    }

    // MARK: - Helpers

    private static func primaryRunType(_ day: DayDetail) -> String? {
        guard let session = day.session, case let .run(activity) = session.primary else { return nil }
        return activity.runType.lowercased()
    }

    private static func primaryPace(_ day: DayDetail) -> String? {
        guard let session = day.session, case let .run(activity) = session.primary else { return nil }
        return activity.pace
    }

    /// Parse "m:ss" or "mm:ss" into minutes (Double). Returns nil if unparseable.
    static func parsePaceMinutes(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
        return m + s / 60.0
    }

    /// Easy-run minutes as a fraction of total run minutes (nil if zero total).
    private static func ratioEasyByMinutes(_ plan: WeeklyPlanV2) -> Double? {
        var easy = 0.0
        var total = 0.0
        for day in plan.days {
            guard case let .run(activity)? = day.session?.primary,
                  let mins = activity.durationMinutes else { continue }
            total += Double(mins)
            let rt = activity.runType.lowercased()
            if rt == "easy" || rt == "recovery" || rt == "recovery_run" || rt == "lsd" || rt == "long_run" {
                easy += Double(mins)
            }
        }
        return total > 0 ? easy / total : nil
    }
}
