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

    @State private var showingEditor = false
    @State private var showingPacePicker = false
    @State private var showingIntervalDistancePicker = false
    @State private var showingTrainingTypePicker = false
    @State private var editValue = ""

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
                if valueType == .pace {
                    showingPacePicker = true
                } else if valueType == .intervalDistance {
                    showingIntervalDistancePicker = true
                } else if valueType == .trainingType {
                    showingTrainingTypePicker = true
                } else {
                    editValue = cleanValueForEditing(value)
                    showingEditor = true
                }
            }
        }) {
            HStack(spacing: 4) {
                if !title.isEmpty {
                    Text(title + ": ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(value)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isEditable ? .blue : .secondary)

                if isEditable {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(isEditable ? 0.15 : 0.05))
            .cornerRadius(12)
        }
        .disabled(!isEditable)
        .alert(localizedTitle, isPresented: $showingEditor) {
            TextField(localizedTitle, text: $editValue)
                .keyboardType(keyboardType)
            Button(NSLocalizedString("edit_value.confirm", comment: "確定")) {
                onEdit(editValue)
            }
            Button(NSLocalizedString("edit_value.cancel", comment: "取消"), role: .cancel) { }
        } message: {
            Text(localizedMessage)
        }
        .sheet(isPresented: $showingPacePicker) {
            PaceWheelPicker(selectedPace: Binding(
                get: { value },
                set: { newValue in onEdit(newValue) }
            ))
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
        }
        .sheet(isPresented: $showingTrainingTypePicker) {
            CombinationTrainingTypeWheelPicker(selectedType: Binding(
                get: { value },
                set: { newValue in onEdit(newValue) }
            ))
        }
    }

    private var localizedTitle: String {
        switch valueType {
        case .distance:
            return NSLocalizedString("edit_value.distance_title", comment: "編輯距離")
        case .intervalDistance:
            return NSLocalizedString("edit_value.interval_distance_title", comment: "編輯間歇距離")
        case .trainingType:
            return NSLocalizedString("edit_value.training_type_title", comment: "編輯訓練類型")
        case .pace:
            return NSLocalizedString("edit_value.pace_title", comment: "編輯配速")
        case .repeats:
            return NSLocalizedString("edit_value.repeats_title", comment: "編輯重複次數")
        case .general:
            return title
        }
    }

    private var localizedMessage: String {
        switch valueType {
        case .distance:
            return NSLocalizedString("edit_value.distance_message", comment: "請輸入距離（公里）")
        case .intervalDistance:
            return NSLocalizedString("edit_value.interval_distance_message", comment: "請選擇間歇距離")
        case .trainingType:
            return NSLocalizedString("edit_value.training_type_message", comment: "請選擇訓練類型")
        case .pace:
            return NSLocalizedString("edit_value.pace_message", comment: "請輸入配速（例如：5:30）")
        case .repeats:
            return NSLocalizedString("edit_value.repeats_message", comment: "請輸入重複次數")
        case .general:
            return NSLocalizedString("edit_value.general_message", comment: "請輸入新的\(title)")
        }
    }

    private var keyboardType: UIKeyboardType {
        switch valueType {
        case .distance:
            return .decimalPad
        case .intervalDistance:
            return .default  // 不會被使用，因為使用 wheel picker
        case .trainingType:
            return .default  // 不會被使用，因為使用 wheel picker
        case .pace:
            return .numbersAndPunctuation
        case .repeats:
            return .numberPad
        case .general:
            return .default
        }
    }

    private func cleanValueForEditing(_ value: String) -> String {
        switch valueType {
        case .distance:
            // Since we no longer display "km" in the value, just trim whitespace
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case .intervalDistance:
            // 不會被使用，因為使用 wheel picker
            return value
        case .trainingType:
            // 不會被使用，因為使用 wheel picker
            return value
        case .repeats:
            // Remove "×" and any whitespace, leave only the numeric value
            return value.replacingOccurrences(of: "×", with: "")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            return value
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

    private var isRestSegment: Bool {
        return title == "恢復段"
    }

    private var isWorkSegment: Bool {
        return title == "衝刺段"
    }

    private var isStaticRest: Bool {
        return segment.pace == nil && segment.distanceKm == nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                // 原地休息切換開關（僅對恢復段顯示）
                if isRestSegment && isEditable {
                    Spacer()

                    HStack(spacing: 4) {
                        Text(NSLocalizedString("interval.static_rest", comment: "原地休息"))
                            .font(.system(size: 10, weight: .medium))
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
                            title: "配速",
                            value: pace,
                            isEditable: isEditable,
                            valueType: .pace
                        ) { newValue in
                            updatePace(newValue)
                        }
                    }

                    if let distance = segment.distanceKm {
                        EditableValueView(
                            title: "距離",
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
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
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
                    title: "配速",
                    value: pace,
                    isEditable: isEditable,
                    valueType: .pace
                ) { newValue in
                    updatePace(newValue)
                }
            }

            if let distance = segment.distanceKm {
                EditableValueView(
                    title: "距離",
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

    var body: some View {
        NavigationView {
            VStack {
                Text("選擇配速")
                    .font(.headline)
                    .padding()

                Picker("配速", selection: $selectedIndex) {
                    ForEach(paceOptions.indices, id: \.self) { index in
                        Text(paceOptions[index])
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)

                Spacer()
            }
            .navigationTitle("配速選擇")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確定") {
                        let newPace = paceOptions[selectedIndex]
                        selectedPace = newPace
                        paceMemory.savePace(newPace)
                        dismiss()
                    }
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
        (200, 0.2, "200m (0.2km)"),
        (400, 0.4, "400m (0.4km)"),
        (600, 0.6, "600m (0.6km)"),
        (800, 0.8, "800m (0.8km)"),
        (1200, 1.2, "1200m (1.2km)")
    ]

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack {
                Text("選擇間歇距離")
                    .font(.headline)
                    .padding()

                Picker("距離", selection: $selectedIndex) {
                    ForEach(distanceOptions.indices, id: \.self) { index in
                        Text(distanceOptions[index].display)
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)

                Spacer()
            }
            .navigationTitle("間歇距離選擇")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確定") {
                        let newDistanceKm = distanceOptions[selectedIndex].km
                        selectedDistanceKm = newDistanceKm
                        dismiss()
                    }
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
                Text("選擇訓練類型")
                    .font(.headline)
                    .padding()

                Picker("訓練類型", selection: $selectedIndex) {
                    ForEach(trainingTypes.indices, id: \.self) { index in
                        Text(trainingTypes[index])
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)

                Spacer()
            }
            .navigationTitle("訓練類型選擇")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確定") {
                        let newType = trainingTypes[selectedIndex]
                        selectedType = newType
                        dismiss()
                    }
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
