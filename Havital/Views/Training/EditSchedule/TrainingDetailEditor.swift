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
    @Published var recoveryPace: String
    @Published var recoveryDistance: Double
    @Published var isRestInPlace: Bool

    // 組合跑欄位
    @Published var segments: [EditableSegment]

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
        self.recoveryPace = details?.recovery?.pace ?? "6:00"
        self.recoveryDistance = details?.recovery?.distanceKm ?? 0.2
        self.isRestInPlace = details?.recovery == nil

        // 組合跑欄位
        if let segs = details?.segments {
            self.segments = segs.map { EditableSegment(from: $0) }
        } else {
            self.segments = [EditableSegment(pace: "6:00", distance: 2.0)]
        }
    }

    var type: DayType {
        DayType(rawValue: trainingType) ?? .rest
    }

    var totalSegmentDistance: Double {
        segments.reduce(0) { $0 + $1.distance }
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

        case .tempo, .threshold, .longRun:
            result.trainingDetails = MutableTrainingDetails(
                description: description,
                distanceKm: distance,
                pace: pace.isEmpty ? nil : pace
            )

        case .interval:
            let work = MutableWorkoutSegment(
                distanceKm: workDistance,
                pace: workPace.isEmpty ? nil : workPace
            )
            let recovery: MutableWorkoutSegment? = isRestInPlace ? nil : MutableWorkoutSegment(
                distanceKm: recoveryDistance,
                pace: recoveryPace.isEmpty ? nil : recoveryPace
            )
            result.trainingDetails = MutableTrainingDetails(
                description: description,
                work: work,
                recovery: recovery,
                repeats: repeats
            )

        case .combination, .progression:
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

        return result
    }

    func addSegment(defaultPace: String) {
        segments.append(EditableSegment(pace: defaultPace, distance: 2.0))
    }

    func removeSegment(at index: Int) {
        guard segments.count > 1, index < segments.count else { return }
        segments.remove(at: index)
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
    let viewModel: TrainingPlanViewModel

    @StateObject private var editState: TrainingDayEditState
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaceTable = false

    init(day: MutableTrainingDay, onSave: @escaping (MutableTrainingDay) -> Void, viewModel: TrainingPlanViewModel) {
        self.originalDay = day
        self.onSave = onSave
        self.viewModel = viewModel
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
                        if let _ = viewModel.currentVDOT, !viewModel.calculatedPaces.isEmpty {
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
                if let vdot = viewModel.currentVDOT {
                    PaceTableView(vdot: vdot, calculatedPaces: viewModel.calculatedPaces)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(editState.type.localizedName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(typeColor)

            Text(editState.dayTarget)
                .font(.body)
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
            EasyRunEditorV2(editState: editState, viewModel: viewModel)
        case .tempo, .threshold:
            TempoEditorV2(editState: editState, viewModel: viewModel)
        case .interval:
            IntervalEditorV2(editState: editState, viewModel: viewModel)
        case .combination, .progression:
            CombinationEditorV2(editState: editState, viewModel: viewModel)
        case .longRun:
            LongRunEditorV2(editState: editState, viewModel: viewModel)
        default:
            SimpleEditorV2(editState: editState, viewModel: viewModel)
        }
    }

    private var typeColor: Color {
        switch editState.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .green
        case .interval, .tempo, .progression, .threshold, .combination:
            return .orange
        case .longRun, .hiking, .cycling:
            return .blue
        case .race:
            return .red
        case .rest:
            return .gray
        case .crossTraining, .strength:
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
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.easyRunSettings.localized)
                .font(.headline)
                .foregroundColor(.green)

            // 建議配速
            if let suggestedPace = viewModel.getSuggestedPace(for: editState.trainingType) {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: viewModel.getPaceRange(for: editState.trainingType),
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
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.tempoRunSettings.localized)
                .font(.headline)
                .foregroundColor(.orange)

            // 建議配速
            if let suggestedPace = viewModel.getSuggestedPace(for: editState.trainingType) {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: viewModel.getPaceRange(for: editState.trainingType),
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
            if editState.pace.isEmpty, let suggested = viewModel.getSuggestedPace(for: editState.trainingType) {
                editState.pace = suggested
            }
        }
    }
}

// MARK: - 間歇跑編輯器

struct IntervalEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var viewModel: TrainingPlanViewModel

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
                .font(.headline)
                .foregroundColor(.orange)

            // 快速選擇模板
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates.indices, id: \.self) { index in
                        Button {
                            applyTemplate(index)
                        } label: {
                            Text(templates[index].name)
                                .font(.caption)
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
            if let suggestedPace = viewModel.getSuggestedPace(for: editState.trainingType) {
                SuggestedPaceViewV2(
                    pace: suggestedPace,
                    paceRange: viewModel.getPaceRange(for: editState.trainingType),
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
                        .font(.subheadline)
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Toggle(L10n.EditSchedule.restInPlace.localized, isOn: $editState.isRestInPlace)

                if !editState.isRestInPlace {
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
            if editState.workPace.isEmpty, let suggested = viewModel.getSuggestedPace(for: editState.trainingType) {
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

        if let suggested = viewModel.getSuggestedPace(for: editState.trainingType) {
            editState.workPace = suggested
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - 組合跑編輯器

struct CombinationEditorV2: View {
    @ObservedObject var editState: TrainingDayEditState
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.combinationSettings.localized)
                .font(.headline)
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
                let defaultPace = viewModel.getSuggestedPace(for: "easy") ?? "6:00"
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
                    .font(.title3)
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                if let desc = segment.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
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
                            .font(.system(size: 14))
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
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.longRunSettings.localized)
                .font(.headline)
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
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.trainingSettings.localized)
                .font(.headline)
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

// MARK: - Picker 欄位元件 (V2 版本，直接使用 @Binding)

struct DistancePickerFieldV2: View {
    let title: String
    @Binding var distance: Double
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(String(format: "%.1f km", distance))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
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
                .font(.subheadline)
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(pace.isEmpty ? "--:--" : "\(pace) /km")
                        .foregroundColor(pace.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
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
                .font(.subheadline)
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text("\(repeats) ×")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
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
                .font(.subheadline)
                .fontWeight(.medium)

            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
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
                    .font(.caption)

                Text(String(format: L10n.EditSchedule.suggestedPace.localized, pace))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(L10n.EditSchedule.apply.localized) {
                    onApply()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if let range = paceRange {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.medium")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(String(format: L10n.EditSchedule.paceRange.localized, range.max, range.min))
                        .font(.caption)
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
                .font(.subheadline)
                .fontWeight(.medium)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
    }
}
