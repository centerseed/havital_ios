import SwiftUI

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

    @State private var distance: String = ""

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
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.EditSchedule.distance.localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $distance)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
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
            if let distanceKm = day.trainingDetails?.distanceKm {
                distance = String(format: "%.1f", distanceKm)
            }

            // 自動填充建議配速（如果配速為空）
            if day.trainingDetails?.pace == nil || day.trainingDetails?.pace?.isEmpty == true {
                if let suggestedPace = getSuggestedPace() {
                    applyPaceField(suggestedPace)
                }
            }
        }
        .onChange(of: distance) { oldValue, newValue in
            updateDistance(newValue)
        }
    }

    private func updateDistance(_ distanceStr: String) {
        guard let distanceValue = Double(distanceStr) else { return }
        if day.trainingDetails != nil {
            day.trainingDetails?.distanceKm = distanceValue
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

    @State private var distance: String = ""
    @State private var pace: String = ""

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
                            pace = suggestedPace
                            updatePace(suggestedPace)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.distance.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $distance)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.pace.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField(L10n.EditSchedule.pacePlaceholder.localized, text: $pace)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
        .onAppear {
            if let details = day.trainingDetails {
                if let distanceKm = details.distanceKm {
                    distance = String(format: "%.1f", distanceKm)
                }
                if let paceStr = details.pace {
                    pace = paceStr
                }
            }

            // 自動填充建議配速（如果配速為空）
            if day.trainingDetails?.pace == nil || day.trainingDetails?.pace?.isEmpty == true {
                if let suggestedPace = getSuggestedPace() {
                    pace = suggestedPace
                    updatePace(suggestedPace)
                }
            }
        }
        .onChange(of: distance) { oldValue, newValue in
            updateDistance(newValue)
        }
        .onChange(of: pace) { oldValue, newValue in
            updatePace(newValue)
        }
    }

    private func updateDistance(_ distanceStr: String) {
        guard let distanceValue = Double(distanceStr) else { return }
        if day.trainingDetails != nil {
            day.trainingDetails?.distanceKm = distanceValue
        }
    }

    private func updatePace(_ paceStr: String) {
        if day.trainingDetails != nil {
            day.trainingDetails?.pace = paceStr.isEmpty ? nil : paceStr
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

    @State private var repeats: String = ""
    @State private var sprintDistance: String = ""
    @State private var sprintPace: String = ""
    @State private var recoveryDistance: String = ""
    @State private var recoveryPace: String = ""
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
                            sprintPace = suggestedPace
                            updateSprintPace(suggestedPace)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.EditSchedule.repeats.localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(L10n.EditSchedule.repeatsPlaceholder.localized, text: $repeats)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            // 衝刺段設定
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.EditSchedule.sprintSegment.localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.EditSchedule.distance.localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $sprintDistance)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.EditSchedule.pace.localized)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        TextField(L10n.EditSchedule.pacePlaceholder.localized, text: $sprintPace)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
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
                
                if !isRestInPlace {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.EditSchedule.distance.localized)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $recoveryDistance)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.EditSchedule.pace.localized)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField(L10n.EditSchedule.pacePlaceholder.localized, text: $recoveryPace)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
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
        .onChange(of: repeats) { oldValue, newValue in updateRepeats(newValue) }
        .onChange(of: sprintDistance) { oldValue, newValue in updateSprintDistance(newValue) }
        .onChange(of: sprintPace) { oldValue, newValue in updateSprintPace(newValue) }
        .onChange(of: recoveryDistance) { oldValue, newValue in updateRecoveryDistance(newValue) }
        .onChange(of: recoveryPace) { oldValue, newValue in updateRecoveryPace(newValue) }
        .onChange(of: isRestInPlace) { oldValue, newValue in updateRestInPlace(newValue) }
    }
    
    private func loadIntervalData() {
        guard let details = day.trainingDetails else { return }

        if let reps = details.repeats {
            repeats = String(reps)
        }

        if let work = details.work {
            if let distance = work.distanceKm {
                sprintDistance = String(format: "%.1f", distance)
            }
            if let pace = work.pace {
                sprintPace = pace
            } else {
                // 自動填充建議配速（如果配速為空）
                if let suggestedPace = getSuggestedPace() {
                    sprintPace = suggestedPace
                    updateSprintPace(suggestedPace)
                }
            }
        }

        if let recovery = details.recovery {
            if let distance = recovery.distanceKm {
                recoveryDistance = String(format: "%.1f", distance)
                isRestInPlace = false
            } else {
                isRestInPlace = true
            }
            if let pace = recovery.pace {
                recoveryPace = pace
            }
        }
    }
    
    private func updateRepeats(_ value: String) {
        guard let reps = Int(value) else { return }
        day.trainingDetails?.repeats = reps
    }
    
    private func updateSprintDistance(_ value: String) {
        guard let distance = Double(value) else { return }
        if day.trainingDetails?.work == nil {
            day.trainingDetails?.work = MutableWorkoutSegment(
                description: nil, distanceKm: distance, distanceM: nil,
                timeMinutes: nil, pace: nil, heartRateRange: nil
            )
        } else {
            day.trainingDetails?.work?.distanceKm = distance
        }
    }
    
    private func updateSprintPace(_ value: String) {
        if day.trainingDetails?.work == nil {
            day.trainingDetails?.work = MutableWorkoutSegment(
                description: nil, distanceKm: nil, distanceM: nil,
                timeMinutes: nil, pace: value.isEmpty ? nil : value, heartRateRange: nil
            )
        } else {
            day.trainingDetails?.work?.pace = value.isEmpty ? nil : value
        }
    }
    
    private func updateRecoveryDistance(_ value: String) {
        guard let distance = Double(value) else { return }
        if day.trainingDetails?.recovery == nil {
            day.trainingDetails?.recovery = MutableWorkoutSegment(
                description: nil, distanceKm: distance, distanceM: nil,
                timeMinutes: nil, pace: nil, heartRateRange: nil
            )
        } else {
            day.trainingDetails?.recovery?.distanceKm = distance
        }
    }
    
    private func updateRecoveryPace(_ value: String) {
        if day.trainingDetails?.recovery == nil {
            day.trainingDetails?.recovery = MutableWorkoutSegment(
                description: nil, distanceKm: nil, distanceM: nil,
                timeMinutes: nil, pace: value.isEmpty ? nil : value, heartRateRange: nil
            )
        } else {
            day.trainingDetails?.recovery?.pace = value.isEmpty ? nil : value
        }
    }
    
    private func updateRestInPlace(_ isRest: Bool) {
        if isRest {
            // 原地休息：清除距離和配速
            day.trainingDetails?.recovery?.distanceKm = nil
            day.trainingDetails?.recovery?.pace = nil
            recoveryDistance = ""
            recoveryPace = ""
        }
    }

    /// 應用間歇訓練模板
    private func applyTemplate(_ template: IntervalTemplate) {
        // 更新 UI 狀態
        repeats = String(template.repeats)
        sprintDistance = String(format: "%.1f", Double(template.distanceM) / 1000.0)
        isRestInPlace = true
        recoveryDistance = ""
        recoveryPace = ""

        // 獲取建議配速
        let suggestedPace = getSuggestedPace() ?? "4:30"
        sprintPace = suggestedPace

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

    @State private var segments: [EditableSegment] = []
    
    struct EditableSegment: Identifiable {
        let id = UUID()
        var description: String
        var distance: String
        var pace: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.EditSchedule.combinationSettings.localized)
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button(L10n.EditSchedule.addSegment.localized) {
                    segments.append(EditableSegment(description: "", distance: "", pace: ""))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            ForEach(segments.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(String(format: L10n.EditSchedule.segment.localized, index + 1))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        if segments.count > 1 {
                            Button(L10n.EditSchedule.delete.localized) {
                                segments.remove(at: index)
                                updateSegments()
                            }
                            .foregroundColor(.red)
                            .controlSize(.small)
                        }
                    }
                    
                    TextField(L10n.EditSchedule.segmentDescription.localized, text: $segments[index].description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.EditSchedule.distance.localized)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $segments[index].distance)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.EditSchedule.pace.localized)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField(L10n.EditSchedule.pacePlaceholder.localized, text: $segments[index].pace)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .onChange(of: segments[index].description) { oldValue, newValue in updateSegments() }
                .onChange(of: segments[index].distance) { oldValue, newValue in updateSegments() }
                .onChange(of: segments[index].pace) { oldValue, newValue in updateSegments() }
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
            loadSegments()
        }
    }
    
    private func loadSegments() {
        guard let details = day.trainingDetails,
              let progressionSegments = details.segments else {
            segments = [EditableSegment(description: "", distance: "", pace: "")]
            return
        }
        
        segments = progressionSegments.map { segment in
            EditableSegment(
                description: segment.description ?? "",
                distance: segment.distanceKm != nil ? String(format: "%.1f", segment.distanceKm!) : "",
                pace: segment.pace ?? ""
            )
        }
        
        if segments.isEmpty {
            segments = [EditableSegment(description: "", distance: "", pace: "")]
        }
    }
    
    private func updateSegments() {
        let mutableSegments = segments.map { editableSegment in
            MutableProgressionSegment(
                distanceKm: Double(editableSegment.distance),
                pace: editableSegment.pace.isEmpty ? nil : editableSegment.pace,
                description: editableSegment.description.isEmpty ? nil : editableSegment.description,
                heartRateRange: nil
            )
        }
        
        if day.trainingDetails == nil {
            // 如果沒有 trainingDetails，創建一個
            day.trainingDetails = MutableTrainingDetails(
                description: nil, distanceKm: nil, totalDistanceKm: nil,
                timeMinutes: nil, pace: nil, work: nil, recovery: nil,
                repeats: nil, heartRateRange: nil, segments: mutableSegments
            )
        } else {
            day.trainingDetails?.segments = mutableSegments
        }
        
        // 計算總距離
        let totalDistance = segments.compactMap { Double($0.distance) }.reduce(0, +)
        if totalDistance > 0 {
            day.trainingDetails?.totalDistanceKm = totalDistance
        }
    }
}

// MARK: - Long Run Detail Editor

struct LongRunDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    @State private var distance: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.longRunSettings.localized)
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.EditSchedule.distance.localized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $distance)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
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
            if let distanceKm = day.trainingDetails?.distanceKm {
                distance = String(format: "%.1f", distanceKm)
            }
        }
        .onChange(of: distance) { oldValue, newValue in
            updateDistance(newValue)
        }
    }
    
    private func updateDistance(_ distanceStr: String) {
        guard let distanceValue = Double(distanceStr) else { return }
        if day.trainingDetails != nil {
            day.trainingDetails?.distanceKm = distanceValue
        }
    }
}

// MARK: - Simple Training Detail Editor

struct SimpleTrainingDetailEditor: View {
    @Binding var day: MutableTrainingDay
    @ObservedObject var viewModel: TrainingPlanViewModel

    @State private var distance: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.EditSchedule.trainingSettings.localized)
                .font(.headline)
                .foregroundColor(.blue)
            
            if day.type != .rest {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.EditSchedule.distance.localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField(L10n.EditSchedule.distancePlaceholder.localized, text: $distance)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
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
        .onAppear {
            if let distanceKm = day.trainingDetails?.distanceKm {
                distance = String(format: "%.1f", distanceKm)
            }
        }
        .onChange(of: distance) { oldValue, newValue in
            if day.type != .rest {
                updateDistance(newValue)
            }
        }
    }
    
    private func updateDistance(_ distanceStr: String) {
        guard let distanceValue = Double(distanceStr) else { return }
        if day.trainingDetails != nil {
            day.trainingDetails?.distanceKm = distanceValue
        }
    }
}