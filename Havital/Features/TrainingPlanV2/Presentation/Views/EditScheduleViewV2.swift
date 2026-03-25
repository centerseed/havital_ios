import SwiftUI
import Foundation

/// V2 週課表編輯視圖
/// 適配 WeeklyPlanV2 和 TrainingPlanV2Repository
/// UI 結構與 V1 EditScheduleView 一致，不依賴 V1 TrainingPlanViewModel
struct EditScheduleViewV2: View {
    @ObservedObject var editViewModel: EditScheduleV2ViewModel
    @ObservedObject var planViewModel: TrainingPlanV2ViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingUnsavedChangesAlert = false
    @State private var hasUnsavedChanges = false
    @State private var showingPaceTable = false

    var body: some View {
        NavigationView {
            Group {
                if editViewModel.isEditingLoaded {
                    editModeView()
                } else {
                    ProgressView(NSLocalizedString("edit_schedule.loading_data", comment: "載入編輯資料..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(NSLocalizedString("edit_schedule.title", comment: "編輯週課表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("edit_schedule.cancel", comment: "取消")) {
                        if hasUnsavedChanges {
                            showingUnsavedChangesAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 配速表按鈕（有 VDOT 時顯示）
                        if editViewModel.currentVDOT != nil {
                            Button {
                                showingPaceTable = true
                            } label: {
                                Image(systemName: "speedometer")
                                    .font(AppFont.body())
                            }
                        }

                        // 儲存按鈕
                        Button(NSLocalizedString("edit_schedule.save", comment: "儲存")) {
                            Task {
                                await saveChanges()
                            }.tracked(from: "EditScheduleViewV2: saveChanges")
                        }
                        .disabled(!hasUnsavedChanges)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaceTable) {
            if let vdot = editViewModel.currentVDOT {
                PaceTableView(vdot: vdot, calculatedPaces: PaceCalculator.calculateTrainingPaces(vdot: vdot))
            }
        }
        .alert(NSLocalizedString("edit_schedule.unsaved_changes", comment: "未儲存的變更"), isPresented: $showingUnsavedChangesAlert) {
            Button(NSLocalizedString("edit_schedule.discard_changes", comment: "放棄變更"), role: .destructive) {
                dismiss()
            }
            Button(NSLocalizedString("edit_schedule.cancel", comment: "取消"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("edit_schedule.unsaved_changes_message", comment: "您有未儲存的變更，確定要放棄嗎？"))
        }
    }

    // MARK: - Edit Mode View

    @ViewBuilder
    private func editModeView() -> some View {
        List {
            ForEach($editViewModel.editingDays) { $day in
                SimplifiedDailyCardV2(
                    day: $day,
                    editViewModel: editViewModel,
                    onDataChanged: {
                        hasUnsavedChanges = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .onMove { source, destination in
                editViewModel.editingDays.move(fromOffsets: source, toOffset: destination)
                for i in editViewModel.editingDays.indices {
                    editViewModel.editingDays[i].dayIndex = "\(i + 1)"
                }
                hasUnsavedChanges = true
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Save

    private func saveChanges() async {
        do {
            let savedPlan = try await editViewModel.saveEdits()
            await MainActor.run {
                planViewModel.weeklyPlan = savedPlan
                planViewModel.planStatus = .ready(savedPlan)
                dismiss()
            }
        } catch {
            // 錯誤已在 ViewModel 記錄，不需要額外處理
            Logger.error("[EditScheduleViewV2] saveChanges failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - SimplifiedDailyCardV2

/// V2 版本的訓練日編輯卡片
/// 不依賴 TrainingPlanViewModel（V1 移除），功能與 V1 SimplifiedDailyCard 一致
struct SimplifiedDailyCardV2: View {
    @Binding var day: MutableTrainingDay
    let editViewModel: EditScheduleV2ViewModel
    var onDataChanged: (() -> Void)? = nil

    @State private var showingEditSheet = false
    @State private var showingDistancePicker = false
    @State private var showingPacePicker = false
    @State private var showingInfoAlert = false

    private var displayDayIndex: Int { day.dayIndexInt }

    private func getTypeColor() -> Color {
        switch day.type {
        case .easyRun, .easy, .recovery_run, .yoga, .lsd:
            return .green
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

    private var isComplexTraining: Bool {
        switch day.type {
        case .interval, .combination, .progression,
             .strides, .hillRepeats, .cruiseIntervals,
             .shortInterval, .longInterval, .norwegian4x4, .yasso800,
             .fartlek, .fastFinish:
            return true
        default:
            return false
        }
    }

    private var complexTrainingSummary: String {
        guard let details = day.trainingDetails else { return "" }
        switch day.type {
        case .interval, .strides, .hillRepeats, .cruiseIntervals, .shortInterval, .longInterval:
            if let repeats = details.repeats, let work = details.work {
                let distText = work.distanceKm.map { String(format: "%.0fm", $0 * 1000) } ?? ""
                let paceText = work.pace ?? ""
                return "\(repeats) × \(distText)" + (paceText.isEmpty ? "" : " @ \(paceText)")
            }
        case .norwegian4x4, .yasso800:
            if let repeats = details.repeats, let work = details.work {
                let timeText = work.timeMinutes.map { "\(Int($0))分鐘" } ?? ""
                let paceText = work.pace ?? ""
                return "\(repeats) × \(timeText)" + (paceText.isEmpty ? "" : " @ \(paceText)")
            }
        case .combination, .progression, .fartlek, .fastFinish:
            if let segments = details.segments {
                let total = details.totalDistanceKm ?? segments.compactMap { $0.distanceKm }.reduce(0, +)
                return "\(segments.count) 段 · \(String(format: "%.1f", total)) km"
            }
        default:
            break
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            detailsView
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(getTypeColor().opacity(0.4), lineWidth: 1.5)
        )
        .sheet(isPresented: $showingEditSheet) {
            TrainingEditSheetV2(
                day: day,
                onSave: { updatedDay in
                    day = updatedDay
                    onDataChanged?()
                },
                paceHelper: PaceCalculationHelper(vdot: editViewModel.currentVDOT)
            )
        }
        .sheet(isPresented: $showingDistancePicker) {
            DistanceWheelPicker(selectedDistance: Binding(
                get: { day.trainingDetails?.distanceKm ?? 5.0 },
                set: { newValue in
                    if var details = day.trainingDetails {
                        details.distanceKm = newValue
                        day.trainingDetails = details
                        onDataChanged?()
                    }
                }
            ))
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingPacePicker) {
            PaceWheelPicker(
                selectedPace: Binding(
                    get: { day.trainingDetails?.pace ?? "5:00" },
                    set: { newValue in
                        if var details = day.trainingDetails {
                            details.pace = newValue
                            day.trainingDetails = details
                            onDataChanged?()
                        }
                    }
                ),
                referenceDistance: day.trainingDetails?.distanceKm
            )
            .presentationDetents([.height(380)])
        }
        .alert(L10n.EditSchedule.cannotEdit.localized, isPresented: $showingInfoAlert) {
            Button(L10n.EditSchedule.confirm.localized, role: .cancel) { }
        } message: {
            Text(editViewModel.getEditStatusMessage(for: displayDayIndex))
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(editViewModel.weekdayName(for: "\(displayDayIndex)"))
                    .font(AppFont.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let date = editViewModel.getDateForDay(dayIndex: displayDayIndex) {
                    Text(editViewModel.formatShortDate(date))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50, alignment: .leading)

            trainingTypeMenu

            Spacer()

            if day.isTrainingDay {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(AppFont.body())
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Details

    private var detailsView: some View {
        Group {
            if day.isTrainingDay {
                Rectangle()
                    .fill(getTypeColor().opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                if isComplexTraining {
                    Text(complexTrainingSummary)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    simpleTrainingControls
                }

                if day.warmup != nil || day.cooldown != nil {
                    warmupCooldownSummary
                }
            }
        }
    }

    @ViewBuilder
    private var warmupCooldownSummary: some View {
        HStack(spacing: 8) {
            if let warmup = day.warmup, let dist = warmup.distanceKm {
                Text("🔥 暖跑 \(String(format: "%.1f", dist))km")
                    .font(AppFont.caption())
                    .foregroundColor(.orange)
            }
            if let cooldown = day.cooldown, let dist = cooldown.distanceKm {
                Text("❄️ 緩和 \(String(format: "%.1f", dist))km")
                    .font(AppFont.caption())
                    .foregroundColor(.blue)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var simpleTrainingControls: some View {
        HStack(spacing: 12) {
            if day.trainingDetails?.pace != nil {
                Button {
                    showingPacePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("配速:")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Text(day.trainingDetails?.pace ?? "")
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            if let distance = day.trainingDetails?.distanceKm ?? day.trainingDetails?.totalDistanceKm {
                Button {
                    showingDistancePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("距離:")
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f km", distance))
                            .font(AppFont.caption())
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Training Type Menu

    @ViewBuilder
    private var trainingTypeMenu: some View {
        Menu {
            Section(header: Text(NSLocalizedString("edit_schedule.category_easy", comment: "輕鬆訓練"))) {
                Button(L10n.EditSchedule.easyRun.localized) { updateTrainingType(.easyRun) }
                Button(L10n.EditSchedule.recoveryRun.localized) { updateTrainingType(.recovery_run) }
            }
            Section(header: Text(NSLocalizedString("edit_schedule.category_intensity", comment: "強度訓練"))) {
                Button(L10n.EditSchedule.tempoRun.localized) { updateTrainingType(.tempo) }
                Button(L10n.EditSchedule.thresholdRun.localized) { updateTrainingType(.threshold) }
                Button(L10n.EditSchedule.intervalTraining.localized) { updateTrainingType(.interval) }
                Button(DayType.strides.localizedName) { updateTrainingType(.strides) }
                Button(DayType.hillRepeats.localizedName) { updateTrainingType(.hillRepeats) }
                Button(DayType.cruiseIntervals.localizedName) { updateTrainingType(.cruiseIntervals) }
                Button(DayType.shortInterval.localizedName) { updateTrainingType(.shortInterval) }
                Button(DayType.longInterval.localizedName) { updateTrainingType(.longInterval) }
                Button(DayType.norwegian4x4.localizedName) { updateTrainingType(.norwegian4x4) }
                Button(DayType.yasso800.localizedName) { updateTrainingType(.yasso800) }
                Button(DayType.fartlek.localizedName) { updateTrainingType(.fartlek) }
                Button(DayType.racePace.localizedName) { updateTrainingType(.racePace) }
                Button(L10n.EditSchedule.combinationRun.localized) { updateTrainingType(.combination) }
            }
            Section(header: Text(NSLocalizedString("edit_schedule.category_long", comment: "長距離訓練"))) {
                Button(L10n.EditSchedule.longEasyRun.localized) { updateTrainingType(.lsd) }
                Button(L10n.EditSchedule.longDistanceRun.localized) { updateTrainingType(.longRun) }
                Button(DayType.progression.localizedName) { updateTrainingType(.progression) }
                Button(DayType.fastFinish.localizedName) { updateTrainingType(.fastFinish) }
            }
            Section(header: Text(NSLocalizedString("edit_schedule.category_other", comment: "其他"))) {
                Button(L10n.EditSchedule.rest.localized) { updateTrainingType(.rest) }
                Button(DayType.crossTraining.localizedName) { updateTrainingType(.crossTraining) }
                Button(DayType.strength.localizedName) { updateTrainingType(.strength) }
                Button(DayType.yoga.localizedName) { updateTrainingType(.yoga) }
                Button(DayType.hiking.localizedName) { updateTrainingType(.hiking) }
                Button(DayType.cycling.localizedName) { updateTrainingType(.cycling) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(day.type.localizedName)
                    .font(AppFont.bodySmall())
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(AppFont.caption())
            }
            .foregroundColor(getTypeColor())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(getTypeColor().opacity(0.15))
            .cornerRadius(8)
        }
    }

    // MARK: - Update Training Type (reuse V1 logic)

    // MARK: - Warmup/cooldown type classification

    private func typeNeedsWarmupCooldown(_ type: DayType) -> Bool {
        let noWarmupTypes: Set<DayType> = [
            .easyRun, .easy, .recovery_run, .lsd, .rest,
            .strength, .crossTraining, .yoga, .hiking, .cycling,
            .swimming, .elliptical, .rowing
        ]
        return !noWarmupTypes.contains(type)
    }

    private func defaultWarmupCooldown(vdot: Double) -> (warmup: RunSegment, cooldown: RunSegment) {
        let recoveryPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:30"
        let warmup = RunSegment(
            distanceKm: 2.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
            durationMinutes: nil, durationSeconds: nil,
            pace: recoveryPace, heartRateRange: nil,
            intensity: "easy", description: "暖跑"
        )
        let cooldown = RunSegment(
            distanceKm: 1.0, distanceM: nil, distanceDisplay: nil, distanceUnit: nil,
            durationMinutes: nil, durationSeconds: nil,
            pace: recoveryPace, heartRateRange: nil,
            intensity: "easy", description: "緩和跑"
        )
        return (warmup, cooldown)
    }

    private func updateTrainingType(_ newType: DayType) {
        day.trainingType = newType.rawValue
        let vdot = editViewModel.currentVDOT ?? PaceCalculator.defaultVDOT

        switch newType {
        case .rest:
            day.dayTarget = "休息日"
            day.trainingDetails = nil
            day.warmup = nil
            day.cooldown = nil

        case .easyRun, .easy, .recovery_run:
            day.dayTarget = newType == .recovery_run ? "恢復跑：低強度恢復訓練" : "輕鬆跑：恢復和建立有氧基礎"
            let pace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 5.0, pace: pace)
            day.warmup = nil
            day.cooldown = nil

        case .tempo, .threshold:
            day.dayTarget = newType == .tempo ? "節奏跑：乳酸閾值訓練" : "閾值跑：提升乳酸清除能力"
            let pace = PaceCalculator.getSuggestedPace(for: newType.rawValue, vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 8.0, pace: pace)
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .interval:
            day.dayTarget = "間歇訓練：提升VO2max和速度"
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.4, distanceM: 400, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: nil, distanceKm: 0.2, distanceM: 200, timeMinutes: nil, pace: rPace, heartRateRange: nil),
                repeats: 4
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .longRun:
            day.dayTarget = "長距離跑：建立耐力基礎"
            let pace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 15.0, pace: pace)
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .lsd:
            day.dayTarget = "LSD長距離慢跑：輕鬆配速建立有氧基礎"
            let pace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 20.0, pace: pace)
            day.warmup = nil
            day.cooldown = nil

        case .progression:
            day.dayTarget = "漸進配速跑：從慢到快逐漸加速"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 12.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 4.0, pace: easyPace, description: "輕鬆配速"),
                    MutableProgressionSegment(distanceKm: 4.0, pace: tempoPace, description: "節奏配速"),
                    MutableProgressionSegment(distanceKm: 4.0, pace: "4:30", description: "加速")
                ]
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .combination:
            day.dayTarget = "組合訓練：多配速混合訓練"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:30"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 10.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 3.0, pace: easyPace, description: "輕鬆跑"),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: "節奏跑"),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "輕鬆跑")
                ]
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .fartlek:
            day.dayTarget = "法特雷克：變速跑訓練配速轉換能力"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 8.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "熱身"),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: "快跑"),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "恢復"),
                    MutableProgressionSegment(distanceKm: 1.0, pace: tempoPace, description: "快跑"),
                    MutableProgressionSegment(distanceKm: 2.0, pace: easyPace, description: "收操")
                ]
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .fastFinish:
            day.dayTarget = "快結尾長跑：後段加速訓練"
            let easyPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:00"
            let tempoPace = PaceCalculator.getSuggestedPace(for: "tempo", vdot: vdot) ?? "5:00"
            day.trainingDetails = MutableTrainingDetails(
                totalDistanceKm: 16.0,
                segments: [
                    MutableProgressionSegment(distanceKm: 11.0, pace: easyPace, description: "輕鬆跑"),
                    MutableProgressionSegment(distanceKm: 5.0, pace: tempoPace, description: "節奏跑")
                ]
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .racePace:
            day.dayTarget = "比賽配速跑：熟悉目標比賽節奏"
            let pace = PaceCalculator.getSuggestedPace(for: "marathon", vdot: vdot) ?? "5:15"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 10.0, pace: pace)
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .strides:
            day.dayTarget = "大步跑：短距離衝刺，提升跑步經濟性"
            let pace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.1, distanceM: 100, timeMinutes: nil, pace: pace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "原地休息1分鐘", distanceKm: nil, distanceM: nil, timeMinutes: 1.0, pace: nil, heartRateRange: nil),
                repeats: 6
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .hillRepeats:
            day.dayTarget = "山坡重複跑：上坡衝刺訓練腿部力量"
            let pace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.2, distanceM: 200, timeMinutes: nil, pace: pace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "慢跑下坡恢復", distanceKm: nil, distanceM: nil, timeMinutes: 2.0, pace: nil, heartRateRange: nil),
                repeats: 6
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .cruiseIntervals:
            day.dayTarget = "巡航間歇：閾值配速間歇訓練"
            let tPace = PaceCalculator.getSuggestedPace(for: "threshold", vdot: vdot) ?? "4:45"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 1.0, distanceM: 1000, timeMinutes: nil, pace: tPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "恢復跑1分鐘", distanceKm: nil, distanceM: nil, timeMinutes: 1.0, pace: rPace, heartRateRange: nil),
                repeats: 4
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .shortInterval:
            day.dayTarget = "短間歇：提升速度和無氧能力"
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.4, distanceM: 400, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "恢復跑", distanceKm: 0.4, distanceM: 400, timeMinutes: nil, pace: rPace, heartRateRange: nil),
                repeats: 12
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .longInterval:
            day.dayTarget = "長間歇：提升VO2max和速度耐力"
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:15"
            let rPace = PaceCalculator.getSuggestedPace(for: "easy", vdot: vdot) ?? "6:30"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 1.0, distanceM: 1000, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "輕鬆跑恢復", distanceKm: nil, distanceM: nil, timeMinutes: 2.5, pace: rPace, heartRateRange: nil),
                repeats: 5
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .norwegian4x4:
            day.dayTarget = "挪威4x4：4組4分鐘高強度間歇"
            let pace = PaceCalculator.getPaceForPercentage(0.92, vdot: vdot)
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: "高強度跑", distanceKm: 0.9, distanceM: 900, timeMinutes: 4.0, pace: pace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "恢復跑3分鐘", distanceKm: nil, distanceM: nil, timeMinutes: 3.0, pace: rPace, heartRateRange: nil),
                repeats: 4
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .yasso800:
            day.dayTarget = "亞索800：800m重複跑，VO2max訓練"
            let iPace = PaceCalculator.getSuggestedPace(for: "interval", vdot: vdot) ?? "4:30"
            let rPace = PaceCalculator.getSuggestedPace(for: "recovery", vdot: vdot) ?? "7:00"
            day.trainingDetails = MutableTrainingDetails(
                work: MutableWorkoutSegment(description: nil, distanceKm: 0.8, distanceM: 800, timeMinutes: nil, pace: iPace, heartRateRange: nil),
                recovery: MutableWorkoutSegment(description: "等時恢復", distanceKm: nil, distanceM: nil, timeMinutes: nil, pace: rPace, heartRateRange: nil),
                repeats: 8
            )
            let wc = defaultWarmupCooldown(vdot: vdot)
            day.warmup = wc.warmup
            day.cooldown = wc.cooldown

        case .crossTraining:
            day.dayTarget = "交叉訓練：非跑步運動訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .strength:
            day.dayTarget = "肌力訓練：增強肌肉力量"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .yoga:
            day.dayTarget = "瑜珈：柔軟度和恢復訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .hiking:
            day.dayTarget = "登山健行：有氧耐力訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        case .cycling:
            day.dayTarget = "騎車：低衝擊有氧訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: nil)
            day.warmup = nil
            day.cooldown = nil

        default:
            day.dayTarget = "自訂訓練"
            day.trainingDetails = MutableTrainingDetails(distanceKm: 6.0)
            day.warmup = nil
            day.cooldown = nil
        }

        onDataChanged?()
    }
}
