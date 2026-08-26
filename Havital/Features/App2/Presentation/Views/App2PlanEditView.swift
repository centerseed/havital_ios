import SwiftUI

// MARK: - App2PlanEditView
/// 2.0 編輯週課表 —— 設計 **frame-03**（整週）。
///
/// **這是既有編輯器的第二個版面，不是第二套編輯器。** 狀態、換課型的預設處方、
/// 送出與寫入全部沿用既有實作：
/// - 編輯狀態與儲存：`EditScheduleV2ViewModel`（`saveEdits()` →
///   `TrainingPlanV2Repository.updateWeeklyPlan` → `PUT /v2/plan/weekly/{plan_id}`）
/// - 換課型的預設距離／配速／間歇結構／暖身緩和：`ScheduleTypeDefaults`
/// - 單日細部編輯（frame-05／06／07／08）：`App2DayEditView`，它用的是 1.4 同一個
///   `TrainingDayEditState` 與 `toMutableTrainingDay(originalDay:)`
/// - 配速／距離輪盤（frame-09）：`App2PaceWheelSheet`／`App2ValueWheelSheet`
struct App2PlanEditView: View {

    @ObservedObject var editViewModel: EditScheduleV2ViewModel
    let onClose: () -> Void
    /// 儲存成功 —— 呼叫端據此重新載入首頁／課表頁。
    let onSaved: () -> Void

    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage: String?
    @State private var showingPaceTable = false
    /// 「已更新 · 請按右上儲存同步」的暫態 toast（設計 §12）。
    @State private var showingSavedToast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                App2EditTopBar(
                    title: L10n.EditSchedule.title.localized,
                    onCancel: {
                        if hasUnsavedChanges { showingDiscardAlert = true } else { onClose() }
                    },
                    onPaceTable: showsPaceTable ? { showingPaceTable = true } : nil,
                    isSaving: editViewModel.isSaving,
                    saveEnabled: hasUnsavedChanges,
                    onSave: { Task { await save() }.tracked(from: "App2PlanEditView: save") },
                    identifierPrefix: "App2_PlanEdit"
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        editModeBanner
                        summaryCard
                        if adjacentQualityWarning {
                            warningCard
                        }
                        dayList
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.bottom, 32)
                }
            }

            if showingSavedToast {
                savedToast
                    .padding(.bottom, 26)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(App2EditStripeBackground())
        .sheet(isPresented: $showingPaceTable) {
            if let vdot = editViewModel.currentVDOT {
                PaceTableView(
                    vdot: vdot,
                    calculatedPaces: PaceCalculator.calculateTrainingPaces(vdot: vdot)
                )
            }
        }
        .alert(L10n.EditSchedule.unsavedChanges.localized, isPresented: $showingDiscardAlert) {
            Button(L10n.EditSchedule.discardChanges.localized, role: .destructive) { onClose() }
            Button(L10n.EditSchedule.cancel.localized, role: .cancel) { }
        } message: {
            Text(L10n.EditSchedule.unsavedChangesMessage.localized)
        }
        .alert(L10n.EditSchedule.saveFailed.localized, isPresented: $showingSaveError) {
            Button(L10n.Common.ok.localized, role: .cancel) { }
        } message: {
            Text(saveErrorMessage ?? L10n.EditSchedule.saveFailedMessage.localized)
        }
    }

    private var showsPaceTable: Bool { editViewModel.currentVDOT != nil }

    // MARK: - 編輯模式橫幅（虛線藍框＝「暫態」的視覺語彙）

    private var editModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(App2Theme.accentBlueDeep)
            Text(L10n.App2.PlanEdit.editModeBanner.localized)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(2)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    App2Theme.accentBlue.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
        .accessibilityIdentifier("App2_PlanEditModeBanner")
    }

    // MARK: - 本週跑量（調整後）
    /// 設計 §12：**只有一個數字**，沒有進度條、沒有百分比、沒有目標分母。

    private var summaryCard: some View {
        App2AccentCard(padding: 15, spacing: 4) {
            Text(L10n.App2.PlanEdit.volumeTitle.localized)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(App2Theme.accentBlueDeep)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(App2NumberFormat.grouped(editedDistanceKm, maximumFractionDigits: 1))
                    .font(.app2Mono(30))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(verbatim: "km")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("App2_PlanEditSummary")
    }

    /// 編輯後的週跑量。**用編輯中的天現算**，不是後端那個 `total_distance_km`——
    /// 那是打開編輯器之前的值，改完不會跟著動。
    private var editedDistanceKm: Double {
        editViewModel.editingDays.reduce(0) { $0 + Self.distanceKm(of: $1) }
    }

    /// 一天的跑量。
    ///
    /// **間歇與分段課沒有 `distance_km`**，量藏在結構裡（趟數 × 衝刺距離 ＋ 組間，
    /// 或各分段相加）。只讀 `distance_km` 的話，把休息日換成 6×400m 之後週跑量
    /// 會紋風不動 —— 那正是這張卡要回答的問題。暖身／緩和在 `trainingDetails`
    /// 之外，一律另外加。
    static func distanceKm(of day: MutableTrainingDay) -> Double {
        guard day.type.isRunningActivity else { return 0 }
        var total = (day.warmup?.distanceKm ?? 0) + (day.cooldown?.distanceKm ?? 0)
        guard let details = day.trainingDetails else { return total }

        if let explicit = details.totalDistanceKm ?? details.distanceKm {
            return total + explicit
        }
        if let repeats = details.repeats, let work = details.work {
            let workKm = work.distanceKm ?? work.distanceM.map { $0 / 1000 } ?? 0
            let recoveryKm = details.recovery?.distanceKm
                ?? details.recovery?.distanceM.map { $0 / 1000 }
                ?? 0
            total += Double(repeats) * workKm + Double(max(repeats - 1, 0)) * recoveryKm
        } else if let segments = details.segments {
            total += segments.compactMap(\.distanceKm).reduce(0, +)
        }
        return total
    }

    // MARK: - 強度日相鄰提醒（條件顯示）

    /// 相鄰兩天都是品質課。
    /// `isQualitySession` 從既有的 `scheduleEditorFamily` 導出，不另立強度分類。
    private var adjacentQualityWarning: Bool {
        let days = editViewModel.editingDays
        for index in days.indices.dropLast()
        where days[index].type.isQualitySession && days[index + 1].type.isQualitySession {
            return true
        }
        return false
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: "#EAB308").opacity(0.18))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(hex: "#A16207"))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.App2.PlanEdit.warningTitle.localized)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.PlanEdit.adjacentWarning.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(2)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#EAB308").opacity(0.12), location: 0),
                            .init(color: .white, location: 0.78)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "#EAB308").opacity(0.32), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_PlanEditAdjacentWarning")
    }

    // MARK: - 七張日編輯卡（可拖曳對調）

    private var dayList: some View {
        App2DragReorderList(
            count: editViewModel.editingDays.count,
            spacing: 10,
            placeholderText: { index in
                guard editViewModel.editingDays.indices.contains(index) else { return nil }
                let weekday = App2PlanViewModel.weekdayLabel(
                    dayIndex: editViewModel.editingDays[index].dayIndexInt
                )
                return String(format: L10n.App2.PlanEdit.dropHere.localized, weekday)
            },
            onCommit: { source, target in swapDays(source, target) }
        ) { index in
            if editViewModel.editingDays.indices.contains(index) {
                App2PlanEditDayCard(
                    day: $editViewModel.editingDays[index],
                    vdot: editViewModel.currentVDOT,
                    weekdayLabel: App2PlanViewModel.weekdayLabel(
                        dayIndex: editViewModel.editingDays[index].dayIndexInt
                    ),
                    dateLabel: App2WeekCalendar.dateLabel(
                        dayIndex: editViewModel.editingDays[index].dayIndexInt,
                        weekStart: App2WeekCalendar.currentWeekStart()
                    ),
                    isToday: isToday(dayIndex: editViewModel.editingDays[index].dayIndexInt),
                    onSelectType: { [dayIndex = editViewModel.editingDays[index].dayIndexInt] newType in
                        applyType(newType, toDayIndex: dayIndex)
                    },
                    onChanged: markChanged
                )
            }
        }
    }

    private func isToday(dayIndex: Int) -> Bool {
        let calendar = Calendar.current
        guard let date = calendar.date(
            byAdding: .day,
            value: dayIndex - 1,
            to: App2WeekCalendar.currentWeekStart()
        ) else { return false }
        return calendar.isDateInToday(date)
    }

    /// 放開＝**兩天對調**（設計 §12 的橫幅與落點文字都是「對調」）。
    ///
    /// 對調只換位置、不動處方，所以 `day_index` 互換之後 `saveEdits` 仍走無損路徑
    /// （`hasSameContent` 刻意忽略 `dayIndex`），編輯器沒有模型化的欄位不會被洗掉。
    private func swapDays(_ source: Int, _ target: Int) {
        guard editViewModel.editingDays.indices.contains(source),
              editViewModel.editingDays.indices.contains(target),
              source != target else { return }
        let sourceIndex = editViewModel.editingDays[source].dayIndex
        let targetIndex = editViewModel.editingDays[target].dayIndex
        editViewModel.editingDays.swapAt(source, target)
        editViewModel.editingDays[source].dayIndex = sourceIndex
        editViewModel.editingDays[target].dayIndex = targetIndex
        markChanged()
    }

    // MARK: - Toast

    private var savedToast: some View {
        HStack(spacing: 7) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(App2Theme.accentBlueLight)
            Text(L10n.App2.PlanEdit.savedToast.localized)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#10151C").opacity(0.92))
        )
        .accessibilityIdentifier("App2_PlanEditToast")
    }

    // MARK: - Actions

    private func markChanged() {
        hasUnsavedChanges = true
        guard !showingSavedToast else { return }
        withAnimation(.easeOut(duration: 0.2)) { showingSavedToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeIn(duration: 0.2)) { showingSavedToast = false }
        }
    }

    private func applyType(_ newType: DayType, toDayIndex dayIndex: Int) {
        guard let index = editViewModel.editingDays.firstIndex(where: { $0.dayIndexInt == dayIndex })
        else { return }
        ScheduleTypeDefaults.apply(
            newType,
            to: &editViewModel.editingDays[index],
            vdot: editViewModel.currentVDOT ?? PaceCalculator.defaultVDOT
        )
        markChanged()
    }

    private func save() async {
        guard hasUnsavedChanges, !editViewModel.isSaving else { return }
        do {
            _ = try await editViewModel.saveEdits()
            onSaved()
            onClose()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
            Logger.error("[App2PlanEditView] 儲存失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - App2PlanEditDayCard
/// 編輯模式的一張日卡（設計 §12）。
///
/// 標題列由左到右：握把 → 週幾 → 日期 →（今日）膠囊 → 撐開 → 課型下拉 chip → 齒輪鈕。
/// **握把在最左、齒輪在最右**；休息日沒有齒輪（只有課型下拉）。
struct App2PlanEditDayCard: View {

    @Binding var day: MutableTrainingDay
    let vdot: Double?
    let weekdayLabel: String
    let dateLabel: String
    var isToday: Bool = false
    /// 選了新課型（套 `ScheduleTypeDefaults` 的預設處方）。
    let onSelectType: (DayType) -> Void
    let onChanged: () -> Void

    @State private var showingDetailSheet = false
    @State private var wheel: Wheel?

    private enum Wheel: String, Identifiable {
        case pace, distance
        var id: String { rawValue }
    }

    private var accent: Color { day.type.app2StripColor }

    var body: some View {
        App2LeftStripCard(strip: accent) {
            header
            fields
            supplementaryNote
        }
        // 休息日卡沒有齒輪鈕（設計 §12），但休息日的單日編輯頁（frame-08：主動恢復、
        // 轉為力量／交叉訓練日）還是要進得去 —— 整張卡就是入口。
        .contentShape(Rectangle())
        .onTapGesture {
            guard day.type == .rest else { return }
            showingDetailSheet = true
        }
        // 整卡加手勢會讓 SwiftUI 把這張卡收成**單一** accessibility element，
        // 卡內的課型 chip 與齒輪鈕就整組消失（2026-08-26 用 maestro hierarchy 確認）。
        // `.contain` 明確保留子元素。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("App2_PlanEditDay_\(day.dayIndexInt)")
        .fullScreenCover(isPresented: $showingDetailSheet) {
            App2DayEditView(
                day: day,
                paceHelper: PaceCalculationHelper(vdot: vdot),
                onSave: { updated in
                    day = updated
                    onChanged()
                }
            )
        }
        .sheet(item: $wheel) { target in
            wheelSheet(for: target)
                .presentationDetents([.fraction(0.56)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(26)
        }
    }

    // MARK: - 標題列

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            App2DragHandle()

            Text(weekdayLabel)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)

            Text(dateLabel)
                .font(.app2Mono(13, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)

            if isToday {
                App2Pill(text: L10n.App2.PlanEdit.today.localized)
            }

            Spacer(minLength: 4)

            // 課型選擇＝平台標準下拉（2026-08-26 裁決），不是自繪的遮罩 sheet。
            App2TrainingTypeMenu(current: day.type, onSelect: onSelectType) {
                App2EditDropdownChip(
                    text: day.type.localizedName,
                    foreground: day.type.app2ChipForeground,
                    background: day.type.app2ChipBackground,
                    border: day.type.app2StripColor.opacity(0.3)
                )
            }
            .accessibilityLabel(L10n.App2.PlanEdit.selectType.localized)
            .accessibilityIdentifier("App2_PlanEditType_\(day.dayIndexInt)")

            // 休息日沒有齒輪鈕（設計 §12）。
            if day.type != .rest {
                App2GearButton(identifier: "App2_PlanEditDetail_\(day.dayIndexInt)") {
                    showingDetailSheet = true
                }
            }
        }
    }

    // MARK: - 下方欄位（依課型不同）

    @ViewBuilder
    private var fields: some View {
        switch day.type.scheduleEditorFamily {
        case .rest:
            // 休息日：只有標題列，沒有任何下方欄位。
            EmptyView()

        case .intervalDistance, .norwegian4x4, .yasso800, .combination:
            structuredRow
            warmupCooldownLines

        case .strength:
            strengthRow

        case .cross:
            crossRow

        case .easy where heartRateSummary != nil:
            // 心率制輕鬆跑：單一整寬欄位「距離 6.0km · 140–161 bpm」。
            App2EditFieldBlock(
                label: L10n.App2.PlanEdit.distanceChip.localized,
                value: heartRateSummary ?? ""
            ) { wheel = .distance }

        default:
            HStack(spacing: 9) {
                App2EditFieldBlock(
                    label: L10n.App2.PlanEdit.paceChip.localized,
                    value: paceText
                ) { wheel = .pace }
                    .accessibilityIdentifier("App2_PlanEditPace_\(day.dayIndexInt)")
                App2EditFieldBlock(
                    label: L10n.App2.PlanEdit.distanceChip.localized,
                    value: distanceText
                ) { wheel = .distance }
                    .accessibilityIdentifier("App2_PlanEditDistance_\(day.dayIndexInt)")
            }
        }
    }

    /// 間歇／組合：單一「課表」列 ＋ 右側「進階編輯」橘膠囊 ＋ `›`。
    private var structuredRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.App2.PlanEdit.planRow.localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Text(structuredSummary ?? L10n.App2.PlanEdit.detailChip.localized)
                    .font(.app2Mono(15, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(App2Theme.inkPrimary)
            }
            Spacer(minLength: 6)
            advancedEditPill(tint: App2Theme.accentOrangeSoft)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .contentShape(Rectangle())
        .onTapGesture { showingDetailSheet = true }
    }

    private var strengthRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(App2Theme.accentViolet.app2Darkened)
            VStack(alignment: .leading, spacing: 1) {
                Text(StrengthEditorV2.label(for: day.strengthType ?? "core_stability"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(strengthSummary)
                    .font(.app2Mono(13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            Spacer(minLength: 6)
            advancedEditPill(tint: App2Theme.accentViolet)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .contentShape(Rectangle())
        .onTapGesture { showingDetailSheet = true }
    }

    private var crossRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(App2Theme.accentViolet.app2Darkened)
            Text(day.dayTarget.isEmpty ? day.type.localizedName : day.dayTarget)
                .font(.system(size: 15, weight: .heavy))
                .lineLimit(1)
                .foregroundStyle(App2Theme.inkPrimary)
            Spacer(minLength: 6)
            advancedEditPill(tint: App2Theme.accentViolet)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.insetBackgroundCool)
        )
        .contentShape(Rectangle())
        .onTapGesture { showingDetailSheet = true }
    }

    private func advancedEditPill(tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(L10n.App2.PlanEdit.advancedEdit.localized)
                .font(.system(size: 12, weight: .black))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .black))
        }
        .foregroundStyle(tint.app2Darkened)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
    }

    /// 結構課下方兩行灰字：`暖身 1.0 km · 7:55/km`／`緩和 …`（帶火焰／風 icon，綠 stroke）。
    @ViewBuilder
    private var warmupCooldownLines: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let warmup = day.warmup {
                segmentLine(
                    symbol: "flame",
                    name: NSLocalizedString("schedule_editor.segment.warmup", comment: ""),
                    segment: warmup
                )
            }
            if let cooldown = day.cooldown {
                segmentLine(
                    symbol: "wind",
                    name: NSLocalizedString("schedule_editor.segment.cooldown", comment: ""),
                    segment: cooldown
                )
            }
        }
    }

    private func segmentLine(symbol: String, name: String, segment: RunSegment) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(App2Theme.accentGreen)
            Text(name)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(App2Theme.inkTertiary)
            Text(Self.segmentDetail(segment))
                .font(.app2Mono(12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(App2Theme.inkTertiary)
            Spacer(minLength: 0)
        }
    }

    static func segmentDetail(_ segment: RunSegment) -> String {
        var parts: [String] = []
        if let km = segment.distanceKm {
            parts.append("\(App2NumberFormat.grouped(km, maximumFractionDigits: 1)) km")
        }
        if let pace = segment.pace, !pace.isEmpty {
            parts.append("\(pace)/km")
        }
        return parts.joined(separator: " · ")
    }

    /// 跑步日附加力量的註記行。編輯情境用紫（力量 owner 色）。
    @ViewBuilder
    private var supplementaryNote: some View {
        if let note = supplementaryStrengthNote {
            HStack(spacing: 5) {
                Image(systemName: "dumbbell")
                    .font(.system(size: 11, weight: .bold))
                Text(note)
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(App2Theme.accentViolet.app2Darkened)
        }
    }

    private var supplementaryStrengthNote: String? {
        guard let activities = day.supplementaryActivities else { return nil }
        for activity in activities {
            guard case .strength(let strength) = activity else { continue }
            let label = StrengthEditorV2.label(for: strength.strengthType)
            if let minutes = strength.durationMinutes {
                return String(
                    format: L10n.App2.PlanEdit.supplementaryNoteMinutes.localized,
                    label, minutes
                )
            }
            return String(format: L10n.App2.PlanEdit.supplementaryNote.localized, label)
        }
        return nil
    }

    // MARK: - 值

    private var paceText: String {
        guard let pace = day.trainingDetails?.pace, !pace.isEmpty else { return "--:--" }
        return "\(pace)/km"
    }

    private var distanceText: String {
        let km = day.trainingDetails?.distanceKm ?? day.trainingDetails?.totalDistanceKm ?? 0
        return "\(App2NumberFormat.grouped(km, maximumFractionDigits: 1)) km"
    }

    /// 心率制輕鬆跑才有值：`6.0 km · 140–161 bpm`。
    private var heartRateSummary: String? {
        guard let range = day.trainingDetails?.heartRateRange,
              let min = range.min, let max = range.max else { return nil }
        let km = day.trainingDetails?.distanceKm ?? day.trainingDetails?.totalDistanceKm ?? 0
        return String(
            format: L10n.App2.PlanEdit.heartRateSummary.localized,
            App2NumberFormat.grouped(km, maximumFractionDigits: 1), min, max
        )
    }

    private var strengthSummary: String {
        let minutes = Int(day.trainingDetails?.timeMinutes ?? 30)
        let count = day.strengthExercises?.count ?? 0
        return String(format: L10n.App2.PlanEdit.strengthSummary.localized, minutes, count)
    }

    /// 結構課的一行摘要（`8 × 400m @ 4:20`／`3 段 · 10.0 km`）。
    /// 組不出來就顯示「編輯內容」，不編一個。
    private var structuredSummary: String? {
        guard let details = day.trainingDetails else { return nil }
        if let repeats = details.repeats, let work = details.work {
            let distance = work.distanceM.map { String(format: "%.0fm", $0) }
                ?? work.distanceKm.map { String(format: "%.0fm", $0 * 1000) }
            let time = work.timeMinutes.map { String(format: L10n.App2.Home.minutes.localized, Int($0)) }
            guard let unit = distance ?? time else { return nil }
            let pace = work.pace.map { " @ \($0)" } ?? ""
            return "\(repeats) × \(unit)\(pace)"
        }
        if let segments = details.segments, !segments.isEmpty {
            let total = details.totalDistanceKm ?? segments.compactMap(\.distanceKm).reduce(0, +)
            return String(format: L10n.App2.Detail.phaseCount.localized, segments.count)
                + " · \(App2NumberFormat.grouped(total, maximumFractionDigits: 1)) km"
        }
        return nil
    }

    // MARK: - 輪盤

    @ViewBuilder
    private func wheelSheet(for target: Wheel) -> some View {
        switch target {
        case .pace:
            App2PaceWheelSheet(
                title: String(
                    format: L10n.App2.DayEdit.wheelPaceTitle.localized,
                    day.type.localizedName
                ),
                suggestion: paceSuggestion,
                initialPace: day.trainingDetails?.pace ?? "5:30"
            ) { newValue in
                guard var details = day.trainingDetails else { return }
                details.pace = newValue
                day.trainingDetails = details
                onChanged()
            }
        case .distance:
            App2ValueWheelSheet(
                title: String(
                    format: L10n.App2.DayEdit.wheelDistanceTitle.localized,
                    day.type.localizedName
                ),
                options: App2ValueWheelSheet.runDistanceOptions,
                label: { String(format: "%.1f", $0) },
                unit: "km",
                initialValue: day.trainingDetails?.distanceKm
                    ?? day.trainingDetails?.totalDistanceKm ?? 5.0
            ) { newValue in
                guard var details = day.trainingDetails else { return }
                details.distanceKm = newValue
                day.trainingDetails = details
                onChanged()
            }
        }
    }

    /// 沒有 VDOT／課型對不到 zone → 建議列整條省略。
    private var paceSuggestion: String? {
        guard let vdot,
              let range = PaceCalculator.getPaceRange(for: day.trainingType, vdot: vdot),
              let zone = PaceCalculator.mapTrainingTypeToZone(day.trainingType) else { return nil }
        return String(
            format: L10n.App2.DayEdit.paceTableSuggestion.localized,
            zone.danielsCode,
            "\(range.min)–\(range.max)"
        )
    }
}

// MARK: - App2PlanEditGate
/// 「修改課表」的入口殼：取本週課表 → 建 `EditScheduleV2ViewModel` → 開編輯頁。
///
/// 編輯器吃的是 domain entity（`WeeklyPlanV2`），而 2.0 的課表頁讀的是 DTO，
/// 兩者沒有 mapper —— 所以這裡走既有的 repository 出口
/// `fetchWeeklyPlan(planId:)`（有快取，不會為了開編輯頁多打一次網路）。
/// 讀不到就明說讀不到，不開一頁空的編輯器。
struct App2PlanEditGate: View {

    let onClose: () -> Void
    let onSaved: () -> Void

    @State private var editViewModel: EditScheduleV2ViewModel?
    @State private var didFail = false

    var body: some View {
        Group {
            if let editViewModel {
                App2PlanEditView(
                    editViewModel: editViewModel,
                    onClose: onClose,
                    onSaved: onSaved
                )
            } else if didFail {
                failureState
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(App2EditStripeBackground())
            }
        }
        .task { await load() }
    }

    private var failureState: some View {
        VStack(spacing: 0) {
            App2PageHeader(
                title: L10n.EditSchedule.title.localized,
                titleSize: 19,
                onBack: onClose,
                backIdentifier: "App2_PlanEditCancel",
                titleIdentifier: "App2_PlanEditFailed"
            ) { EmptyView() }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 12)
            Spacer()
            Text(L10n.App2.PlanEdit.loadFailed.localized)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(App2Theme.inkSecondary)
                .padding(.horizontal, 34)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(App2EditStripeBackground())
    }

    private func load() async {
        guard editViewModel == nil, !didFail else { return }
        let container = DependencyContainer.shared
        if !container.isRegistered(TrainingPlanV2Repository.self) {
            container.registerTrainingPlanV2Dependencies()
        }
        let repository: TrainingPlanV2Repository = container.resolve()
        do {
            let status = try await repository.getPlanStatus(forceRefresh: false)
            guard let planId = status.currentWeekPlanId else {
                Logger.debug("[App2PlanEditGate] 本週尚無課表,無法編輯")
                didFail = true
                return
            }
            let plan = try await repository.fetchWeeklyPlan(planId: planId)
            editViewModel = EditScheduleV2ViewModel(
                weeklyPlan: plan,
                // 日卡的日期與課表頁同一支週起點（裝置日曆的週一）。
                startDate: App2WeekCalendar.currentWeekStart(),
                repository: repository
            )
        } catch {
            guard !error.isCancellationError else { return }
            Logger.debug("[App2PlanEditGate] 週課表取得失敗: \(error)")
            didFail = true
        }
    }
}
