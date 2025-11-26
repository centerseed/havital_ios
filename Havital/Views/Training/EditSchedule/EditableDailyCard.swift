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
            case .interval:
                IntervalEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .tempo, .threshold, .longRun:
                TempoRunEditView(day: day, details: details, isEditable: isEditable, onEdit: onEdit)
            case .progression, .combination:
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
                        title: "距離",
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
        updatedDay.trainingDetails?.distanceKm = newDistance
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
                        title: "配速",
                        value: pace,
                        isEditable: isEditable,
                        valueType: .pace
                    ) { newValue in
                        updatePace(newValue)
                    }
                }

                if let distance = details.distanceKm {
                    EditableValueView(
                        title: "距離",
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
        updatedDay.trainingDetails?.pace = newPace
        onEdit(updatedDay)
    }

    private func updateDistance(_ newDistance: Double) {
        var updatedDay = day
        updatedDay.trainingDetails?.distanceKm = newDistance
        onEdit(updatedDay)
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
                Text("間歇訓練")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                if let repeats = details.repeats {
                    EditableValueView(
                        title: "重複",
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
                    title: "衝刺段",
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
                    title: "恢復段",
                    segment: recovery,
                    isEditable: isEditable,
                    color: .blue
                ) { updatedSegment in
                    updateRecoverySegment(updatedSegment)
                }
            }
        }
    }

    private func updateRepeats(_ newRepeats: Int) {
        var updatedDay = day
        updatedDay.trainingDetails?.repeats = newRepeats
        onEdit(updatedDay)
    }

    private func updateWorkSegment(_ segment: MutableWorkoutSegment) {
        var updatedDay = day
        updatedDay.trainingDetails?.work = segment
        onEdit(updatedDay)
    }

    private func updateRecoverySegment(_ segment: MutableWorkoutSegment) {
        var updatedDay = day
        updatedDay.trainingDetails?.recovery = segment
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
            HStack {
                Text(day.type.localizedName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                if let total = details.totalDistanceKm {
                    Text(String(format: "%.1f", total))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                }
            }

            Divider()
                .background(Color.orange.opacity(0.3))

            if let segments = details.segments {
                VStack(spacing: 4) {
                    ForEach(segments.indices, id: \.self) { index in
                        if index < segments.count {
                            CombinationSegmentEditView(
                                title: "區段\(index + 1)",
                                segment: segments[index],
                                isEditable: isEditable
                            ) { updatedSegment in
                                updateSegment(at: index, with: updatedSegment)
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateSegment(at index: Int, with segment: MutableProgressionSegment) {
        var updatedDay = day
        updatedDay.trainingDetails?.segments?[index] = segment
        onEdit(updatedDay)
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
                if let distance = details.distanceKm {
                    EditableValueView(
                        title: "距離",
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
        updatedDay.trainingDetails?.distanceKm = newDistance
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

    init(title: String, value: String, isEditable: Bool, valueType: EditValueType = .general, onEdit: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.isEditable = isEditable
        self.valueType = valueType
        self.onEdit = onEdit
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
                case .general:
                    showingDistancePicker = true
                }
            }
        }) {
            HStack(spacing: 4) {
                if !title.isEmpty {
                    Text(title + ": ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isEditable ? .blue : .secondary)

                if isEditable {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(isEditable ? 0.12 : 0.05))
            .cornerRadius(8)
        }
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
    }
}

enum EditValueType {
    case distance
    case intervalDistance  // 間歇跑距離選擇
    case trainingType      // 組合訓練類型選擇
    case pace
    case repeats
    case general
}

struct IntervalSegmentEditView: View {
    let title: String
    let segment: MutableWorkoutSegment
    let isEditable: Bool
    let color: Color
    let onEdit: (MutableWorkoutSegment) -> Void

    private let recoverySegmentTitle = NSLocalizedString("edit_schedule.recovery_segment", comment: "恢復段")
    private let sprintSegmentTitle = NSLocalizedString("edit_schedule.sprint_segment", comment: "衝刺段")

    private var isRestSegment: Bool {
        return title == recoverySegmentTitle
    }

    private var isWorkSegment: Bool {
        return title == sprintSegmentTitle
    }

    private var isStaticRest: Bool {
        return segment.pace == nil && segment.distanceKm == nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                // 原地休息切換開關（僅對恢復段顯示）
                if isRestSegment && isEditable {
                    Spacer()

                    HStack(spacing: 4) {
                        Text(NSLocalizedString("interval.static_rest", comment: "原地休息"))
                            .font(.caption)
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

            // 配速和距離編輯（非原地休息時顯示）
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

                    if let distance = segment.distanceKm {
                        EditableValueView(
                            title: NSLocalizedString("edit_schedule.distance", comment: "距離"),
                            value: isWorkSegment ? formatIntervalDistance(distance) : String(format: "%.1f", distance),
                            isEditable: isEditable,
                            valueType: isWorkSegment ? .intervalDistance : .distance
                        ) { newValue in
                            if isWorkSegment {
                                // 處理間歇距離格式 "400m"
                                updateIntervalDistance(newValue)
                            } else {
                                updateDistance(Double(newValue) ?? distance)
                            }
                        }
                    }

                    Spacer()
                }
            } else {
                // 原地休息狀態顯示
                HStack {
                    Text(NSLocalizedString("interval.static_rest", comment: "原地休息"))
                        .font(.caption)
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

    private func toggleStaticRest(_ isStatic: Bool) {
        var updatedSegment = segment
        if isStatic {
            // 切換到原地休息：清除配速和距離
            updatedSegment.pace = nil
            updatedSegment.distanceKm = nil
        } else {
            // 切換到跑步恢復：設定預設配速
            updatedSegment.pace = "6:00"
            updatedSegment.distanceKm = nil // 恢復段通常只有配速，沒有距離
        }
        onEdit(updatedSegment)
    }

    private func formatIntervalDistance(_ km: Double) -> String {
        let meters = Int(km * 1000)
        return "\(meters)m"
    }

    private func updateIntervalDistance(_ meterString: String) {
        // 從 "400m" 格式中提取 km 值
        if meterString.hasSuffix("m") {
            let meterValue = meterString.replacingOccurrences(of: "m", with: "")
            if let meters = Double(meterValue) {
                let km = meters / 1000.0
                updateDistance(km)
            }
        }
    }
}

struct CombinationSegmentEditView: View {
    let title: String
    let segment: MutableProgressionSegment
    let isEditable: Bool
    let onEdit: (MutableProgressionSegment) -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 訓練類型選擇器
            if let description = segment.description {
                EditableValueView(
                    title: "",
                    value: description,
                    isEditable: isEditable,
                    valueType: .trainingType
                ) { newValue in
                    updateTrainingType(newValue)
                }
            }

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

            if let distance = segment.distanceKm {
                EditableValueView(
                    title: NSLocalizedString("edit_schedule.distance", comment: "距離"),
                    value: String(format: "%.1f", distance),
                    isEditable: isEditable
                ) { newValue in
                    updateDistance(Double(newValue) ?? distance)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
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

    private func updateTrainingType(_ newType: String) {
        var updatedSegment = segment
        updatedSegment.description = newType
        onEdit(updatedSegment)
    }
}

// MARK: - Training Edit Sheet

struct TrainingEditSheet: View {
    let day: MutableTrainingDay
    let onSave: (MutableTrainingDay) -> Void
    let viewModel: TrainingPlanViewModel

    var body: some View {
        TrainingDetailEditor(day: day, onSave: onSave, viewModel: viewModel)
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
                    .font(.headline)
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
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("edit_schedule.estimated_time", comment: "預估時間"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(estimatedTime(for: distance, pace: paceOptions[selectedIndex]))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Text(String(format: NSLocalizedString("edit_schedule.for_distance", comment: "%.1f 公里"), distance))
                            .font(.caption)
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

    // 間歇跑常見距離選項
    private let distanceOptions: [(meters: Int, km: Double, display: String)] = [
        (200, 0.2, "200m"),
        (400, 0.4, "400m"),
        (600, 0.6, "600m"),
        (800, 0.8, "800m"),
        (1000, 1.0, "1000m"),
        (1200, 1.2, "1200m")
    ]

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(NSLocalizedString("edit_schedule.select_interval_distance", comment: "選擇間歇距離"))
                    .font(.headline)
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
            // 設定初始選擇
            if let currentIndex = distanceOptions.firstIndex(where: { $0.km == selectedDistanceKm }) {
                selectedIndex = currentIndex
            } else {
                // 預設為 400m (0.4km)
                selectedIndex = 1
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
                    .font(.headline)
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
                    .font(.headline)
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
                    .font(.headline)
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
