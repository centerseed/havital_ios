import SwiftUI

/// V2 週訓練時間軸視圖 - 顯示本週所有訓練的時間軸
/// 基於 V1 WeekTimelineView，適配 V2 ViewModel 和 WeeklyPlanV2
struct WeekTimelineViewV2: View {
    var viewModel: TrainingPlanV2ViewModel
    let plan: WeeklyPlanV2
    @State private var selectedWorkout: WorkoutV2?
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
                        onWorkoutSelect: { workout in
                            selectedWorkout = workout
                        },
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
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailViewV2(workout: workout)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            todayTrigger = Date()
        }
    }
}

/// V2 時間軸單項視圖
struct TimelineItemViewV2: View {
    var viewModel: TrainingPlanV2ViewModel
    let day: DayDetail
    let onWorkoutSelect: (WorkoutV2) -> Void
    let todayTrigger: Date

    @State private var isExpanded = false
    @State private var showTrainingTypeInfo = false
    @Environment(\.colorScheme) private var colorScheme

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
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    if !isToday {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 第一行：日期 + 訓練類型標籤 + 收折按鈕
                        HStack(alignment: .center, spacing: 8) {
                            // 日期
                            HStack(spacing: 6) {
                                Text(DateFormatterHelper.weekdayName(for: day.dayIndexInt))
                                    .font(AppFont.bodySmall())
                                    .fontWeight(isToday ? .semibold : .regular)
                                    .foregroundColor(isToday ? .blue : .primary)

                                if let date = viewModel.getDate(for: day.dayIndexInt) {
                                    Text(DateFormatterHelper.formatShortDate(date))
                                        .font(AppFont.caption())
                                        .foregroundColor(.secondary)
                                }

                                if isToday {
                                    Text(NSLocalizedString("training_plan.today", comment: "Today"))
                                        .font(AppFont.caption())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                }
                            }

                            Spacer()

                            // 訓練類型標籤
                            if TrainingTypeInfo.info(for: day.type) != nil {
                                Button(action: {
                                    showTrainingTypeInfo = true
                                }) {
                                    Text(day.type.localizedName)
                                        .font(AppFont.bodySmall())
                                        .fontWeight(.medium)
                                        .foregroundColor(getTypeColor())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(getTypeColor().opacity(0.15))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).run_type")
                            } else {
                                Text(day.type.localizedName)
                                    .font(AppFont.bodySmall())
                                    .fontWeight(.medium)
                                    .foregroundColor(getTypeColor())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(getTypeColor().opacity(0.15))
                                    .cornerRadius(8)
                                    .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).run_type")
                            }

                            // 展開/收起圖示
                            if !isToday {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(AppFont.bodySmall())
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // 訓練內容區域（只在展開或今日時顯示）
                if isExpanded || isToday {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        // 訓練目標描述
                        if !day.reason.isEmpty {
                            Text(day.reason)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(day.dayTarget)
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // 訓練詳情
                        if day.session != nil {
                            TrainingDetailsViewV2(day: day)
                        }

                        // 已完成的訓練記錄
                        if !workouts.isEmpty {
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
                                        onWorkoutSelect(workout)
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
                }

                // 折疊時也顯示已完成訓練
                if !isExpanded && !isToday && !workouts.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                            .padding(.vertical, 4)

                        ForEach(workouts.prefix(2), id: \.id) { workout in
                            Button {
                                onWorkoutSelect(workout)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(getCardBackgroundColor(isToday: isToday, isCompleted: isCompleted))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(getCardBorderColor(isToday: isToday, isCompleted: isCompleted, isPast: isPast), lineWidth: isToday ? 1.5 : 1.0)
            )
            .shadow(
                color: getShadowColor(isToday: isToday, isCompleted: isCompleted),
                radius: isToday ? 8 : 3,
                x: 0,
                y: isToday ? 4 : 1
            )
            .accessibilityIdentifier("v2.weekly.day_\(day.dayIndexInt).card")
        }
        .sheet(isPresented: $showTrainingTypeInfo) {
            if let trainingTypeInfo = TrainingTypeInfo.info(for: day.type) {
                TrainingTypeInfoView(trainingTypeInfo: trainingTypeInfo)
            }
        }
    }

    // MARK: - Helper Functions

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
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .mint
        case .interval, .tempo, .progression, .threshold, .combination, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
            return .orange
        case .longRun, .hiking, .cycling, .fastFinish:
            return .blue
        case .race, .racePace:
            return .red
        case .rest:
            return .gray
        case .crossTraining, .strength, .fartlek, .swimming, .elliptical, .rowing:
            return .purple
        }
    }

    private func getCardBackgroundColor(isToday: Bool, isCompleted: Bool) -> Color {
        if isToday {
            return colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.08)
        } else {
            return Color(.secondarySystemGroupedBackground)
        }
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
        if !items.isEmpty {
            ForEach(items.indices, id: \.self) { idx in
                if idx > 0 || true {
                    Text("·")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                Text(items[idx])
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }
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
        if let pace = segment.pace {
            items.append(pace)
        }
        if let hr = segment.heartRateRange, hr.isValid, let text = hr.displayText {
            items.append("HR \(text)")
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
        if let pace = activity.pace { return pace }
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
                Text("HR \(text)")
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

                        if let pace = seg.pace {
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
                            Text("HR \(text)")
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
                        .foregroundColor(.purple)
                }
                if !activity.exercises.isEmpty {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text("\(activity.exercises.count) \(NSLocalizedString("training.exercises_count_unit", comment: "exercises"))")
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                if let mins = activity.durationMinutes {
                    Text("·").font(AppFont.caption()).foregroundColor(.secondary)
                    Text("\(mins) \(NSLocalizedString("training.minutes_unit", comment: "min"))")
                        .font(AppFont.bodySmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
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
