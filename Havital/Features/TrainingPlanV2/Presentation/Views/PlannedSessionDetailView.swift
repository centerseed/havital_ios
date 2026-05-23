import SwiftUI

// MARK: - PlannedSessionDetailView
// Phase C: Training detail sheet for planned (future) days.
// Accepts DayDetail + optional date + optional WorkoutV2.
// When WorkoutV2 is nil (planned/future), history-only controls are hidden.
// History workout: pushes existing WorkoutDetailViewV2 instead.
// Design source: /tmp/paceriz-design/paceriz-app/project/workout-detail.jsx

struct PlannedSessionDetailView: View {
    let day: DayDetail
    let date: Date?
    @State private var showTrainingTypeInfo = false
    @AppStorage("climateAdjustmentEnabled") private var climateAdjustmentEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroCard.padding(.horizontal, 16).padding(.top, 12)
                coachIntentCard.padding(.horizontal, 16).padding(.top, 12)
                structureSectionIfNeeded.padding(.horizontal, 16).padding(.top, 12)
                targetZonesSection.padding(.horizontal, 16).padding(.top, 12)
                nonRunContentSection.padding(.horizontal, 16).padding(.top, 12)
                tipSection.padding(.horizontal, 16).padding(.top, 12)
                supplementarySection.padding(.horizontal, 16).padding(.top, 12)
                climateSection.padding(.horizontal, 16).padding(.top, 12)
                secondaryButtons.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    if let date {
                        Text("\(weekdayString(date)) · \(shortDateString(date))")
                            .font(AppFont.micro()).foregroundColor(.secondary)
                    }
                    Text(NSLocalizedString("training.detail.title", comment: "")).font(AppFont.labelStrong()).kerning(-0.01)
                }
            }
        }
        .sheet(isPresented: $showTrainingTypeInfo) {
            if let info = TrainingTypeInfo.info(for: day.type) {
                TrainingTypeInfoView(trainingTypeInfo: info)
            }
        }
    }

    // MARK: - Workout Type Metadata

    private enum WorkoutMeta {
        static func accentColor(for type: DayType) -> Color {
            switch type {
            case .easyRun, .easy, .recovery_run:
                return PacerizColor.green
            case .lsd:
                return PacerizColor.blue
            case .interval, .tempo, .progression, .threshold, .combination,
                 .strides, .hillRepeats, .cruiseIntervals, .shortInterval,
                 .longInterval, .norwegian4x4, .yasso800:
                return PacerizColor.orange
            case .longRun, .hiking, .cycling, .fastFinish:
                return PacerizColor.blue
            case .race, .racePace:
                return Color(red: 0.96, green: 0.26, blue: 0.21)
            case .rest:
                return Color(.systemGray)
            case .crossTraining, .strength, .fartlek, .swimming, .elliptical, .rowing, .yoga:
                return Color.purple
            }
        }

        // chip label + display name。用 exhaustive switch（編譯器保證涵蓋所有 DayType；
        // 未來新增型態會編譯失敗，逼著補上，避免 hero 顯示醜 fallback）。
        private static func labelPair(for type: DayType) -> (chip: String, name: String) {
            switch type {
            case .easy, .easyRun:   return ("EASY · Z2",             NSLocalizedString("training.type.easy", comment: ""))
            case .recovery_run:     return ("EASY · Z2",             NSLocalizedString("training.type.recovery", comment: ""))
            case .lsd, .longRun:    return ("LONG · Z2-Z3",          NSLocalizedString("training.type.lsd", comment: ""))
            case .interval:         return ("INTERVAL · Z4",         NSLocalizedString("training.type.interval", comment: ""))
            case .tempo:            return ("TEMPO · Z3-Z4",         NSLocalizedString("training.type.tempo", comment: ""))
            case .threshold:        return ("THRESHOLD · Z4",        NSLocalizedString("training.type.threshold", comment: ""))
            case .progression:      return ("PROGRESSION · Z2 → Z4", NSLocalizedString("training.type.progression", comment: ""))
            case .fastFinish:       return ("FAST FINISH · Z2 + Z3", NSLocalizedString("training.type.fast_finish", comment: ""))
            case .race:             return ("RACE · Z5",             NSLocalizedString("training.type.race", comment: ""))
            case .racePace:         return ("RACE PACE · Z4-Z5",     NSLocalizedString("training.type.race_pace", comment: ""))
            case .combination:      return ("COMBINATION",           NSLocalizedString("training.type.combination", comment: ""))
            case .strides:          return ("STRIDES · Z4-Z5",       NSLocalizedString("training.type.strides", comment: ""))
            case .hillRepeats:      return ("HILL REPEATS · Z4",     NSLocalizedString("training.type.hill_repeats", comment: ""))
            case .cruiseIntervals:  return ("CRUISE · Z3-Z4",        NSLocalizedString("training.type.cruise_intervals", comment: ""))
            case .shortInterval:    return ("SHORT · Z5",            NSLocalizedString("training.type.short_interval", comment: ""))
            case .longInterval:     return ("LONG · Z4-Z5",          NSLocalizedString("training.type.long_interval", comment: ""))
            case .norwegian4x4:     return ("NOR 4×4 · Z4-Z5",       NSLocalizedString("training.type.norwegian_4x4", comment: ""))
            case .yasso800:         return ("YASSO 800 · Z4-Z5",     NSLocalizedString("training.type.yasso_800", comment: ""))
            case .fartlek:          return ("FARTLEK · Z2-Z4",       NSLocalizedString("training.type.fartlek", comment: ""))
            case .strength:         return ("STRENGTH",              NSLocalizedString("training.type.strength", comment: ""))
            case .crossTraining:    return ("CROSS TRAINING",        NSLocalizedString("training.type.cross_training", comment: ""))
            case .yoga:             return ("CROSS TRAINING",        NSLocalizedString("training.type.yoga", comment: ""))
            case .hiking:           return ("CROSS TRAINING",        NSLocalizedString("training.type.hiking", comment: ""))
            case .cycling:          return ("CROSS TRAINING",        NSLocalizedString("training.type.cycling", comment: ""))
            case .swimming:         return ("CROSS TRAINING",        NSLocalizedString("training.type.swimming", comment: ""))
            case .elliptical:       return ("CROSS TRAINING",        NSLocalizedString("training.type.elliptical", comment: ""))
            case .rowing:           return ("CROSS TRAINING",        NSLocalizedString("training.type.rowing", comment: ""))
            case .rest:             return ("REST",                  NSLocalizedString("training.type.rest", comment: ""))
            }
        }

        static func chipLabel(for type: DayType) -> String {
            labelPair(for: type).chip
        }

        static func typeName(for type: DayType) -> String {
            labelPair(for: type).name
        }
    }

    /// 非跑步主項（力量／交叉訓練）：primary 不是 run 的課表日。
    private var isNonRunSession: Bool { day.session != nil && day.primaryRunActivity == nil }

    private var typeAccentColor: Color {
        isNonRunSession ? PacerizColor.indigo : WorkoutMeta.accentColor(for: day.type)
    }
    private var typeChipLabel: String { WorkoutMeta.chipLabel(for: day.type) }
    private var workoutTypeName: String { WorkoutMeta.typeName(for: day.type) }

    /// Easy / long-easy runs: single-segment, relaxed. Pace shown as original ±20s, no structure.
    private var isEasyOrLSD: Bool {
        switch day.type {
        case .easy, .easyRun, .recovery_run, .lsd, .longRun: return true
        default: return false
        }
    }

    /// Original (non-climate-adjusted) pace widened by ±20s, e.g. "5:40–6:20"（依使用者單位換算）。
    private func easyPaceRange(_ run: RunActivity) -> String? {
        let original = run.basePace ?? run.pace
        guard let original, let sec = paceStringToSeconds(original) else { return original }
        return "\(convertedPaceString(secondsPerKm: max(0, sec - 20)))–\(convertedPaceString(secondsPerKm: sec + 20))"
    }

    // MARK: - Pace Unit Conversion
    // 後端配速一律以「秒/km」回傳；顯示時依使用者單位設定（公制 /km、英制 /mi）換算。

    /// 目前單位的配速後綴（"/km" 或 "/mi"）。
    private var paceSuffix: String { UnitManager.shared.currentUnitSystem.paceSuffix }

    /// 將「秒/km」換算為使用者單位的 "mm:ss" 配速字串（不含後綴）。
    private func convertedPaceString(secondsPerKm: Int) -> String {
        let converted = UnitManager.shared.currentUnitSystem == .imperial
            ? Double(secondsPerKm) * 1.60934
            : Double(secondsPerKm)
        return secondsToPaceString(Int(converted.rounded()))
    }

    /// 將後端 "mm:ss"（秒/km）配速換算為使用者單位（不含後綴）；無法解析時原樣回傳。
    private func displayPace(_ perKm: String?) -> String? {
        guard let perKm, let sec = paceStringToSeconds(perKm) else { return perKm }
        return convertedPaceString(secondsPerKm: sec)
    }

    /// 預估時間範圍：配速算出的時間為下限，×1.15(四捨五入取整)為上限。
    /// 回傳如 "62-71"（不含單位；上限與下限相同時只回單一值）。
    private func estimatedTimeRange(minutes: Int) -> String {
        let upper = Int((Double(minutes) * 1.15).rounded())
        return upper > minutes ? "\(minutes)-\(upper)" : "\(minutes)"
    }

    // MARK: - Hero Card

    private enum HeroVariant { case interval, segmented, simple }

    private var heroVariant: HeroVariant {
        guard let run = day.primaryRunActivity else { return .simple }
        if run.interval != nil { return .interval }
        if let segs = run.segments, segs.count > 1 { return .segmented }
        return .simple
    }

    private var heroCard: some View {
        let accentColor = typeAccentColor
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: PacerizRadius.card)
                .fill(LinearGradient(
                    colors: [accentColor, accentColor.opacity(0.87)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: accentColor.opacity(0.4), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 0) {
                Text(typeChipLabel).font(AppFont.micro()).tracking(0.06).foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 3).background(Color.white.opacity(0.22)).clipShape(Capsule())
                Text(workoutTypeName).font(AppFont.numberLarge()).tracking(-0.02).foregroundColor(.white).padding(.top, 10)

                Group {
                    if isNonRunSession {
                        nonRunHeroMetrics
                    } else {
                        switch heroVariant {
                        case .interval: intervalHeroMetrics
                        case .segmented: segmentedHeroMetrics
                        case .simple: simpleHeroMetrics
                        }
                    }
                }
                .padding(.top, 14)
            }
            .padding(18)
        }
    }

    private var simpleHeroMetrics: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if let run = day.primaryRunActivity {
                heroMetricColumn(title: NSLocalizedString("training.detail.metric_distance", comment: ""), value: distanceString(run), unit: distanceUnit(run))
                heroDivider
                if isEasyOrLSD {
                    // Easy/long-easy runs are HR-driven → show 距離 + 心率 (pace lives in target zones as a range).
                    let hr = heroHRValue(run)
                    heroMetricColumn(title: NSLocalizedString("training.zone.target_hr", comment: ""), value: hr.value, unit: hr.unit)
                } else {
                    heroMetricColumn(title: NSLocalizedString("training.detail.metric_estimated_time", comment: ""), value: durationString(run), unit: nil)
                    heroDivider
                    heroMetricColumn(title: NSLocalizedString("common.pace", comment: ""), value: displayPace(run.effectivePace) ?? "-", unit: paceSuffix)
                }
            }
        }
    }

    /// 非跑步主項的 hero 指標：力量→動作數＋時長；交叉→時長＋距離。
    @ViewBuilder
    private var nonRunHeroMetrics: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if let session = day.session {
                switch session.primary {
                case .strength(let s):
                    if !s.exercises.isEmpty {
                        heroMetricColumn(title: NSLocalizedString("training.exercises", comment: ""), value: "\(s.exercises.count)", unit: NSLocalizedString("training.exercises_count_unit", comment: ""))
                    }
                    if let mins = s.durationMinutes {
                        if !s.exercises.isEmpty { heroDivider }
                        heroMetricColumn(title: NSLocalizedString("training.detail.metric_estimated_time", comment: ""), value: "\(mins)", unit: NSLocalizedString("training.minute_abbr", comment: ""))
                    }
                case .cross(let c):
                    heroMetricColumn(title: NSLocalizedString("training.detail.metric_estimated_time", comment: ""), value: "\(c.durationMinutes)", unit: NSLocalizedString("training.minute_abbr", comment: ""))
                    if c.distanceDisplay != nil || c.distanceKm != nil {
                        let rawDist = c.distanceDisplay ?? c.distanceKm ?? 0
                        let distVal = c.distanceUnit != nil ? rawDist : UnitManager.shared.convertedDistance(rawDist)
                        let distUnit = c.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                        heroDivider
                        heroMetricColumn(title: NSLocalizedString("training.detail.metric_distance", comment: ""), value: String(format: "%.1f", distVal), unit: distUnit)
                    }
                case .run:
                    EmptyView()
                }
            }
        }
    }

    /// Hero heart-rate value: explicit HR range (bpm) if present, else inferred zone string.
    private func heroHRValue(_ run: RunActivity) -> (value: String, unit: String) {
        if let hr = run.heartRateRange, hr.isValid, let text = hr.displayText {
            return (text, "bpm")
        }
        return (inferredHRZone(for: day.type), "")
    }

    private var segmentedHeroMetrics: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if let run = day.primaryRunActivity {
                heroMetricColumn(title: NSLocalizedString("training.detail.metric_total_distance", comment: ""), value: distanceString(run), unit: distanceUnit(run))
                heroDivider
                heroMetricColumn(title: NSLocalizedString("training.detail.metric_estimated_time", comment: ""), value: durationString(run), unit: nil)
                heroDivider
                heroMetricColumn(title: NSLocalizedString("training.detail.metric_pace_variation", comment: ""), value: String(format: NSLocalizedString("training.detail.segment_count", comment: ""), run.segments?.count ?? 1), unit: nil)
            }
        }
        .overlay(alignment: .bottom) {
            if let label = segmentStructureLabel {
                VStack {
                    Spacer()
                    HStack {
                        Text(label)
                            .font(AppFont.micro())
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(.top, 10)
                    .overlay(alignment: .top) {
                        Divider().background(Color.white.opacity(0.18))
                    }
                }
            }
        }
    }

    private var intervalHeroMetrics: some View {
        Group {
            if let run = day.primaryRunActivity, let interval = run.interval {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text("\(interval.repeats) × \(workDistanceLabel(interval))")
                        .font(AppFont.numberLarge().monospacedDigit()).tracking(-0.03).foregroundColor(.white)
                    Text(NSLocalizedString("training.segment.sprint", comment: "")).font(AppFont.micro()).foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    @ViewBuilder
    private func heroMetricColumn(title: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Unit lives next to the title (consistent across all cards), not the value.
            HStack(spacing: 3) {
                Text(title).font(AppFont.micro()).foregroundColor(.white.opacity(0.85))
                if let unit, !unit.isEmpty {
                    Text(unit).font(AppFont.micro()).foregroundColor(.white.opacity(0.6))
                }
            }
            Text(value).font(AppFont.numberLarge().monospacedDigit()).tracking(-0.03).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroDivider: some View {
        Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1).padding(.horizontal, 8)
    }

    // MARK: - Coach Intent Card

    private var coachIntentCard: some View {
        let accentColor = typeAccentColor
        // Priority: day.reason (coach annotation) → day.dayTarget → activity description
        let reasonText = day.reason.isEmpty ? nil : day.reason
        let goalText: String
        if let reason = reasonText {
            goalText = reason
        } else if !day.dayTarget.isEmpty {
            goalText = day.dayTarget
        } else {
            goalText = day.session.map { session -> String in
                switch session.primary {
                case .run(let r): return r.description ?? ""
                case .strength(let s): return s.description ?? ""
                case .cross(let c): return c.description ?? ""
                }
            } ?? ""
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(AppFont.captionRegular()).foregroundColor(accentColor)
                Text(NSLocalizedString("training.detail.section_goal", comment: "")).font(AppFont.chip()).tracking(0.04).foregroundColor(accentColor)
            }
            Text(goalText).font(AppFont.micro()).foregroundColor(.primary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(PacerizRadius.card)
    }

    // MARK: - Training Structure Section

    @ViewBuilder
    private var structureSectionIfNeeded: some View {
        // Easy / long-easy runs are a single relaxed segment — no structure section needed.
        let segments = buildDetailSegmentsForDetailPage()
        if !isEasyOrLSD, !segments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: NSLocalizedString("training.detail.section_structure", comment: ""), subtitle: String(format: NSLocalizedString("training.detail.structure_subtitle", comment: ""), segments.count, totalMinutes))
                VStack(spacing: 8) {
                    ForEach(segments.indices, id: \.self) { idx in
                        DetailSegmentRow(segment: segments[idx], accentColor: typeAccentColor)
                    }
                }
            }
        }
    }

    // MARK: - Target Zones Section

    @ViewBuilder
    private var targetZonesSection: some View {
        // 非跑步主項沒有配速/區間 pill → 不顯示空的「目標區間」格子。
        let pills = buildTargetZonePills()
        if !pills.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: NSLocalizedString("training.detail.section_target_zone", comment: ""), subtitle: nil)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(pills.indices, id: \.self) { idx in
                        let pill = pills[idx]
                        TargetZonePill(label: pill.label, value: pill.value, unit: pill.unit, isDanger: pill.isDanger, accentColor: typeAccentColor)
                    }
                }
            }
        }
    }

    // MARK: - Supplementary Section

    @ViewBuilder
    private var supplementarySection: some View {
        if let supplementary = day.session?.supplementary, !supplementary.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: NSLocalizedString("training.detail.section_supplementary", comment: ""), subtitle: NSLocalizedString("training.detail.supplementary_subtitle", comment: ""))
                SupplementaryTrainingView(activities: supplementary)
            }
        }
    }

    // MARK: - Non-Run Content Section

    /// 非跑步主項的內容：力量訓練顯示動作清單（鏡射 day card 展開）；交叉訓練的時長/距離已在 hero。
    @ViewBuilder
    private var nonRunContentSection: some View {
        if let session = day.session {
            switch session.primary {
            case .strength(let strength):
                if !strength.exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(title: NSLocalizedString("training.exercises", comment: ""), subtitle: nil)
                        ExercisesListView(exercises: strength.exercises)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .cross, .run:
                EmptyView()
            }
        }
    }

    // MARK: - Climate Section

    @ViewBuilder
    private var climateSection: some View {
        if climateAdjustmentEnabled, let climateMeta = day.effectiveClimateMeta {
            ClimateTipCard(
                meta: climateMeta,
                // 危險級後端不給 climate_adjusted_pace，用原本 pace 當基準算「若仍戶外」放慢配速。
                basePace: day.primaryRunActivity?.basePace ?? day.primaryRunActivity?.pace,
                adjustedPace: day.primaryRunActivity?.climateAdjustedPace
            )
        }
    }

    // MARK: - Tip Row (per variant)

    // Tip data per run type, derived from design spec (workout-detail.jsx).
    private struct WorkoutTip {
        let icon: String
        let text: String
    }

    private var workoutTip: WorkoutTip? {
        // Priority: DayDetail.tips from API → hardcode fallback by runType
        if let apiTip = day.tips, !apiTip.isEmpty {
            return WorkoutTip(icon: "💡", text: apiTip)
        }

        // Hardcode fallback
        let runType = day.session.flatMap { session -> String? in
            if case .run(let r) = session.primary { return r.runType }
            return nil
        } ?? day.type.rawValue

        switch runType {
        case "lsd", "long_slow_distance", "longRun", "long_run":
            return WorkoutTip(icon: "💧", text: NSLocalizedString("tip.lsd", value: "預計超過 60 分鐘，建議攜帶水分與能量補給", comment: "LSD tip"))
        case "easy", "easyRun", "easy_run":
            return nil  // easy runs typically no extra tip (climate section handles heat)
        case "interval", "shortInterval", "longInterval", "norwegian4x4", "yasso800", "strides", "hillRepeats":
            return WorkoutTip(icon: "⚠️", text: NSLocalizedString("tip.interval", value: "高強度日後請安排足夠睡眠與蛋白質補充", comment: "Interval tip"))
        case "progression":
            return WorkoutTip(icon: "🌫️", text: NSLocalizedString("tip.progression", value: "前三分之一不要起太快，預留體力給最後一段", comment: "Progression tip"))
        case "fastFinish":
            return WorkoutTip(icon: "🔋", text: NSLocalizedString("tip.fastFinish", value: "末段交接前補水補給 · 加速時保持上半身放鬆", comment: "Fast finish tip"))
        default:
            // Fallback by DayType
            switch day.type {
            case .lsd, .longRun:
                return WorkoutTip(icon: "💧", text: NSLocalizedString("tip.lsd", value: "預計超過 60 分鐘，建議攜帶水分與能量補給", comment: "LSD tip"))
            case .interval, .shortInterval, .longInterval, .norwegian4x4, .yasso800, .strides, .hillRepeats:
                return WorkoutTip(icon: "⚠️", text: NSLocalizedString("tip.interval", value: "高強度日後請安排足夠睡眠與蛋白質補充", comment: "Interval tip"))
            case .progression:
                return WorkoutTip(icon: "🌫️", text: NSLocalizedString("tip.progression", value: "前三分之一不要起太快，預留體力給最後一段", comment: "Progression tip"))
            case .fastFinish:
                return WorkoutTip(icon: "🔋", text: NSLocalizedString("tip.fastFinish", value: "末段交接前補水補給 · 加速時保持上半身放鬆", comment: "Fast finish tip"))
            default:
                return nil
            }
        }
    }

    @ViewBuilder
    private var tipSection: some View {
        if let tip = workoutTip {
            WorkoutTipBox(icon: tip.icon, text: tip.text, accentColor: typeAccentColor)
        }
    }

    // MARK: - Secondary Buttons

    private var secondaryButtons: some View {
        // 「調整這一天」目前無功能，先移除避免誤導；保留「這是什麼訓練」資訊入口。
        SecondaryActionButton(icon: "info.circle", label: String(format: NSLocalizedString("training.detail.what_is_type", comment: ""), workoutTypeName), action: { showTrainingTypeInfo = true })
    }

    // MARK: - Section Header Helper

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AppFont.chip()).foregroundColor(.primary)
            if let subtitle { Text(subtitle).font(AppFont.micro()).foregroundColor(.secondary) }
            Spacer()
        }
    }

    // MARK: - Segment Helpers

    private var segmentStructureLabel: String? {
        switch day.type {
        case .progression:
            guard let segs = day.primaryRunActivity?.segments, segs.count == 3 else { return nil }
            return NSLocalizedString("training.segment.progression_label", comment: "")
        case .fastFinish:
            return NSLocalizedString("training.segment.fast_finish_label", comment: "")
        default:
            return nil
        }
    }

    private var totalMinutes: Int { day.primaryRunActivity?.durationMinutes ?? 0 }

    // MARK: - Detail Segment Building

    struct DetailSegmentData {
        let index: Int
        let label: String
        let distance: String?
        let pace: String?
        let hr: String?
        let reps: Int?
        let rest: String?
        let isMain: Bool
    }

    // Detail-page variant: always shows segments (Fix 4). Single-segment runs show 1 row.
    // DayCard (WeekTimelineViewV2) still uses buildDetailSegments() with the single-segment guard.
    private func buildDetailSegmentsForDetailPage() -> [DetailSegmentData] {
        guard let session = day.session,
              case .run(let run) = session.primary else { return [] }

        // Multi-segment / interval: delegate to existing builder (removes the single-seg guard path)
        if run.interval != nil || (run.segments?.count ?? 0) > 1 {
            return buildDetailSegments() ?? []
        }

        // Single-segment (or no segments array): synthesize a single row from the run itself
        let segLabel: String
        switch day.type {
        case .lsd, .longRun:
            segLabel = NSLocalizedString("training.segment.lsd_single", comment: "")
        case .easy, .easyRun:
            segLabel = NSLocalizedString("training.segment.easy_single", comment: "")
        case .recovery_run:
            segLabel = NSLocalizedString("training.segment.recovery_single", comment: "")
        case .tempo:
            segLabel = NSLocalizedString("training.segment.tempo_single", comment: "")
        case .threshold:
            segLabel = NSLocalizedString("training.segment.threshold_single", comment: "")
        default:
            segLabel = workoutTypeName
        }
        let hrText: String? = run.heartRateRange?.displayText
        return [DetailSegmentData(
            index: 1,
            label: segLabel,
            distance: distanceString(run) + " " + distanceUnit(run),
            pace: displayPace(run.effectivePace),
            hr: hrText,
            reps: nil,
            rest: nil,
            isMain: true
        )]
    }

    private func buildDetailSegments() -> [DetailSegmentData]? {
        guard let session = day.session,
              case .run(let run) = session.primary else { return nil }

        if run.interval == nil && (run.segments == nil || run.segments?.count ?? 0 <= 1) { return nil }

        var result: [DetailSegmentData] = []
        var idx = 1

        if let warmup = session.warmup {
            result.append(bookendSegment(index: idx, label: NSLocalizedString("training.segment.warmup", comment: ""), seg: warmup)); idx += 1
        }

        if let interval = run.interval {
            let restStr: String? = {
                if let sec = interval.recoveryDurationSeconds { return String(format: NSLocalizedString("training.detail.rest_seconds_jog", comment: ""), sec) }
                if let min = interval.recoveryDurationMinutes { return String(format: NSLocalizedString("training.detail.rest_minutes_jog", comment: ""), min) }
                return interval.recoveryDescription
            }()
            // Prefer real HR range from RunActivity; fall back to inferred zone label
            let intervalHR = run.heartRateRange?.displayText.map { "\($0) bpm" } ?? "Z4"
            result.append(DetailSegmentData(index: idx, label: NSLocalizedString("training.segment.sprint", comment: ""), distance: workDistanceLabel(interval),
                pace: displayPace(interval.workPace), hr: intervalHR, reps: interval.repeats, rest: restStr, isMain: true))
            idx += 1
        } else if let segs = run.segments, segs.count > 1 {
            for (segIdx, seg) in segs.enumerated() {
                // Use real HR range from segment if available
                let segHR = seg.heartRateRange?.displayText.map { "\($0) bpm" }
                result.append(DetailSegmentData(index: idx, label: segmentLabel(index: segIdx, total: segs.count),
                    distance: segmentDistanceString(seg), pace: displayPace(seg.effectivePace),
                    hr: segHR, reps: nil, rest: nil, isMain: segIdx == segs.count - 1))
                idx += 1
            }
        }

        if let cooldown = session.cooldown {
            result.append(bookendSegment(index: idx, label: NSLocalizedString("training.segment.cooldown", comment: ""), seg: cooldown))
        }

        return result.isEmpty ? nil : result
    }

    private func bookendSegment(index: Int, label: String, seg: RunSegment) -> DetailSegmentData {
        // Use real HR range from segment if available; otherwise no HR label
        let hr = seg.heartRateRange?.displayText.map { "\($0) bpm" }
        return DetailSegmentData(index: index, label: label,
            distance: segmentDistanceString(seg), pace: displayPace(seg.effectivePace),
            hr: hr,
            reps: nil, rest: nil, isMain: false)
    }

    private func segmentLabel(index: Int, total: Int) -> String {
        switch (total, index) {
        case (3, 0): return NSLocalizedString("training.segment.easy_pace", comment: "")
        case (3, 1): return NSLocalizedString("training.segment.tempo_pace", comment: "")
        case (3, 2): return NSLocalizedString("training.segment.accelerate", comment: "")
        case (2, 0): return NSLocalizedString("training.type.easy", comment: "")
        case (2, 1): return NSLocalizedString("training.segment.tempo_finish", comment: "")
        default: return String(format: NSLocalizedString("training.segment_n", comment: ""), index + 1)
        }
    }

    // MARK: - Target Zone Pills

    struct TargetZonePillData {
        let label: String
        let value: String
        let unit: String
        let isDanger: Bool
    }

    // Infer heart-rate zone string from run type (used when no explicit HR data is present).
    private func inferredHRZone(for type: DayType) -> String {
        switch type {
        case .easy, .easyRun, .recovery_run:
            return "Z2"
        case .lsd, .longRun:
            return "Z2-Z3"
        case .tempo, .cruiseIntervals, .fastFinish:
            return "Z3-Z4"
        case .threshold, .progression:
            return "Z4"
        case .interval, .shortInterval, .longInterval, .norwegian4x4, .yasso800, .strides, .hillRepeats:
            return "Z4-Z5"
        case .race, .racePace:
            return "Z5"
        default:
            return "Z2-Z3"
        }
    }

    // Infer RPE (1-10) from run type (used when targetIntensity is nil).
    private func inferredRPE(for type: DayType) -> String {
        switch type {
        case .easy, .easyRun, .recovery_run:
            return "3"
        case .lsd, .longRun:
            return "4-5"
        case .fastFinish:
            return "4-7"
        case .tempo, .cruiseIntervals:
            return "6"
        case .threshold, .progression:
            return "7"
        case .interval, .shortInterval, .longInterval, .norwegian4x4, .yasso800, .strides, .hillRepeats:
            return "8"
        case .race, .racePace:
            return "9"
        default:
            return "5"
        }
    }

    private func buildTargetZonePills() -> [TargetZonePillData] {
        guard let run = day.primaryRunActivity else { return [] }
        var pills: [TargetZonePillData] = []

        // Pill 1: pace (label varies by type) — 配速依使用者單位換算。
        if let interval = run.interval {
            if let pace = interval.workPace {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.sprint_pace", comment: ""), value: displayPace(pace) ?? pace, unit: paceSuffix, isDanger: false))
            }
            if let recPace = interval.recoveryPace {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.recovery_pace", comment: ""), value: displayPace(recPace) ?? recPace, unit: paceSuffix, isDanger: false))
            }
        } else if let pace = run.effectivePace {
            let paceLabel: String
            switch day.type {
            case .progression: paceLabel = NSLocalizedString("training.zone.start_pace", comment: "")
            case .fastFinish: paceLabel = NSLocalizedString("training.segment.easy_pace", comment: "")
            default: paceLabel = NSLocalizedString("training.zone.target_pace", comment: "")
            }
            // Easy/LSD: show original pace widened by ±20s instead of the climate-adjusted single value.
            let paceValue = isEasyOrLSD ? (easyPaceRange(run) ?? (displayPace(pace) ?? pace)) : (displayPace(pace) ?? pace)
            pills.append(TargetZonePillData(label: paceLabel, value: paceValue, unit: paceSuffix, isDanger: false))
        }

        // Pill 2: heart-rate zone — prefer explicit HR range, fall back to inferred zone string
        if let hr = run.heartRateRange, hr.isValid, let hrText = hr.displayText {
            pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.target_hr", comment: ""), value: hrText, unit: "bpm", isDanger: true))
        } else {
            let zone = inferredHRZone(for: day.type)
            pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.target_hr", comment: ""), value: zone, unit: "", isDanger: false))
        }

        // Pill 3: RPE — prefer explicit targetIntensity, fall back to inferred.
        // 體感值與 /10 合併顯示為「3/10」（值內含分母，讀起來更直覺，不讓 /10 浮在標籤旁）。
        let rpeValue = run.targetIntensity ?? inferredRPE(for: day.type)
        pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.rpe", comment: ""), value: "\(rpeValue)/10", unit: "", isDanger: false))

        // Pill 4: varies by type
        // Interval → 訓練負荷 (TSS estimated); Progression/FastFinish add end-pace pill (already added above as separate pace); others → 預估時間
        switch day.type {
        case .interval, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
            // Pill 4: rest — prefer recoveryDurationSeconds/Minutes/Description; fall back to total sets
            if let interval = run.interval {
                if let sec = interval.recoveryDurationSeconds {
                    pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.rest_between", comment: ""), value: "\(sec)", unit: NSLocalizedString("training.seconds_unit", comment: ""), isDanger: false))
                } else if let min = interval.recoveryDurationMinutes {
                    pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.rest_between", comment: ""), value: "\(min)", unit: NSLocalizedString("training.minute_abbr", comment: ""), isDanger: false))
                } else if let desc = interval.recoveryDescription {
                    pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.rest_between", comment: ""), value: desc, unit: "", isDanger: false))
                } else {
                    pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.total_sets", comment: ""), value: "\(interval.repeats)", unit: NSLocalizedString("training.sets_unit", comment: ""), isDanger: false))
                }
            }
        case .progression:
            // Add end-pace pill from last segment
            if let segs = run.segments, segs.count > 1, let lastPace = segs.last?.effectivePace {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.end_pace", comment: ""), value: displayPace(lastPace) ?? lastPace, unit: paceSuffix, isDanger: false))
            } else if let mins = run.durationMinutes {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.estimated_time", comment: ""), value: estimatedTimeRange(minutes: mins), unit: NSLocalizedString("training.minute_abbr", comment: ""), isDanger: false))
            }
        case .fastFinish:
            // Add tempo/fast pace from last segment
            if let segs = run.segments, segs.count > 1, let lastPace = segs.last?.effectivePace {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.segment.tempo_pace", comment: ""), value: displayPace(lastPace) ?? lastPace, unit: paceSuffix, isDanger: false))
            } else if let mins = run.durationMinutes {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.estimated_time", comment: ""), value: estimatedTimeRange(minutes: mins), unit: NSLocalizedString("training.minute_abbr", comment: ""), isDanger: false))
            }
        default:
            if let mins = run.durationMinutes {
                pills.append(TargetZonePillData(label: NSLocalizedString("training.zone.estimated_time", comment: ""), value: estimatedTimeRange(minutes: mins), unit: NSLocalizedString("training.minute_abbr", comment: ""), isDanger: false))
            }
        }

        return pills
    }

    // MARK: - Format Helpers

    private func distanceString(_ run: RunActivity) -> String {
        let km = run.distanceDisplay ?? run.distanceKm
        return km.map { String(format: "%.1f", UnitManager.shared.convertedDistance($0)) } ?? "-"
    }

    private func distanceUnit(_ run: RunActivity) -> String {
        run.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
    }

    private func durationString(_ run: RunActivity) -> String {
        guard let mins = run.durationMinutes else { return "-" }
        let (h, m) = (mins / 60, mins % 60)
        return h > 0 ? String(format: "%d:%02d:00", h, m) : String(format: "%d:00", m)
    }

    // Returns distance string for a segment; prefers distanceDisplay if available.
    private func segmentDistanceString(_ seg: RunSegment) -> String? {
        let um = UnitManager.shared
        if let disp = seg.distanceDisplay {
            let unit = seg.distanceUnit ?? um.currentUnitSystem.distanceSuffix
            let val = seg.distanceUnit != nil ? disp : um.convertedDistance(disp)
            return String(format: "%.1f \(unit)", val)
        }
        if let km = seg.distanceKm { return String(format: "%.1f \(um.currentUnitSystem.distanceSuffix)", um.convertedDistance(km)) }
        if let m = seg.distanceM { return "\(m)m" }
        return nil
    }

    private func workDistanceLabel(_ interval: IntervalBlock) -> String {
        if let m = interval.workDistanceM { return "\(m)m" }
        if let km = interval.workDistanceKm { return String(format: "%.1fkm", km) }
        if let mins = interval.workDurationMinutes { return "\(mins)\(NSLocalizedString("training.minute_abbr", comment: ""))" }
        return ""
    }

    private func weekdayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private func shortDateString(_ date: Date) -> String {
        DateFormatterHelper.formatShortDate(date)
    }
}

// MARK: - SecondaryActionButton

private struct SecondaryActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(AppFont.captionRegular())
                Text(label).font(AppFont.micro())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .foregroundColor(.primary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - DetailSegmentRow

private struct DetailSegmentRow: View {
    let segment: PlannedSessionDetailView.DetailSegmentData
    let accentColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(segment.isMain ? accentColor : Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: segment.isMain ? accentColor.opacity(0.55) : .clear, radius: 3, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(segment.isMain ? Color.clear : accentColor.opacity(0.55), lineWidth: 1.5)
                    )
                Text("\(segment.index)")
                    .font(AppFont.chip())
                    .foregroundColor(segment.isMain ? .white : accentColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(segment.label).font(AppFont.chip()).foregroundColor(.primary)
                HStack(spacing: 4) {
                    if let dist = segment.distance {
                        Text(dist).font(AppFont.micro().monospacedDigit()).foregroundColor(.secondary)
                    }
                    if let pace = segment.pace {
                        Text("·").font(AppFont.micro()).foregroundColor(.secondary.opacity(0.4))
                        Text(pace).font(AppFont.micro().monospacedDigit()).foregroundColor(.secondary)
                    }
                    if let hr = segment.hr {
                        Text("·").font(AppFont.micro()).foregroundColor(.secondary.opacity(0.4))
                        Text(hr).font(AppFont.micro().monospacedDigit()).foregroundColor(.secondary)
                    }
                }
                if let rest = segment.rest {
                    Text(String(format: NSLocalizedString("training.detail.rest_with_desc", comment: ""), rest)).font(AppFont.micro()).foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()

            if let reps = segment.reps {
                Text("× \(reps)").font(AppFont.chip().monospacedDigit()).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(accentColor).clipShape(Capsule())
                    .shadow(color: accentColor.opacity(0.55), radius: 3, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(segment.isMain ? accentColor.opacity(0.065) : Color(UIColor.secondarySystemGroupedBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(segment.isMain ? accentColor.opacity(0.2) : Color.clear, lineWidth: 1))
        )
    }
}

// MARK: - TargetZonePill

private struct TargetZonePill: View {
    let label: String
    let value: String
    let unit: String
    let isDanger: Bool
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Unit next to the label (consistent across all cards), not the value.
            HStack(spacing: 3) {
                Text(label).font(AppFont.micro()).tracking(0.04).foregroundColor(.secondary)
                if !unit.isEmpty {
                    Text(unit).font(AppFont.micro()).foregroundColor(Color(.tertiaryLabel))
                }
            }
            Text(value).font(AppFont.numberMedium().monospacedDigit()).tracking(-0.02)
                .foregroundColor(isDanger ? PacerizColor.orange : accentColor)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - ClimateTipCard

private struct ClimateTipCard: View {
    let meta: ClimateMeta
    var basePace: String? = nil
    var adjustedPace: String? = nil

    // Climate tip uses its OWN heat-alert level colour (mild/moderate/high/danger),
    // not the workout type colour — the warning severity should drive the colour.
    private var climateColor: Color { meta.badgeForegroundColor }

    private var headerChip: String {
        // 溫度需明確標示為「體感」，避免被誤會成實際氣溫。
        if let t = meta.feelsLikeTempText {
            return "\(meta.shortLevelDisplayText) · \(meta.temperatureTitle) \(t)"
        }
        return meta.shortLevelDisplayText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header：熱適應 + 等級・體感溫度
            HStack(spacing: 8) {
                Image(systemName: "thermometer.sun.fill")
                    .font(AppFont.bodyRegular())
                    .foregroundColor(climateColor)
                Text(meta.sectionTitle)
                    .font(AppFont.bodyStrong())
                    .foregroundColor(.primary)
                Spacer()
                Text(headerChip)
                    .font(AppFont.micro())
                    .fontWeight(.semibold)
                    .foregroundColor(climateColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(climateColor.opacity(0.14))
                    .clipShape(Capsule())
            }

            // 為什麼調整（說明）
            Text(meta.heatAdaptationExplanation)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 配速建議：非危險顯示「原 → 今日（調整後）」；危險即使後端不給百分比，
            // 也算出「若仍戶外」至少放慢的具體配速（依知識庫：放慢 ≥ 一個配速等級）。
            paceGuidanceRow

            // 建議時段／室內
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sun.haze.fill")
                    .font(AppFont.caption())
                    .foregroundColor(climateColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.recommendationTitle)
                        .font(AppFont.micro())
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(meta.trainingTimeRecommendation)
                        .font(AppFont.micro())
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(climateColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(PacerizRadius.card)
    }

    @ViewBuilder
    private var paceGuidanceRow: some View {
        if meta.normalizedHeatPressureLevel == "danger",
           let b = basePace, let bs = paceStringToSeconds(b) {
            // 危險：原配速 → 至少放慢一個配速等級（約 base + 60 秒/km）。
            let floorPace = secondsToPaceString(bs + meta.dangerOutdoorMinSlowdownSeconds)
            HStack(spacing: 10) {
                paceChip(meta.originalPaceTitle, b, .secondary)
                Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                paceChip(meta.dangerOutdoorPaceTitle, "\(floorPace)+", climateColor)
                Spacer()
            }
        } else if let b = basePace, let a = adjustedPace, b != a {
            HStack(spacing: 10) {
                paceChip(meta.originalPaceTitle, b, .secondary)
                Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                paceChip(meta.adjustedPaceTitle, a, climateColor)
                Spacer()
            }
        }
    }

    private func paceChip(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(AppFont.micro())
                .foregroundColor(.secondary)
            Text(value)
                .font(AppFont.caption().monospacedDigit())
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - WorkoutTipBox

private struct WorkoutTipBox: View {
    let icon: String
    let text: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Text(icon).font(AppFont.bodyRegular())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("training.detail.reminder", comment: "")).font(AppFont.chip()).foregroundColor(.primary)
                Text(text)
                    .font(AppFont.micro())
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(PacerizRadius.card)
    }
}

// MARK: - Preview

#Preview {
    // NavigationStack is required because PlannedSessionDetailView uses .toolbar and
    // .navigationBarTitleDisplayMode which rely on the parent NavigationStack environment.
    NavigationStack {
        PlannedSessionDetailView(
            day: DayDetail(
                dayIndex: 3,
                dayTarget: "建立有氧基礎，幫助身體恢復並適應週初強度。",
                reason: "easy day",
                tips: nil,
                category: .run,
                climateMeta: nil,
                session: TrainingSession(
                    warmup: nil,
                    primary: .run(RunActivity(
                        runType: "easy",
                        distanceKm: 6.0,
                        distanceDisplay: nil,
                        distanceUnit: nil,
                        paceUnit: nil,
                        durationMinutes: 36,
                        durationSeconds: nil,
                        pace: "6:00",
                        basePace: nil,
                        climateAdjustedPace: nil,
                        heartRateRange: HeartRateRangeV2(min: 138, max: 148),
                        interval: nil,
                        segments: nil,
                        description: nil,
                        targetIntensity: "3",
                        climateMeta: nil
                    )),
                    cooldown: nil,
                    supplementary: nil
                )
            ),
            date: Date()
        )
    }
}
