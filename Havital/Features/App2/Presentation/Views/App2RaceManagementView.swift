import SwiftUI

// MARK: - App2RaceManagementView
/// 2.0 賽事管理 —— 設計 **frame-12「賽事管理」**（新增／編輯是 frame-13 的 sheet，
/// 賽事資料庫是 frame-14 的覆蓋頁）。
///
/// **只做版面**：讀寫全部走 `App2RaceManagementViewModel` → `TargetRepository`
/// （與 1.x 的目標賽事編輯、onboarding 的賽事挑選同一組出口）。
struct App2RaceManagementView: View {

    let onClose: () -> Void
    let onPromotionComplete: () -> Void
    @StateObject private var viewModel: App2RaceManagementViewModel

    /// nil = 沒有開表單；有值 = frame-13 的 sheet（新增或編輯都是同一張）。
    @State private var editingForm: App2RaceForm?
    /// 二次確認：刪除是不可逆的，設計的垃圾桶按一下就沒了太危險。
    @State private var pendingDeletion: App2RaceCard?
    @State private var pendingPromotion: App2RaceCard?
    @State private var successAlertMessage: String?

    init(
        onClose: @escaping () -> Void,
        onPromotionComplete: @escaping () -> Void = {},
        viewModel: App2RaceManagementViewModel? = nil
    ) {
        self.onClose = onClose
        self.onPromotionComplete = onPromotionComplete
        _viewModel = StateObject(wrappedValue: viewModel ?? App2RaceManagementViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                App2PageHeader(
                    title: L10n.App2.Races.title.localized,
                    onBack: onClose,
                    backIdentifier: "App2_RacesClose",
                    titleIdentifier: "App2_RaceManagementView"
                ) { EmptyView() }

                Text(L10n.App2.Races.subtitle.localized)
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSubtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: 8, leading: 4, bottom: 16, trailing: 4))

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    mainSection
                    supportSection
                    addRaceButton
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.reload() }
        .sheet(item: $editingForm) { form in
            App2RaceEditSheet(
                form: form,
                isSaving: viewModel.isSaving,
                onSave: { updated in
                    Task {
                        if await viewModel.save(updated) { editingForm = nil }
                    }
                },
                onDelete: { id in
                    editingForm = nil
                    Task { await viewModel.delete(id) }
                },
                onClose: { editingForm = nil }
            )
        }
        .confirmationDialog(
            NSLocalizedString("app2.races.promote_confirm_title", comment: ""),
            isPresented: Binding(
                get: { pendingPromotion != nil },
                set: {
                    if !$0 {
                        pendingPromotion = nil
                        if viewModel.pendingPromotionID != nil {
                            viewModel.cancelSetAsMainConfirmation()
                        }
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let race = pendingPromotion {
                Button(NSLocalizedString("app2.races.promote_confirm_action", comment: "")) {
                    let confirmedID = viewModel.takePendingSetAsMainConfirmation()
                    pendingPromotion = nil
                    guard let confirmedID else { return }
                    Task { await viewModel.setAsMain(confirmedID) }
                }
                .accessibilityIdentifier("App2_RacesPromoteConfirm")
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {
                    pendingPromotion = nil
                    viewModel.cancelSetAsMainConfirmation()
                }
                    .accessibilityIdentifier("App2_RacesPromoteCancel")
            }
        } message: {
            if let race = pendingPromotion {
                Text(String(format: NSLocalizedString("app2.races.promote_confirm_body", comment: ""), race.name))
            }
        }
        .alert(
            NSLocalizedString("app2.races.promote_success_title", comment: ""),
            isPresented: Binding(
                get: { successAlertMessage != nil },
                set: { if !$0 { successAlertMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("app2.races.promote_success_action", comment: "")) {
                successAlertMessage = nil
                onPromotionComplete()
            }
            .accessibilityIdentifier("App2_RacesPromoteSuccessContinue")
        } message: {
            Text(successAlertMessage ?? "")
        }
        .onChange(of: viewModel.didPromoteMainRace) { _, didPromote in
            guard didPromote else { return }
            if let message = viewModel.successMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                successAlertMessage = message
            } else {
                onPromotionComplete()
            }
        }
        .alert(
            L10n.App2.Races.deleteConfirmTitle.localized,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { race in
            Button(L10n.App2.Races.delete.localized, role: .destructive) {
                Task { await viewModel.delete(race.id) }
            }
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
        } message: { race in
            Text(String(format: L10n.App2.Races.deleteConfirmBody.localized, race.name))
        }
    }

    // MARK: - 主要賽事

    private var mainSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                L10n.App2.Races.mainSection.localized,
                color: App2Theme.accentBlueDeep,
                ruleColor: App2Theme.accentBlue.opacity(0.22)
            )

            if let main = viewModel.mainRace {
                mainCard(main)
            } else {
                dashedButton(
                    title: L10n.App2.Races.noMainTitle.localized,
                    subtitle: L10n.App2.Races.noMainBody.localized,
                    tint: App2Theme.accentBlueDeep,
                    border: App2Theme.accentBlue.opacity(0.35),
                    identifier: "App2_RacesSetMainCta"
                ) {
                    editingForm = viewModel.newRaceForm()
                }
            }
        }
        .padding(.bottom, 22)
    }

    private func mainCard(_ race: App2RaceCard) -> some View {
        App2AccentCard(strength: 0.12, padding: 18, spacing: 0) {
            HStack(spacing: 6) {
                App2SectionLabel(text: L10n.App2.Races.mainSection.localized)
                Spacer(minLength: 4)
                App2Pill(
                    text: race.distanceLabel,
                    foreground: App2Theme.accentBlueDeep,
                    background: App2Theme.accentBlue.opacity(0.1),
                    border: App2Theme.accentBlue.opacity(0.22)
                )
                App2Pill(text: L10n.App2.Races.mainBadge.localized)
            }

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(race.name)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(race.dateLabel)
                    .font(.app2Mono(14, weight: .medium))
                    .foregroundStyle(App2Theme.inkSubtle)
            }
            .padding(.top, 12)

            HStack(alignment: .bottom, spacing: 24) {
                App2FieldColumn(
                    label: L10n.App2.Races.countdown.localized,
                    value: countdownValue(race),
                    valueColor: App2Theme.accentBlueDark,
                    valueSize: 26,
                    suffix: race.countdownDays >= 0
                        ? " " + L10n.App2.Races.countdownUnit.localized
                        : nil
                )
                if let goal = race.goalTime {
                    App2FieldColumn(
                        label: L10n.App2.Races.goalTime.localized,
                        value: goal
                    )
                }
                App2FieldColumn(
                    label: L10n.App2.Races.supportCount.localized,
                    value: String(
                        format: L10n.App2.Races.supportCountValue.localized,
                        viewModel.supportingRaces.count
                    )
                )
                Spacer(minLength: 0)
            }
            .padding(.top, 13)

            HStack(spacing: 9) {
                actionButton(
                    title: L10n.App2.Races.edit.localized,
                    systemImage: "pencil",
                    tint: App2Theme.accentBlueDeep,
                    border: App2Theme.accentBlue.opacity(0.25),
                    fillsWidth: true,
                    identifier: "App2_RacesEditMain"
                ) {
                    editingForm = viewModel.editForm(for: race.id)
                }
                actionButton(
                    title: L10n.App2.Races.delete.localized,
                    systemImage: "trash",
                    tint: App2Theme.accentRed,
                    border: App2Theme.accentRed.opacity(0.28),
                    fillsWidth: false,
                    identifier: "App2_RacesDeleteMain"
                ) {
                    pendingDeletion = race
                }
            }
            .padding(.top, 16)
        }
    }

    /// 倒數：已過期的賽事說「已結束」，不印負數。
    private func countdownValue(_ race: App2RaceCard) -> String {
        race.countdownDays >= 0
            ? String(race.countdownDays)
            : L10n.App2.Races.countdownPast.localized
    }

    // MARK: - 支援賽事

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(L10n.App2.Races.supportSection.localized)
                    .font(.system(size: 16, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(App2Theme.inkPrimary)
                Rectangle()
                    .fill(App2Theme.shadowInk.opacity(0.12))
                    .frame(height: 1)
                Text(L10n.App2.Races.sortedByDate.localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .fixedSize()
            }
            .padding(.horizontal, 2)

            if viewModel.supportingRaces.isEmpty {
                Text(L10n.App2.Races.noSupport.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(App2Theme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
                    )
                    .accessibilityIdentifier("App2_RacesNoSupport")
            } else {
                ForEach(viewModel.supportingRaces) { race in
                    supportCard(race)
                }
            }
        }
    }

    private func supportCard(_ race: App2RaceCard) -> some View {
        App2LeftStripCard(
            strip: App2Theme.accentBlue,
            cornerRadius: 18,
            padding: EdgeInsets(top: 14, leading: 15, bottom: 13, trailing: 15)
        ) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(race.name)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 8) {
                        App2Pill(
                            text: race.distanceLabel,
                            foreground: App2Theme.accentBlueDeep,
                            background: App2Theme.accentBlue.opacity(0.1),
                            border: App2Theme.accentBlue.opacity(0.2)
                        )
                        Text(race.dateLabel)
                            .font(.app2Mono(13, weight: .semibold))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(race.countdownDays >= 0
                         ? "\(L10n.App2.Races.countdown.localized) "
                            + String(format: L10n.App2.Races.countdownDays.localized, race.countdownDays)
                         : L10n.App2.Races.countdownPast.localized)
                        .font(.app2Mono(13))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                    if let goal = race.goalTime {
                        Text("\(L10n.App2.Races.goalTime.localized) \(goal)")
                            .font(.app2Mono(13, weight: .bold))
                            .foregroundStyle(App2Theme.inkTertiary)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                if race.canBecomeMain {
                    actionButton(
                        title: L10n.App2.Races.setAsMain.localized,
                        systemImage: "star",
                        tint: App2Theme.accentBlueDeep,
                        border: App2Theme.accentBlue.opacity(0.22),
                        background: App2Theme.accentBlue.opacity(0.1),
                        fillsWidth: true,
                        identifier: "App2_RacesSetMain_\(race.id)",
                        isDisabled: viewModel.isSaving,
                        showsProgress: viewModel.isSaving,
                        progressIdentifier: "App2_RacesPromotionLoading"
                    ) {
                        pendingPromotion = race
                        viewModel.requestSetAsMainConfirmation(race.id)
                    }
                } else {
                    Spacer(minLength: 0)
                }
                iconButton(
                    systemImage: "pencil",
                    tint: App2Theme.inkSubtle,
                    background: App2Theme.insetBackground,
                    border: App2Theme.cardBorder,
                    identifier: "App2_RacesEdit_\(race.id)"
                ) {
                    editingForm = viewModel.editForm(for: race.id)
                }
                iconButton(
                    systemImage: "trash",
                    tint: App2Theme.accentRed,
                    background: App2Theme.accentRed.opacity(0.07),
                    border: App2Theme.accentRed.opacity(0.2),
                    identifier: "App2_RacesDelete_\(race.id)"
                ) {
                    pendingDeletion = race
                }
            }
            .padding(.top, 5)
        }
    }

    // MARK: - 新增賽事

    private var addRaceButton: some View {
        dashedButton(
            title: L10n.App2.Races.addRace.localized,
            subtitle: nil,
            tint: App2Theme.inkSecondary,
            border: App2Theme.shadowInk.opacity(0.18),
            identifier: "App2_RacesAddCta"
        ) {
            editingForm = viewModel.newRaceForm()
        }
        .padding(.top, 16)
    }

    // MARK: - 小元件

    private func sectionHeader(_ title: String, color: Color, ruleColor: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .black))
                .tracking(0.5)
                .foregroundStyle(color)
            Rectangle().fill(ruleColor).frame(height: 1)
        }
        .padding(.horizontal, 2)
    }

    /// 形狀走共用的 `App2DashedAddButton`（`App2EditComponents`）——這一頁只是白底、
    /// 圓角與內距不同，不是第二顆虛線新增鈕。
    private func dashedButton(
        title: String,
        subtitle: String?,
        tint: Color,
        border: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        App2DashedAddButton(
            title: title,
            subtitle: subtitle,
            tint: tint,
            border: border,
            background: App2Theme.cardBackground,
            cornerRadius: subtitle == nil ? 16 : 22,
            verticalPadding: subtitle == nil ? 15 : 26,
            identifier: identifier,
            action: action
        )
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        border: Color,
        background: Color = App2Theme.cardBackground,
        fillsWidth: Bool,
        identifier: String,
        isDisabled: Bool = false,
        showsProgress: Bool = false,
        progressIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .heavy))
            }
            Text(title)
                .font(.system(size: 14, weight: .heavy))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .padding(.horizontal, fillsWidth ? 10 : 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(background))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { if !isDisabled { action() } }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityIdentifier(showsProgress ? (progressIdentifier ?? identifier) : identifier)
    }

    private func iconButton(
        systemImage: String,
        tint: Color,
        background: Color,
        border: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(tint)
            .frame(width: 40, height: 38)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(background))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
    }
}

// MARK: - App2RaceForm + Identifiable
/// `sheet(item:)` 要一個 identity。新增時沒有 target id，用一個固定值即可
/// （同時間只會有一張表單）。
extension App2RaceForm: Identifiable {
    var id: String { targetId ?? "new" }
}
