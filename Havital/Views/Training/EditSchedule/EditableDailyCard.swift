import SwiftUI

// MARK: - Training Details Edit View

struct TrainingDetailsEditView: View {
    let day: MutableTrainingDay
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        if let details = day.trainingDetails {
            switch day.type {
            case .easyRun, .easy, .recovery_run, .lsd:
                EasyRunEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .norwegian4x4:
                // 挪威4x4 專用卡片
                Norwegian4x4CardView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .yasso800:
                // 亞索800 專用卡片
                Yasso800CardView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .interval, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval:
                // 一般間歇訓練類型（大步跑、山坡重複跑、巡航間歇、短間歇、長間歇）
                IntervalEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .tempo, .threshold, .longRun, .racePace:
                // 節奏/閾值/長跑類型（包含新增的比賽配速跑）
                TempoRunEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .progression, .combination, .fartlek, .fastFinish:
                // 組合訓練類型（包含新增的法特雷克、快結尾長跑）
                CombinationEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            default:
                SimpleTrainingEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            }
        }
    }
}

// MARK: - Individual Training Type Edit Views

struct EasyRunEditView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let distance = details.distanceKm {
                    EditableValueView(
                        title: NSLocalizedString("edit_schedule.distance_label", comment: "Distance"),
                        value: String(format: "%.1f", distance),
                        isEditable: isEditable,
                        valueType: .distance
                    ) { newValue in
                        updateDistance(Double(newValue) ?? distance)
                    }
                }

                Spacer()
            }
        }
    }

    private func updateDistance(_ newDistance: Double) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.distanceKm = newDistance
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }
}

struct TempoRunEditView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let pace = details.pace {
                    EditableValueView(
                        title: NSLocalizedString("edit_schedule.pace", comment: "Pace"),
                        value: pace,
                        isEditable: isEditable,
                        valueType: .pace
                    ) { newValue in
                        updatePace(newValue)
                    }
                }

                if let distance = details.distanceKm {
                    EditableValueView(
                        title: NSLocalizedString("edit_schedule.distance_label", comment: "Distance"),
                        value: String(format: "%.1f", distance),
                        isEditable: isEditable,
                        valueType: .distance
                    ) { newValue in
                        updateDistance(Double(newValue) ?? distance)
                    }
                }

                Spacer()
            }
        }
    }

    private func updatePace(_ newPace: String) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.pace = newPace
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }

    private func updateDistance(_ newDistance: Double) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.distanceKm = newDistance
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }
}

// MARK: - 挪威4x4 專用卡片

struct Norwegian4x4CardView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 標題行
            HStack {
                Text(NSLocalizedString("training.interval_type.norwegian_4x4", comment: "Norwegian 4x4"))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                if let repeats = details.repeats {
                    Text(String(format: NSLocalizedString("training.interval.repeats", comment: "Repeats"), repeats))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            // 訓練內容
            HStack(spacing: 12) {
                // 工作段
                if let work = details.work {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("training.interval.work_label.default", comment: "Sprint"))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            if let timeMinutes = work.timeMinutes {
                                Text("\(Int(timeMinutes)) " + NSLocalizedString("training.minutes_unit", comment: "min"))
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                            }
                            if let pace = work.pace {
                                Text("@ \(pace)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }

                // 恢復段
                if let recovery = details.recovery {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("edit_schedule.recovery", comment: "Recovery"))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            if let timeMinutes = recovery.timeMinutes {
                                Text("\(Int(timeMinutes)) " + NSLocalizedString("training.minutes_unit", comment: "min"))
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                            }
                            if let pace = recovery.pace {
                                Text("@ \(pace)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }

                Spacer()
            }
        }
    }
}

// MARK: - 亞索800 專用卡片

struct Yasso800CardView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 標題行
            HStack {
                Text(NSLocalizedString("training.interval_type.yasso_800", comment: "Yasso 800"))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                if let repeats = details.repeats {
                    Text(String(format: NSLocalizedString("training.interval.repeats", comment: "Repeats"), repeats))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            // 訓練內容
            HStack(spacing: 12) {
                // 工作段
                if let work = details.work {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("training.interval.work_label.default", comment: "Sprint"))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            // 顯示距離（優先 distanceM，否則 distanceKm）
                            if let distanceM = work.distanceM {
                                Text("\(Int(distanceM))m")
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                            } else if let distanceKm = work.distanceKm {
                                Text("\(Int(distanceKm * 1000))m")
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                            }
                            if let pace = work.pace {
                                Text("@ \(pace)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }

                // 恢復段
                if let recovery = details.recovery {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("edit_schedule.recovery", comment: "Recovery"))
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            if let timeMinutes = recovery.timeMinutes {
                                Text("\(Int(timeMinutes)) " + NSLocalizedString("training.minutes_unit", comment: "min"))
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                            }
                            if let pace = recovery.pace {
                                Text("@ \(pace)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }

                Spacer()
            }
        }
    }
}

struct IntervalEditView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("training.interval_type.interval", comment: "Interval Training"))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                if let repeats = details.repeats {
                    EditableValueView(
                        title: NSLocalizedString("edit_schedule.repeats", comment: "Repeats"),
                        value: "\(repeats) × ",
                        isEditable: isEditable,
                        valueType: .repeats
                    ) { newValue in
                        updateRepeats(Int(newValue) ?? repeats)
                    }
                }
            }

            Divider()
                .background(Color.orange.opacity(0.3))

            // 衝刺段
            if let work = details.work {
                IntervalSegmentEditView(
                    title: NSLocalizedString("edit_schedule.sprint_segment", comment: "Sprint segment"),
                    segment: work,
                    isEditable: isEditable,
                    color: .orange
                ) { updatedSegment in
                    updateWorkSegment(updatedSegment)
                }
            }

            // 恢復段
            if let recovery = details.recovery {
                IntervalSegmentEditView(
                    title: NSLocalizedString("edit_schedule.recovery_segment", comment: "Recovery segment"),
                    segment: recovery,
                    isEditable: isEditable,
                    color: .blue
                ) { updatedSegment in
                    updateRecoverySegment(updatedSegment)
                }
            } else {
                // recovery 為 nil 時顯示原地休息
                HStack(spacing: 8) {
                    Text(NSLocalizedString("edit_schedule.recovery_segment", comment: "Recovery Segment"))
                        .font(AppFont.caption())
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(NSLocalizedString("interval.static_rest", comment: "原地休息"))
                        .font(AppFont.caption())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
    }

    private func updateRepeats(_ newRepeats: Int) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.repeats = newRepeats
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }

    private func updateWorkSegment(_ segment: MutableWorkoutSegment) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.work = segment
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }

    private func updateRecoverySegment(_ segment: MutableWorkoutSegment) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.recovery = segment
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }
}

struct CombinationEditView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 顯示分段摘要（簡潔版，詳細編輯用右側按鈕）
            if let segments = details.segments, !segments.isEmpty {
                // 水平滾動顯示所有分段
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(segments.indices, id: \.self) { index in
                            if let segment = segments[safe: index] {
                                CombinationSegmentSummary(
                                    segmentIndex: index + 1,
                                    segment: segment
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 組合訓練分段摘要視圖（只讀）
struct CombinationSegmentSummary: View {
    let segmentIndex: Int
    let segment: MutableProgressionSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 分段描述或編號
            if let desc = segment.description, !desc.isEmpty {
                Text(desc)
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)
            }

            // 距離和配速
            HStack(spacing: 4) {
                if let distance = segment.distanceKm {
                    Text(String(format: "%.1fkm", distance))
                        .font(AppFont.caption())
                        .fontWeight(.medium)
                }
                if let pace = segment.pace {
                    Text("@\(pace)")
                        .font(AppFont.captionSmall())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

// 安全的數組索引存取
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct SimpleTrainingEditView: View {
    let day: MutableTrainingDay
    let details: MutableTrainingDetails
    let isEditable: Bool
    let onEdit: (MutableTrainingDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // 只有跑步活動才顯示距離（瑜珈、重訓、交叉訓練等不顯示）
                if day.type.isRunningActivity, let distance = details.distanceKm {
                    EditableValueView(
                        title: NSLocalizedString("edit_schedule.distance_label", comment: "Distance"),
                        value: String(format: "%.1f", distance),
                        isEditable: isEditable,
                        valueType: .distance
                    ) { newValue in
                        updateDistance(Double(newValue) ?? distance)
                    }
                }

                Spacer()
            }
        }
    }

    private func updateDistance(_ newDistance: Double) {
        var updatedDay = day
        if var details = updatedDay.trainingDetails {
            details.distanceKm = newDistance
            updatedDay.trainingDetails = details
        }
        onEdit(updatedDay)
    }
}

// MARK: - Helper Views

struct EditableValueView: View {
    let title: String
    let value: String
    let isEditable: Bool
    let valueType: EditValueType
    let onEdit: (String) -> Void

    @State private var showingPacePicker = false
    @State private var showingDistancePicker = false
    @State private var showingIntervalDistancePicker = false
    @State private var showingTrainingTypePicker = false
    @State private var showingRepeatsPicker = false
    @State private var showingTimePicker = false

    init(title: String, value: String, isEditable: Bool, valueType: EditValueType = .general, onEdit: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.isEditable = isEditable
        self.valueType = valueType
        self.onEdit = onEdit
    }

    /// 顯示用的格式化值，對 .time 類型加上語系化的分鐘標籤
    private var displayValue: String {
        guard valueType == .time else { return value }
        // value 格式為 "4" 或 "4.5" 或 "4 (~800m)"
        let parts = value.components(separatedBy: " (~")
        let numericPart = parts[0].trimmingCharacters(in: .whitespaces)
        let minuteLabel = NSLocalizedString("time.picker.minutes", comment: "minutes")
        if parts.count > 1 {
            return "\(numericPart)\(minuteLabel) (~\(parts[1])"
        }
        return "\(numericPart)\(minuteLabel)"
    }

    var body: some View {
        Button(action: {
            if isEditable {
                switch valueType {
                case .pace:
                    showingPacePicker = true
                case .intervalDistance:
                    showingIntervalDistancePicker = true
                case .trainingType:
                    showingTrainingTypePicker = true
                case .distance:
                    showingDistancePicker = true
                case .repeats:
                    showingRepeatsPicker = true
                case .time:
                    showingTimePicker = true
                case .general:
                    showingDistancePicker = true
                }
            }
        }) {
            HStack(spacing: 4) {
                if !title.isEmpty {
                    Text(title + ": ")
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }

                Text(displayValue)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(isEditable ? .blue : .secondary)

                if isEditable {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(AppFont.captionSmall())
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(isEditable ? 0.12 : 0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)  // 確保在 List 中能正確響應點擊
        .disabled(!isEditable)
        .sheet(isPresented: $showingPacePicker) {
            PaceWheelPicker(selectedPace: Binding(
                get: { value },
                set: { newValue in onEdit(newValue) }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingDistancePicker) {
            DistanceWheelPicker(selectedDistance: Binding(
                get: { Double(value) ?? 5.0 },
                set: { newValue in onEdit(String(format: "%.1f", newValue)) }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingIntervalDistancePicker) {
            IntervalDistanceWheelPicker(selectedDistanceKm: Binding(
                get: {
                    // 從 "400m" 格式中提取 km 值
                    if value.hasSuffix("m") {
                        let meterString = value.replacingOccurrences(of: "m", with: "")
                        if let meters = Double(meterString) {
                            return meters / 1000.0
                        }
                    }
                    return Double(value) ?? 0.4
                },
                set: { newValue in
                    // 轉換為公尺顯示格式
                    let meters = Int(newValue * 1000)
                    onEdit("\(meters)m")
                }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingTrainingTypePicker) {
            CombinationTrainingTypeWheelPicker(selectedType: Binding(
                get: { value },
                set: { newValue in onEdit(newValue) }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingRepeatsPicker) {
            RepeatsWheelPicker(selectedRepeats: Binding(
                get: {
                    let cleanValue = value.replacingOccurrences(of: "×", with: "")
                        .replacingOccurrences(of: " ", with: "")
                    return Int(cleanValue) ?? 4
                },
                set: { newValue in onEdit("\(newValue) ×") }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingTimePicker) {
            TimeWheelPicker(selectedTime: Binding(
                get: {
                    // 從純數字格式（或帶有附加資訊的格式，如 "4 (~800m)"）中提取分鐘值
                    let numericPart = value.components(separatedBy: " ").first ?? value
                    return Double(numericPart) ?? 1.0
                },
                set: { newValue in
                    // 使用純數字格式，避免語系依賴
                    if newValue == floor(newValue) {
                        onEdit("\(Int(newValue))")
                    } else {
                        onEdit(String(format: "%.1f", newValue))
                    }
                }
            ))
            .presentationDetents([.height(320)])
        }
    }
}

enum EditValueType {
    case distance
    case intervalDistance  // 間歇跑距離選擇
    case trainingType      // 組合訓練類型選擇
    case pace
    case repeats
    case time              // 時間選擇（用於時間基準訓練）
    case general
}

struct IntervalSegmentEditView: View {
    let title: String
    let segment: MutableWorkoutSegment
    let isEditable: Bool
    let color: Color
    let onEdit: (MutableWorkoutSegment) -> Void

    private let recoverySegmentTitle = NSLocalizedString("edit_schedule.recovery_segment", comment: "恢復段")

    private var isRestSegment: Bool {
        return title == recoverySegmentTitle
    }

    private var isStaticRest: Bool {
        return segment.pace == nil && segment.distanceKm == nil && segment.distanceM == nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                // 原地休息切換開關（僅對恢復段顯示）
                if isRestSegment && isEditable {
                    Spacer()

                    HStack(spacing: 4) {
                        Text(NSLocalizedString("interval.static_rest", comment: "原地休息"))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)

                        Toggle("", isOn: Binding(
                            get: { isStaticRest },
                            set: { newValue in
                                toggleStaticRest(newValue)
                            }
                        ))
                        .scaleEffect(0.8)
                        .labelsHidden()
                    }
                } else {
                    Spacer()
                }
            }

            // 配速、距離或時間編輯（非原地休息時顯示）
            if !isStaticRest {
                HStack(spacing: 8) {
                    if let pace = segment.pace {
                        EditableValueView(
                            title: NSLocalizedString("edit_schedule.pace", comment: "配速"),
                            value: pace,
                            isEditable: isEditable,
                            valueType: .pace
                        ) { newValue in
                            updatePace(newValue)
                        }
                    }

                    // 優先顯示時間（時間基準訓練），否則顯示距離
                    if let timeMinutes = segment.timeMinutes {
                        EditableValueView(
                            title: NSLocalizedString("edit_schedule.time", comment: "時間"),
                            value: formatTime(timeMinutes),
                            isEditable: isEditable,
                            valueType: .time
                        ) { newValue in
                            updateTime(newValue)
                        }
                    } else if let distanceM = segment.distanceM {
                        // 優先顯示 distanceM（公尺），用於新的時間基準訓練
                        EditableValueView(
                            title: NSLocalizedString("edit_schedule.distance", comment: "距離"),
                            value: formatDistanceMeters(distanceM),
                            isEditable: isEditable,
                            valueType: .intervalDistance
                        ) { newValue in
                            updateIntervalDistance(newValue)
                        }
                    } else if let distance = segment.distanceKm {
                        EditableValueView(
                            title: NSLocalizedString("edit_schedule.distance", comment: "距離"),
                            value: formatIntervalDistance(distance),
                            isEditable: isEditable,
                            valueType: .intervalDistance
                        ) { newValue in
                            // 處理間歇距離格式 "400m"
                            updateIntervalDistance(newValue)
                        }
                    }

                    Spacer()
                }
            } else {
                // 原地休息狀態顯示
                HStack {
                    Text(NSLocalizedString("interval.static_rest", comment: "原地休息"))
                        .font(AppFont.caption())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)

                    Spacer()
                }
            }
        }
    }

    private func updatePace(_ newPace: String) {
        var updatedSegment = segment
        updatedSegment.pace = newPace
        onEdit(updatedSegment)
    }

    private func updateDistance(_ newDistance: Double) {
        var updatedSegment = segment
        updatedSegment.distanceKm = newDistance
        onEdit(updatedSegment)
    }

    private func formatTime(_ minutes: Double) -> String {
        // 格式化時間顯示，並計算基於配速的約略距離
        // 使用純數字格式作為內部資料，避免語系依賴
        let timeText: String
        if minutes == floor(minutes) {
            timeText = "\(Int(minutes))"
        } else {
            timeText = String(format: "%.1f", minutes)
        }

        // 如果有配速，計算約略距離（以200m為單位）
        if let pace = segment.pace, let distanceKm = calculateDistanceFromPace(pace: pace, timeMinutes: minutes) {
            let meters = Int(distanceKm * 1000)
            let roundedMeters = (meters / 200) * 200  // 四捨五入到最接近的200m
            if roundedMeters > 0 {
                return "\(timeText) (~\(roundedMeters)m)"
            }
        }

        return timeText
    }

    /// 從配速和時間計算距離
    private func calculateDistanceFromPace(pace: String, timeMinutes: Double) -> Double? {
        // 解析配速格式 "5:10" -> 5分10秒/公里
        let components = pace.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        let paceMinutes = Double(components[0])
        let paceSeconds = Double(components[1])
        let paceMinutesPerKm = paceMinutes + paceSeconds / 60.0

        // 計算距離 = 時間 / 配速
        guard paceMinutesPerKm > 0 else { return nil }
        return timeMinutes / paceMinutesPerKm
    }

    private func updateTime(_ timeString: String) {
        // 從純數字格式（或帶有附加資訊的格式，如 "4 (~800m)"）中提取分鐘值
        var cleanedString = timeString
        // 移除附加距離資訊（如果存在）
        if let parenIndex = cleanedString.firstIndex(of: "(") {
            cleanedString = String(cleanedString[..<parenIndex])
        }
        cleanedString = cleanedString.trimmingCharacters(in: .whitespaces)

        if let minutes = Double(cleanedString) {
            var updatedSegment = segment
            updatedSegment.timeMinutes = minutes
            onEdit(updatedSegment)
        }
    }

    private func toggleStaticRest(_ isStatic: Bool) {
        var updatedSegment = segment
        if isStatic {
            // 切換到原地休息：清除配速和距離
            updatedSegment.pace = nil
            updatedSegment.distanceKm = nil
            updatedSegment.distanceM = nil
        } else {
            // 切換到跑步恢復：設定預設配速和距離
            updatedSegment.pace = "6:00"
            // 優先設定 distanceM（如果原本有 distanceM），否則設定 distanceKm
            if segment.distanceM != nil {
                updatedSegment.distanceM = 200.0 // 預設 200m 恢復跑
            } else {
                updatedSegment.distanceKm = 0.2 // 預設 200m 恢復跑
            }
        }
        onEdit(updatedSegment)
    }

    private func formatIntervalDistance(_ km: Double) -> String {
        let meters = Int(km * 1000)
        return "\(meters)m"
    }

    private func formatDistanceMeters(_ meters: Double) -> String {
        return "\(Int(meters))m"
    }

    private func updateIntervalDistance(_ meterString: String) {
        // 從 "400m" 格式中提取公尺值
        if meterString.hasSuffix("m") {
            let meterValue = meterString.replacingOccurrences(of: "m", with: "")
            if let meters = Double(meterValue) {
                var updatedSegment = segment

                // 如果原本是 distanceM，更新 distanceM；否則轉換為 distanceKm
                if segment.distanceM != nil {
                    updatedSegment.distanceM = meters
                } else {
                    let km = meters / 1000.0
                    updatedSegment.distanceKm = km
                }

                onEdit(updatedSegment)
            }
        }
    }
}

// MARK: - Training Edit Sheet

struct TrainingEditSheet: View {
    let day: MutableTrainingDay
    let onSave: (MutableTrainingDay) -> Void
    let viewModel: TrainingPlanViewModel

    // iOS 18 修復：把 @State 放在這裡，避免 TrainingDetailEditor 重複 init 時重置
    @State private var editedDay: MutableTrainingDay

    init(day: MutableTrainingDay, onSave: @escaping (MutableTrainingDay) -> Void, viewModel: TrainingPlanViewModel) {
        self.day = day
        self.onSave = onSave
        self.viewModel = viewModel
        self._editedDay = State(initialValue: day)
        print("🔍 [TrainingEditSheet] init - repeats = \(day.trainingDetails?.repeats ?? -1)")
    }

    var body: some View {
        // 移除高頻日誌：body 每次重新評估都會觸發
        // iOS 18 修復：使用 TrainingEditSheetV2
        TrainingEditSheetV2(
            day: editedDay,
            onSave: { updatedDay in
                print("🔍 [TrainingEditSheet] onSave 回調 - repeats = \(updatedDay.trainingDetails?.repeats ?? -1)")
                onSave(updatedDay)
            },
            paceHelper: PaceCalculationHelper(vdot: viewModel.currentVDOT)
        )
    }
}

// MARK: - Pace Picker Components

class PaceMemoryManager: ObservableObject {
    static let shared = PaceMemoryManager()

    @Published var lastSelectedPace: String = "5:00"

    private let userDefaults = UserDefaults.standard
    private let lastPaceKey = "lastSelectedPace"

    private init() {
        lastSelectedPace = userDefaults.string(forKey: lastPaceKey) ?? "5:00"
    }

    func savePace(_ pace: String) {
        lastSelectedPace = pace
        userDefaults.set(pace, forKey: lastPaceKey)
    }
}

struct PaceWheelPicker: View {
    @Binding var selectedPace: String
    var referenceDistance: Double? = nil  // 可選的參考距離，用於計算預估時間
    @StateObject private var paceMemory = PaceMemoryManager.shared
    @Environment(\.dismiss) private var dismiss

    // 生成配速選項：3:00 到 8:00，每隔5秒
    private let paceOptions: [String] = {
        var options: [String] = []
        for minutes in 3...8 {
            for seconds in stride(from: 0, to: 60, by: 5) {
                options.append(String(format: "%d:%02d", minutes, seconds))
            }
        }
        return options
    }()

    @State private var selectedIndex: Int = 0

    /// 將配速字串轉換為秒數
    private func paceToSeconds(_ pace: String) -> Int {
        let parts = pace.split(separator: ":")
        guard parts.count == 2,
              let minutes = Int(parts[0]),
              let seconds = Int(parts[1]) else { return 300 }
        return minutes * 60 + seconds
    }

    /// 計算預估完成時間
    private func estimatedTime(for distance: Double, pace: String) -> String {
        let paceSeconds = paceToSeconds(pace)
        let totalSeconds = Int(Double(paceSeconds) * distance)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("edit_schedule.select_pace", comment: "選擇配速"))
                    .font(AppFont.headline())
                    .padding()

                Picker(NSLocalizedString("edit_schedule.pace", comment: "配速"), selection: $selectedIndex) {
                    ForEach(paceOptions.indices, id: \.self) { index in
                        Text(paceOptions[index] + " /km")
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 180)

                // 預估完成時間顯示
                if let distance = referenceDistance, distance > 0 {
                    VStack(spacing: 4) {
                        Divider()
                            .padding(.horizontal)

                        HStack {
                            Image(systemName: "clock")
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("edit_schedule.estimated_time", comment: "預估時間"))
                                .font(AppFont.caption())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(estimatedTime(for: distance, pace: paceOptions[selectedIndex]))
                                .font(AppFont.title3())
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Text(String(format: NSLocalizedString("edit_schedule.for_distance", comment: "%.1f 公里"), distance))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }

                Spacer()
            }
            .navigationTitle(NSLocalizedString("edit_schedule.pace_selection", comment: "配速選擇"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("edit_schedule.confirm", comment: "確定")) {
                        let newPace = paceOptions[selectedIndex]
                        selectedPace = newPace
                        paceMemory.savePace(newPace)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 設定初始選擇
            if let currentIndex = paceOptions.firstIndex(of: selectedPace) {
                selectedIndex = currentIndex
            } else if let memoryIndex = paceOptions.firstIndex(of: paceMemory.lastSelectedPace) {
                selectedIndex = memoryIndex
            } else {
                // 預設為 5:00
                selectedIndex = paceOptions.firstIndex(of: "5:00") ?? 12
            }
        }
    }
}

struct IntervalDistanceWheelPicker: View {
    @Binding var selectedDistanceKm: Double
    @Environment(\.dismiss) private var dismiss

    // 間歇跑常見距離選項（公尺）
    private let distanceOptions: [(meters: Int, km: Double, display: String)] = [
        (100, 0.1, "100m"),
        (200, 0.2, "200m"),
        (400, 0.4, "400m"),
        (600, 0.6, "600m"),
        (800, 0.8, "800m"),
        (1000, 1.0, "1000m"),
        (1200, 1.2, "1200m"),
        (1600, 1.6, "1600m"),
        (2000, 2.0, "2000m"),
        (2400, 2.4, "2400m"),
        (2800, 2.8, "2800m"),
        (3000, 3.0, "3000m"),
        (3200, 3.2, "3200m"),
        (3600, 3.6, "3600m"),
        (4000, 4.0, "4000m"),
        (5000, 5.0, "5000m"),
        (6000, 6.0, "6000m"),
        (7000, 7.0, "7000m"),
        (8000, 8.0, "8000m")
    ]

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("edit_schedule.select_interval_distance", comment: "選擇間歇距離"))
                    .font(AppFont.headline())
                    .padding()

                Picker(NSLocalizedString("edit_schedule.distance", comment: "距離"), selection: $selectedIndex) {
                    ForEach(distanceOptions.indices, id: \.self) { index in
                        Text(distanceOptions[index].display)
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 180)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("edit_schedule.interval_distance_selection", comment: "間歇距離選擇"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("edit_schedule.confirm", comment: "確定")) {
                        let newDistanceKm = distanceOptions[selectedIndex].km
                        selectedDistanceKm = newDistanceKm
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 設定初始選擇 - 找最接近的距離
            if let currentIndex = distanceOptions.firstIndex(where: { abs($0.km - selectedDistanceKm) < 0.01 }) {
                selectedIndex = currentIndex
            } else {
                // 找最接近的距離
                let closestIndex = distanceOptions.enumerated().min(by: {
                    abs($0.element.km - selectedDistanceKm) < abs($1.element.km - selectedDistanceKm)
                })?.offset ?? 2 // 預設為 400m
                selectedIndex = closestIndex
            }
        }
    }
}

struct CombinationTrainingTypeWheelPicker: View {
    @Binding var selectedType: String
    @Environment(\.dismiss) private var dismiss

    // 組合訓練可用的訓練類型（不包含休息，因為組合訓練本身就是一個訓練日）
    private let trainingTypes: [String] = [
        "輕鬆跑",
        "節奏跑",
        "閾值跑",
        "間歇跑",
        "恢復跑",
        "熱身",
        "收操"
    ]

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack {
                Text(NSLocalizedString("edit_schedule.select_training_type", comment: "選擇訓練類型"))
                    .font(AppFont.headline())
                    .padding()

                Picker(NSLocalizedString("edit_schedule.training_type", comment: "訓練類型"), selection: $selectedIndex) {
                    ForEach(trainingTypes.indices, id: \.self) { index in
                        Text(trainingTypes[index])
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("edit_schedule.training_type_selection", comment: "訓練類型選擇"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("edit_schedule.confirm", comment: "確定")) {
                        let newType = trainingTypes[selectedIndex]
                        selectedType = newType
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 設定初始選擇
            if let currentIndex = trainingTypes.firstIndex(of: selectedType) {
                selectedIndex = currentIndex
            } else {
                // 預設為輕鬆跑
                selectedIndex = 0
            }
        }
    }
}

// MARK: - Distance Wheel Picker

struct DistanceWheelPicker: View {
    @Binding var selectedDistance: Double
    @Environment(\.dismiss) private var dismiss

    // 距離選項：1.0 到 30.0 km，每隔 0.5 km
    private let distanceOptions: [Double] = {
        var options: [Double] = []
        var distance = 1.0
        while distance <= 30.0 {
            options.append(distance)
            distance += 0.5
        }
        return options
    }()

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("edit_schedule.select_distance", comment: "選擇距離"))
                    .font(AppFont.headline())
                    .padding()

                Picker(NSLocalizedString("edit_schedule.distance", comment: "距離"), selection: $selectedIndex) {
                    ForEach(distanceOptions.indices, id: \.self) { index in
                        Text(String(format: "%.1f km", distanceOptions[index]))
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 180)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("edit_schedule.distance_selection", comment: "距離選擇"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("edit_schedule.confirm", comment: "確定")) {
                        selectedDistance = distanceOptions[selectedIndex]
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 設定初始選擇
            if let currentIndex = distanceOptions.firstIndex(where: { abs($0 - selectedDistance) < 0.01 }) {
                selectedIndex = currentIndex
            } else {
                // 找到最接近的距離
                let closestIndex = distanceOptions.enumerated().min(by: {
                    abs($0.element - selectedDistance) < abs($1.element - selectedDistance)
                })?.offset ?? 8 // 預設為 5.0 km
                selectedIndex = closestIndex
            }
        }
    }
}

// MARK: - Repeats Wheel Picker

struct RepeatsWheelPicker: View {
    @Binding var selectedRepeats: Int
    @Environment(\.dismiss) private var dismiss

    // 重複次數選項：1 到 20
    private let repeatsOptions: [Int] = Array(1...20)

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("edit_schedule.select_repeats", comment: "選擇重複次數"))
                    .font(AppFont.headline())
                    .padding()

                Picker(NSLocalizedString("edit_schedule.repeats", comment: "重複次數"), selection: $selectedIndex) {
                    ForEach(repeatsOptions.indices, id: \.self) { index in
                        Text("\(repeatsOptions[index]) ×")
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 180)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("edit_schedule.repeats_selection", comment: "重複次數選擇"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("edit_schedule.confirm", comment: "確定")) {
                        selectedRepeats = repeatsOptions[selectedIndex]
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 設定初始選擇
            if let currentIndex = repeatsOptions.firstIndex(of: selectedRepeats) {
                selectedIndex = currentIndex
            } else {
                // 預設為 4 次
                selectedIndex = 3
            }
        }
    }
}

/// 時間選擇器（用於時間基準訓練）
struct TimeWheelPicker: View {
    @Binding var selectedTime: Double
    @Environment(\.dismiss) private var dismiss

    // 時間選項：0.5 到 10 分鐘，以 0.5 分鐘為單位
    private let timeOptions: [Double] = {
        var options: [Double] = []
        var time = 0.5
        while time <= 10.0 {
            options.append(time)
            time += 0.5
        }
        return options
    }()

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("edit_schedule.select_time", comment: "選擇時間"))
                    .font(AppFont.headline())
                    .padding()

                Picker(NSLocalizedString("edit_schedule.time", comment: "時間"), selection: $selectedIndex) {
                    ForEach(timeOptions.indices, id: \.self) { index in
                        let time = timeOptions[index]
                        if time == floor(time) {
                            Text("\(Int(time))" + NSLocalizedString("training.minutes_unit", comment: "min"))
                                .tag(index)
                        } else {
                            Text(String(format: "%.1f", time) + NSLocalizedString("training.minutes_unit", comment: "min"))
                                .tag(index)
                        }
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 180)

                Spacer()
            }
            .navigationTitle(NSLocalizedString("edit_schedule.time_selection", comment: "時間選擇"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("edit_schedule.confirm", comment: "確定")) {
                        selectedTime = timeOptions[selectedIndex]
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 設定初始選擇
            if let currentIndex = timeOptions.firstIndex(of: selectedTime) {
                selectedIndex = currentIndex
            } else {
                // 找最接近的值
                if let nearestIndex = timeOptions.enumerated().min(by: { abs($0.element - selectedTime) < abs($1.element - selectedTime) })?.offset {
                    selectedIndex = nearestIndex
                } else {
                    // 預設為 4 分鐘（index 7: 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0）
                    selectedIndex = 7
                }
            }
        }
    }
}
