import SwiftUI

// MARK: - Wheel Picker Input Components

/// 距離選擇輸入欄位
struct DistancePickerField: View {
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

/// 配速選擇輸入欄位
struct PacePickerField: View {
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

/// 重複次數選擇輸入欄位
struct RepeatsPickerField: View {
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

/// 間歇距離選擇輸入欄位（公尺格式）
struct IntervalDistancePickerField: View {
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

// MARK: - 詳細訓練編輯器

struct TrainingDetailEditor: View {
    let day: MutableTrainingDay
    let onSave: (MutableTrainingDay) -> Void
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedDay: MutableTrainingDay
    @State private var showingSaveAlert = false
    @State private var showingPaceTable = false

    init(day: MutableTrainingDay, onSave: @escaping (MutableTrainingDay) -> Void, viewModel: TrainingPlanViewModel) {
        self.day = day
        self.onSave = onSave
        self.viewModel = viewModel
        self._editedDay = State(initialValue: day)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 訓練類型標題
                    VStack(alignment: .leading, spacing: 8) {
                        Text(editedDay.type.localizedName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(getTypeColor())
                        
                        Text(editedDay.dayTarget)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // 根據訓練類型顯示相應的編輯界面
                    Group {
                        switch editedDay.type {
                        case .easyRun, .easy, .recovery_run, .lsd:
                            EasyRunDetailEditor(day: $editedDay, viewModel: viewModel)
                        case .interval:
                            IntervalDetailEditor(day: $editedDay, viewModel: viewModel)
                        case .tempo, .threshold:
                            TempoRunDetailEditor(day: $editedDay, viewModel: viewModel)
                        case .progression, .combination:
                            CombinationDetailEditor(day: $editedDay, viewModel: viewModel)
                        case .longRun:
                            LongRunDetailEditor(day: $editedDay, viewModel: viewModel)
                        default:
                            SimpleTrainingDetailEditor(day: $editedDay, viewModel: viewModel)
                        }
                    }
                    
                    Spacer()
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

                // 配速表按鈕
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if let vdot = viewModel.currentVDOT, !viewModel.calculatedPaces.isEmpty {
                            Button {
                                showingPaceTable = true
                            } label: {
                                Image(systemName: "speedometer")
                                    .font(.body)
                            }
                        }

                        Button(L10n.EditSchedule.save.localized) {
                            onSave(editedDay)
                            dismiss()
                        }
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
    
    private func getTypeColor() -> Color {
        switch editedDay.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return Color.green
        case .interval, .tempo, .progression, .threshold, .combination:
            return Color.orange
        case .longRun, .hiking, .cycling:
            return Color.blue
        case .race:
            return Color.red
        case .rest:
            return Color.gray
        case .crossTraining, .strength:
            return Color.purple
        }
    }
}

// MARK: - Easy Run Detail Editor

struct EasyRunDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.easyRunSettings.localized)
                .font(.headline)
                .foregroundColor(.green)

            // 顯示建議配速提示和配速區間
            if let suggestedPace = getSuggestedPace() {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text(String(format: L10n.EditSchedule.suggestedPace.localized, suggestedPace))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(L10n.EditSchedule.apply.localized) {
                            applyPaceField(suggestedPace)
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // 配速區間範圍
                    if let paceRange = getPaceRange() {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.medium")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(String(format: L10n.EditSchedule.paceRange.localized, paceRange.max, paceRange.min))
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

            DistancePickerField(
                title: L10n.EditSchedule.distance.localized,
                distance: Binding(
                    get: { day.trainingDetails?.distanceKm ?? 5.0 },
                    set: { newValue in
                        if day.trainingDetails != nil {
                            day.trainingDetails?.distanceKm = newValue
                        }
                    }
                )
            )

            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.description.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            // 自動填充建議配速（如果配速為空）
            if day.trainingDetails?.pace == nil || day.trainingDetails?.pace?.isEmpty == true {
                if let suggestedPace = getSuggestedPace() {
                    applyPaceField(suggestedPace)
                }
            }
        }
    }

    private func getSuggestedPace() -> String? {
        return viewModel.getSuggestedPace(for: day.trainingType)
    }

    private func getPaceRange() -> (min: String, max: String)? {
        return viewModel.getPaceRange(for: day.trainingType)
    }

    private func applyPaceField(_ pace: String) {
        if day.trainingDetails == nil {
            day.trainingDetails = MutableTrainingDetails(pace: pace)
        } else {
            day.trainingDetails?.pace = pace
        }
    }
}

// MARK: - Tempo Run Detail Editor

struct TempoRunDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.tempoRunSettings.localized)
                .font(.headline)
                .foregroundColor(.orange)

            // 顯示建議配速提示和配速區間
            if let suggestedPace = getSuggestedPace() {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text(String(format: L10n.EditSchedule.suggestedPace.localized, suggestedPace))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(L10n.EditSchedule.apply.localized) {
                            applyPace(suggestedPace)
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // 配速區間範圍
                    if let paceRange = getPaceRange() {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.medium")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(String(format: L10n.EditSchedule.paceRange.localized, paceRange.max, paceRange.min))
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

            HStack(spacing: 16) {
                DistancePickerField(
                    title: L10n.EditSchedule.distance.localized,
                    distance: Binding(
                        get: { day.trainingDetails?.distanceKm ?? 5.0 },
                        set: { newValue in
                            if day.trainingDetails != nil {
                                day.trainingDetails?.distanceKm = newValue
                            }
                        }
                    )
                )

                PacePickerField(
                    title: L10n.EditSchedule.pace.localized,
                    pace: Binding(
                        get: { day.trainingDetails?.pace ?? "" },
                        set: { newValue in
                            if day.trainingDetails != nil {
                                day.trainingDetails?.pace = newValue.isEmpty ? nil : newValue
                            }
                        }
                    ),
                    referenceDistance: day.trainingDetails?.distanceKm
                )
            }

            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.description.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            // 自動填充建議配速（如果配速為空）
            if day.trainingDetails?.pace == nil || day.trainingDetails?.pace?.isEmpty == true {
                if let suggestedPace = getSuggestedPace() {
                    applyPace(suggestedPace)
                }
            }
        }
    }

    private func applyPace(_ pace: String) {
        if day.trainingDetails != nil {
            day.trainingDetails?.pace = pace
        }
    }

    private func getSuggestedPace() -> String? {
        return viewModel.getSuggestedPace(for: day.trainingType)
    }

    private func getPaceRange() -> (min: String, max: String)? {
        return viewModel.getPaceRange(for: day.trainingType)
    }
}

// MARK: - Interval Detail Editor

struct IntervalDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    @State private var isRestInPlace: Bool = false
    @State private var selectedTemplateIndex: Int? = nil

    // 常用間歇訓練模板
    private struct IntervalTemplate: Identifiable {
        let id = UUID()
        let name: String
        let repeats: Int
        let distanceM: Int
        let description: String
    }

    private let templates: [IntervalTemplate] = [
        IntervalTemplate(name: "400m × 8", repeats: 8, distanceM: 400, description: NSLocalizedString("interval.template.400x8", comment: "適合提升速度耐力")),
        IntervalTemplate(name: "400m × 10", repeats: 10, distanceM: 400, description: NSLocalizedString("interval.template.400x10", comment: "進階速度耐力訓練")),
        IntervalTemplate(name: "800m × 5", repeats: 5, distanceM: 800, description: NSLocalizedString("interval.template.800x5", comment: "中距離間歇訓練")),
        IntervalTemplate(name: "1000m × 4", repeats: 4, distanceM: 1000, description: NSLocalizedString("interval.template.1000x4", comment: "提升有氧閾值")),
        IntervalTemplate(name: "200m × 12", repeats: 12, distanceM: 200, description: NSLocalizedString("interval.template.200x12", comment: "短距離速度訓練"))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.intervalSettings.localized)
                .font(.headline)
                .foregroundColor(.orange)

            // 快速模板選擇
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("edit_schedule.quick_templates", comment: "快速選擇"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates.indices, id: \.self) { index in
                            Button {
                                applyTemplate(templates[index])
                                selectedTemplateIndex = index
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(templates[index].name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(templates[index].description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTemplateIndex == index ? Color.orange.opacity(0.2) : Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedTemplateIndex == index ? Color.orange : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // 顯示建議配速提示和配速區間
            if let suggestedPace = getSuggestedPace() {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text(String(format: L10n.EditSchedule.sprintSuggestedPace.localized, suggestedPace))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(L10n.EditSchedule.apply.localized) {
                            applySprintPace(suggestedPace)
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // 配速區間範圍
                    if let paceRange = getPaceRange() {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.medium")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(String(format: L10n.EditSchedule.intervalPaceRange.localized, paceRange.max, paceRange.min))
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

            // 重複次數
            RepeatsPickerField(
                title: L10n.EditSchedule.repeats.localized,
                repeats: Binding(
                    get: { day.trainingDetails?.repeats ?? 4 },
                    set: { newValue in
                        day.trainingDetails?.repeats = newValue
                    }
                )
            )

            // 衝刺段設定
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.EditSchedule.sprintSegment.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)

                HStack(spacing: 16) {
                    IntervalDistancePickerField(
                        title: L10n.EditSchedule.distance.localized,
                        distanceKm: Binding(
                            get: { day.trainingDetails?.work?.distanceKm ?? 0.4 },
                            set: { newValue in
                                ensureWorkSegment()
                                day.trainingDetails?.work?.distanceKm = newValue
                            }
                        )
                    )

                    PacePickerField(
                        title: L10n.EditSchedule.pace.localized,
                        pace: Binding(
                            get: { day.trainingDetails?.work?.pace ?? "" },
                            set: { newValue in
                                ensureWorkSegment()
                                day.trainingDetails?.work?.pace = newValue.isEmpty ? nil : newValue
                            }
                        )
                    )
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // 恢復段設定
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.EditSchedule.recoverySegment.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Toggle(L10n.EditSchedule.restInPlace.localized, isOn: $isRestInPlace)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: isRestInPlace) { oldValue, newValue in
                        updateRestInPlace(newValue)
                    }

                if !isRestInPlace {
                    HStack(spacing: 16) {
                        IntervalDistancePickerField(
                            title: L10n.EditSchedule.distance.localized,
                            distanceKm: Binding(
                                get: { day.trainingDetails?.recovery?.distanceKm ?? 0.2 },
                                set: { newValue in
                                    ensureRecoverySegment()
                                    day.trainingDetails?.recovery?.distanceKm = newValue
                                }
                            )
                        )

                        PacePickerField(
                            title: L10n.EditSchedule.pace.localized,
                            pace: Binding(
                                get: { day.trainingDetails?.recovery?.pace ?? "" },
                                set: { newValue in
                                    ensureRecoverySegment()
                                    day.trainingDetails?.recovery?.pace = newValue.isEmpty ? nil : newValue
                                }
                            )
                        )
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.description.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            loadIntervalData()
        }
    }

    private func loadIntervalData() {
        guard let details = day.trainingDetails else { return }

        // 檢查是否為原地休息
        if let recovery = details.recovery {
            isRestInPlace = recovery.distanceKm == nil && recovery.pace == nil
        } else {
            isRestInPlace = true
        }

        // 自動填充建議配速（如果配速為空）
        if details.work?.pace == nil || details.work?.pace?.isEmpty == true {
            if let suggestedPace = getSuggestedPace() {
                applySprintPace(suggestedPace)
            }
        }
    }

    private func ensureWorkSegment() {
        if day.trainingDetails?.work == nil {
            day.trainingDetails?.work = MutableWorkoutSegment(
                description: nil, distanceKm: 0.4, distanceM: nil,
                timeMinutes: nil, pace: nil, heartRateRange: nil
            )
        }
    }

    private func ensureRecoverySegment() {
        if day.trainingDetails?.recovery == nil {
            day.trainingDetails?.recovery = MutableWorkoutSegment(
                description: nil, distanceKm: 0.2, distanceM: nil,
                timeMinutes: nil, pace: "6:00", heartRateRange: nil
            )
        }
    }

    private func applySprintPace(_ pace: String) {
        ensureWorkSegment()
        day.trainingDetails?.work?.pace = pace
    }

    private func updateRestInPlace(_ isRest: Bool) {
        if isRest {
            // 原地休息：清除距離和配速
            day.trainingDetails?.recovery?.distanceKm = nil
            day.trainingDetails?.recovery?.pace = nil
        } else {
            // 跑步恢復：設定預設值
            ensureRecoverySegment()
            if day.trainingDetails?.recovery?.distanceKm == nil {
                day.trainingDetails?.recovery?.distanceKm = 0.2
            }
            if day.trainingDetails?.recovery?.pace == nil {
                day.trainingDetails?.recovery?.pace = "6:00"
            }
        }
    }

    /// 應用間歇訓練模板
    private func applyTemplate(_ template: IntervalTemplate) {
        isRestInPlace = true

        // 獲取建議配速
        let suggestedPace = getSuggestedPace() ?? "4:30"

        // 更新 day 資料
        day.trainingDetails?.repeats = template.repeats
        day.trainingDetails?.work = MutableWorkoutSegment(
            description: nil,
            distanceKm: Double(template.distanceM) / 1000.0,
            distanceM: nil,
            timeMinutes: nil,
            pace: suggestedPace,
            heartRateRange: nil
        )
        day.trainingDetails?.recovery = MutableWorkoutSegment(
            description: nil,
            distanceKm: nil,
            distanceM: nil,
            timeMinutes: nil,
            pace: nil,
            heartRateRange: nil
        )

        // 觸發震動回饋
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func getSuggestedPace() -> String? {
        return viewModel.getSuggestedPace(for: day.trainingType)
    }

    private func getPaceRange() -> (min: String, max: String)? {
        return viewModel.getPaceRange(for: day.trainingType)
    }
}

// MARK: - Combination Detail Editor

struct CombinationDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.combinationSettings.localized)
                .font(.headline)
                .foregroundColor(.orange)

            if let segments = day.trainingDetails?.segments {
                ForEach(segments.indices, id: \.self) { index in
                    CombinationSegmentEditor(
                        segmentIndex: index,
                        segment: Binding(
                            get: { day.trainingDetails?.segments?[index] ?? MutableProgressionSegment(distanceKm: nil, pace: nil, description: nil, heartRateRange: nil) },
                            set: { newValue in
                                day.trainingDetails?.segments?[index] = newValue
                                updateTotalDistance()
                            }
                        )
                    )
                }
            }

            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.description.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func updateTotalDistance() {
        guard let segments = day.trainingDetails?.segments else { return }
        let totalDistance = segments.compactMap { $0.distanceKm }.reduce(0, +)
        if totalDistance > 0 {
            day.trainingDetails?.totalDistanceKm = totalDistance
        }
    }
}

/// 組合訓練單一段落編輯器
struct CombinationSegmentEditor: View {
    let segmentIndex: Int
    @Binding var segment: MutableProgressionSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: L10n.EditSchedule.segment.localized, segmentIndex + 1))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                // 段落描述標籤（僅顯示，不可編輯）
                if let desc = segment.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 16) {
                DistancePickerField(
                    title: L10n.EditSchedule.distance.localized,
                    distance: Binding(
                        get: { segment.distanceKm ?? 2.0 },
                        set: { newValue in segment.distanceKm = newValue }
                    )
                )

                PacePickerField(
                    title: L10n.EditSchedule.pace.localized,
                    pace: Binding(
                        get: { segment.pace ?? "" },
                        set: { newValue in segment.pace = newValue.isEmpty ? nil : newValue }
                    ),
                    referenceDistance: segment.distanceKm
                )
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Long Run Detail Editor

struct LongRunDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.longRunSettings.localized)
                .font(.headline)
                .foregroundColor(.blue)

            DistancePickerField(
                title: L10n.EditSchedule.distance.localized,
                distance: Binding(
                    get: { day.trainingDetails?.distanceKm ?? 15.0 },
                    set: { newValue in
                        if day.trainingDetails != nil {
                            day.trainingDetails?.distanceKm = newValue
                        }
                    }
                )
            )

            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.description.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Simple Training Detail Editor

struct SimpleTrainingDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.trainingSettings.localized)
                .font(.headline)
                .foregroundColor(.blue)

            if day.type != .rest {
                DistancePickerField(
                    title: L10n.EditSchedule.distance.localized,
                    distance: Binding(
                        get: { day.trainingDetails?.distanceKm ?? 5.0 },
                        set: { newValue in
                            if day.trainingDetails != nil {
                                day.trainingDetails?.distanceKm = newValue
                            }
                        }
                    )
                )
            }

            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.description.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(desc)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}