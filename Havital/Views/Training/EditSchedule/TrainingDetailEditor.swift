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
            .navigationTitle(NSLocalizedString("edit_schedule.edit_training", comment: "編輯訓練"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
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

                        Button(NSLocalizedString("edit_schedule.save", comment: "儲存")) {
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
            Text("輕鬆跑設定")
                .font(.headline)
                .foregroundColor(.green)

            // 顯示建議配速提示和配速區間
            if let suggestedPace = getSuggestedPace() {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text("建議配速: \(suggestedPace)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("套用") {
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

                            Text("配速區間: \(paceRange.max) - \(paceRange.min)")
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
                Text("距離 (公里)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("例如: 5.0", text: $distance)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
            }
            
            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("訓練說明")
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
            Text("節奏跑設定")
                .font(.headline)
                .foregroundColor(.orange)

            // 顯示建議配速提示和配速區間
            if let suggestedPace = getSuggestedPace() {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text("建議配速: \(suggestedPace)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("套用") {
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

                            Text("配速區間: \(paceRange.max) - \(paceRange.min)")
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
                    Text("距離 (公里)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("例如: 8.0", text: $distance)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("配速 (分:秒/公里)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("例如: 4:30", text: $pace)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("訓練說明")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("間歇訓練設定")
                .font(.headline)
                .foregroundColor(.orange)

            // 顯示建議配速提示和配速區間
            if let suggestedPace = getSuggestedPace() {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        Text("衝刺段建議配速: \(suggestedPace)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("套用") {
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
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text("間歇配速區間: \(paceRange.max) - \(paceRange.min)")
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
                Text("重複次數")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("例如: 6", text: $repeats)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            // 衝刺段設定
            VStack(alignment: .leading, spacing: 12) {
                Text("衝刺段")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("距離 (公里)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        TextField("例如: 1.0", text: $sprintDistance)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("配速 (分:秒/公里)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        TextField("例如: 4:00", text: $sprintPace)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
            // 恢復段設定
            VStack(alignment: .leading, spacing: 12) {
                Text("恢復段")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Toggle("原地休息", isOn: $isRestInPlace)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if !isRestInPlace {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("距離 (公里)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField("例如: 0.4", text: $recoveryDistance)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("配速 (分:秒/公里)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField("例如: 5:30", text: $recoveryPace)
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
                    Text("訓練說明")
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
                Text("組合跑設定")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("新增區段") {
                    segments.append(EditableSegment(description: "", distance: "", pace: ""))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            ForEach(segments.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("區段 \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        if segments.count > 1 {
                            Button("刪除") {
                                segments.remove(at: index)
                                updateSegments()
                            }
                            .foregroundColor(.red)
                            .controlSize(.small)
                        }
                    }
                    
                    TextField("區段描述", text: $segments[index].description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("距離 (公里)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField("例如: 2.0", text: $segments[index].distance)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("配速 (分:秒/公里)")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            TextField("例如: 4:45", text: $segments[index].pace)
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
                    Text("訓練說明")
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
            Text("長距離跑設定")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("距離 (公里)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("例如: 15.0", text: $distance)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
            }
            
            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("訓練說明")
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
            Text("訓練設定")
                .font(.headline)
                .foregroundColor(.blue)
            
            if day.type != .rest {
                VStack(alignment: .leading, spacing: 8) {
                    Text("距離 (公里)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("例如: 5.0", text: $distance)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
            }
            
            if let details = day.trainingDetails, let desc = details.description {
                VStack(alignment: .leading, spacing: 8) {
                    Text("訓練說明")
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