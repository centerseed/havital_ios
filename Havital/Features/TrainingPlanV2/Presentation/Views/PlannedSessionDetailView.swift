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
    @Environment(\.dismiss) private var dismiss
    @State private var showTrainingTypeInfo = false
    @AppStorage("climateAdjustmentEnabled") private var climateAdjustmentEnabled = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroCard.padding(.horizontal, 16).padding(.top, 12)
                    coachIntentCard.padding(.horizontal, 16).padding(.top, 12)
                    structureSectionIfNeeded.padding(.horizontal, 16).padding(.top, 12)
                    targetZonesSection.padding(.horizontal, 16).padding(.top, 12)
                    supplementarySection.padding(.horizontal, 16).padding(.top, 12)
                    climateSection.padding(.horizontal, 16).padding(.top, 12)
                    secondaryButtons.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

                    Color.clear.frame(height: 80)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        if let date {
                            Text("\(weekdayString(date)) · \(shortDateString(date))")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                        }
                        Text("訓練詳情").font(.system(size: 15, weight: .heavy)).kerning(-0.01)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.primary) }
                }
            }
            .overlay(alignment: .bottom) {
                startTodayButton
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
            case .easyRun, .easy, .recovery_run, .lsd:
                return PacerizColor.green
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

        // chip label + display name keyed by DayType rawValue
        private static let labels: [String: (chip: String, name: String)] = [
            "easy":           ("EASY · Z2",            "輕鬆跑"),
            "easyRun":        ("EASY · Z2",            "輕鬆跑"),
            "recovery_run":   ("EASY · Z2",            "恢復跑"),
            "lsd":            ("LONG · Z2-Z3",         "長距離 LSD"),
            "interval":       ("INTERVAL · Z4",        "間歇訓練"),
            "tempo":          ("TEMPO · Z3-Z4",        "節奏跑"),
            "threshold":      ("THRESHOLD · Z4",       "閾值跑"),
            "progression":    ("PROGRESSION · Z2 → Z4","漸速跑"),
            "fastFinish":     ("FAST FINISH · Z2 + Z3","快速完成跑"),
            "longRun":        ("LONG · Z2-Z3",         "長距離跑"),
            "race":           ("RACE · Z5",            "比賽"),
            "racePace":       ("RACE PACE · Z4-Z5",    "比賽配速跑"),
            "combination":    ("COMBINATION",          "組合訓練"),
            "strides":        ("STRIDES · Z4-Z5",      "衝刺跑"),
            "hillRepeats":    ("HILL REPEATS · Z4",    "坡度訓練"),
            "cruiseIntervals":("CRUISE · Z3-Z4",       "節奏間歇"),
            "shortInterval":  ("SHORT · Z5",           "短間歇"),
            "longInterval":   ("LONG · Z4-Z5",         "長間歇"),
            "norwegian4x4":   ("NOR 4×4 · Z4-Z5",     "挪威4×4"),
            "yasso800":       ("YASSO 800 · Z4-Z5",    "800m間歇"),
            "fartlek":        ("FARTLEK · Z2-Z4",      "法特雷克"),
            "strength":       ("STRENGTH",             "力量訓練"),
            "crossTraining":  ("CROSS TRAINING",       "交叉訓練"),
            "yoga":           ("CROSS TRAINING",       "瑜伽"),
            "hiking":         ("CROSS TRAINING",       "健行"),
            "cycling":        ("CROSS TRAINING",       "騎車"),
            "swimming":       ("CROSS TRAINING",       "游泳"),
            "elliptical":     ("CROSS TRAINING",       "橢圓機"),
            "rowing":         ("CROSS TRAINING",       "划船"),
            "rest":           ("REST",                 "休息"),
        ]

        static func chipLabel(for type: DayType) -> String {
            labels[type.rawValue]?.chip ?? type.rawValue.uppercased()
        }

        static func typeName(for type: DayType) -> String {
            labels[type.rawValue]?.name ?? type.rawValue
        }
    }

    private var typeAccentColor: Color { WorkoutMeta.accentColor(for: day.type) }
    private var typeChipLabel: String { WorkoutMeta.chipLabel(for: day.type) }
    private var workoutTypeName: String { WorkoutMeta.typeName(for: day.type) }

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
                Text(typeChipLabel).font(.system(size: 10.5, weight: .heavy)).tracking(0.06).foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 3).background(Color.white.opacity(0.22)).clipShape(Capsule())
                Text(workoutTypeName).font(.system(size: 28, weight: .heavy)).tracking(-0.02).foregroundColor(.white).padding(.top, 10)

                Group {
                    switch heroVariant {
                    case .interval: intervalHeroMetrics
                    case .segmented: segmentedHeroMetrics
                    case .simple: simpleHeroMetrics
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
                heroMetricColumn(title: "距離", value: distanceString(run), unit: distanceUnit(run))
                heroDivider
                heroMetricColumn(title: "預計時間", value: durationString(run), unit: nil)
                heroDivider
                heroMetricColumn(title: "配速", value: run.effectivePace ?? "-", unit: nil)
            }
        }
    }

    private var segmentedHeroMetrics: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if let run = day.primaryRunActivity {
                heroMetricColumn(title: "總距離", value: distanceString(run), unit: distanceUnit(run))
                heroDivider
                heroMetricColumn(title: "預計時間", value: durationString(run), unit: nil)
                heroDivider
                heroMetricColumn(title: "配速變化", value: "\(run.segments?.count ?? 1) 段", unit: nil)
            }
        }
        .overlay(alignment: .bottom) {
            if let label = segmentStructureLabel {
                VStack {
                    Spacer()
                    HStack {
                        Text(label)
                            .font(.system(size: 11, weight: .bold))
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("間歇架構").font(.system(size: 10, weight: .heavy)).tracking(0.06).foregroundColor(.white.opacity(0.85))
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(interval.repeats) × \(workDistanceLabel(interval))")
                            .font(.system(size: 32, weight: .heavy).monospacedDigit()).tracking(-0.03).foregroundColor(.white)
                        Text("衝刺").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.7))
                    }

                    if let pace = interval.workPace {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("配速").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.7))
                            Text(pace).font(.system(size: 20, weight: .heavy).monospacedDigit()).tracking(-0.03).foregroundColor(.white)
                            Text("/km").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Divider().background(Color.white.opacity(0.18)).padding(.top, 10)

                    HStack(spacing: 8) {
                        if let warmup = day.session?.warmup {
                            intervalBookendLabel(icon: "🔥", text: segmentDistanceString(warmup) ?? "")
                            dotSeparator
                        }
                        if let recoverPace = interval.recoveryPace {
                            intervalBookendLabel(icon: "🔄", text: recoverPace + "/km")
                            dotSeparator
                        } else if let recoverSec = interval.recoveryDurationSeconds {
                            intervalBookendLabel(icon: "🔄", text: "\(recoverSec)秒")
                            dotSeparator
                        }
                        if let cooldown = day.session?.cooldown {
                            intervalBookendLabel(icon: "🌀", text: segmentDistanceString(cooldown) ?? "")
                        }
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func intervalBookendLabel(icon: String, text: String) -> some View {
        Label {
            Text(text).font(.system(size: 10.5, weight: .bold).monospacedDigit())
        } icon: {
            Text(icon).font(.system(size: 10.5))
        }
    }

    private var dotSeparator: some View {
        Text("·").font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
    }

    @ViewBuilder
    private func heroMetricColumn(title: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.85))
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 26, weight: .heavy).monospacedDigit()).tracking(-0.03).foregroundColor(.white)
                if let unit { Text(unit).font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.85)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroDivider: some View {
        Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1).padding(.horizontal, 8)
    }

    // MARK: - Coach Intent Card

    private var coachIntentCard: some View {
        let accentColor = typeAccentColor
        let goalText = day.session.map { session -> String in
            switch session.primary {
            case .run(let r): return r.description ?? day.dayTarget
            case .strength(let s): return s.description ?? day.dayTarget
            case .cross(let c): return c.description ?? day.dayTarget
            }
        } ?? day.dayTarget

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 14)).foregroundColor(accentColor)
                Text("本次訓練目標").font(.system(size: 12, weight: .heavy)).tracking(0.04).foregroundColor(accentColor)
            }
            Text(goalText).font(.system(size: 13.5)).foregroundColor(.primary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(PacerizRadius.card)
    }

    // MARK: - Training Structure Section

    @ViewBuilder
    private var structureSectionIfNeeded: some View {
        if let segments = buildDetailSegments(), !segments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: "訓練結構", subtitle: "\(segments.count) 段 · \(totalMinutes) 分鐘")
                VStack(spacing: 8) {
                    ForEach(segments.indices, id: \.self) { idx in
                        DetailSegmentRow(segment: segments[idx], accentColor: typeAccentColor)
                    }
                }
            }
        }
    }

    // MARK: - Target Zones Section

    private var targetZonesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "目標區間", subtitle: nil)
            let pills = buildTargetZonePills()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(pills.indices, id: \.self) { idx in
                    let pill = pills[idx]
                    TargetZonePill(label: pill.label, value: pill.value, unit: pill.unit, isDanger: pill.isDanger, accentColor: typeAccentColor)
                }
            }
        }
    }

    // MARK: - Supplementary Section

    @ViewBuilder
    private var supplementarySection: some View {
        if let supplementary = day.session?.supplementary, !supplementary.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: "補充訓練", subtitle: "跑後進行")
                SupplementaryTrainingView(activities: supplementary)
            }
        }
    }

    // MARK: - Climate Section

    @ViewBuilder
    private var climateSection: some View {
        if climateAdjustmentEnabled, let climateMeta = day.effectiveClimateMeta {
            ClimateTipCard(meta: climateMeta, accentColor: typeAccentColor)
        }
    }

    // MARK: - Secondary Buttons

    private var secondaryButtons: some View {
        HStack(spacing: 8) {
            SecondaryActionButton(icon: "info.circle", label: "什麼是\(workoutTypeName)？", action: { showTrainingTypeInfo = true })
            SecondaryActionButton(icon: "arrow.triangle.2.circlepath", label: "調整這一天", action: { /* stub */ })
        }
    }

    // MARK: - Sticky CTA

    private var startTodayButton: some View {
        let ac = typeAccentColor
        return VStack(spacing: 0) {
            Button { /* stub */ } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 12))
                    Text(NSLocalizedString("training_plan.start_today_workout", comment: "開始今日訓練"))
                        .font(.system(size: 14, weight: .heavy)).tracking(-0.2)
                }
                .frame(maxWidth: .infinity).frame(height: 50).foregroundColor(.white)
                .background(LinearGradient(colors: [ac, ac.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(14).shadow(color: ac.opacity(0.33), radius: 8, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle()).padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Section Header Helper

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 14, weight: .heavy)).foregroundColor(.primary)
            if let subtitle { Text(subtitle).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary) }
            Spacer()
        }
    }

    // MARK: - Segment Helpers

    private var segmentStructureLabel: String? {
        switch day.type {
        case .progression:
            guard let segs = day.primaryRunActivity?.segments, segs.count == 3 else { return nil }
            return "三段進階：輕 → 節奏 → 快"
        case .fastFinish:
            return "二段式：輕鬆 → 節奏"
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

    private func buildDetailSegments() -> [DetailSegmentData]? {
        guard let session = day.session,
              case .run(let run) = session.primary else { return nil }

        if run.interval == nil && (run.segments == nil || run.segments?.count ?? 0 <= 1) { return nil }

        var result: [DetailSegmentData] = []
        var idx = 1

        if let warmup = session.warmup {
            result.append(bookendSegment(index: idx, label: "暖身", seg: warmup)); idx += 1
        }

        if let interval = run.interval {
            let restStr: String? = {
                if let sec = interval.recoveryDurationSeconds { return "\(sec)秒 慢跑" }
                if let min = interval.recoveryDurationMinutes { return "\(min)分 慢跑" }
                return interval.recoveryDescription
            }()
            result.append(DetailSegmentData(index: idx, label: "衝刺", distance: workDistanceLabel(interval),
                pace: interval.workPace, hr: "Z4", reps: interval.repeats, rest: restStr, isMain: true))
            idx += 1
        } else if let segs = run.segments, segs.count > 1 {
            for (segIdx, seg) in segs.enumerated() {
                result.append(DetailSegmentData(index: idx, label: segmentLabel(index: segIdx, total: segs.count),
                    distance: segmentDistanceString(seg), pace: seg.effectivePace,
                    hr: nil, reps: nil, rest: nil, isMain: segIdx == segs.count - 1))
                idx += 1
            }
        }

        if let cooldown = session.cooldown {
            result.append(bookendSegment(index: idx, label: "緩和", seg: cooldown))
        }

        return result.isEmpty ? nil : result
    }

    private func bookendSegment(index: Int, label: String, seg: RunSegment) -> DetailSegmentData {
        DetailSegmentData(index: index, label: label,
            distance: segmentDistanceString(seg), pace: seg.effectivePace,
            hr: seg.heartRateRange?.displayText != nil ? "Z2" : nil,
            reps: nil, rest: nil, isMain: false)
    }

    private func segmentLabel(index: Int, total: Int) -> String {
        switch (total, index) {
        case (3, 0): return "輕鬆配速"
        case (3, 1): return "節奏配速"
        case (3, 2): return "加速"
        case (2, 0): return "輕鬆跑"
        case (2, 1): return "節奏跑收尾"
        default: return "第\(index + 1)段"
        }
    }

    // MARK: - Target Zone Pills

    struct TargetZonePillData {
        let label: String
        let value: String
        let unit: String
        let isDanger: Bool
    }

    private func buildTargetZonePills() -> [TargetZonePillData] {
        guard let run = day.primaryRunActivity else { return [] }
        var pills: [TargetZonePillData] = []

        if let interval = run.interval {
            if let pace = interval.workPace {
                pills.append(TargetZonePillData(label: "衝刺配速", value: pace, unit: "/km", isDanger: false))
            }
            if let recPace = interval.recoveryPace {
                pills.append(TargetZonePillData(label: "恢復配速", value: recPace, unit: "/km", isDanger: false))
            }
        } else if let pace = run.effectivePace {
            let paceLabel: String
            switch day.type {
            case .progression: paceLabel = "起始配速"
            case .fastFinish: paceLabel = "輕鬆配速"
            default: paceLabel = "目標配速"
            }
            pills.append(TargetZonePillData(label: paceLabel, value: pace, unit: "/km", isDanger: false))
        }

        if let hr = run.heartRateRange, hr.isValid, let hrText = hr.displayText {
            pills.append(TargetZonePillData(label: "目標心率", value: hrText, unit: "bpm", isDanger: true))
        }
        if let intensity = run.targetIntensity {
            pills.append(TargetZonePillData(label: "體感", value: intensity, unit: "/10", isDanger: false))
        }
        if let mins = run.durationMinutes {
            pills.append(TargetZonePillData(label: "預估時間", value: "\(mins)", unit: "分", isDanger: false))
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
        if let mins = interval.workDurationMinutes { return "\(mins)分" }
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
                Image(systemName: icon).font(.system(size: 14))
                Text(label).font(.system(size: 13, weight: .bold))
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
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(segment.isMain ? .white : accentColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(segment.label).font(.system(size: 14, weight: .heavy)).foregroundColor(.primary)
                HStack(spacing: 4) {
                    if let dist = segment.distance {
                        Text(dist).font(.system(size: 11.5, weight: .semibold).monospacedDigit()).foregroundColor(.secondary)
                    }
                    if let pace = segment.pace {
                        Text("·").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.4))
                        Text(pace).font(.system(size: 11.5, weight: .semibold).monospacedDigit()).foregroundColor(.secondary)
                    }
                    if let hr = segment.hr {
                        Text("·").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.4))
                        Text(hr).font(.system(size: 11.5, weight: .semibold).monospacedDigit()).foregroundColor(.secondary)
                    }
                }
                if let rest = segment.rest {
                    Text("組間休息：\(rest)").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()

            if let reps = segment.reps {
                Text("× \(reps)").font(.system(size: 13, weight: .heavy).monospacedDigit()).foregroundColor(.white)
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
            Text(label).font(.system(size: 10, weight: .bold)).tracking(0.04).foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .heavy).monospacedDigit()).tracking(-0.02)
                    .foregroundColor(isDanger ? PacerizColor.orange : accentColor)
                Text(unit).font(.system(size: 10, weight: .bold)).foregroundColor(Color(.tertiaryLabel))
            }
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
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(accentColor.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: "thermometer.sun").font(.system(size: 16)).foregroundColor(accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("提醒").font(.system(size: 12, weight: .heavy)).foregroundColor(.primary)
                Text(meta.reasonText).font(.system(size: 11.5, weight: .semibold)).foregroundColor(.secondary)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(PacerizRadius.card)
    }
}

// MARK: - Preview

#Preview {
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
