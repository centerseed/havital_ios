import SwiftUI

// MARK: - App2PlanEditView
/// 2.0 編輯週課表 —— 設計 **frame-03**（整週）／**frame-04**（課型選單 sheet）。
///
/// **這是既有編輯器的第二個版面，不是第二套編輯器。** 狀態、換課型的預設處方、
/// 送出與寫入全部沿用既有實作：
/// - 編輯狀態與儲存：`EditScheduleV2ViewModel`（`saveEdits()` →
///   `TrainingPlanV2Repository.updateWeeklyPlan` → `PUT /v2/plan/weekly/{plan_id}`）
/// - 換課型的預設距離／配速／間歇結構／暖身緩和：`ScheduleTypeDefaults`
/// - 單日細部編輯（frame-05 距離制間歇／frame-06 組合訓練／frame-07 肌力／
///   frame-08 休息日）：`TrainingEditSheetV2`，它已經依 `scheduleEditorFamily` 分流
/// - 配速輪盤（frame-09）／距離輪盤：`PaceWheelPicker`／`DistanceWheelPicker`
///
/// 這一層只負責 2.0 的版面：週跑量摘要、強度日相鄰提醒、日卡、拖曳排序、課型 sheet。
struct App2PlanEditView: View {

    @ObservedObject var editViewModel: EditScheduleV2ViewModel
    let onClose: () -> Void
    /// 儲存成功 —— 呼叫端據此重新載入首頁／課表頁。
    let onSaved: () -> Void

    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage: String?
    /// 正在選課型的那一天（`day_index`）。nil = sheet 沒開。
    @State private var typeSheetDay: App2EditingDayRef?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            summaryCard
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.bottom, 10)
            if let warning = adjacentQualityWarning {
                warningBanner(warning)
                    .padding(.horizontal, App2Theme.pagePadding)
                    .padding(.bottom, 10)
            }
            dayList
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .sheet(item: $typeSheetDay) { ref in
            App2TrainingTypeSheet(
                current: day(at: ref.id)?.type ?? .rest,
                onSelect: { newType in
                    applyType(newType, toDayIndex: ref.id)
                    typeSheetDay = nil
                }
            )
            .presentationDetents([.medium, .large])
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

    // MARK: - 頁首（取消 ＋ 標題 ＋ 儲存）

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(L10n.EditSchedule.cancel.localized)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(App2Theme.inkSubtle)
                .contentShape(Rectangle())
                .onTapGesture {
                    if hasUnsavedChanges { showingDiscardAlert = true } else { onClose() }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_PlanEditCancel")

            Spacer(minLength: 4)

            Text(L10n.EditSchedule.title.localized)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
                .accessibilityIdentifier("App2_PlanEditView")

            Spacer(minLength: 4)

            Group {
                if editViewModel.isSaving {
                    ProgressView().frame(width: 46)
                } else {
                    Text(L10n.EditSchedule.save.localized)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(hasUnsavedChanges ? App2Theme.accentBlue : App2Theme.chevron)
                        .frame(minWidth: 46, alignment: .trailing)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard hasUnsavedChanges, !editViewModel.isSaving else { return }
                Task { await save() }.tracked(from: "App2PlanEditView: save")
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(L10n.EditSchedule.save.localized)
            .accessibilityIdentifier("App2_PlanEditSave")
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.vertical, 12)
    }

    // MARK: - 本週跑量（設計 frame-03 上方：調整後的量 ＋ 與原本的差）

    private var summaryCard: some View {
        App2AccentCard(padding: 15, spacing: 6) {
            HStack {
                Text(L10n.App2.Plan.volumeTitle.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.accentBlueDeep)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(App2NumberFormat.grouped(editedDistanceKm, maximumFractionDigits: 1))
                    .font(.app2Mono(26))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(verbatim: "km")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 6)
                Text(deltaLabel)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(deltaColor)
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

    private var originalDistanceKm: Double { editViewModel.weeklyPlan.totalDistance }

    private var deltaLabel: String {
        let delta = editedDistanceKm - originalDistanceKm
        let magnitude = App2NumberFormat.grouped(abs(delta), maximumFractionDigits: 1)
        if abs(delta) < 0.05 { return L10n.App2.PlanEdit.deltaSame.localized }
        return delta > 0
            ? String(format: L10n.App2.PlanEdit.deltaUp.localized, magnitude)
            : String(format: L10n.App2.PlanEdit.deltaDown.localized, magnitude)
    }

    private var deltaColor: Color {
        let delta = editedDistanceKm - originalDistanceKm
        if abs(delta) < 0.05 { return App2Theme.inkTertiary }
        return delta > 0 ? App2Theme.accentOrangeText : App2Theme.accentBlueDeep
    }

    // MARK: - 強度日相鄰提醒（設計 frame-03）

    /// 相鄰兩天都是品質課 —— 回傳第一組的星期字串。
    /// `isQualitySession` 從既有的 `scheduleEditorFamily` 導出，不另立強度分類。
    private var adjacentQualityWarning: String? {
        let days = editViewModel.editingDays
        for index in days.indices.dropLast() where
            days[index].type.isQualitySession && days[index + 1].type.isQualitySession {
            return L10n.App2.PlanEdit.adjacentWarning.localized
        }
        return nil
    }

    private func warningBanner(_ text: String) -> some View {
        App2NoteBox(symbol: "exclamationmark.triangle.fill", accent: App2Theme.accentOrangeBright) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(2)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("App2_PlanEditAdjacentWarning")
    }

    // MARK: - 日卡清單（可拖曳排序）

    private var dayList: some View {
        // 拖曳排序要 `List` 的 `onMove`（SwiftUI 沒有 ScrollView 版），
        // 所以這一段用 List ＋ 透明列背景維持 2.0 的卡片語彙。
        List {
            ForEach($editViewModel.editingDays) { $day in
                App2PlanEditDayCard(
                    day: $day,
                    vdot: editViewModel.currentVDOT,
                    weekdayLabel: App2PlanViewModel.weekdayLabel(dayIndex: day.dayIndexInt),
                    dateLabel: App2PlanViewModel.dateLabel(
                        dayIndex: day.dayIndexInt,
                        weekStart: App2PlanViewModel.currentWeekStart()
                    ),
                    onOpenTypeSheet: { typeSheetDay = App2EditingDayRef(id: day.dayIndexInt) },
                    onChanged: { hasUnsavedChanges = true }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: App2Theme.pagePadding, bottom: 6, trailing: App2Theme.pagePadding))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                editViewModel.editingDays.move(fromOffsets: source, toOffset: destination)
                for index in editViewModel.editingDays.indices {
                    editViewModel.editingDays[index].dayIndex = "\(index + 1)"
                }
                hasUnsavedChanges = true
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Actions

    private func day(at dayIndex: Int) -> MutableTrainingDay? {
        editViewModel.editingDays.first { $0.dayIndexInt == dayIndex }
    }

    private func applyType(_ newType: DayType, toDayIndex dayIndex: Int) {
        guard let index = editViewModel.editingDays.firstIndex(where: { $0.dayIndexInt == dayIndex })
        else { return }
        ScheduleTypeDefaults.apply(
            newType,
            to: &editViewModel.editingDays[index],
            vdot: editViewModel.currentVDOT ?? PaceCalculator.defaultVDOT
        )
        hasUnsavedChanges = true
    }

    private func save() async {
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

// MARK: - App2EditingDayRef
/// `sheet(item:)` 要 Identifiable，而 `Int` 不是（也不該為了這個對 `Int` 加
/// retroactive conformance —— 那會影響整個 app）。
struct App2EditingDayRef: Identifiable, Equatable {
    let id: Int
}

// MARK: - App2PlanEditDayCard
/// 編輯模式的一張日卡（設計 frame-03）：星期／日期 ＋ 課型徽章（點開 frame-04 sheet）
/// ＋ 距離／配速快改 ＋ 複雜課型的「編輯內容」入口。
struct App2PlanEditDayCard: View {

    @Binding var day: MutableTrainingDay
    let vdot: Double?
    let weekdayLabel: String
    let dateLabel: String
    let onOpenTypeSheet: () -> Void
    let onChanged: () -> Void

    @State private var showingDetailSheet = false
    @State private var showingPacePicker = false
    @State private var showingDistancePicker = false

    private var accent: Color { day.type.app2StripColor }

    var body: some View {
        App2LeftStripCard(strip: accent) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(weekdayLabel)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(dateLabel)
                        .font(.app2Mono(12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
                .frame(width: 48, alignment: .leading)

                App2Chip(
                    text: day.type.localizedName,
                    foreground: day.type.app2ChipForeground,
                    background: day.type.app2ChipBackground
                )
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(day.type.app2ChipForeground)
                        .offset(x: 9)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpenTypeSheet)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("App2_PlanEditType_\(day.dayIndexInt)")

                Spacer(minLength: 4)
            }

            if day.type != .rest {
                controls
            }
        }
        .sheet(isPresented: $showingDetailSheet) {
            TrainingEditSheetV2(
                day: day,
                onSave: { updated in
                    day = updated
                    onChanged()
                },
                paceHelper: PaceCalculationHelper(vdot: vdot)
            )
        }
        .sheet(isPresented: $showingPacePicker) {
            PaceWheelPicker(
                selectedPace: Binding(
                    get: { day.trainingDetails?.pace ?? "5:00" },
                    set: { newValue in
                        guard var details = day.trainingDetails else { return }
                        details.pace = newValue
                        day.trainingDetails = details
                        onChanged()
                    }
                ),
                referenceDistance: day.trainingDetails?.distanceKm
            )
            .presentationDetents([.height(380)])
        }
        .sheet(isPresented: $showingDistancePicker) {
            DistanceWheelPicker(selectedDistance: Binding(
                get: { day.trainingDetails?.distanceKm ?? 5.0 },
                set: { newValue in
                    guard var details = day.trainingDetails else { return }
                    details.distanceKm = newValue
                    day.trainingDetails = details
                    onChanged()
                }
            ))
            .presentationDetents([.height(320)])
        }
    }

    /// 簡單課型直接改距離／配速；間歇與分段課的結構改不動一行，走既有的細部編輯 sheet
    /// （frame-05／06／07 就是那幾張）。
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 8) {
            if day.type.isComplexScheduleTraining || day.type == .strength {
                editChip(
                    symbol: "slider.horizontal.3",
                    label: L10n.App2.PlanEdit.detailChip.localized,
                    value: complexSummary
                ) { showingDetailSheet = true }
                    .accessibilityIdentifier("App2_PlanEditDetail_\(day.dayIndexInt)")
            } else {
                if let distance = day.trainingDetails?.distanceKm ?? day.trainingDetails?.totalDistanceKm {
                    editChip(
                        symbol: "ruler",
                        label: L10n.App2.PlanEdit.distanceChip.localized,
                        value: "\(App2NumberFormat.grouped(distance, maximumFractionDigits: 1)) km"
                    ) { showingDistancePicker = true }
                        .accessibilityIdentifier("App2_PlanEditDistance_\(day.dayIndexInt)")
                }
                if let pace = day.trainingDetails?.pace {
                    editChip(
                        symbol: "speedometer",
                        label: L10n.App2.PlanEdit.paceChip.localized,
                        value: pace
                    ) { showingPacePicker = true }
                        .accessibilityIdentifier("App2_PlanEditPace_\(day.dayIndexInt)")
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// 複雜課型的一行摘要（`6 × 400m @ 4:30`／`3 段 · 10.0 km`）。
    /// 組不出來就只顯示「編輯內容」，不編一個。
    private var complexSummary: String? {
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

    private func editChip(
        symbol: String,
        label: String,
        value: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(value ?? label)
                .font(.app2Mono(13, weight: .bold))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .heavy))
        }
        .foregroundStyle(App2Theme.accentBlueDeep)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(label)
    }
}

// MARK: - App2TrainingTypeSheet
/// 課型選單（設計 frame-04）：bottom sheet 版的課型清單。
///
/// **分組沿用 `TrainingTypeMenu` 的 static 清單**——版面不同，但「有哪些課型、
/// 分成哪幾組」只有一份，不會出現 1.4 選得到、2.0 選不到的課型。
struct App2TrainingTypeSheet: View {

    let current: DayType
    let onSelect: (DayType) -> Void

    private var groups: [(title: String, types: [DayType])] {
        [
            (L10n.EditSchedule.easyTrainingSection.localized, TrainingTypeMenu.easyTypes),
            (L10n.EditSchedule.intensityTrainingSection.localized, TrainingTypeMenu.intensityTypes),
            (L10n.EditSchedule.longDistanceTrainingSection.localized, TrainingTypeMenu.longDistanceTypes),
            (L10n.EditSchedule.otherTrainingSection.localized, TrainingTypeMenu.otherTypes)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.App2.PlanEdit.selectType.localized)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .padding(.top, 6)
                    .accessibilityIdentifier("App2_TrainingTypeSheet")

                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 8) {
                        App2SectionCaption(text: group.title)
                        ForEach(group.types, id: \.rawValue) { type in
                            typeRow(type)
                        }
                    }
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.bottom, 24)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
    }

    private func typeRow(_ type: DayType) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(type.app2StripColor)
                .frame(width: 8, height: 8)
            Text(type.localizedName)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
            Spacer(minLength: 6)
            if type == current {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(App2Theme.accentBlue)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2CardSurface(cornerRadius: 13)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(type) }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_TrainingType_\(type.rawValue)")
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
                    .background(App2Theme.pageGradient.ignoresSafeArea())
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
        .background(App2Theme.pageGradient.ignoresSafeArea())
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
                startDate: App2PlanViewModel.currentWeekStart(),
                repository: repository
            )
        } catch {
            guard !error.isCancellationError else { return }
            Logger.debug("[App2PlanEditGate] 週課表取得失敗: \(error)")
            didFail = true
        }
    }
}
