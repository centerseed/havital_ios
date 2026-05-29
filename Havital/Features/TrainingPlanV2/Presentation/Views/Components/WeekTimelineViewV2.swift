import SwiftUI

// MARK: - WorkoutDetailDestination
// Phase C C4: Distinguishes history record push vs planned-day push.
// Hashable implementation uses only the stable id string for navigation identity.
struct WorkoutDetailDestination: Identifiable, Hashable {
    enum Kind {
        case history(WorkoutV2)
        case planned(DayDetail, Date?)
    }

    let id: String
    let kind: Kind

    static func history(_ workout: WorkoutV2) -> WorkoutDetailDestination {
        WorkoutDetailDestination(id: "history-\(workout.id)", kind: .history(workout))
    }

    static func planned(_ day: DayDetail, _ date: Date?) -> WorkoutDetailDestination {
        WorkoutDetailDestination(id: "planned-\(day.dayIndex)", kind: .planned(day, date))
    }

    static func == (lhs: WorkoutDetailDestination, rhs: WorkoutDetailDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// V2 週訓練時間軸視圖 - 顯示本週所有訓練的時間軸
/// 基於 V1 WeekTimelineView，適配 V2 ViewModel 和 WeeklyPlanV2
struct WeekTimelineViewV2: View {
    var viewModel: TrainingPlanV2ViewModel
    let plan: WeeklyPlanV2
    /// Destination callback：由 TrainingPlanV2View 提供，把 destination 狀態上移至 NavigationStack 直接子層
    let onDestinationSelect: (WorkoutDetailDestination) -> Void
    /// 午夜跨日觸發器：值變化時強制重繪所有 TimelineItemViewV2，修正「兩天都顯示今日」
    @State private var todayTrigger = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(AppFont.headline())
                Text(NSLocalizedString("training.daily_training", comment: "Daily Training"))
                    .font(AppFont.headline())
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .accessibilityIdentifier("v2.weekly.timeline_header")

            // 時間軸列表（按 dayIndex 排序確保日期順序正確）
            VStack(spacing: 12) {
                ForEach(plan.days.sorted { $0.dayIndexInt < $1.dayIndexInt }) { day in
                    TimelineItemViewV2(
                        viewModel: viewModel,
                        day: day,
                        onDestinationSelect: onDestinationSelect,
                        todayTrigger: todayTrigger
                    )
                }
            }
            .background(
                // 在整個列表背景繪製完整的垂直連接線
                GeometryReader { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .offset(x: 7)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            todayTrigger = Date()
        }
    }
}

/// V2 時間軸單項視圖
// MARK: - PACERIZ REDESIGN 2026-05
// Visual enhancements to TimelineItemViewV2:
//   1. Type accent 3pt left bar (per §3.5 G)
//   2. Today outline upgraded to 2.0pt PacerizColor.blue (per §3.5 G)
//   3. Planned/actual dual row display for non-rest days (per §3.5 G)
// Phase C C4: Interaction model refactored:
//   - Removed isExpanded toggle for non-today days
//   - Only today shows segments inline (always expanded)
//   - All past/future days are collapsed regardless of type (interval, supplementary, etc.)
//   - Tap (non-today, non-rest) → push WorkoutDetailDestination (.history or .planned)
struct TimelineItemViewV2: View {
    var viewModel: TrainingPlanV2ViewModel
    let day: DayDetail
    let onDestinationSelect: (WorkoutDetailDestination) -> Void
    let todayTrigger: Date

    @State private var showRestDayInfo = false
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("climateAdjustmentEnabled") private var climateAdjustmentEnabled = false

    /// 是否有可展開的內容。
    /// 單趟訓練（純跑步、無暖身/緩和/間歇/分段、無補充訓練）header 已含全部資訊，不需展開。
    /// 多段/間歇跑、含暖身緩和、含補充訓練、或非跑步主項（力量/交叉）才允許展開。
    private var canExpand: Bool {
        guard let session = day.session else { return false }  // rest 日無展開內容
        if case .run(let run) = session.primary {
            let hasRunStructure = run.interval != nil
                || (run.segments?.isEmpty == false)
                || session.warmup != nil
                || session.cooldown != nil
            let hasSupplementary = (session.supplementary?.isEmpty == false)
            return hasRunStructure || hasSupplementary
        }
        return true  // 力量／交叉等非跑步主項一律可展開
    }

    var body: some View {
        // todayTrigger 參與 body，確保日期變化時 SwiftUI 重繪
        let _ = todayTrigger
        let isToday = viewModel.isToday(dayIndex: day.dayIndexInt)
        let workouts = viewModel.loader.workoutsByDay[day.dayIndexInt] ?? []

        // 判斷是否為過去的日期
        let isPast: Bool = {
            guard let dayDate = viewModel.getDate(for: day.dayIndexInt) else {
                return false
            }
            let today = Calendar.current.startOfDay(for: Date())
            let targetDay = Calendar.current.startOfDay(for: dayDate)
            return targetDay < today
        }()

        // 休息日只有在當天或已過去時才標記為已完成
        let isCompletedRest = day.type == .rest && (isToday || isPast)
        let isCompleted = isCompletedRest || !workouts.isEmpty

        HStack(alignment: .top, spacing: 12) {
            // 左側時間軸狀態點
            ZStack {
                Circle()
                    .fill(getStatusColor(isCompleted: isCompleted, isToday: isToday, isPast: isPast))
                    .frame(width: 16, height: 16)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(AppFont.captionSmall())
                        .foregroundColor(.white)
                } else if isToday {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 16, height: 16)

            // 右側內容卡片
            // Bug 3: Outer HStack holds card body button + standalone chevron toggle button
            // so chevron tap does NOT trigger card navigation.
            HStack(alignment: .top, spacing: 0) {
                // Card body button — date/chip/plan rows → navigation
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        Logger.debug("[TimelineItemViewV2] tap day=\(day.dayIndexInt) isToday=\(isToday) type=\(day.type) workouts=\(workouts.count)")
                        if day.type == .rest {
                            // 休息日若有補充訓練（力量），點卡片進「訓練詳情」看內容；否則彈出休息日說明。
                            if day.effectiveSupplementary?.isEmpty == false {
                                let date = viewModel.getDate(for: day.dayIndexInt)
                                onDestinationSelect(.planned(day, date))
                            } else {
                                showRestDayInfo = true
                            }
                        } else {
                            // Always push planned (課表詳情) regardless of today/past/future or workout existence
                            let date = viewModel.getDate(for: day.dayIndexInt)
                            Logger.debug("[TimelineItemViewV2] onDestinationSelect .planned day=\(day.dayIndexInt)")
                            onDestinationSelect(.planned(day, date))
                        }

                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            // 第一行：日期 + 訓練類型標籤
                            HStack(alignment: .center, spacing: 8) {
                                // 日期
                                HStack(spacing: 6) {
                                    Text(DateFormatterHelper.weekdayName(for: day.dayIndexInt))
                                        .font(AppFont.bodySmall())
                                        .fontWeight(isToday ? .semibold : .regular)
                                        .foregroundColor(isToday ? .blue : .primary)
                                        .lineLimit(1)

                                    if let date = viewModel.getDate(for: day.dayIndexInt) {
                                        Text(DateFormatterHelper.formatShortDate(date))
                                            .font(AppFont.caption())
                                            .foregroundColor(.primary)
                                    }

                                    if isToday {
                                        Text(NSLocalizedString("training_plan.today", comment: "Today"))
                                            .font(AppFont.micro())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .cornerRadius(4)
                                    }
                                }

                                Spacer()

                                // 訓練類型標籤
                                // F6.c: type chip height 22pt per design jsx L827 — display only, no tap
                                Text(day.type.localizedName)
                                    .font(AppFont.micro())
                                    .fontWeight(.medium)
                                    .foregroundColor(getTypeColor())
                                    .padding(.horizontal, 10)
                                    .frame(height: 22)
                                    .background(getTypeColor().opacity(0.15))
                                    .cornerRadius(8)
                                    .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).run_type")

                                if climateAdjustmentEnabled, let climateMeta = day.effectiveClimateMeta {
                                    // day card 只放溫度計圖示，詳細調整建議在課表詳情。
                                    ClimateBadgeView(meta: climateMeta)
                                        .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).climate_badge")
                                }
                            }

                            // PACERIZ REDESIGN 2026-05: 課表/實際雙行（§3.5 G）
                            // Always show for non-rest days; actual row only when workouts exist.
                            // F6.c: rest day shows 「主動恢復日」in collapsed state per design jsx L823
                            if day.type == .rest {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("training_plan.active_recovery_day", comment: "主動恢復日"))
                                        .font(AppFont.micro())
                                        .foregroundColor(.secondary)
                                    // 休息日的補充訓練（力量）指示：點卡片可進詳情看動作。
                                    if let supp = day.effectiveSupplementary, !supp.isEmpty {
                                        supplementaryIndicatorRow(supp)
                                    }
                                    // 休息日當天若有實際運動紀錄仍要顯示，原本被 rest 分支整段吃掉。
                                    if let workout = workouts.first {
                                        actualWorkoutRow(workout)
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    // 計畫 row (always show for non-rest)
                                    if let run = day.primaryRunActivity {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(NSLocalizedString("training.timeline.plan_label", comment: ""))
                                                .font(AppFont.micro())
                                                .tracking(0.4)
                                                .foregroundColor(.secondary)
                                                .textCase(.uppercase)
                                                .frame(width: 40, alignment: .leading)

                                            let plannedDistStr = run.distanceKm.map { String(format: "%.1f \(UnitManager.shared.currentUnitSystem.distanceSuffix)", UnitManager.shared.convertedDistance($0)) } ?? ""
                                            // 輕鬆跑：拿掉時間，課表只顯示距離（時間對輕鬆跑無意義，依配速/體感跑）。
                                            let isEasyType = day.type == .easyRun || day.type == .easy || day.type == .recovery_run
                                            let plannedDurStr = isEasyType ? "" : formatPlannedDuration(minutes: run.durationMinutes, seconds: run.durationSeconds)
                                            let planParts = [plannedDistStr, plannedDurStr].filter { !$0.isEmpty }
                                            Text(planParts.joined(separator: " · "))
                                                .font(AppFont.micro().monospacedDigit())
                                                .foregroundColor(.secondary)

                                            // 輕鬆跑／長距離輕鬆跑依心率區間跑 → 課表顯示目標心率
                                            let showHR = day.type == .easyRun || day.type == .easy || day.type == .recovery_run || day.type == .lsd
                                            if showHR, let hr = run.heartRateRange, hr.isValid, let hrText = hr.displayText {
                                                Text("·").font(AppFont.micro()).foregroundColor(.secondary)
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.pink.opacity(0.75))
                                                Text(hrText)
                                                    .font(AppFont.micro().monospacedDigit())
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                    // 實際 row (only when workouts exist)
                                    if let workout = workouts.first {
                                        actualWorkoutRow(workout)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    // 訓練內容區域
                    // 單趟訓練不展開（canExpand=false）：今日 always-expanded 與 chevron 都跳過。
                    // 多段/間歇/含補充訓練/非跑步主項才展開。
                    if (isToday || isExpanded) && canExpand {
                        VStack(alignment: .leading, spacing: 8) {

                            // PACERIZ REDESIGN 2026-05: 訓練詳情移至前，使用 RedesignedSegmentsView（run）或原 TrainingDetailsViewV2（非 run）
                            if day.session != nil {
                                if day.primaryRunActivity != nil {
                                    RedesignedSegmentsView(day: day)
                                    // RedesignedSegmentsView 只畫跑步段落；補充訓練（力量/交叉）另外補上。
                                    if let supplementary = day.session?.supplementary, !supplementary.isEmpty {
                                        SupplementaryTrainingView(activities: supplementary)
                                    }
                                } else {
                                    TrainingDetailsViewV2(day: day)
                                }
                            }

                            if climateAdjustmentEnabled, let climateMeta = day.effectiveClimateMeta {
                                ClimateAdjustmentDetailView(day: day, meta: climateMeta)
                                    .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).climate_detail")
                            }

                            // 已完成的訓練記錄 (only shown in today's always-expanded card)
                            if isToday && !workouts.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(NSLocalizedString("training.completed_workouts", comment: "Completed Workouts"))
                                        .font(AppFont.captionSmall())
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                        .padding(.bottom, 2)

                                    ForEach(workouts.prefix(2), id: \.id) { workout in
                                        Button {
                                            onDestinationSelect(WorkoutDetailDestination.history(workout))
                                        } label: {
                                            HStack {
                                                Image(systemName: "figure.run")
                                                    .foregroundColor(.green)
                                                    .font(AppFont.captionSmall())

                                                let rawDistVal = workout.distanceDisplay ?? (workout.distance ?? 0.0) / 1000.0
                                                let distVal = workout.distanceUnit != nil ? rawDistVal : UnitManager.shared.convertedDistance(rawDistVal)
                                                let distUnit = workout.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                                                Text(String(format: "%.2f \(distUnit)", distVal))
                                                    .font(AppFont.caption())
                                                    .foregroundColor(.primary)

                                                Text("·")
                                                    .foregroundColor(.secondary)

                                                Text(formatDuration(workout.duration))
                                                    .font(AppFont.caption())
                                                    .foregroundColor(.secondary)

                                                Spacer()
                                            }
                                            .padding(.vertical, 2)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }

                                    if workouts.count > 2 {
                                        Text("+ \(workouts.count - 2) " + NSLocalizedString("training.more_workouts", comment: "more"))
                                            .font(AppFont.captionSmall())
                                            .foregroundColor(.blue)
                                    }
                                }
                            }

                        }
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Bug 3: Standalone chevron toggle button — only for non-today, non-rest days.
                // 單趟訓練（canExpand=false）不顯示展開箭頭，點卡片直接進課表詳情。
                // Placed OUTSIDE the card body VStack so its tap does NOT trigger card navigation.
                // chevron.right = collapsed, chevron.down = expanded; 44pt hit target per HIG.
                if !isToday && day.type != .rest && canExpand {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                        Logger.debug("[TimelineItemViewV2] chevron toggle day=\(day.dayIndexInt) isExpanded=\(isExpanded)")
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                            .font(AppFont.bodySmall())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).chevron_toggle")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: PacerizRadius.card)
                    .fill(getCardBackgroundColor(isToday: isToday, isCompleted: isCompleted))
            )
            // PACERIZ REDESIGN 2026-05: today outline upgraded to 2.0pt PacerizColor.blue (§3.5 G)
            .overlay(
                RoundedRectangle(cornerRadius: PacerizRadius.card)
                    .strokeBorder(
                        isToday ? PacerizColor.blue : getCardBorderColor(isToday: false, isCompleted: isCompleted, isPast: isPast),
                        lineWidth: isToday ? 2.0 : 1.0
                    )
            )
            // PACERIZ REDESIGN 2026-05: type accent 3pt left bar (§3.5 G); hidden for rest days
            .overlay(alignment: .leading) {
                if day.type != .rest {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(getTypeColor())
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
            }
            .shadow(
                color: getShadowColor(isToday: isToday, isCompleted: isCompleted),
                radius: isToday ? 8 : 3,
                x: 0,
                y: isToday ? 4 : 1
            )
            .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).card")
        }
        .sheet(isPresented: $showRestDayInfo) {
            RestDayInfoSheet()
        }
    }

    // MARK: - Helper Functions

    // 實際運動紀錄行：休息日與訓練日共用，確保任何一天只要有實際紀錄都會顯示。
    @ViewBuilder
    private func actualWorkoutRow(_ workout: WorkoutV2) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(NSLocalizedString("training.timeline.actual_label", comment: ""))
                .font(AppFont.micro())
                .tracking(0.4)
                .foregroundColor(PacerizColor.greenDeep)
                .textCase(.uppercase)
                .frame(width: 40, alignment: .leading)

            let rawDistVal = workout.distanceDisplay ?? (workout.distance ?? 0.0) / 1000.0
            let distVal = workout.distanceUnit != nil ? rawDistVal : UnitManager.shared.convertedDistance(rawDistVal)
            let distUnit = workout.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
            // 有距離才顯示距離（力量／瑜珈等無距離項目只顯示時間）。
            let actualDurStr = formatDuration(workout.duration)
            let actualText = distVal > 0
                ? "\(String(format: "%.2f \(distUnit)", distVal)) · \(actualDurStr)"
                : actualDurStr
            Text(actualText)
                .font(AppFont.micro().monospacedDigit())
                .foregroundColor(.primary)
        }
    }

    // 休息日補充訓練指示：啞鈴 + 「補充訓練 · N 動作」，點卡片可進詳情。
    @ViewBuilder
    private func supplementaryIndicatorRow(_ activities: [SupplementaryActivity]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 9))
                .foregroundColor(PacerizColor.indigo)
            Text(supplementarySummaryText(activities))
                .font(AppFont.micro())
                .foregroundColor(PacerizColor.indigo)
        }
    }

    private func supplementarySummaryText(_ activities: [SupplementaryActivity]) -> String {
        let label = NSLocalizedString("training.supplementary", comment: "Supplementary Training")
        for activity in activities {
            if case .strength(let s) = activity, !s.exercises.isEmpty {
                let unit = NSLocalizedString("training.exercises_count_unit", comment: "")
                return "\(label) · \(s.exercises.count) \(unit)"
            }
        }
        return label
    }

    private func getStatusColor(isCompleted: Bool, isToday: Bool, isPast: Bool) -> Color {
        if isCompleted {
            return .mint
        } else if isToday {
            return .blue
        } else if isPast {
            return .gray
        } else {
            return .orange
        }
    }

    private func getTypeColor() -> Color {
        // 非跑步主項（力量／交叉訓練）統一用 indigo，與跑步色系區隔。
        if day.type != .rest, day.primaryRunActivity == nil {
            return PacerizColor.indigo
        }
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .mint
        case .interval, .tempo, .progression, .threshold, .combination, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .norwegianSingles, .yasso800:
            return .orange
        case .longRun, .hiking, .cycling, .fastFinish:
            return .blue
        case .race, .racePace:
            return .red
        case .rest:
            // Use adaptive systemGray so rest chip is visible in both light and dark mode
            return Color(.systemGray)
        case .crossTraining, .strength, .fartlek, .swimming, .elliptical, .rowing:
            return .purple
        }
    }

    // F6.b: today no longer gets blue background — only 2pt blue outline distinguishes today
    private func getCardBackgroundColor(isToday: Bool, isCompleted: Bool) -> Color {
        return Color(.secondarySystemGroupedBackground)
    }

    private func getCardBorderColor(isToday: Bool, isCompleted: Bool, isPast: Bool) -> Color {
        if isToday {
            return colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2)
        } else if !isCompleted && !isPast {
            return Color.orange.opacity(0.3)
        } else {
            return Color.clear
        }
    }

    private func getShadowColor(isToday: Bool, isCompleted: Bool) -> Color {
        if isToday {
            return Color.blue.opacity(0.2)
        } else if isCompleted {
            return Color.green.opacity(0.15)
        } else {
            return Color.black.opacity(0.05)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // PACERIZ REDESIGN 2026-05: helper for planned duration display in 課表 row (§3.5 G)
    private func formatPlannedDuration(minutes: Int?, seconds: Int?) -> String {
        let totalSec = (minutes ?? 0) * 60 + (seconds ?? 0)
        guard totalSec > 0 else { return "" }
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        let s = totalSec % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - V2 Training Details Components

/// 原子級 badge pill 元件
private struct DataBadge: View {
    let icon: String?
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(AppFont.captionSmall())
                    .foregroundColor(.white)
            }
            Text(text)
                .font(AppFont.caption())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(color)
        .cornerRadius(4)
    }
}

/// 暖身/緩和統一元件 — 輕量 inline 文字行
private struct PhaseRow: View {
    let segment: RunSegment
    let isWarmup: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(isWarmup ? "🔥" : "❄️")
                .font(AppFont.caption())

            Text(isWarmup
                ? NSLocalizedString("training.warmup", comment: "Warmup")
                : NSLocalizedString("training.cooldown", comment: "Cooldown"))
                .font(AppFont.caption())
                .fontWeight(.medium)
                .foregroundColor(.primary)

            detailItems
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isWarmup ? Color.orange.opacity(0.06) : Color.blue.opacity(0.06))
        )
    }

    @ViewBuilder
    private var detailItems: some View {
        let items = buildDetailStrings()
        ForEach(items.indices, id: \.self) { idx in
            Text("·")
                .font(AppFont.caption())
                .foregroundColor(.secondary)
            Text(items[idx])
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
        if let hr = segment.heartRateRange, hr.isValid, let text = hr.displayText {
            Text("·").font(AppFont.caption()).foregroundColor(.secondary)
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundColor(.pink)
            Text(text)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
    }

    private func buildDetailStrings() -> [String] {
        var items: [String] = []
        if let display = segment.distanceDisplay {
            let unit = segment.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
            let val = segment.distanceUnit != nil ? display : UnitManager.shared.convertedDistance(display)
            items.append(String(format: "%.1f\(unit)", val))
        } else if let km = segment.distanceKm {
            let converted = UnitManager.shared.convertedDistance(km)
            items.append(String(format: "%.1f\(UnitManager.shared.currentUnitSystem.distanceSuffix)", converted))
        } else if let m = segment.distanceM {
            items.append("\(m)m")
        }
        if let pace = segment.effectivePace {
            items.append(pace)
        }
        return items
    }
}

/// 簡單跑步 — 文字行風格
private struct SimpleRunBadgesView: View {
    let activity: RunActivity
    let dayType: DayType

    private var shouldHidePace: Bool {
        dayType == .easyRun || dayType == .easy || dayType == .recovery_run || dayType == .lsd
    }

    private var displayPace: String? {
        guard !shouldHidePace else { return nil }
        if let pace = activity.effectivePace { return pace }
        let vdot = effectiveVDOT()
        return PaceCalculator.getSuggestedPace(for: activity.runType, vdot: vdot)
    }

    var body: some View {
        HStack(spacing: 4) {
            // 距離（加粗主資訊）
            if activity.distanceDisplay != nil || activity.distanceKm != nil {
                let rawDistVal = activity.distanceDisplay ?? activity.distanceKm ?? 0
                let distVal = activity.distanceUnit != nil ? rawDistVal : UnitManager.shared.convertedDistance(rawDistVal)
                let distUnit = activity.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                Text(String(format: "%.1f \(distUnit)", distVal))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("simple_run_distance")
            }

            // 配速
            if let pace = displayPace {
                Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                Text(pace)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            // 時間
            if let mins = activity.durationMinutes {
                Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                Text(String(format: NSLocalizedString("common.minutes_format", comment: "Minutes format"), mins))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            // 心率
            if let hr = activity.heartRateRange, hr.isValid, let text = hr.displayText {
                Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundColor(.pink)
                Text(text)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("simple_run_heart_rate")
            }

            Spacer()
        }
    }
}

/// 取得有效 VDOT（從本地快取讀取，失敗則用預設值）
private func effectiveVDOT() -> Double {
    VDOTManager.shared.loadLocalCacheSync()
    let vdot = VDOTManager.shared.currentVDOT
    return vdot > 0 ? vdot : PaceCalculator.defaultVDOT
}

/// 間歇訓練區塊 — 結構化卡片風格（accent bar + 文字表格）
private struct IntervalBlockView: View {
    let interval: IntervalBlock
    let runType: String

    var body: some View {
        let vdot = effectiveVDOT()
        let effectiveWorkPace = interval.workPace ?? fallbackWorkPace(vdot: vdot)

        VStack(alignment: .leading, spacing: 6) {
            // Header: 訓練名稱 + 組數
            HStack {
                Text(runTypeDisplayName)
                    .font(AppFont.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: NSLocalizedString("training.interval.repeats", comment: "Repeats"), interval.repeats))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            // Work + Recovery 結構化區域
            VStack(spacing: 0) {
                // Work row — 橘色 accent bar
                IntervalRow(
                    accentColor: .orange,
                    label: workLabel,
                    distance: workDistanceText,
                    pace: effectiveWorkPace,
                    duration: interval.workDurationMinutes,
                    description: interval.workDescription
                )

                // Recovery row — 灰綠色 accent bar
                IntervalRow(
                    accentColor: recoveryColor,
                    label: recoveryLabel,
                    distance: recoveryDistanceText,
                    pace: interval.recoveryPace,
                    duration: interval.recoveryDurationMinutes,
                    description: interval.recoveryDescription
                )
            }
            .background(Color(.quaternarySystemFill))
            .cornerRadius(8)
        }
    }

    private func fallbackWorkPace(vdot: Double) -> String? {
        let effectiveType = interval.variant ?? runType
        switch effectiveType.lowercased() {
        case "strides":
            return PaceCalculator.getPaceForPercentage(0.975, vdot: vdot)
        case "cruise_intervals":
            return PaceCalculator.getSuggestedPace(for: "threshold", vdot: vdot)
        case "norwegian_4x4":
            return PaceCalculator.getPaceForPercentage(0.92, vdot: vdot)
        default:
            return PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot)
        }
    }

    private var workDistanceText: String? {
        if let display = interval.workDistanceDisplay {
            let unit = interval.workDistanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
            let val = interval.workDistanceUnit != nil ? display : UnitManager.shared.convertedDistance(display)
            return String(format: "%.1f\(unit)", val)
        } else if let km = interval.workDistanceKm {
            let converted = UnitManager.shared.convertedDistance(km)
            return String(format: "%.1f\(UnitManager.shared.currentUnitSystem.distanceSuffix)", converted)
        } else if let m = interval.workDistanceM {
            return "\(m)m"
        }
        return nil
    }

    private var recoveryDistanceText: String? {
        if let km = interval.recoveryDistanceKm {
            return String(format: "%.1fkm", km)
        } else if let m = interval.recoveryDistanceM {
            return "\(m)m"
        }
        return nil
    }

    private var runTypeDisplayName: String {
        switch runType.lowercased() {
        case "interval":
            return NSLocalizedString("training.interval_type.interval", comment: "Interval")
        case "fartlek":
            return NSLocalizedString("training.interval_type.fartlek", comment: "Fartlek")
        case "strides":
            return NSLocalizedString("training.interval_type.strides", comment: "Strides")
        case "hill_repeats":
            return NSLocalizedString("training.interval_type.hill_repeats", comment: "Hill Repeats")
        case "cruise_intervals":
            return NSLocalizedString("training.interval_type.cruise_intervals", comment: "Cruise Intervals")
        case "short_interval":
            return NSLocalizedString("training.interval_type.short_interval", comment: "Short Interval")
        case "long_interval":
            return NSLocalizedString("training.interval_type.long_interval", comment: "Long Interval")
        case "norwegian_4x4":
            return NSLocalizedString("training.interval_type.norwegian_4x4", comment: "Norwegian 4x4")
        case "yasso_800":
            return NSLocalizedString("training.interval_type.yasso_800", comment: "Yasso 800")
        default:
            return NSLocalizedString("training.interval_type.interval", comment: "Interval")
        }
    }

    private var workLabel: String {
        switch runType.lowercased() {
        case "hill_repeats":
            return NSLocalizedString("training.interval.work_label.hill_repeats", comment: "Hill Sprint")
        case "strides":
            return NSLocalizedString("training.interval.work_label.strides", comment: "Acceleration")
        default:
            return NSLocalizedString("training.interval.work_label.default", comment: "Sprint")
        }
    }

    private var recoveryLabel: String {
        let hasMovement = interval.recoveryDistanceKm != nil
            || interval.recoveryDistanceM != nil
            || interval.recoveryPace != nil
        return hasMovement
            ? NSLocalizedString("training.interval.recovery_run", comment: "Recovery Run")
            : NSLocalizedString("training.interval.rest", comment: "Rest")
    }

    private var recoveryColor: Color {
        let hasMovement = interval.recoveryDistanceKm != nil
            || interval.recoveryDistanceM != nil
            || interval.recoveryPace != nil
        return hasMovement ? .mint : .gray
    }
}

/// 間歇訓練中的單行（衝刺/恢復）— 左側 accent bar
private struct IntervalRow: View {
    let accentColor: Color
    let label: String
    let distance: String?
    let pace: String?
    let duration: Int?
    var description: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            // 左側 accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)

            HStack(spacing: 4) {
                Text(label)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(minWidth: 40, alignment: .leading)

                if let distance = distance {
                    Text(distance)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                if let pace = pace {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text(pace)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                } else if let desc = description, !desc.isEmpty {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text(desc)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let mins = duration {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text(String(format: NSLocalizedString("common.minutes_format", comment: "Minutes format"), mins))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.leading, 8)
            .padding(.vertical, 6)
        }
    }
}

/// 分段訓練（progression, combination）— accent bar + 文字行
private struct SegmentsView: View {
    let segments: [RunSegment]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { idx in
                let seg = segments[idx]
                HStack(spacing: 0) {
                    // 左側 accent bar — 依段落序號遞進色彩
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segmentColor(index: idx, total: segments.count))
                        .frame(width: 3)

                    HStack(spacing: 4) {
                        Text(String(format: NSLocalizedString("training.segment_n", comment: "Segment N"), idx + 1))
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(minWidth: 36, alignment: .leading)

                        if let display = seg.distanceDisplay {
                            let unit = seg.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                            let val = seg.distanceUnit != nil ? display : UnitManager.shared.convertedDistance(display)
                            Text(String(format: "%.1f\(unit)", val))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        } else if let km = seg.distanceKm {
                            let converted = UnitManager.shared.convertedDistance(km)
                            Text(String(format: "%.1f\(UnitManager.shared.currentUnitSystem.distanceSuffix)", converted))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        } else if let m = seg.distanceM {
                            Text("\(m)m")
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }

                        if let pace = seg.effectivePace {
                            Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                            Text(pace)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }

                        if let mins = seg.durationMinutes {
                            Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                            Text(String(format: NSLocalizedString("common.minutes_format", comment: "Minutes format"), mins))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }

                        if let hr = seg.heartRateRange, hr.isValid, let text = hr.displayText {
                            Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.pink)
                            Text(text)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.leading, 8)
                    .padding(.vertical, 5)
                }
            }
        }
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }

    /// 依段落索引產生漸進色（橘 → 紅）
    private func segmentColor(index: Int, total: Int) -> Color {
        if total <= 1 { return .orange }
        let fraction = Double(index) / Double(total - 1)
        // 從橘色漸進到紅色
        return fraction < 0.5 ? .orange : .red
    }
}

/// 把「6:45」/「7:11/km」配速字串轉為秒數（忽略單位後綴）。
func paceStringToSeconds(_ pace: String) -> Int? {
    let core = pace.split(separator: "/").first.map(String.init) ?? pace
    let parts = core.trimmingCharacters(in: .whitespaces).split(separator: ":")
    guard parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) else { return nil }
    return m * 60 + s
}

/// 秒數轉「m:ss」配速字串。
func secondsToPaceString(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

/// day card 上的氣候徽章 —— 只放溫度計圖示（依等級上色），詳細調整建議在課表詳情。
private struct ClimateBadgeView: View {
    let meta: ClimateMeta

    var body: some View {
        Image(systemName: "thermometer.medium")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(meta.badgeForegroundColor)
            .frame(width: 24, height: 24)
            .background(meta.badgeBackgroundColor)
            .clipShape(Circle())
    }
}

private struct ClimateAdjustmentDetailView: View {
    let day: DayDetail
    let meta: ClimateMeta

    private var runActivity: RunActivity? {
        day.primaryRunActivity
    }

    /// 分段型課表逐段「原 → 今日」配速（後端不給分段調整，app 端補算）。
    private var segmentAdjustedRows: [(title: String, base: String, adjusted: String)] {
        guard let segs = runActivity?.segments, segs.count > 1 else { return [] }
        return segs.enumerated().compactMap { idx, seg in
            guard let p = seg.pace, let adj = meta.climateAdjustedPace(forBasePace: p) else { return nil }
            return (seg.description ?? "段 \(idx + 1)", p, adj)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "thermometer.sun.fill")
                    .font(AppFont.caption())
                    .foregroundColor(meta.badgeAccentColor)
                Text(meta.sectionTitle)
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack(spacing: 8) {
                ClimateValueChip(title: meta.levelTitle, value: meta.levelDisplayText)
                if let temp = meta.feelsLikeTempText {
                    ClimateValueChip(title: meta.temperatureTitle, value: temp)
                }
                if let adjustment = meta.adjustmentText {
                    ClimateValueChip(title: meta.adjustmentTitle, value: adjustment)
                }
            }

            if let basePace = runActivity?.basePace,
               let adjustedPace = runActivity?.climateAdjustedPace {
                HStack(spacing: 8) {
                    ClimateValueChip(title: meta.originalPaceTitle, value: basePace)
                    ClimateValueChip(title: meta.adjustedPaceTitle, value: adjustedPace)
                }
            } else if !segmentAdjustedRows.isEmpty {
                // 分段型課表：逐段顯示「原 → 今日」。
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(segmentAdjustedRows.indices, id: \.self) { i in
                        let row = segmentAdjustedRows[i]
                        ClimateValueChip(title: row.title, value: "\(row.base) → \(row.adjusted)")
                    }
                }
            }

            if let reduction = meta.longRunReductionText {
                Text(reduction)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            Text(meta.reasonText)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(meta.badgeBackgroundColor.opacity(0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(meta.badgeAccentColor.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct ClimateValueChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFont.captionSmall())
                .foregroundColor(.secondary)
            Text(value)
                .font(AppFont.caption())
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
extension ClimateMeta {
    var currentLanguage: SupportedLanguage {
        LanguageManager.shared.currentLanguage
    }

    /// 熱適應「為什麼調整」的說明（課表詳情用）。多語。
    var heatAdaptationExplanation: String {
        switch currentLanguage {
        case .traditionalChinese:
            return "高溫濕熱會讓心率上升、同樣配速感覺更累——這是正常生理反應，不是退步。系統已依今日體感溫度把配速目標放寬，讓你用對的強度安全完成這次訓練。"
        case .english:
            return "Heat and humidity raise your heart rate and make the same pace feel harder — that's a normal physiological response, not a loss of fitness. Today's pace target has been eased based on the feels-like temperature so you can finish this session safely at the right effort."
        case .japanese:
            return "高温多湿は心拍数を上げ、同じペースでもよりきつく感じます。これは正常な生理反応で、走力の低下ではありません。本日の体感温度に合わせてペース目標を緩めてあるので、適切な強度で安全に完了できます。"
        }
    }

    /// 建議訓練時段／室內（依等級，對齊 SPEC-climate-engine 附錄 A 建議時段）。多語。
    var trainingTimeRecommendation: String {
        switch currentLanguage {
        case .traditionalChinese:
            switch normalizedHeatPressureLevel {
            case "danger":
                return "強烈建議改到室內（跑步機／交叉訓練）或改期；若一定要戶外，請選最涼的清晨或入夜後，務必大幅放慢、縮短距離並隨時補水。"
            case "high":
                return "建議在清晨或傍晚較涼時段進行，避開 11:00–15:00 高溫；長跑可縮短 20–30%，或改到室內。"
            case "moderate":
                return "避開 11:00–15:00 最熱時段，長跑改到清晨；訓練全程注意補水。"
            default:
                return "天氣偏熱，建議清晨或傍晚較舒適時段訓練，並記得補充水分。"
            }
        case .english:
            switch normalizedHeatPressureLevel {
            case "danger":
                return "Strongly consider moving indoors (treadmill / cross-training) or rescheduling. If you must go outside, pick the coolest early morning or after dark, slow down significantly, shorten the distance, and hydrate constantly."
            case "high":
                return "Train in the cooler early morning or evening and avoid 11:00–15:00. Shorten long runs by 20–30%, or move them indoors."
            case "moderate":
                return "Avoid the hottest 11:00–15:00 window and move long runs to early morning. Hydrate throughout."
            default:
                return "It's warm — train in the cooler early morning or evening and remember to hydrate."
            }
        case .japanese:
            switch normalizedHeatPressureLevel {
            case "danger":
                return "室内（トレッドミル／クロストレーニング）への変更か日程の延期を強く推奨します。屋外で行う場合は最も涼しい早朝か夜間を選び、大幅にペースを落とし、距離を短くし、こまめに水分補給してください。"
            case "high":
                return "涼しい早朝か夕方に行い、11:00〜15:00は避けてください。ロング走は20〜30%短縮するか、屋内に変更しましょう。"
            case "moderate":
                return "最も暑い11:00〜15:00を避け、ロング走は早朝へ。トレーニング中はこまめに水分補給を。"
            default:
                return "暑めです。涼しい早朝か夕方に行い、水分補給を忘れずに。"
            }
        }
    }

    /// 建議時段標題。多語。
    var recommendationTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "建議時段"
        case .english: return "When to train"
        case .japanese: return "おすすめの時間帯"
        }
    }

    var isDangerLevel: Bool { normalizedHeatPressureLevel == "danger" }

    /// 危險級「若仍要戶外」的最低放慢量（秒/km）。
    /// 依據：knowledge_base/09_environmental_adaptation 高熱(30-34°C)=放慢 30–60 秒/km（一個配速等級），
    /// 危險(>34°C) 至少不低於此，故取 60 秒/km 為下限。
    var dangerOutdoorMinSlowdownSeconds: Int { 60 }

    /// app 端依本日體感調整百分比，從原始配速補算熱調整後配速。
    /// 後端只對單一配速跑與間歇 work_pace 套用，分段型課表（progression/fast_finish/combination）
    /// 後端不給 climate_adjusted_pace，由 app 在溫度補償卡逐段補算（公式對齊後端 l5_response_builder）。
    func climateAdjustedPace(forBasePace basePace: String) -> String? {
        guard let baseSec = paceStringToSeconds(basePace) else { return nil }
        if normalizedHeatPressureLevel == "danger" {
            // 危險級後端常不給百分比：至少放慢一個配速等級。
            return "\(secondsToPaceString(baseSec + dangerOutdoorMinSlowdownSeconds))+"
        }
        let pct = paceAdjustmentPct ?? 0
        guard pct > 0 else { return nil }
        return secondsToPaceString(Int((Double(baseSec) * (1 + pct / 100)).rounded()))
    }

    /// 危險級標題：若仍要戶外的配速建議。多語。
    var dangerOutdoorPaceTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "若仍戶外"
        case .english: return "If outdoors"
        case .japanese: return "屋外なら"
        }
    }

    var badgeAccentColor: Color {
        switch normalizedHeatPressureLevel {
        case "mild":
            return .yellow
        case "moderate":
            return .orange
        case "high":
            return .red
        case "danger":
            return Color(red: 0.55, green: 0.10, blue: 0.12)
        default:
            return .gray
        }
    }

    var badgeBackgroundColor: Color {
        badgeAccentColor.opacity(normalizedHeatPressureLevel == "danger" ? 0.18 : 0.15)
    }

    var badgeForegroundColor: Color {
        normalizedHeatPressureLevel == "mild" ? .orange : badgeAccentColor
    }

    var shortLevelDisplayText: String {
        switch currentLanguage {
        case .traditionalChinese:
            switch normalizedHeatPressureLevel {
            case "mild": return "輕熱"
            case "moderate": return "中熱"
            case "high": return "高熱"
            case "danger": return "危險"
            default: return "熱調整"
            }
        case .english:
            switch normalizedHeatPressureLevel {
            case "mild": return "Mild Heat"
            case "moderate": return "Heat"
            case "high": return "High Heat"
            case "danger": return "Danger"
            default: return "Heat"
            }
        case .japanese:
            switch normalizedHeatPressureLevel {
            case "mild": return "軽い暑熱"
            case "moderate": return "暑熱"
            case "high": return "高暑熱"
            case "danger": return "危険"
            default: return "暑熱調整"
            }
        }
    }

    var levelDisplayText: String {
        switch currentLanguage {
        case .traditionalChinese:
            switch normalizedHeatPressureLevel {
            case "mild": return "輕度熱壓力"
            case "moderate": return "中度熱壓力"
            case "high": return "高度熱壓力"
            case "danger": return "危險熱壓力"
            default: return "舒適"
            }
        case .english:
            switch normalizedHeatPressureLevel {
            case "mild": return "Mild heat stress"
            case "moderate": return "Moderate heat stress"
            case "high": return "High heat stress"
            case "danger": return "Danger heat stress"
            default: return "Comfortable"
            }
        case .japanese:
            switch normalizedHeatPressureLevel {
            case "mild": return "軽度の暑熱ストレス"
            case "moderate": return "中度の暑熱ストレス"
            case "high": return "高度の暑熱ストレス"
            case "danger": return "危険な暑熱ストレス"
            default: return "快適"
            }
        }
    }

    var sectionTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "熱適應"
        case .english: return "Heat Adaptation"
        case .japanese: return "暑熱順化"
        }
    }

    var levelTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "等級"
        case .english: return "Level"
        case .japanese: return "レベル"
        }
    }

    var temperatureTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "體感"
        case .english: return "Feels like"
        case .japanese: return "体感"
        }
    }

    var adjustmentTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "調整"
        case .english: return "Adjustment"
        case .japanese: return "調整"
        }
    }

    var originalPaceTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "原配速"
        case .english: return "Base Pace"
        case .japanese: return "元のペース"
        }
    }

    var adjustedPaceTitle: String {
        switch currentLanguage {
        case .traditionalChinese: return "調整後"
        case .english: return "Adjusted"
        case .japanese: return "調整後"
        }
    }

    var feelsLikeTempText: String? {
        guard let feelsLikeTempC else { return nil }
        return String(format: "%.1f°C", feelsLikeTempC)
    }

    var adjustmentText: String? {
        // 危險級（≥36°C）依 SPEC 不給百分比；修正幅度四捨五入為 0 也不顯示（避免「配速 +0%」）。
        if let paceAdjustmentPct, paceAdjustmentPct.rounded() != 0 {
            switch currentLanguage {
            case .traditionalChinese:
                return String(format: "配速 +%.0f%%", paceAdjustmentPct)
            case .english:
                return String(format: "Pace +%.0f%%", paceAdjustmentPct)
            case .japanese:
                return String(format: "ペース +%.0f%%", paceAdjustmentPct)
            }
        }
        if let longRunReductionPct, longRunReductionPct.rounded() != 0 {
            switch currentLanguage {
            case .traditionalChinese:
                return String(format: "縮量 %.0f%%", longRunReductionPct)
            case .english:
                return String(format: "Reduce %.0f%%", longRunReductionPct)
            case .japanese:
                return String(format: "%.0f%%短縮", longRunReductionPct)
            }
        }
        return nil
    }

    var longRunReductionText: String? {
        guard let longRunReductionPct else { return nil }
        switch currentLanguage {
        case .traditionalChinese:
            return String(format: "長跑建議縮減 %.0f%%，優先改期或改室內。", longRunReductionPct)
        case .english:
            return String(format: "Long run recommended reduction: %.0f%%. Prefer rescheduling or moving indoors.", longRunReductionPct)
        case .japanese:
            return String(format: "ロング走は%.0f%%短縮推奨。日程変更または屋内代替を優先してください。", longRunReductionPct)
        }
    }

    var segmentAdjustmentSummary: String {
        switch currentLanguage {
        case .traditionalChinese:
            return "分段配速已依當日熱壓力調整。"
        case .english:
            return "Segment paces were adjusted for the day's heat stress."
        case .japanese:
            return "各セグメントのペースは当日の暑熱ストレスに合わせて調整済みです。"
        }
    }
}

/// 力量訓練內容 — 文字行風格
private struct StrengthContentView: View {
    let activity: StrengthActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 摘要列：類型名稱 · 動作數量 · 時長
            HStack(spacing: 4) {
                if !activity.strengthType.isEmpty {
                    Text(strengthTypeDisplayName(activity.strengthType))
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(PacerizColor.indigo)
                }
                if !activity.exercises.isEmpty {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text("\(activity.exercises.count) \(NSLocalizedString("training.exercises_count_unit", comment: "exercises"))")
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(PacerizColor.indigo)
                }
                if let mins = activity.durationMinutes {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text("\(mins) \(NSLocalizedString("training.minutes_unit", comment: "min"))")
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(PacerizColor.indigo)
                }
                Spacer()
            }

            if !activity.exercises.isEmpty {
                ExercisesListView(exercises: activity.exercises)
            }
        }
    }

    private func strengthTypeDisplayName(_ type: String) -> String {
        switch type {
        case "core_stability":  return NSLocalizedString("training.strength_type.core_stability", comment: "Core Stability")
        case "glutes_hip":      return NSLocalizedString("training.strength_type.glutes_hip", comment: "Glutes Hip")
        case "lower_strength":  return NSLocalizedString("training.strength_type.lower_strength", comment: "Lower Strength")
        case "upper_strength":  return NSLocalizedString("training.strength_type.upper_strength", comment: "Upper Strength")
        case "full_body":       return NSLocalizedString("training.strength_type.full_body", comment: "Full Body")
        case "plyometric":      return NSLocalizedString("training.strength_type.plyometric", comment: "Plyometric")
        case "mobility":        return NSLocalizedString("training.strength_type.mobility", comment: "Mobility")
        default:                return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// 交叉訓練內容 — 文字行風格
private struct CrossContentView: View {
    let activity: CrossActivity

    var body: some View {
        HStack(spacing: 4) {
            Text(String(format: NSLocalizedString("common.minutes_format", comment: "Minutes format"), activity.durationMinutes))
                .font(AppFont.bodySmall())
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if activity.distanceDisplay != nil || activity.distanceKm != nil {
                let rawDistVal = activity.distanceDisplay ?? activity.distanceKm ?? 0
                let distVal = activity.distanceUnit != nil ? rawDistVal : UnitManager.shared.convertedDistance(rawDistVal)
                let distUnit = activity.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                Text(String(format: "%.1f \(distUnit)", distVal))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

/// 跑步活動內容分流（interval / segments / simple）
private struct RunActivityContentView: View {
    let activity: RunActivity
    let dayType: DayType

    var body: some View {
        if let interval = activity.interval {
            IntervalBlockView(interval: interval, runType: activity.runType)
        } else if let segments = activity.segments, !segments.isEmpty {
            SegmentsView(segments: segments)
        } else {
            SimpleRunBadgesView(activity: activity, dayType: dayType)
        }
    }
}

/// 主活動分流（run / strength / cross）
private struct MainActivityView: View {
    let primary: PrimaryActivity
    let dayType: DayType

    var body: some View {
        switch primary {
        case .run(let runActivity):
            RunActivityContentView(activity: runActivity, dayType: dayType)
        case .strength(let strengthActivity):
            StrengthContentView(activity: strengthActivity)
        case .cross(let crossActivity):
            CrossContentView(activity: crossActivity)
        }
    }
}

// MARK: - PACERIZ REDESIGN 2026-05 — Flat segments renderer (today inline only, not used by WorkoutDetail screen)

/// 統一 pill row 樣式的 segments 視圖，僅用於今日 inline 展開場景。
/// 只處理 run activity；force/cross 仍走 TrainingDetailsViewV2。
private struct RedesignedSegmentsView: View {
    let day: DayDetail

    private struct FlatSegment {
        let label: String
        let detail: String
        let subDetail: String?
        let reps: String?
        let accent: Color

        init(label: String, detail: String, subDetail: String? = nil, reps: String? = nil, accent: Color) {
            self.label = label
            self.detail = detail
            self.subDetail = subDetail
            self.reps = reps
            self.accent = accent
        }
    }

    private func emojiPrefix(for role: String) -> String {
        switch role {
        case "warmup": return "🔥"
        case "cooldown": return "🌀"
        case "recovery": return "💨"
        default: return "⚡"
        }
    }

    /// 分段語意化標籤，對齊 PlannedSessionDetailView.segmentLabel，確保 day card 與詳情頁一致。
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

    private func buildSegments() -> [FlatSegment] {
        guard let session = day.session,
              case .run(let run) = session.primary else { return [] }

        var result: [FlatSegment] = []

        // 暖身
        if let warmup = session.warmup {
            let distStr: String
            if let km = warmup.distanceKm {
                let val = UnitManager.shared.convertedDistance(km)
                distStr = String(format: "%.1f \(UnitManager.shared.currentUnitSystem.distanceSuffix)", val)
            } else if let m = warmup.distanceM {
                distStr = "\(m)m"
            } else {
                distStr = ""
            }
            let paceStr = warmup.effectivePace ?? ""
            let parts = [distStr, paceStr].filter { !$0.isEmpty }
            result.append(FlatSegment(
                label: "\(emojiPrefix(for: "warmup")) 暖身",
                detail: parts.joined(separator: " · "),
                reps: nil,
                accent: .orange
            ))
        }

        // 主活動
        if let interval = run.interval {
            // F12: 間歇訓練合併成一個 row（衝刺 + 恢復），顯示趟數
            let variantName: String
            switch (interval.variant ?? run.runType).lowercased() {
            case "strides": variantName = "加速跑"
            case "hill_repeats": variantName = "坡度間歇"
            case "cruise_intervals": variantName = "節奏間歇"
            case "norwegian_4x4": variantName = "4x4間歇"
            case "yasso_800": variantName = "800m間歇"
            default: variantName = "衝刺"
            }

            // 主行：工作距離 @ 配速
            var workParts: [String] = []
            if let m = interval.workDistanceM {
                workParts.append("\(m)m")
            } else if let km = interval.workDistanceKm {
                workParts.append(String(format: "%.1fkm", km))
            }
            if let pace = interval.workPace {
                workParts.append("@ \(pace)")
            }
            let workDetail = workParts.joined(separator: " ")

            // 副行：恢復資訊
            let hasRecoveryInfo = interval.recoveryDistanceKm != nil
                || interval.recoveryDistanceM != nil
                || interval.recoveryPace != nil
                || interval.recoveryDurationMinutes != nil
                || interval.recoveryDurationSeconds != nil
                || interval.recoveryDescription != nil
            let recoverySubDetail: String?
            if hasRecoveryInfo {
                var recoveryParts: [String] = ["恢復"]
                if let km = interval.recoveryDistanceKm {
                    recoveryParts.append(String(format: "%.1fkm", km))
                } else if let m = interval.recoveryDistanceM {
                    recoveryParts.append("\(m)m")
                }
                if let pace = interval.recoveryPace {
                    recoveryParts.append("@ \(pace)/km")
                }
                if let min = interval.recoveryDurationMinutes {
                    recoveryParts.append("\(min)min")
                } else if let sec = interval.recoveryDurationSeconds {
                    recoveryParts.append("\(sec)s")
                }
                if recoveryParts.count == 1 {
                    recoveryParts.append(interval.recoveryDescription ?? NSLocalizedString("training.interval.rest", comment: "Rest"))
                }
                recoverySubDetail = recoveryParts.joined(separator: " ")
            } else {
                recoverySubDetail = nil
            }

            result.append(FlatSegment(
                label: "⚡ \(variantName) + 恢復",
                detail: workDetail,
                subDetail: recoverySubDetail,
                reps: "× \(interval.repeats) 趟",
                accent: .orange
            ))
        } else if let segs = run.segments, !segs.isEmpty {
            // 分段跑（progression / combination）
            // 分段跑（progression / fast_finish / combination）：segments 是主課表結構，
            // 用語意化標籤（輕鬆／節奏收尾…），勿以位置硬套暖身/緩和——真正的暖身緩和在 session.warmup/cooldown。
            for (idx, seg) in segs.enumerated() {
                let distStr: String
                if let display = seg.distanceDisplay {
                    let unit = seg.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                    let val = seg.distanceUnit != nil ? display : UnitManager.shared.convertedDistance(display)
                    distStr = String(format: "%.1f\(unit)", val)
                } else if let km = seg.distanceKm {
                    let val = UnitManager.shared.convertedDistance(km)
                    distStr = String(format: "%.1f\(UnitManager.shared.currentUnitSystem.distanceSuffix)", val)
                } else if let m = seg.distanceM {
                    distStr = "\(m)m"
                } else {
                    distStr = ""
                }
                let paceStr = seg.effectivePace ?? ""
                let parts = [distStr, paceStr].filter { !$0.isEmpty }
                result.append(FlatSegment(
                    label: "\(emojiPrefix(for: "main")) \(segmentLabel(index: idx, total: segs.count))",
                    detail: parts.joined(separator: " · "),
                    reps: nil,
                    accent: idx == segs.count - 1 ? .red : .blue
                ))
            }
        } else {
            // 簡單跑
            let distStr: String
            if let display = run.distanceDisplay {
                let unit = run.distanceUnit ?? UnitManager.shared.currentUnitSystem.distanceSuffix
                let val = run.distanceUnit != nil ? display : UnitManager.shared.convertedDistance(display)
                distStr = String(format: "%.1f \(unit)", val)
            } else if let km = run.distanceKm {
                let val = UnitManager.shared.convertedDistance(km)
                distStr = String(format: "%.1f \(UnitManager.shared.currentUnitSystem.distanceSuffix)", val)
            } else {
                distStr = ""
            }
            let paceStr = run.effectivePace ?? ""
            let parts = [distStr, paceStr].filter { !$0.isEmpty }
            result.append(FlatSegment(
                label: "\(emojiPrefix(for: "main")) \(run.runType)",
                detail: parts.joined(separator: " · "),
                reps: nil,
                accent: .blue
            ))
        }

        // 緩和
        if let cooldown = session.cooldown {
            let distStr: String
            if let km = cooldown.distanceKm {
                let val = UnitManager.shared.convertedDistance(km)
                distStr = String(format: "%.1f \(UnitManager.shared.currentUnitSystem.distanceSuffix)", val)
            } else if let m = cooldown.distanceM {
                distStr = "\(m)m"
            } else {
                distStr = ""
            }
            let paceStr = cooldown.effectivePace ?? ""
            let parts = [distStr, paceStr].filter { !$0.isEmpty }
            result.append(FlatSegment(
                label: "\(emojiPrefix(for: "cooldown")) 緩和",
                detail: parts.joined(separator: " · "),
                reps: nil,
                accent: .mint
            ))
        }

        return result
    }

    var body: some View {
        let segments = buildSegments()
        // 單段 workout 不渲染（資訊與 card header 重複）
        if segments.count > 1 {
            VStack(spacing: 8) {
                ForEach(segments.indices, id: \.self) { idx in
                    let seg = segments[idx]
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(seg.accent.opacity(0.7))
                            .frame(width: 4)
                            .clipShape(Capsule())

                        if seg.subDetail != nil {
                            // F12: 2 行版型（有 subDetail 時使用）
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(seg.label)
                                        .font(AppFont.bodyStrong())
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let reps = seg.reps {
                                        Text(reps)
                                            .font(AppFont.micro())
                                            .foregroundColor(.primary)
                                    }
                                }
                                HStack(spacing: 4) {
                                    if !seg.detail.isEmpty {
                                        Text(seg.detail)
                                            .font(AppFont.micro().monospacedDigit())
                                            .foregroundColor(.secondary)
                                    }
                                    if let sub = seg.subDetail {
                                        if !seg.detail.isEmpty {
                                            Text("·")
                                                .font(AppFont.micro())
                                                .foregroundColor(.secondary)
                                        }
                                        Text(sub)
                                            .font(AppFont.micro())
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        } else {
                            // 單行版型（原有）
                            Text(seg.label)
                                .font(AppFont.bodyStrong())
                                .foregroundColor(.primary)
                                .frame(minWidth: 64, alignment: .leading)
                            Text(seg.detail)
                                .font(AppFont.micro().monospacedDigit())
                                .foregroundColor(.secondary)
                            Spacer()
                            if let reps = seg.reps {
                                Text(reps)
                                    .font(AppFont.micro())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, seg.subDetail != nil ? 8 : 6)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - B4: Rest Day Info Sheet

/// 主動恢復日說明 sheet（B4 rest day tap 互動）
private struct RestDayInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("rest_day.info_body", comment: "Rest day info body"))
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(24)
            .navigationTitle(NSLocalizedString("rest_day.info_title", comment: "主動恢復日"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// 訓練詳情視圖 — 直接讀取 V2 entity
private struct TrainingDetailsViewV2: View {
    let day: DayDetail

    var body: some View {
        if let session = day.session {
            VStack(alignment: .leading, spacing: 8) {
                // 暖身
                if let warmup = session.warmup {
                    PhaseRow(segment: warmup, isWarmup: true)
                }

                // 主活動
                MainActivityView(primary: session.primary, dayType: day.type)

                // 緩和
                if let cooldown = session.cooldown {
                    PhaseRow(segment: cooldown, isWarmup: false)
                }

                // 補充訓練
                if let supplementary = session.supplementary, !supplementary.isEmpty {
                    SupplementaryTrainingView(activities: supplementary)
                }
            }
            .padding(.top, 4)
        }
    }
}
