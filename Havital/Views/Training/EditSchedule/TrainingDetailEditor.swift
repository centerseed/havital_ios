import SwiftUI

// MARK: - 編輯狀態管理（ObservableObject 作為唯一資料源）

/// 訓練日編輯狀態 - 使用 class 確保 reference semantics
final class TrainingDayEditState: ObservableObject {
    // 基本資訊
    @Published var dayIndex: String
    @Published var dayTarget: String
    @Published var trainingType: String

    // 通用欄位
    @Published var distance: Double
    @Published var pace: String

    // 間歇跑欄位
    @Published var repeats: Int
    @Published var workPace: String
    @Published var workDistance: Double
    @Published var workTimeMinutes: Double  // 時間制間歇的工作段時間（分鐘）- 用於挪威4x4等
    @Published var isTimeBased: Bool  // 是否為時間制間歇（vs 距離制）
    @Published var recoveryPace: String
    @Published var recoveryDistance: Double
    @Published var recoveryTimeMinutes: Double  // 原地休息的時間（分鐘，支援 0.5 增量）
    @Published var isRestInPlace: Bool

    // 組合跑欄位
    @Published var segments: [EditableSegment]

    // 暖跑/緩和跑欄位
    @Published var hasWarmup: Bool
    @Published var warmupDistance: Double
    @Published var warmupPace: String
    @Published var hasCooldown: Bool
    @Published var cooldownDistance: Double
    @Published var cooldownPace: String

    // 描述
    @Published var description: String?

    init(from day: MutableTrainingDay) {
        self.dayIndex = day.dayIndex
        self.dayTarget = day.dayTarget
        self.trainingType = day.trainingType
        self.description = day.trainingDetails?.description

        let details = day.trainingDetails

        // 通用欄位
        self.distance = details?.distanceKm ?? details?.totalDistanceKm ?? 5.0
        self.pace = details?.pace ?? ""

        // 間歇跑欄位
        self.repeats = details?.repeats ?? 4
        self.workPace = details?.work?.pace ?? ""
        self.workDistance = details?.work?.distanceKm ?? 0.4
        self.workTimeMinutes = details?.work?.timeMinutes ?? 4.0
        // 判斷是否為時間制間歇：有 timeMinutes 且 distanceKm 為空或 0
        let workHasTime = details?.work?.timeMinutes != nil && details!.work!.timeMinutes! > 0
        let workHasDistance = details?.work?.distanceKm != nil && details!.work!.distanceKm! > 0
        self.isTimeBased = workHasTime && !workHasDistance

        // 判斷是否為原地休息：有 timeMinutes 或 timeSeconds，但沒有 distanceKm（或為 0）
        let recovery = details?.recovery
        let hasTimeMinutes = recovery?.timeMinutes != nil && recovery!.timeMinutes! > 0
        let hasTimeSeconds = recovery?.timeSeconds != nil && recovery!.timeSeconds! > 0
        let hasTime = hasTimeMinutes || hasTimeSeconds  // 有時間就視為有時間
        let hasDistance = recovery?.distanceKm != nil && recovery!.distanceKm! > 0
        let isRest = hasTime && !hasDistance
        self.isRestInPlace = isRest

        // 恢復段參數：優先用 timeSeconds（精確值），沒有則用 timeMinutes
        self.recoveryPace = recovery?.pace ?? "6:00"
        self.recoveryDistance = recovery?.distanceKm ?? 0.2
        if let seconds = recovery?.timeSeconds {
            // 優先用秒數，轉換為分鐘（精確值）
            self.recoveryTimeMinutes = Double(seconds) / 60.0
        } else {
            // 備選用分鐘
            self.recoveryTimeMinutes = recovery?.timeMinutes ?? 2.0
        }

        // 組合跑欄位
        if let segs = details?.segments {
            self.segments = segs.map { EditableSegment(from: $0) }
        } else {
            self.segments = [EditableSegment(pace: "6:00", distance: 2.0)]
        }

        // 暖跑/緩和跑欄位
        if let w = day.warmup {
            self.hasWarmup = true
            self.warmupDistance = w.distanceKm ?? 2.0
            self.warmupPace = w.pace ?? "6:30"
        } else {
            self.hasWarmup = false
            self.warmupDistance = 2.0
            self.warmupPace = "6:30"
        }
        if let c = day.cooldown {
            self.hasCooldown = true
            self.cooldownDistance = c.distanceKm ?? 1.0
            self.cooldownPace = c.pace ?? "6:30"
        } else {
            self.hasCooldown = false
            self.cooldownDistance = 1.0
            self.cooldownPace = "6:30"
        }
    }

    var type: DayType {
        DayType(rawValue: trainingType) ?? .rest
    }

    var totalSegmentDistance: Double {
        segments.reduce(0) { $0 + $1.distance }
    }

    /// 判斷當前訓練類型是否需要暖跑/緩和跑
    var needsWarmupCooldown: Bool {
        let noWarmupTypes: Set<DayType> = [
            .easyRun, .easy, .recovery_run, .lsd, .rest,
            .strength, .crossTraining, .yoga, .hiking, .cycling,
            .swimming, .elliptical, .rowing
        ]
        return !noWarmupTypes.contains(type)
    }

    /// 轉換回 MutableTrainingDay
    func toMutableTrainingDay(originalDay: MutableTrainingDay) -> MutableTrainingDay {
        var result = originalDay
        result.dayIndex = dayIndex
        result.dayTarget = dayTarget
        result.trainingType = trainingType

        // 根據訓練類型建立 trainingDetails
        switch type {
        case .rest:
            result.trainingDetails = nil

        case .easyRun, .easy, .recovery_run, .lsd:
            result.trainingDetails = MutableTrainingDetails(
                description: description,
                distanceKm: distance,
                pace: pace.isEmpty ? nil : pace
            )

        case .tempo, .threshold, .longRun, .racePace:
            // 節奏/閾值/長跑/比賽配速跑
            result.trainingDetails = MutableTrainingDetails(
                description: description,
                distanceKm: distance,
                pace: pace.isEmpty ? nil : pace
            )

        // 間歇訓練類型（包含新增的大步跑、山坡重複跑、巡航間歇）
        case .interval, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval:
            let work = MutableWorkoutSegment(
                description: nil,
                distanceKm: workDistance,
                distanceM: workDistance * 1000,  // 確保 distanceM 與 distanceKm 一致
                timeMinutes: nil,
                pace: workPace.isEmpty ? nil : workPace,
                heartRateRange: nil
            )

            // 原地休息：只設置 timeSeconds
            // 主動恢復：設置 distanceKm 和 pace
            let recovery: MutableWorkoutSegment
            if isRestInPlace {
                // 從分鐘轉換為秒數（只發送秒數給後端）
                let timeSeconds = Int(round(recoveryTimeMinutes * 60))
                recovery = MutableWorkoutSegment(
                    description: "原地休息\(formatRecoveryTime(recoveryTimeMinutes))",
                    distanceKm: nil,
                    distanceM: nil,
                    timeMinutes: nil,      // 不發送給後端
                    timeSeconds: timeSeconds,  // 精確秒數
                    pace: nil,
                    heartRateRange: nil
                )
            } else {
                recovery = MutableWorkoutSegment(
                    description: nil,
                    distanceKm: recoveryDistance,
                    distanceM: recoveryDistance * 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: recoveryPace.isEmpty ? nil : recoveryPace,
                    heartRateRange: nil
                )
                Logger.debug("[原地休息] 保存間歇跑 - 主動恢復: distanceKm=\(recoveryDistance), distanceM=\(recoveryDistance * 1000), pace=\(recoveryPace)")
            }

            result.trainingDetails = MutableTrainingDetails(
                description: description,
                work: work,
                recovery: recovery,
                repeats: repeats
            )

        // 時間制間歇訓練：挪威4x4、亞索800
        case .norwegian4x4, .yasso800:
            // 時間制間歇：使用 timeMinutes 而非 distanceKm
            let work: MutableWorkoutSegment
            if isTimeBased {
                work = MutableWorkoutSegment(
                    description: type == .norwegian4x4 ? "高強度跑（92% VO2max）" : "亞索800",
                    distanceKm: nil,
                    distanceM: nil,
                    timeMinutes: workTimeMinutes,
                    pace: workPace.isEmpty ? nil : workPace,
                    heartRateRange: nil
                )
            } else {
                work = MutableWorkoutSegment(
                    description: nil,
                    distanceKm: workDistance,
                    distanceM: workDistance * 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: workPace.isEmpty ? nil : workPace,
                    heartRateRange: nil
                )
            }

            // 原地休息：只設置 timeSeconds
            // 恢復跑：挪威4x4 使用 timeMinutes + pace，亞索800 使用 distanceKm + pace
            let recovery: MutableWorkoutSegment
            if isRestInPlace {
                // 從分鐘轉換為秒數（只發送秒數給後端）
                let timeSeconds = Int(round(recoveryTimeMinutes * 60))
                recovery = MutableWorkoutSegment(
                    description: "原地休息\(formatRecoveryTime(recoveryTimeMinutes))",
                    distanceKm: nil,
                    distanceM: nil,
                    timeMinutes: nil,      // 不發送給後端
                    timeSeconds: timeSeconds,  // 精確秒數
                    pace: nil,
                    heartRateRange: nil
                )
            } else if type == .norwegian4x4 {
                // 挪威4x4：時間制恢復跑，同時設置 timeSeconds
                let timeSeconds = Int(round(recoveryTimeMinutes * 60))
                let recoveryDistanceM = calculateDistanceMeters(pace: recoveryPace, timeMinutes: recoveryTimeMinutes)
                let recoveryDistanceKm = recoveryDistanceM.map { $0 / 1000.0 }  // 確保 distanceKm 與 distanceM 一致
                recovery = MutableWorkoutSegment(
                    description: "恢復跑\(formatRecoveryTime(recoveryTimeMinutes))",
                    distanceKm: recoveryDistanceKm,
                    distanceM: recoveryDistanceM,
                    timeMinutes: recoveryTimeMinutes,
                    timeSeconds: timeSeconds,  // 同時設置秒數
                    pace: recoveryPace.isEmpty ? nil : recoveryPace,
                    heartRateRange: nil
                )
                Logger.debug("[恢復跑] 保存挪威4x4 - 恢復跑: timeMinutes=\(recoveryTimeMinutes), timeSeconds=\(timeSeconds), distanceKm=\(recoveryDistanceKm ?? 0), distanceM=\(recoveryDistanceM ?? 0), pace=\(recoveryPace)")
            } else {
                // 亞索800 等：距離制恢復跑
                recovery = MutableWorkoutSegment(
                    description: nil,
                    distanceKm: recoveryDistance,
                    distanceM: recoveryDistance * 1000,  // 確保 distanceM 與 distanceKm 一致
                    timeMinutes: nil,
                    pace: recoveryPace.isEmpty ? nil : recoveryPace,
                    heartRateRange: nil
                )
                Logger.debug("[恢復跑] 保存亞索800 - 恢復跑: distanceKm=\(recoveryDistance), distanceM=\(recoveryDistance * 1000), pace=\(recoveryPace)")
            }

            result.trainingDetails = MutableTrainingDetails(
                description: description,
                work: work,
                recovery: recovery,
                repeats: repeats
            )

        // 組合訓練類型（包含新增的法特雷克、快結尾長跑）
        case .combination, .progression, .fartlek, .fastFinish:
            let mutableSegments = segments.map { seg in
                MutableProgressionSegment(
                    distanceKm: seg.distance,
                    pace: seg.pace.isEmpty ? nil : seg.pace,
                    description: seg.description
                )
            }
            result.trainingDetails = MutableTrainingDetails(
                description: description,
                totalDistanceKm: totalSegmentDistance,
                segments: mutableSegments
            )

        default:
            result.trainingDetails = MutableTrainingDetails(
                description: description,
                distanceKm: distance
            )
        }

        // Write back warmup/cooldown
        if needsWarmupCooldown {
            result.warmup = hasWarmup ? RunSegment(
                distanceKm: warmupDistance,
                distanceM: nil,
                distanceDisplay: nil,
                distanceUnit: nil,
                durationMinutes: nil,
                durationSeconds: nil,
                pace: warmupPace.isEmpty ? nil : warmupPace,
                heartRateRange: nil,
                intensity: "easy",
                description: "暖跑"
            ) : nil
            result.cooldown = hasCooldown ? RunSegment(
                distanceKm: cooldownDistance,
                distanceM: nil,
                distanceDisplay: nil,
                distanceUnit: nil,
                durationMinutes: nil,
                durationSeconds: nil,
                pace: cooldownPace.isEmpty ? nil : cooldownPace,
                heartRateRange: nil,
                intensity: "easy",
                description: "緩和跑"
            ) : nil
        } else {
            result.warmup = nil
            result.cooldown = nil
        }

        return result
    }

    func addSegment(defaultPace: String) {
        segments.append(EditableSegment(pace: defaultPace, distance: 2.0))
    }

    func removeSegment(at index: Int) {
        guard segments.count > 1, index < segments.count else { return }
        segments.remove(at: index)
    }

    // MARK: - Helper Functions

    /// 根據配速和時間計算距離（公尺），四捨五入到指定單位
    private func calculateDistanceMeters(pace: String, timeMinutes: Double, roundTo: Double = 100.0) -> Double? {
        guard let distanceKm = calculateDistanceFromPace(pace: pace, timeMinutes: timeMinutes) else {
            return nil
        }
        let meters = distanceKm * 1000.0
        return round(meters / roundTo) * roundTo
    }

    /// 根據配速和時間計算距離（公里）
    private func calculateDistanceFromPace(pace: String, timeMinutes: Double) -> Double? {
        // 解析配速格式 "mm:ss"
        let components = pace.split(separator: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return nil
        }

        let paceInMinutes = minutes + seconds / 60.0
        guard paceInMinutes > 0 else { return nil }

        // 距離 = 時間 / 配速
        return timeMinutes / paceInMinutes
    }

    /// 格式化恢復時間顯示（支援 1 秒精度）
    /// - Parameter minutes: 時間（分鐘，例如 2.5 表示 2 分 30 秒）
    /// - Returns: 格式化字串，例如 "2分30秒" 或 "3分鐘" 或 "45秒"
    func formatRecoveryTime(_ minutes: Double) -> String {
        let totalSeconds = Int(round(minutes * 60))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60

        if mins == 0 {
            return "\(secs)秒"
        } else if secs == 0 {
            return "\(mins)分鐘"
        } else {
            return "\(mins)分\(secs)秒"
        }
    }
}

struct EditableSegment: Identifiable, Equatable {
    let id = UUID()
    var pace: String
    var distance: Double
    var description: String?

    init(pace: String, distance: Double, description: String? = nil) {
        self.pace = pace
        self.distance = distance
        self.description = description
    }

    init(from segment: MutableProgressionSegment) {
        self.pace = segment.pace ?? ""
        self.distance = segment.distanceKm ?? 2.0
        self.description = segment.description
    }
}

// MARK: - 主編輯頁面

struct TrainingEditSheetV2: View {
    let originalDay: MutableTrainingDay
    let onSave: (MutableTrainingDay) -> Void
    let paceHelper: PaceCalculationHelper

    @StateObject private var editState: TrainingDayEditState
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaceTable = false

    init(day: MutableTrainingDay, onSave: @escaping (MutableTrainingDay) -> Void, paceHelper: PaceCalculationHelper) {
        self.originalDay = day
        self.onSave = onSave
        self.paceHelper = paceHelper
        self._editState = StateObject(wrappedValue: TrainingDayEditState(from: day))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 標題區域
                    headerSection

                    // 根據類型顯示編輯器
                    editorSection

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle(L10n.EditSchedule.editTraining.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.EditSchedule.cancel.localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if let _ = paceHelper.currentVDOT, !paceHelper.calculatedPaces.isEmpty {
                            Button {
                                showingPaceTable = true
                            } label: {
                                Image(systemName: "speedometer")
                            }
                        }

                        Button(L10n.EditSchedule.save.localized) {
                            saveAndDismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingPaceTable) {
                if let vdot = paceHelper.currentVDOT {
                    PaceTableView(vdot: vdot, calculatedPaces: paceHelper.calculatedPaces)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(editState.type.localizedName)
                .font(AppFont.title2())
                .fontWeight(.bold)
                .foregroundColor(typeColor)

            Text(editState.dayTarget)
                .font(AppFont.body())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var editorSection: some View {
        switch editState.type {
        case .easyRun, .easy, .recovery_run, .lsd:
            EasyRunEditorV2(editState: editState, paceHelper: paceHelper)
        case .tempo, .threshold, .racePace:
            // 節奏/閾值/比賽配速跑 - 需要配速和距離
            TempoEditorV2(editState: editState, paceHelper: paceHelper)
            WarmupCooldownEditorV2(editState: editState)
        case .norwegian4x4:
            // 挪威4x4 專屬編輯器
            Norwegian4x4EditorV2(editState: editState, paceHelper: paceHelper)
            WarmupCooldownEditorV2(editState: editState)
        case .yasso800:
            // 亞索800 專屬編輯器
            Yasso800EditorV2(editState: editState, paceHelper: paceHelper)
            WarmupCooldownEditorV2(editState: editState)
        case .interval, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval:
            // 一般間歇訓練類型（大步跑、山坡重複跑、巡航間歇）
            IntervalEditorV2(editState: editState, paceHelper: paceHelper)
            WarmupCooldownEditorV2(editState: editState)
        case .combination, .progression, .fartlek, .fastFinish:
            // 組合訓練類型（包含新增的法特雷克、快結尾長跑）
            CombinationEditorV2(editState: editState, paceHelper: paceHelper)
            WarmupCooldownEditorV2(editState: editState)
        case .longRun:
            LongRunEditorV2(editState: editState, paceHelper: paceHelper)
            WarmupCooldownEditorV2(editState: editState)
        default:
            SimpleEditorV2(editState: editState, paceHelper: paceHelper)
        }
    }

    private var typeColor: Color {
        switch editState.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .green
        case .interval, .tempo, .progression, .threshold, .combination,
             .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval, .norwegian4x4, .yasso800:
            // 間歇/強度訓練類型
            return .orange
        case .longRun, .hiking, .cycling, .fastFinish:
            // 長跑類型（包含快結尾長跑）
            return .blue
        case .race, .racePace:
            // 比賽/比賽配速訓練
            return .red
        case .fartlek:
            // 法特雷克 - 較自由的變速跑
            return .purple
        case .rest:
            return .gray
        case .crossTraining, .strength, .swimming, .elliptical, .rowing:
            return .purple
        }
    }

    private func saveAndDismiss() {
        let updatedDay = editState.toMutableTrainingDay(originalDay: originalDay)
        onSave(updatedDay)
        dismiss()
    }
}

// MARK: - 輕鬆跑編輯器

struct EasyRunEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.easyRunSettings.localized)
                .font(AppFont.headline())
                .foregroundColor(.green)

            // 建議配速
            if let suggestedPace = paceHelper.getSuggestedPace(for: editState.trainingType) {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: paceHelper.getPaceRange(for: editState.trainingType),
                    onApply: { editState.pace = suggestedPace }
                )
            }

            // 距離選擇
            DistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distance: $editState.distance)

            // 描述
            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 節奏跑編輯器

struct TempoEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.tempoRunSettings.localized)
                .font(AppFont.headline())
                .foregroundColor(.orange)

            // 建議配速
            if let suggestedPace = paceHelper.getSuggestedPace(for: editState.trainingType) {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: paceHelper.getPaceRange(for: editState.trainingType),
                    onApply: { editState.pace = suggestedPace }
                )
            }

            HStack(spacing: 16) {
                PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $editState.pace, referenceDistance: editState.distance)
                DistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distance: $editState.distance)
            }

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            // 自動填充建議配速
            if editState.pace.isEmpty, let suggested = paceHelper.getSuggestedPace(for: editState.trainingType) {
                editState.pace = suggested
            }
        }
    }
}

// MARK: - 間歇跑編輯器

struct IntervalEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    @State private var selectedTemplate: Int? = nil

    private let templates = [
        (name: "400m × 8", repeats: 8, distanceM: 400),
        (name: "400m × 10", repeats: 10, distanceM: 400),
        (name: "800m × 5", repeats: 5, distanceM: 800),
        (name: "800m × 6", repeats: 6, distanceM: 800),
        (name: "1000m × 4", repeats: 4, distanceM: 1000),
        (name: "1000m × 5", repeats: 5, distanceM: 1000),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.intervalSettings.localized)
                .font(AppFont.headline())
                .foregroundColor(.orange)

            // 快速選擇模板
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates.indices, id: \.self) { index in
                        Button {
                            applyTemplate(index)
                        } label: {
                            Text(templates[index].name)
                                .font(AppFont.caption())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTemplate == index ? Color.orange : Color.orange.opacity(0.15))
                                .foregroundColor(selectedTemplate == index ? .white : .orange)
                                .cornerRadius(16)
                        }
                    }
                }
            }

            // 建議配速
            if let suggestedPace = paceHelper.getSuggestedPace(for: editState.trainingType) {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: paceHelper.getPaceRange(for: editState.trainingType),
                    onApply: { editState.workPace = suggestedPace }
                )
            }

            // 重複次數
            RepeatsPickerFieldV2(title: L10n.EditSchedule.repeats.localized, repeats: $editState.repeats)

            // 衝刺段
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text(L10n.EditSchedule.sprintSegment.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                }

                HStack(spacing: 16) {
                    PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $editState.workPace, referenceDistance: editState.workDistance)
                    IntervalDistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distanceKm: $editState.workDistance)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // 恢復段
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text(L10n.EditSchedule.recoverySegment.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                }

                Toggle(L10n.EditSchedule.restInPlace.localized, isOn: $editState.isRestInPlace)

                if editState.isRestInPlace {
                    // 原地休息：顯示時間選擇器
                    RestTimePickerFieldV2(title: "休息時間", timeMinutes: $editState.recoveryTimeMinutes)
                } else {
                    // 主動恢復：顯示配速和距離
                    HStack(spacing: 16) {
                        PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $editState.recoveryPace, referenceDistance: editState.recoveryDistance)
                        IntervalDistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distanceKm: $editState.recoveryDistance)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            if editState.workPace.isEmpty, let suggested = paceHelper.getSuggestedPace(for: editState.trainingType) {
                editState.workPace = suggested
            }
        }
    }

    private func applyTemplate(_ index: Int) {
        let template = templates[index]
        selectedTemplate = index
        editState.repeats = template.repeats
        editState.workDistance = Double(template.distanceM) / 1000.0
        editState.isRestInPlace = true

        if let suggested = paceHelper.getSuggestedPace(for: editState.trainingType) {
            editState.workPace = suggested
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - 挪威4x4 專屬編輯器

struct Norwegian4x4EditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題：挪威4x4訓練設定（不是通用的「間歇訓練設定」）
            HStack {
                Text("🇳🇴")
                    .font(AppFont.title2())
                Text(L10n.EditSchedule.norwegian4x4Settings.localized)
                    .font(AppFont.headline())
                    .foregroundColor(.orange)
            }

            // 訓練說明
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.EditSchedule.norwegian4x4Description.localized)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // 建議配速（使用 92% VO2max）
            if let vdot = paceHelper.currentVDOT {
                let suggestedPace = PaceCalculator.getPaceForPercentage(0.92, vdot: vdot)
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: nil,
                    onApply: { editState.workPace = suggestedPace }
                )
            }

            // 重複次數（固定為 4 組，但可調整）
            RepeatsPickerFieldV2(title: L10n.EditSchedule.repeats.localized, repeats: $editState.repeats)

            // 工作段（時間制：4 分鐘）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text(L10n.EditSchedule.sprintSegment.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                }

                HStack(spacing: 16) {
                    PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $editState.workPace, referenceDistance: nil)
                    WorkTimePickerFieldV2(title: L10n.EditSchedule.time.localized, timeMinutes: $editState.workTimeMinutes)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // 恢復段（恢復跑 3 分鐘，60-70% 最大心率）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text(L10n.EditSchedule.recoverySegment.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                    Spacer()
                    Text("恢復跑")
                        .font(AppFont.caption())
                        .foregroundColor(.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.mint.opacity(0.2))
                        .cornerRadius(4)
                }

                HStack(spacing: 16) {
                    // 恢復跑時間
                    RestTimePickerFieldV2(title: L10n.EditSchedule.time.localized, timeMinutes: $editState.recoveryTimeMinutes)
                    // 恢復跑配速
                    PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $editState.recoveryPace, referenceDistance: nil)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            // 初始化挪威4x4預設值
            editState.isTimeBased = true
            editState.isRestInPlace = false  // 挪威4x4 使用恢復跑，不是原地休息
            if editState.repeats == 0 || editState.repeats == 4 {
                editState.repeats = 4
            }
            if editState.workTimeMinutes == 0 {
                editState.workTimeMinutes = 4.0
            }
            if editState.recoveryTimeMinutes == 0 {
                editState.recoveryTimeMinutes = 3.0
            }
            // 設置 92% VO2max 配速
            if editState.workPace.isEmpty, let vdot = paceHelper.currentVDOT {
                editState.workPace = PaceCalculator.getPaceForPercentage(0.92, vdot: vdot)
            }
            // 設置恢復跑配速
            if editState.recoveryPace.isEmpty, let vdot = paceHelper.currentVDOT {
                editState.recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            }
        }
    }
}

// MARK: - 亞索800 專屬編輯器

struct Yasso800EditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 標題：亞索800訓練設定
            Text(L10n.EditSchedule.yasso800Settings.localized)
                .font(AppFont.headline())
                .foregroundColor(.orange)

            // 訓練說明
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.EditSchedule.yasso800Description.localized)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // 建議配速（間歇配速）
            if let suggestedPace = paceHelper.getSuggestedPace(for: "interval") {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: paceHelper.getPaceRange(for: "interval"),
                    onApply: { editState.workPace = suggestedPace }
                )
            }

            // 重複次數（通常 10 組）
            RepeatsPickerFieldV2(title: L10n.EditSchedule.repeats.localized, repeats: $editState.repeats)

            // 工作段（固定 800m）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text(L10n.EditSchedule.sprintSegment.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                    Spacer()
                    Text("800m")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }

                PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $editState.workPace, referenceDistance: 0.8)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // 恢復段（400m 慢跑或原地休息）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text(L10n.EditSchedule.recoverySegment.localized)
                        .font(AppFont.bodySmall())
                        .fontWeight(.medium)
                }

                Toggle(L10n.EditSchedule.restInPlace.localized, isOn: $editState.isRestInPlace)

                if editState.isRestInPlace {
                    RestTimePickerFieldV2(title: L10n.EditSchedule.restTime.localized, timeMinutes: $editState.recoveryTimeMinutes)
                } else {
                    HStack {
                        Text("400m 慢跑恢復")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            // 初始化亞索800預設值
            editState.isTimeBased = false
            editState.workDistance = 0.8  // 800m
            if editState.repeats == 0 {
                editState.repeats = 10
            }
            if editState.recoveryDistance == 0 {
                editState.recoveryDistance = 0.4  // 400m
            }
            if editState.recoveryTimeMinutes == 0 {
                editState.recoveryTimeMinutes = 3.0
            }
            // 設置間歇配速
            if editState.workPace.isEmpty, let suggested = paceHelper.getSuggestedPace(for: "interval") {
                editState.workPace = suggested
            }
        }
    }
}

// MARK: - 工作段時間選擇器（用於時間制間歇）

struct WorkTimePickerFieldV2: View {
    let title: String
    @Binding var timeMinutes: Double
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(String(format: "%.0f 分鐘", timeMinutes))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingPicker) {
                WorkTimeWheelPicker(selectedTimeMinutes: $timeMinutes)
                    .presentationDetents([.height(320)])
            }
        }
    }
}

struct WorkTimeWheelPicker: View {
    @Binding var selectedTimeMinutes: Double
    @Environment(\.dismiss) private var dismiss

    private let timeOptions: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("工作時間", selection: $selectedTimeMinutes) {
                    ForEach(timeOptions, id: \.self) { minutes in
                        Text("\(Int(minutes)) 分鐘").tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
            }
            .navigationTitle("選擇工作時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - 組合跑編輯器

struct CombinationEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.combinationSettings.localized)
                .font(AppFont.headline())
                .foregroundColor(.orange)

            // 分段列表
            ForEach(editState.segments.indices, id: \.self) { index in
                SegmentEditorRowV2(
                    index: index,
                    segment: $editState.segments[index],
                    canDelete: editState.segments.count > 1,
                    onDelete: { editState.removeSegment(at: index) }
                )
            }

            // 新增分段按鈕
            Button {
                let defaultPace = paceHelper.getSuggestedPace(for: "easy") ?? "6:00"
                editState.addSegment(defaultPace: defaultPace)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(L10n.EditSchedule.addSegment.localized)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }

            // 總距離
            HStack {
                Text(L10n.EditSchedule.totalDistance.localized)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f km", editState.totalSegmentDistance))
                    .font(AppFont.title3())
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SegmentEditorRowV2: View {
    let index: Int
    @Binding var segment: EditableSegment
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: L10n.EditSchedule.segment.localized, index + 1))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                if let desc = segment.description, !desc.isEmpty {
                    Text(desc)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                }

                Spacer()

                if canDelete {
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }

            HStack(spacing: 16) {
                PacePickerFieldV2(title: L10n.EditSchedule.pace.localized, pace: $segment.pace, referenceDistance: segment.distance)
                DistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distance: $segment.distance)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 長跑編輯器

struct LongRunEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.longRunSettings.localized)
                .font(AppFont.headline())
                .foregroundColor(.blue)

            DistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distance: $editState.distance)

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 簡單訓練編輯器

struct SimpleEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var paceHelper: PaceCalculationHelper

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.trainingSettings.localized)
                .font(AppFont.headline())
                .foregroundColor(.blue)

            if editState.type != .rest {
                DistancePickerFieldV2(title: L10n.EditSchedule.distance.localized, distance: $editState.distance)
            }

            if let desc = editState.description, !desc.isEmpty {
                DescriptionViewV2(description: desc)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 暖跑/緩和跑編輯器

struct WarmupCooldownEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("暖跑 / 緩和跑")
                .font(AppFont.headline())
                .foregroundColor(.orange)

            // 暖跑
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $editState.hasWarmup) {
                    HStack(spacing: 6) {
                        Text("🔥")
                        Text("暖跑")
                            .font(AppFont.bodySmall())
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }

                if editState.hasWarmup {
                    HStack(spacing: 16) {
                        DistancePickerFieldV2(title: "距離", distance: $editState.warmupDistance)
                        PacePickerFieldV2(title: "配速", pace: $editState.warmupPace, referenceDistance: editState.warmupDistance)
                    }

                    let estimatedMinutes = estimateDuration(distanceKm: editState.warmupDistance, pace: editState.warmupPace)
                    if let mins = estimatedMinutes {
                        Text("預估時間：約 \(Int(mins)) 分鐘")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(8)

            // 緩和跑
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $editState.hasCooldown) {
                    HStack(spacing: 6) {
                        Text("❄️")
                        Text("緩和跑")
                            .font(AppFont.bodySmall())
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }

                if editState.hasCooldown {
                    HStack(spacing: 16) {
                        DistancePickerFieldV2(title: "距離", distance: $editState.cooldownDistance)
                        PacePickerFieldV2(title: "配速", pace: $editState.cooldownPace, referenceDistance: editState.cooldownDistance)
                    }

                    let estimatedMinutes = estimateDuration(distanceKm: editState.cooldownDistance, pace: editState.cooldownPace)
                    if let mins = estimatedMinutes {
                        Text("預估時間：約 \(Int(mins)) 分鐘")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.08))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func estimateDuration(distanceKm: Double, pace: String) -> Double? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let mins = Double(parts[0]),
              let secs = Double(parts[1]) else { return nil }
        let paceMinPerKm = mins + secs / 60.0
        guard paceMinPerKm > 0 else { return nil }
        return distanceKm * paceMinPerKm
    }
}

// MARK: - Picker 欄位元件 (V2 版本，直接使用 @Binding)

struct DistancePickerFieldV2: View {
    let title: String
    @Binding var distance: Double
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(String(format: "%.1f km", distance))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingPicker) {
                DistanceWheelPicker(selectedDistance: $distance)
                    .presentationDetents([.height(320)])
            }
        }
    }
}

struct PacePickerFieldV2: View {
    let title: String
    @Binding var pace: String
    var referenceDistance: Double? = nil
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(pace.isEmpty ? "--:--" : "\(pace) /km")
                        .foregroundColor(pace.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingPicker) {
                PaceWheelPicker(selectedPace: $pace, referenceDistance: referenceDistance)
                    .presentationDetents([.height(referenceDistance != nil ? 380 : 320)])
            }
        }
    }
}

struct RepeatsPickerFieldV2: View {
    let title: String
    @Binding var repeats: Int
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text("\(repeats) ×")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingPicker) {
                RepeatsWheelPicker(selectedRepeats: $repeats)
                    .presentationDetents([.height(320)])
            }
        }
    }
}

struct IntervalDistancePickerFieldV2: View {
    let title: String
    @Binding var distanceKm: Double
    @State private var showingPicker = false

    private var displayText: String {
        let meters = Int(distanceKm * 1000)
        return "\(meters)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingPicker) {
                IntervalDistanceWheelPicker(selectedDistanceKm: $distanceKm)
                    .presentationDetents([.height(320)])
            }
        }
    }
}

struct RestTimePickerFieldV2: View {
    let title: String
    @Binding var timeMinutes: Double
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(formatTime(timeMinutes))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.caption())
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .sheet(isPresented: $showingPicker) {
                RestTimeWheelPicker(selectedTimeMinutes: $timeMinutes)
                    .presentationDetents([.height(420)])
            }
        }
    }

    /// 格式化時間顯示（支援 1 秒精度）
    private func formatTime(_ minutes: Double) -> String {
        let totalSeconds = Int(round(minutes * 60))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60

        if mins == 0 {
            return "\(secs) 秒"
        } else if secs == 0 {
            return "\(mins) 分鐘"
        } else {
            return "\(mins) 分 \(secs) 秒"
        }
    }
}

struct RestTimeWheelPicker: View {
    @Binding var selectedTimeMinutes: Double
    @Environment(\.dismiss) private var dismiss

    // 內部狀態：分鐘和秒分開管理
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    // 可選範圍：0-10 分鐘，0-59 秒
    private let minuteOptions = Array(0...10)
    private let secondOptions = Array(0..<60)

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 當前選擇時間顯示
                Text(formatTime(Double(minutes) + Double(seconds) / 60.0))
                    .font(AppFont.title1())
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 8)

                // 雙輪選擇器
                HStack(spacing: 0) {
                    // 分鐘選擇器
                    Picker("分鐘", selection: $minutes) {
                        ForEach(minuteOptions, id: \.self) { min in
                            Text("\(min)").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()

                    Text("分")
                        .font(AppFont.body())
                        .foregroundColor(.secondary)
                        .frame(width: 30)

                    // 秒選擇器
                    Picker("秒", selection: $seconds) {
                        ForEach(secondOptions, id: \.self) { sec in
                            Text(String(format: "%02d", sec)).tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()

                    Text("秒")
                        .font(AppFont.body())
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
                .frame(height: 180)

                // 快速選擇按鈕
                VStack(spacing: 8) {
                    Text("快速選擇")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        QuickSelectButton(label: "30秒", action: { setTime(0, 30) })
                        QuickSelectButton(label: "1分", action: { setTime(1, 0) })
                        QuickSelectButton(label: "1分30秒", action: { setTime(1, 30) })
                        QuickSelectButton(label: "2分", action: { setTime(2, 0) })
                        QuickSelectButton(label: "3分", action: { setTime(3, 0) })
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("選擇休息時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 更新 binding 值
                        selectedTimeMinutes = Double(minutes) + Double(seconds) / 60.0
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // 初始化分鐘和秒的狀態
                let totalSeconds = Int(round(selectedTimeMinutes * 60))
                minutes = totalSeconds / 60
                seconds = totalSeconds % 60
            }
        }
    }

    private func setTime(_ mins: Int, _ secs: Int) {
        minutes = mins
        seconds = secs
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 格式化時間顯示（支援 1 秒精度）
    private func formatTime(_ totalMinutes: Double) -> String {
        let totalSeconds = Int(round(totalMinutes * 60))
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60

        if mins == 0 {
            return "\(secs) 秒"
        } else if secs == 0 {
            return "\(mins) 分鐘"
        } else {
            return "\(mins) 分 \(secs) 秒"
        }
    }
}

// MARK: - 快速選擇按鈕元件
private struct QuickSelectButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.caption())
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(16)
        }
    }
}

// MARK: - 共用元件

struct SuggestedPaceViewV2: View {
    let pace: String
    let paceRange: (min: String, max: String)?
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(AppFont.caption())

                Text(String(format: L10n.EditSchedule.suggestedPace.localized, pace))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)

                Spacer()

                Button(L10n.EditSchedule.apply.localized) {
                    onApply()
                }
                .font(AppFont.caption())
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if let range = paceRange {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.medium")
                        .font(AppFont.captionSmall())
                        .foregroundColor(.secondary)

                    Text(String(format: L10n.EditSchedule.paceRange.localized, range.max, range.min))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DescriptionViewV2: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.EditSchedule.description.localized)
                .font(AppFont.bodySmall())
                .fontWeight(.medium)

            Text(description)
                .font(AppFont.body())
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }
}
