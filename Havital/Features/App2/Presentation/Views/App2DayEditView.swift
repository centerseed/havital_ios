import SwiftUI

// MARK: - App2DayEditView
/// 2.0 的「編輯單日」——設計 **frame-05**（距離制間歇）／**frame-06**（組合訓練）／
/// **frame-07**（肌力訓練）／**frame-08**（休息日）。
///
/// **只換 UI，不換狀態與寫入。** 編輯狀態仍是既有的 `TrainingDayEditState`
/// （1.4 的 `TrainingEditSheetV2` 用的同一個 class），寫回仍是
/// `toMutableTrainingDay(originalDay:)`；欄位校驗（肌力日動作清單不得為空）也照舊。
/// 這一層負責的是設計稿的版面：hero、快選模板、stepper、分段卡、動作列、休息日轉換。
///
/// 1.4 的 `TrainingEditSheetV2` **不刪**——1.0 殼還在用它。
struct App2DayEditView: View {

    let originalDay: MutableTrainingDay
    let paceHelper: PaceCalculationHelper
    let onSave: (MutableTrainingDay) -> Void

    @StateObject private var editState: TrainingDayEditState
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaceTable = false
    @State private var wheel: WheelTarget?
    @State private var pendingStrengthType: String?
    @State private var showingStrengthTypeAlert = false
    @State private var selectedTemplate: String?

    init(
        day: MutableTrainingDay,
        paceHelper: PaceCalculationHelper,
        onSave: @escaping (MutableTrainingDay) -> Void
    ) {
        self.originalDay = day
        self.paceHelper = paceHelper
        self.onSave = onSave
        _editState = StateObject(wrappedValue: TrainingDayEditState(from: day))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            App2EditTopBar(
                title: L10n.EditSchedule.editTraining.localized,
                onCancel: { dismiss() },
                // 肌力日與休息日沒有配速，整顆「配速表」鈕不出現（設計 §16／§17）。
                onPaceTable: showsPaceTable ? { showingPaceTable = true } : nil,
                saveEnabled: true,
                onSave: saveAndDismiss,
                identifierPrefix: "App2_DayEdit"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    App2EditHero(
                        kicker: kicker,
                        title: editState.type.localizedName,
                        accent: accent,
                        detail: heroDetail
                    )
                    .padding(.bottom, 2)

                    sections
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
        }
        .background(App2EditStripeBackground())
        .sheet(isPresented: $showingPaceTable) {
            if let vdot = paceHelper.currentVDOT {
                PaceTableView(vdot: vdot, calculatedPaces: paceHelper.calculatedPaces)
            }
        }
        .sheet(item: $wheel) { target in
            wheelSheet(for: target)
                .presentationDetents([.fraction(0.56)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(26)
        }
        .alert(L10n.EditSchedule.typeChangeAlert.localized, isPresented: $showingStrengthTypeAlert) {
            Button(L10n.EditSchedule.confirm.localized, role: .destructive) {
                if let pendingStrengthType {
                    editState.strengthType = pendingStrengthType
                    editState.strengthExercises = StrengthEditorV2.defaultExercises[pendingStrengthType] ?? []
                }
                pendingStrengthType = nil
            }
            Button(L10n.EditSchedule.cancel.localized, role: .cancel) { pendingStrengthType = nil }
        }
        .accessibilityIdentifier("App2_DayEditView")
    }

    // MARK: - Hero

    private var accent: Color { editState.type.app2StripColor }

    private var showsPaceTable: Bool {
        guard paceHelper.currentVDOT != nil, !paceHelper.calculatedPaces.isEmpty else { return false }
        switch editState.type.scheduleEditorFamily {
        case .strength, .rest, .cross: return false
        default: return true
        }
    }

    private var kicker: String {
        switch editState.type.scheduleEditorFamily {
        case .easy:             return L10n.App2.DayEdit.kickerEasy.localized
        case .tempo:            return L10n.App2.DayEdit.kickerTempo.localized
        case .longRun:          return L10n.App2.DayEdit.kickerLongRun.localized
        case .intervalDistance: return L10n.App2.DayEdit.kickerIntervalDistance.localized
        case .norwegian4x4, .yasso800:
            return L10n.App2.DayEdit.kickerIntervalTime.localized
        case .combination:      return L10n.App2.DayEdit.kickerCombination.localized
        case .strength:         return L10n.App2.DayEdit.kickerStrength.localized
        case .rest:             return L10n.App2.DayEdit.kickerRest.localized
        case .cross:            return L10n.App2.DayEdit.kickerCross.localized
        }
    }

    /// hero 的說明段。
    ///
    /// **不另寫一份課型文案**：走既有的 `TrainingTypeInfo.howToRun`（三語已齊）。
    /// 組合訓練另外點名它是共用編輯器（設計 §15 明寫這一句）。
    private var heroDetail: String? {
        if editState.type.scheduleEditorFamily == .combination {
            return L10n.App2.DayEdit.combinationHint.localized
        }
        if let info = TrainingTypeInfo.info(for: editState.type) {
            return info.howToRun
        }
        return editState.dayTarget.isEmpty ? nil : editState.dayTarget
    }

    // MARK: - 依家族分流的區塊
    //
    // 走 `scheduleEditorFamily`：全部 DayType 必須有家族，禁止 default 把結構化課表
    // 打成簡易編輯器（與 1.4 的 `TrainingEditSheetV2` 同一條規則）。

    @ViewBuilder
    private var sections: some View {
        switch editState.type.scheduleEditorFamily {
        case .easy:
            simpleRunCard(showsPace: true)
            supplementaryStrengthSection
        case .tempo, .longRun:
            simpleRunCard(showsPace: true)
            warmupCooldownCard
            supplementaryStrengthSection
        case .intervalDistance, .yasso800:
            quickTemplatesSection
            repeatsCard
            sprintCard
            recoveryCard
            warmupCooldownCard
            supplementaryStrengthSection
        case .norwegian4x4:
            repeatsCard
            sprintCardTimeBased
            recoveryCard
            warmupCooldownCard
            supplementaryStrengthSection
        case .combination:
            segmentListSection
            totalDistanceCard
            compactWarmupCooldownCard
            supplementaryStrengthSection
        case .strength:
            strengthTypeCard
            strengthDurationCard
            exerciseListCard
            strengthFooter
        case .rest:
            restDaySection
        case .cross:
            simpleRunCard(showsPace: false)
            supplementaryStrengthSection
        }
    }

    // MARK: - 簡單跑步日（配速／距離兩個等寬欄位）

    private func simpleRunCard(showsPace: Bool) -> some View {
        App2Card(spacing: 10) {
            App2EditCardHeader(dotColor: accent, title: editState.type.localizedName)
            HStack(spacing: 9) {
                if showsPace {
                    App2EditFieldBlock(
                        label: L10n.App2.PlanEdit.paceChip.localized,
                        value: editState.pace.isEmpty ? "--:--" : "\(editState.pace)/km",
                        accent: accent.app2Darkened
                    ) { wheel = .simplePace }
                }
                App2EditFieldBlock(
                    label: L10n.App2.PlanEdit.distanceChip.localized,
                    value: "\(App2NumberFormat.grouped(editState.distance, maximumFractionDigits: 1)) km"
                ) { wheel = .simpleDistance }
            }
        }
        .accessibilityIdentifier("App2_DayEditSimpleCard")
    }

    // MARK: - frame-05 快選模板

    private var quickTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L10n.App2.DayEdit.quickTemplates.localized)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.DayEdit.quickTemplatesHint.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 0)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ScheduleTypeDefaults.intervalQuickTemplates) { template in
                    templateChip(template)
                }
            }
        }
        .accessibilityIdentifier("App2_DayEditTemplates")
    }

    private func templateChip(_ template: ScheduleTypeDefaults.IntervalTemplate) -> some View {
        let isSelected = selectedTemplate == template.id
            || (editState.repeats == template.repeats
                && abs(editState.workDistance - template.distanceKm) < 0.001)
        return Text(template.name)
            .font(.app2Mono(13, weight: .black))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isSelected ? Color.white : App2Theme.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [App2Theme.accentOrangeSoft, App2Theme.accentOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isSelected ? .clear : App2Theme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: isSelected ? App2Theme.accentOrange.opacity(0.32) : .clear,
                radius: isSelected ? 8 : 0, x: 0, y: isSelected ? 5 : 0
            )
            .contentShape(Rectangle())
            .onTapGesture { apply(template) }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_DayEditTemplate_\(template.id)")
    }

    private func apply(_ template: ScheduleTypeDefaults.IntervalTemplate) {
        selectedTemplate = template.id
        editState.repeats = template.repeats
        editState.workDistance = template.distanceKm
        editState.isRestInPlace = true
        if let suggested = paceHelper.getSuggestedPace(for: editState.trainingType) {
            editState.workPace = suggested
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - frame-05 重複次數（灰「−」／藍「＋」）

    private var repeatsCard: some View {
        App2Card(spacing: 0) {
            HStack {
                Text(L10n.EditSchedule.repeats.localized)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                App2EditStepper(
                    value: editState.repeats,
                    unit: L10n.App2.DayEdit.repeatsUnit.localized,
                    identifier: "App2_DayEditRepeats",
                    onMinus: { editState.repeats = max(1, editState.repeats - 1) },
                    onPlus: { editState.repeats = min(30, editState.repeats + 1) }
                )
            }
        }
    }

    // MARK: - frame-05 衝刺段／恢復段

    private var sprintCard: some View {
        App2Card(spacing: 0) {
            App2EditCardHeader(dotColor: App2Theme.accentOrangeSoft, title: L10n.EditSchedule.sprintSegment.localized)
            App2EditValueRow(
                label: L10n.App2.PlanEdit.paceChip.localized,
                value: editState.workPace.isEmpty ? "--:--" : "\(editState.workPace)/km"
            ) { wheel = .workPace }
            App2EditDivider(inset: 0)
            App2EditValueRow(
                label: L10n.App2.PlanEdit.distanceChip.localized,
                value: String(format: "%.0fm", editState.workDistance * 1000)
            ) { wheel = .workDistance }
        }
        .accessibilityIdentifier("App2_DayEditSprintCard")
    }

    /// 挪威 4x4 是時間制：衝刺段是「幾分鐘」，不是「幾公尺」。
    private var sprintCardTimeBased: some View {
        App2Card(spacing: 0) {
            App2EditCardHeader(dotColor: App2Theme.accentOrangeSoft, title: L10n.EditSchedule.sprintSegment.localized)
            App2EditValueRow(
                label: L10n.App2.PlanEdit.paceChip.localized,
                value: editState.workPace.isEmpty ? "--:--" : "\(editState.workPace)/km"
            ) { wheel = .workPace }
            App2EditDivider()
            App2EditValueRow(
                label: L10n.EditSchedule.time.localized,
                value: String(
                    format: NSLocalizedString("time.minutes_format", comment: ""),
                    Int(editState.workTimeMinutes.rounded())
                )
            ) { wheel = .workTime }
        }
        .accessibilityIdentifier("App2_DayEditSprintCard")
    }

    private var recoveryCard: some View {
        App2Card(spacing: 0) {
            App2EditCardHeader(dotColor: Color(hex: "#EAB308"), title: L10n.EditSchedule.recoverySegment.localized)
            App2EditToggleRow(
                label: L10n.EditSchedule.restInPlace.localized,
                isOn: $editState.isRestInPlace,
                identifier: "App2_DayEditRestInPlace"
            )
            App2EditDivider()
            // 條件顯示（設計 §14）：開＝只設休息秒數；關＝改成恢復配速與距離兩列。
            if editState.isRestInPlace {
                App2EditValueRow(
                    label: L10n.EditSchedule.restTime.localized,
                    value: editState.formatRecoveryTime(editState.recoveryTimeMinutes)
                ) { wheel = .restTime }
            } else {
                App2EditValueRow(
                    label: L10n.App2.PlanEdit.paceChip.localized,
                    value: editState.recoveryPace.isEmpty ? "--:--" : "\(editState.recoveryPace)/km"
                ) { wheel = .recoveryPace }
                App2EditDivider()
                App2EditValueRow(
                    label: L10n.App2.PlanEdit.distanceChip.localized,
                    value: String(format: "%.0fm", editState.recoveryDistance * 1000)
                ) { wheel = .recoveryDistance }
            }
            Text(L10n.App2.DayEdit.recoveryNote.localized)
                .font(.system(size: 12, weight: .semibold))
                .lineSpacing(2)
                .foregroundStyle(App2Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .accessibilityIdentifier("App2_DayEditRecoveryCard")
    }

    // MARK: - 暖身與緩和

    @ViewBuilder
    private var warmupCooldownCard: some View {
        if editState.needsWarmupCooldown {
            App2Card(spacing: 12) {
                Text(L10n.App2.DayEdit.warmupCooldown.localized)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)

                warmupCooldownBlock(
                    symbol: "flame",
                    name: NSLocalizedString("schedule_editor.segment.warmup", comment: ""),
                    isOn: $editState.hasWarmup,
                    distance: editState.warmupDistance,
                    pace: editState.warmupPace,
                    identifier: "Warmup",
                    onPace: { wheel = .warmupPace },
                    onDistance: { wheel = .warmupDistance }
                )

                App2EditDivider()

                warmupCooldownBlock(
                    symbol: "wind",
                    name: NSLocalizedString("schedule_editor.segment.cooldown", comment: ""),
                    isOn: $editState.hasCooldown,
                    distance: editState.cooldownDistance,
                    pace: editState.cooldownPace,
                    identifier: "Cooldown",
                    onPace: { wheel = .cooldownPace },
                    onDistance: { wheel = .cooldownDistance }
                )
            }
            .accessibilityIdentifier("App2_DayEditWarmupCooldown")
        }
    }

    private func warmupCooldownBlock(
        symbol: String,
        name: String,
        isOn: Binding<Bool>,
        distance: Double,
        pace: String,
        identifier: String,
        onPace: @escaping () -> Void,
        onDistance: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isOn.wrappedValue ? App2Theme.accentGreen : App2Theme.inkTertiary)
                Text(name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(isOn.wrappedValue ? App2Theme.inkPrimary : Color(hex: "#8A929C"))
                if isOn.wrappedValue {
                    Text("≈ \(pace)")
                        .font(.app2Mono(13, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                } else {
                    // 關閉態（設計 §15 明列）：數值換成「未加入」。
                    Text(L10n.App2.DayEdit.notAdded.localized)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.chevron)
                }
                Spacer(minLength: 6)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(App2Theme.accentBlue)
                    .accessibilityIdentifier("App2_DayEdit\(identifier)Toggle")
            }

            if isOn.wrappedValue {
                HStack(spacing: 9) {
                    App2EditFieldBlock(
                        label: L10n.App2.PlanEdit.distanceChip.localized,
                        value: "\(App2NumberFormat.grouped(distance, maximumFractionDigits: 1)) km",
                        onTap: onDistance
                    )
                    App2EditFieldBlock(
                        label: L10n.App2.PlanEdit.paceChip.localized,
                        value: pace.isEmpty ? "--:--" : pace,
                        onTap: onPace
                    )
                }
            }
        }
    }

    /// 組合訓練頁的精簡版：只有兩列開關，不展開欄位（設計 §15）。
    @ViewBuilder
    private var compactWarmupCooldownCard: some View {
        if editState.needsWarmupCooldown {
            App2Card(spacing: 8) {
                Text(L10n.App2.DayEdit.warmupCooldown.localized)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                compactSegmentRow(
                    symbol: "flame",
                    name: NSLocalizedString("schedule_editor.segment.warmup", comment: ""),
                    isOn: $editState.hasWarmup,
                    value: "\(App2NumberFormat.grouped(editState.warmupDistance, maximumFractionDigits: 1)) km · \(editState.warmupPace)",
                    identifier: "Warmup"
                )
                App2EditDivider()
                compactSegmentRow(
                    symbol: "wind",
                    name: NSLocalizedString("schedule_editor.segment.cooldown", comment: ""),
                    isOn: $editState.hasCooldown,
                    value: "\(App2NumberFormat.grouped(editState.cooldownDistance, maximumFractionDigits: 1)) km · \(editState.cooldownPace)",
                    identifier: "Cooldown"
                )
            }
            .accessibilityIdentifier("App2_DayEditWarmupCooldown")
        }
    }

    private func compactSegmentRow(
        symbol: String,
        name: String,
        isOn: Binding<Bool>,
        value: String,
        identifier: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isOn.wrappedValue ? App2Theme.accentGreen : Color(hex: "#8A97A6"))
            Text(name)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(isOn.wrappedValue ? App2Theme.inkPrimary : Color(hex: "#8A929C"))
            Spacer(minLength: 6)
            Text(isOn.wrappedValue ? value : L10n.App2.DayEdit.notAdded.localized)
                .font(isOn.wrappedValue ? .app2Mono(13, weight: .bold) : .system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isOn.wrappedValue ? App2Theme.inkTertiary : App2Theme.chevron)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(App2Theme.accentBlue)
                .accessibilityIdentifier("App2_DayEdit\(identifier)Toggle")
        }
        .padding(.vertical, 4)
    }

    // MARK: - frame-06 分段清單

    private var segmentListSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L10n.App2.DayEdit.segmentList.localized)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(String(format: L10n.App2.DayEdit.segmentCount.localized, editState.segments.count))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    Text(L10n.App2.DayEdit.dragToReorder.localized)
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(App2Theme.inkTertiary)
            }

            App2DragReorderList(
                count: editState.segments.count,
                spacing: 9,
                placeholderText: { _ in nil },
                onCommit: { from, to in
                    let moved = editState.segments.remove(at: from)
                    editState.segments.insert(moved, at: to)
                }
            ) { index in
                segmentCard(index: index)
            }

            App2DashedAddButton(
                title: L10n.EditSchedule.addSegment.localized,
                tint: App2Theme.accentOrangeSoft,
                border: App2Theme.accentOrangeSoft.opacity(0.85),
                identifier: "App2_DayEditAddSegment"
            ) {
                let defaultPace = paceHelper.getSuggestedPace(for: "easy") ?? "6:00"
                editState.addSegment(defaultPace: defaultPace)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .accessibilityIdentifier("App2_DayEditSegments")
    }

    private func segmentCard(index: Int) -> some View {
        let segment = editState.segments[index]
        // 分段的「類型」在資料裡是 `description`（`輕鬆`／`快`…），編輯器沒有第二個欄位。
        let isFast = Self.isFastSegment(segment, easyPace: paceHelper.getSuggestedPace(for: "easy"))
        let stripe = isFast ? App2Theme.accentOrangeSoft : App2Theme.accentGreenBright
        return App2LeftStripCard(strip: stripe, cornerRadius: 14) {
            HStack(spacing: 8) {
                App2DragHandle(width: 26, height: 32)
                App2EditDropdownChip(
                    text: segment.description?.isEmpty == false
                        ? (segment.description ?? "")
                        : (isFast
                            ? L10n.App2.DayEdit.segmentFast.localized
                            : L10n.App2.DayEdit.segmentEasy.localized),
                    foreground: stripe.app2Darkened,
                    background: stripe.opacity(0.13)
                )
                Spacer(minLength: 4)
                if editState.segments.count > 1 {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(App2Theme.cardBorder, lineWidth: 1))
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color(hex: "#DC7676"))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editState.removeSegment(at: index) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("App2_DayEditSegmentDelete_\(index)")
                }
            }
            HStack(spacing: 9) {
                App2EditFieldBlock(
                    label: L10n.App2.PlanEdit.paceChip.localized,
                    value: segment.pace.isEmpty ? "--:--" : segment.pace
                ) { wheel = .segmentPace(index) }
                App2EditFieldBlock(
                    label: L10n.App2.PlanEdit.distanceChip.localized,
                    value: segmentDistanceText(segment.distance)
                ) { wheel = .segmentDistance(index) }
            }
        }
        .accessibilityIdentifier("App2_DayEditSegment_\(index)")
    }

    private func segmentDistanceText(_ km: Double) -> String {
        km < 1 ? String(format: "%.0f m", km * 1000) : "\(App2NumberFormat.grouped(km, maximumFractionDigits: 1)) km"
    }

    /// 分段是不是「快」的那一段：比輕鬆配速快就是。沒有 VDOT 時全部當輕鬆段。
    static func isFastSegment(_ segment: EditableSegment, easyPace: String?) -> Bool {
        guard let easyPace, let easy = paceSeconds(easyPace), let value = paceSeconds(segment.pace) else {
            return false
        }
        return value < easy - 15
    }

    static func paceSeconds(_ pace: String) -> Int? {
        let parts = pace.split(separator: ":")
        guard parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) else { return nil }
        return m * 60 + s
    }

    /// 總距離＝**只加分段清單**，不含暖身緩和（設計 §15 明寫）。
    private var totalDistanceCard: some View {
        HStack {
            Text(L10n.EditSchedule.totalDistance.localized)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkSecondary)
            Spacer(minLength: 6)
            Text("\(App2NumberFormat.grouped(editState.totalSegmentDistance, maximumFractionDigits: 1)) km")
                .font(.app2Mono(24, weight: .black))
                .foregroundStyle(App2Theme.accentOrange)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: App2Theme.accentOrange.opacity(0.06), location: 0),
                            .init(color: .white, location: 0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(App2Theme.accentOrange.opacity(0.24), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_DayEditTotalDistance")
    }

    // MARK: - frame-07 肌力訓練

    private var strengthTypeCard: some View {
        App2Card(spacing: 10) {
            HStack {
                Text(NSLocalizedString("edit_schedule.training_type", comment: ""))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                Menu {
                    ForEach(StrengthEditorV2.strengthTypeOptions, id: \.0) { key, label in
                        Button(label) { requestStrengthType(key) }
                    }
                } label: {
                    App2EditDropdownChip(
                        text: StrengthEditorV2.label(for: editState.strengthType),
                        foreground: App2Theme.accentViolet.app2Darkened,
                        background: App2Theme.accentViolet.opacity(0.13)
                    )
                }
                .accessibilityIdentifier("App2_DayEditStrengthType")
            }

            App2NoteBox(symbol: "info.circle", accent: Color(hex: "#EAB308")) {
                Text(L10n.App2.DayEdit.strengthTypeWarning.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(2)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func requestStrengthType(_ key: String) {
        guard key != editState.strengthType else { return }
        if editState.strengthExercises.isEmpty {
            editState.strengthType = key
            editState.strengthExercises = StrengthEditorV2.defaultExercises[key] ?? []
        } else {
            pendingStrengthType = key
            showingStrengthTypeAlert = true
        }
    }

    private var strengthDurationCard: some View {
        App2Card(spacing: 12) {
            HStack {
                Text(NSLocalizedString("edit_schedule.training_duration", comment: ""))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 8)
                App2EditStepper(
                    value: editState.strengthDurationMinutes,
                    unit: NSLocalizedString("training.minutes_unit", comment: ""),
                    valueSize: 22,
                    identifier: "App2_DayEditDuration",
                    onMinus: { editState.strengthDurationMinutes = max(5, editState.strengthDurationMinutes - 5) },
                    onPlus: { editState.strengthDurationMinutes = min(120, editState.strengthDurationMinutes + 5) }
                )
            }

            // 線性映射 5–120 分（設計 §16）。
            VStack(spacing: 4) {
                GeometryReader { geo in
                    let fraction = Double(editState.strengthDurationMinutes - 5) / 115.0
                    ZStack(alignment: .leading) {
                        Capsule().fill(App2Theme.shadowInk.opacity(0.07))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#C084FC"), App2Theme.accentViolet],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * max(0, min(1, fraction)))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(App2Theme.accentViolet, lineWidth: 2.5))
                            .offset(x: geo.size.width * max(0, min(1, fraction)) - 8)
                    }
                }
                .frame(height: 16)

                HStack {
                    Text(String(format: NSLocalizedString("time.minutes_format", comment: ""), 5))
                        .font(.app2Mono(11, weight: .bold))
                    Spacer()
                    Text(String(format: NSLocalizedString("time.minutes_format", comment: ""), 120))
                        .font(.app2Mono(11, weight: .bold))
                }
                .foregroundStyle(App2Theme.inkTertiary)
            }
        }
    }

    private var exerciseListCard: some View {
        App2Card(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(NSLocalizedString("edit_schedule.exercise_list", comment: ""))
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(String(format: L10n.App2.DayEdit.exerciseCount.localized, editState.strengthExercises.count))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 6)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text(L10n.EditSchedule.reapplyDefaults.localized)
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(App2Theme.accentBlueDeep)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    editState.strengthExercises = StrengthEditorV2.defaultExercises[editState.strengthType] ?? []
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_DayEditApplyDefaults")
            }

            ForEach(Array(editState.strengthExercises.enumerated()), id: \.element.id) { index, exercise in
                exerciseRow(index: index, exercise: exercise)
                if index < editState.strengthExercises.count - 1 {
                    App2EditDivider(inset: 30)
                }
            }

            App2DashedAddButton(
                title: L10n.App2.DayEdit.addFromLibrary.localized,
                tint: App2Theme.accentViolet,
                border: App2Theme.accentViolet.opacity(0.5),
                identifier: "App2_DayEditAddExercise"
            ) {
                editState.strengthExercises.append(MutableExercise())
            }
        }
        .accessibilityIdentifier("App2_DayEditExerciseList")
    }

    private func exerciseRow(index: Int, exercise: MutableExercise) -> some View {
        HStack(spacing: 9) {
            Text(String(format: "%02d", index + 1))
                .font(.app2Mono(13, weight: .black))
                .foregroundStyle(App2Theme.chevron)
                .frame(width: 21, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.name.isEmpty ? NSLocalizedString("edit_schedule.exercise_list", comment: "") : exercise.name)
                    .font(.system(size: 15, weight: .heavy))
                    .lineLimit(1)
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(Self.exerciseSummary(exercise))
                    .font(.app2Mono(13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }

            Spacer(minLength: 4)

            // 這裡的 ± 兩顆都是灰的（設計 §16，與間歇頁的「灰−／藍＋」不同）。
            App2EditStepper(
                value: exercise.sets ?? 3,
                size: 28,
                valueSize: 15,
                plusFilled: false,
                identifier: "App2_DayEditSets_\(index)",
                onMinus: { updateSets(at: index, delta: -1) },
                onPlus: { updateSets(at: index, delta: 1) }
            )

            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(App2Theme.cardBorder, lineWidth: 1))
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(hex: "#DC7676"))
                }
                .contentShape(Rectangle())
                .onTapGesture { editState.strengthExercises.remove(at: index) }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_DayEditExerciseDelete_\(index)")
        }
        .padding(.vertical, 5)
    }

    private func updateSets(at index: Int, delta: Int) {
        guard editState.strengthExercises.indices.contains(index) else { return }
        let current = editState.strengthExercises[index].sets ?? 3
        editState.strengthExercises[index].sets = max(1, min(10, current + delta))
    }

    static func exerciseSummary(_ exercise: MutableExercise) -> String {
        let sets = exercise.sets ?? 3
        if let duration = exercise.durationSeconds {
            return String(format: NSLocalizedString("time.sets_seconds_format", comment: ""), sets, duration)
        }
        if let reps = exercise.reps, !reps.isEmpty {
            return String(format: NSLocalizedString("training.sets_reps_format", comment: ""), sets, reps)
        }
        return String(format: NSLocalizedString("training.sets_only_format", comment: ""), sets)
    }

    private var strengthFooter: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 15, weight: .bold))
                Text(L10n.EditSchedule.changeToRestDay.localized)
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(App2Theme.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .app2CardSurface(cornerRadius: 16)
            .contentShape(Rectangle())
            .onTapGesture {
                editState.trainingType = DayType.rest.rawValue
                editState.strengthExercises = []
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_DayEditChangeToRest")

            Text(L10n.App2.DayEdit.strengthEmptyHint.localized)
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    editState.showStrengthValidationError && editState.strengthExercises.isEmpty
                        ? App2Theme.accentRed
                        : App2Theme.inkTertiary
                )
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - frame-08 休息日

    private var restDaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            App2Card(spacing: 0) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(App2Theme.insetBackground)
                        .frame(width: 40, height: 40)
                        .overlay {
                            // 暫停符號，不是月亮（月亮只在今日課表休息卡）。
                            Image(systemName: "pause.fill")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(App2Theme.inkSubtle)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.App2.DayEdit.restActiveTitle.localized)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Text(L10n.App2.DayEdit.restActiveSub.localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                    Spacer(minLength: 0)
                }
            }

            Text(L10n.App2.DayEdit.restConvertSection.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)

            // 兩張卡刻意不同權重：力量是主推（漸層＋紫標題），交叉是次要（白底＋黑標題）。
            convertRow(
                symbol: "dumbbell",
                title: L10n.App2.DayEdit.restToStrengthTitle.localized,
                subtitle: L10n.App2.DayEdit.restToStrengthSub.localized,
                titleColor: App2Theme.accentViolet.app2Darkened,
                chevronColor: Color(hex: "#C9A6EC"),
                emphasised: true,
                identifier: "App2_DayEditToStrength"
            ) {
                editState.trainingType = DayType.strength.rawValue
                if editState.strengthExercises.isEmpty {
                    editState.strengthExercises = StrengthEditorV2.defaultExercises[editState.strengthType] ?? []
                }
            }

            convertRow(
                symbol: "figure.run",
                title: L10n.App2.DayEdit.restToCrossTitle.localized,
                subtitle: L10n.App2.DayEdit.restToCrossSub.localized,
                titleColor: App2Theme.inkPrimary,
                chevronColor: App2Theme.chevron,
                emphasised: false,
                identifier: "App2_DayEditToCross"
            ) {
                editState.trainingType = DayType.crossTraining.rawValue
            }

            App2NoteBox(symbol: "lightbulb", accent: App2Theme.inkMuted) {
                Text(L10n.App2.DayEdit.restFooterHint.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(2)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func convertRow(
        symbol: String,
        title: String,
        subtitle: String,
        titleColor: Color,
        chevronColor: Color,
        emphasised: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.accentViolet.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(App2Theme.accentViolet.app2Darkened)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(titleColor)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(chevronColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    emphasised
                        ? AnyShapeStyle(LinearGradient(
                            stops: [
                                .init(color: App2Theme.accentViolet.opacity(0.09), location: 0),
                                .init(color: .white, location: 0.78)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.white)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    emphasised ? App2Theme.accentViolet.opacity(0.28) : App2Theme.cardBorder,
                    lineWidth: 1
                )
        )
        .shadow(
            color: emphasised ? App2Theme.accentViolet.opacity(0.22) : App2Theme.shadowTightColor,
            radius: emphasised ? 10 : 1, x: 0, y: emphasised ? 7 : 1
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 補充力量訓練（跑步日附加）

    @ViewBuilder
    private var supplementaryStrengthSection: some View {
        if editState.hasSupplementaryStrength {
            App2Card(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(L10n.App2.DayEdit.supplementaryStrength.localized)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(L10n.App2.DayEdit.supplementaryStrengthSub.localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(App2Theme.accentViolet.app2Darkened)
                    Menu {
                        ForEach(StrengthEditorV2.strengthTypeOptions, id: \.0) { key, label in
                            Button(label) {
                                editState.supplementaryStrengthType = key
                                editState.supplementaryStrengthExercises = StrengthEditorV2.defaultExercises[key] ?? []
                            }
                        }
                    } label: {
                        App2EditDropdownChip(
                            text: StrengthEditorV2.label(for: editState.supplementaryStrengthType),
                            foreground: App2Theme.accentViolet.app2Darkened,
                            background: App2Theme.accentViolet.opacity(0.13)
                        )
                    }
                    .accessibilityIdentifier("App2_DayEditSupplementaryType")
                    Spacer(minLength: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(App2Theme.cardBorder, lineWidth: 1))
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color(hex: "#DC7676"))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editState.hasSupplementaryStrength = false
                            editState.supplementaryStrengthExercises = []
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("App2_DayEditRemoveSupplementary")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(App2Theme.accentViolet.opacity(0.06))
                )

                ForEach(Array(editState.supplementaryStrengthExercises.enumerated()), id: \.element.id) { index, exercise in
                    HStack(spacing: 9) {
                        Text(String(format: "%02d", index + 1))
                            .font(.app2Mono(13, weight: .black))
                            .foregroundStyle(App2Theme.chevron)
                            .frame(width: 21, alignment: .leading)
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .heavy))
                            .lineLimit(1)
                            .foregroundStyle(App2Theme.inkPrimary)
                        Spacer(minLength: 6)
                        Text(Self.exerciseSummary(exercise))
                            .font(.app2Mono(13, weight: .semibold))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                    .padding(.vertical, 4)
                }

                Text(L10n.App2.DayEdit.addExercise.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.accentViolet.app2Darkened)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { editState.supplementaryStrengthExercises.append(MutableExercise()) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("App2_DayEditAddSupplementaryExercise")
            }
            .overlay(
                RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(App2Theme.accentViolet.opacity(0.22), lineWidth: 1)
            )
            .accessibilityIdentifier("App2_DayEditSupplementary")
        } else {
            // ⚠︎ 設計 §14 待裁決 (9)：整卡永遠在 vs 無力量時給入口。
            // 這裡維持 1.4 既有行為（給入口），不自行拍板。
            App2DashedAddButton(
                title: L10n.App2.DayEdit.addSupplementaryStrength.localized,
                tint: App2Theme.accentViolet,
                border: App2Theme.accentViolet.opacity(0.5),
                identifier: "App2_DayEditAddSupplementary"
            ) {
                editState.hasSupplementaryStrength = true
                if editState.supplementaryStrengthExercises.isEmpty {
                    editState.supplementaryStrengthExercises =
                        StrengthEditorV2.defaultExercises[editState.supplementaryStrengthType] ?? []
                }
            }
        }
    }

    // MARK: - 輪盤

    enum WheelTarget: Identifiable, Hashable {
        case simplePace, simpleDistance
        case workPace, workDistance, workTime
        case recoveryPace, recoveryDistance, restTime
        case warmupPace, warmupDistance, cooldownPace, cooldownDistance
        case segmentPace(Int), segmentDistance(Int)

        var id: String {
            switch self {
            case .simplePace: return "simplePace"
            case .simpleDistance: return "simpleDistance"
            case .workPace: return "workPace"
            case .workDistance: return "workDistance"
            case .workTime: return "workTime"
            case .recoveryPace: return "recoveryPace"
            case .recoveryDistance: return "recoveryDistance"
            case .restTime: return "restTime"
            case .warmupPace: return "warmupPace"
            case .warmupDistance: return "warmupDistance"
            case .cooldownPace: return "cooldownPace"
            case .cooldownDistance: return "cooldownDistance"
            case .segmentPace(let i): return "segmentPace-\(i)"
            case .segmentDistance(let i): return "segmentDistance-\(i)"
            }
        }
    }

    /// `配速表建議 I 強度 4:18–4:25／km`。
    /// **區間給不出來（沒有 VDOT、或這個課型沒有對應 zone）就整列省略**，不編一個。
    private func paceSuggestion(for trainingType: String) -> String? {
        guard let range = paceHelper.getPaceRange(for: trainingType),
              let zone = PaceCalculator.mapTrainingTypeToZone(trainingType) else { return nil }
        return String(
            format: L10n.App2.DayEdit.paceTableSuggestion.localized,
            zone.danielsCode,
            "\(range.min)–\(range.max)"
        )
    }

    @ViewBuilder
    private func wheelSheet(for target: WheelTarget) -> some View {
        switch target {
        case .simplePace:
            paceWheel(
                title: paceTitle(editState.type.localizedName),
                suggestionType: editState.trainingType,
                current: editState.pace.isEmpty ? "5:30" : editState.pace
            ) { editState.pace = $0 }

        case .simpleDistance:
            distanceWheel(
                title: distanceTitle(editState.type.localizedName),
                current: editState.distance
            ) { editState.distance = $0 }

        case .workPace:
            paceWheel(
                title: paceTitle(L10n.EditSchedule.sprintSegment.localized),
                suggestionType: editState.trainingType,
                current: editState.workPace.isEmpty ? "4:30" : editState.workPace
            ) { editState.workPace = $0 }

        case .workDistance:
            App2ValueWheelSheet(
                title: distanceTitle(L10n.EditSchedule.sprintSegment.localized),
                options: App2ValueWheelSheet.intervalDistanceOptions,
                label: { String(format: "%.0f", $0) },
                unit: "m",
                initialValue: editState.workDistance * 1000
            ) { editState.workDistance = $0 / 1000 }

        case .workTime:
            App2ValueWheelSheet(
                title: L10n.EditSchedule.selectWorkTime.localized,
                options: (1...20).map(Double.init),
                label: { String(format: "%.0f", $0) },
                unit: NSLocalizedString("training.minutes_unit", comment: ""),
                initialValue: editState.workTimeMinutes
            ) { editState.workTimeMinutes = $0 }

        case .recoveryPace:
            paceWheel(
                title: paceTitle(L10n.EditSchedule.recoverySegment.localized),
                suggestionType: "recovery",
                current: editState.recoveryPace.isEmpty ? "6:30" : editState.recoveryPace
            ) { editState.recoveryPace = $0 }

        case .recoveryDistance:
            App2ValueWheelSheet(
                title: distanceTitle(L10n.EditSchedule.recoverySegment.localized),
                options: App2ValueWheelSheet.intervalDistanceOptions,
                label: { String(format: "%.0f", $0) },
                unit: "m",
                initialValue: editState.recoveryDistance * 1000
            ) { editState.recoveryDistance = $0 / 1000 }

        case .restTime:
            App2ValueWheelSheet(
                title: L10n.EditSchedule.restTime.localized,
                options: App2ValueWheelSheet.restSecondsOptions,
                label: { String(format: "%.0f", $0) },
                unit: L10n.App2.DayEdit.secondsUnit.localized,
                initialValue: (editState.recoveryTimeMinutes * 60).rounded()
            ) { editState.recoveryTimeMinutes = $0 / 60 }

        case .warmupPace:
            paceWheel(
                title: paceTitle(NSLocalizedString("schedule_editor.segment.warmup", comment: "")),
                suggestionType: "recovery",
                current: editState.warmupPace.isEmpty ? "6:30" : editState.warmupPace
            ) { editState.warmupPace = $0 }

        case .warmupDistance:
            distanceWheel(
                title: distanceTitle(NSLocalizedString("schedule_editor.segment.warmup", comment: "")),
                current: editState.warmupDistance
            ) { editState.warmupDistance = $0 }

        case .cooldownPace:
            paceWheel(
                title: paceTitle(NSLocalizedString("schedule_editor.segment.cooldown", comment: "")),
                suggestionType: "recovery",
                current: editState.cooldownPace.isEmpty ? "6:30" : editState.cooldownPace
            ) { editState.cooldownPace = $0 }

        case .cooldownDistance:
            distanceWheel(
                title: distanceTitle(NSLocalizedString("schedule_editor.segment.cooldown", comment: "")),
                current: editState.cooldownDistance
            ) { editState.cooldownDistance = $0 }

        case .segmentPace(let index):
            if editState.segments.indices.contains(index) {
                paceWheel(
                    title: paceTitle(String(format: L10n.EditSchedule.segment.localized, index + 1)),
                    suggestionType: editState.trainingType,
                    current: editState.segments[index].pace.isEmpty ? "6:00" : editState.segments[index].pace
                ) { editState.segments[index].pace = $0 }
            }

        case .segmentDistance(let index):
            if editState.segments.indices.contains(index) {
                distanceWheel(
                    title: distanceTitle(String(format: L10n.EditSchedule.segment.localized, index + 1)),
                    current: editState.segments[index].distance
                ) { editState.segments[index].distance = $0 }
            }
        }
    }

    private func paceTitle(_ subject: String) -> String {
        String(format: L10n.App2.DayEdit.wheelPaceTitle.localized, subject)
    }

    private func distanceTitle(_ subject: String) -> String {
        String(format: L10n.App2.DayEdit.wheelDistanceTitle.localized, subject)
    }

    private func paceWheel(
        title: String,
        suggestionType: String,
        current: String,
        onDone: @escaping (String) -> Void
    ) -> some View {
        App2PaceWheelSheet(
            title: title,
            suggestion: paceSuggestion(for: suggestionType),
            initialPace: current,
            onDone: onDone
        )
    }

    private func distanceWheel(
        title: String,
        current: Double,
        onDone: @escaping (Double) -> Void
    ) -> some View {
        App2ValueWheelSheet(
            title: title,
            options: App2ValueWheelSheet.runDistanceOptions,
            label: { String(format: "%.1f", $0) },
            unit: "km",
            initialValue: current,
            onDone: onDone
        )
    }

    // MARK: - 儲存

    private func saveAndDismiss() {
        // 校驗照舊：肌力日的動作清單不得為空（設計 §16 頁尾那句話就是這條）。
        if editState.type == .strength && editState.strengthExercises.isEmpty {
            editState.showStrengthValidationError = true
            return
        }
        onSave(editState.toMutableTrainingDay(originalDay: originalDay))
        dismiss()
    }
}
