import SwiftUI

// MARK: - App2HeartRateZoneSettingsView
/// 2.0「心率區間」（設計 frame-26）：最大／靜息心率輸入 ＋ HRR 換算的 Z1–Z5 色條。
///
/// - 區間換算沿用 `App2OnboardingProjection.heartRateBands`（frame-33 同一支），
///   它底下是既有的 `HeartRateZone.calculateZones`。
/// - 儲存走 `App2SettingsViewModel.saveHeartRate` → 既有的 `UpdateHeartRateZonesUseCase`
///   （repository 會寫 profile 的 canonical 欄位 `max_hr`／`relaxing_hr` 並重算快取區間；
///   讀回來的也是同一組，所以存完重進來看到的是新值）。
struct App2HeartRateZoneSettingsView: View {

    @MainActor
    static func applySettingsSaveResult(
        _ changed: Bool,
        recompute: App2HeartRateRecomputeViewModel
    ) -> Bool {
        recompute.applyBackendSaveResult(changed)
    }

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    @State private var maxHR: Int = 190
    @State private var restingHR: Int = 60
    @State private var isSaving = false
    @State private var didLoadInitial = false
    @State private var profileResolved = false
    @State private var profileLoadFailed = false
    @State private var originalMaxHR: Int?
    @State private var originalRestingHR: Int?
    @State private var errorMessage: String?
    /// 這次進頁後真的存過、且後端說心率有變：範圍選「不重算」時直接收頁。
    @State private var closeAfterPrompt = false
    @StateObject private var recompute: App2HeartRateRecomputeViewModel

    init(onClose: @escaping () -> Void, viewModel: App2SettingsViewModel) {
        self.onClose = onClose
        self.viewModel = viewModel
        _recompute = StateObject(
            wrappedValue: App2HeartRateRecomputeViewModel(
                repository: DependencyContainer.shared.resolve() as HeartRateRecomputeRepository,
                autoUpdateMaxHR: viewModel.autoUpdateMaxHeartRate,
                updateProfile: { await viewModel.profile.updateUserProfile($0) }
            )
        )
    }

    /// 設計 frame-26／33 的五條色帶。
    private static let bandColors: [Color] = [
        App2Theme.trackAhead, App2Theme.trackOnTrack, App2Theme.bandAmber,
        App2Theme.bandOrange, App2Theme.bandRed
    ]

    private var bands: [App2OnboardingProjection.HeartRateBand] {
        App2OnboardingProjection.heartRateBands(maxHR: maxHR, restingHR: restingHR)
    }

    private var isValid: Bool { maxHR > restingHR }

    var body: some View {
        App2SettingsPageScaffold(
            title: NSLocalizedString("training.heart_rate_zone", comment: "HR Zone"),
            onBack: onClose,
            backIdentifier: "App2_HeartRateZoneClose",
            titleIdentifier: "App2_HeartRateZoneView",
            ctaTitle: NSLocalizedString("common.save", comment: "Save"),
            ctaEnabled: profileResolved && isValid,
            ctaBusy: isSaving,
            ctaIdentifier: "App2_HeartRateZoneSave",
            ctaAction: { save() }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if profileLoadFailed {
                    Button(NSLocalizedString("common.retry", comment: "Retry")) {
                        Task { await loadInitialIfNeeded() }
                    }
                    .accessibilityIdentifier("App2_HeartRateZoneRetry")
                }
                Text(L10n.App2.Onboarding.hrSubtitle.localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                stepperCard(
                    title: L10n.App2.Onboarding.hrMax.localized,
                    value: $maxHR,
                    range: 120...220,
                    identifier: "App2_HeartRateZoneMax",
                    source: viewModel.maxHeartRateSource,
                    sourceIdentifier: "App2_HeartRateZoneMaxSource",
                    isEstimated: viewModel.maxHeartRateIsEstimated
                )
                stepperCard(
                    title: L10n.App2.Onboarding.hrResting.localized,
                    value: $restingHR,
                    range: 30...120,
                    identifier: "App2_HeartRateZoneResting",
                    source: viewModel.restingHeartRateSource,
                    sourceIdentifier: "App2_HeartRateZoneRestingSource",
                    isEstimated: viewModel.restingHeartRateIsEstimated
                )

                bandsSection

                if let note = recompute.autoUpdate { autoUpdateNoteCard(note) }
                if let reminder = recompute.reminder { reminderCard(reminder) }
                autoUpdateCard
                recomputeSection
            }
        }
        .task {
            // This page must not render its 190/60 placeholders before the fresh profile read.
            await viewModel.profile.loadUserProfile(forceRefresh: true)
            resolveFreshProfile()
            await recompute.loadWatchCheck()
            await recompute.refresh()
        }
        .confirmationDialog(
            NSLocalizedString("app2.hr_recompute.prompt_title", comment: ""),
            isPresented: $recompute.isPromptPresented,
            titleVisibility: .visible
        ) {
            ForEach(App2HeartRateRecomputeViewModel.promptChoices, id: \.self) { choice in
                switch choice {
                case .days(let days):
                    Button(Self.title(for: days)) {
                        closeAfterPrompt = false
                        Task { await recompute.choose(days) }
                    }
                case .skip:
                    // 不設 `.cancel` 角色：iPhone 的 confirmationDialog 會把 cancel 藏起來。
                    Button(NSLocalizedString("app2.hr_recompute.no_recompute", comment: "")) {
                        let shouldClose = closeAfterPrompt
                        closeAfterPrompt = false
                        Task {
                            await recompute.choose(.skip)
                            if shouldClose { onClose() }
                        }
                    }
                }
            }
        } message: {
            Text(NSLocalizedString("app2.hr_recompute.prompt_message", comment: ""))
        }
        .alert(
            NSLocalizedString("error.unknown", comment: ""),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 數值卡（設計是左值右 −／＋）

    private func stepperCard(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        identifier: String,
        source: HeartRateParameterSource,
        sourceIdentifier: String,
        isEstimated: Bool
    ) -> some View {
        App2Card(spacing: 4) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.inkTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(value.wrappedValue)")
                            .font(.app2Numeric(32, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Text(L10n.App2.Onboarding.hrBpm.localized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                    Text(NSLocalizedString(source.localizationKey, comment: ""))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(App2Theme.inkMuted)
                        .accessibilityIdentifier(sourceIdentifier)
                    if isEstimated {
                        Text(NSLocalizedString("hr_zone.estimated_value", comment: "Estimated value"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                }
                Spacer(minLength: 8)
                // 形狀走共用的 `App2StepperButton`（`App2EditComponents`）——這一頁只是
                // 尺寸不同（52×46／圓角 14），不是第二顆 stepper 鈕。
                App2StepperButton(
                    systemImage: "minus",
                    width: 52, height: 46, cornerRadius: 14, glyphSize: 17,
                    identifier: "\(identifier)Minus"
                ) {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                }
                App2StepperButton(
                    systemImage: "plus",
                    filled: true,
                    width: 52, height: 46, cornerRadius: 14, glyphSize: 17,
                    identifier: "\(identifier)Plus"
                ) {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 區間色條

    private var bandsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.App2.Onboarding.hrBandsTitle.localized)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)

            HStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                    VStack(spacing: 2) {
                        Text("Z\(band.index)")
                            .font(.system(size: 14, weight: .black))
                        Text(band.nameKey.localized)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .background(Self.bandColors[min(index, Self.bandColors.count - 1)].opacity(0.95))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
            .accessibilityIdentifier("App2_HeartRateZoneBands")

            HStack(spacing: 0) {
                ForEach(bands) { band in
                    Text("\(band.upperBpm)")
                        .font(.app2Mono(13, weight: .bold))
                        .foregroundStyle(App2Theme.inkSubtle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Text(L10n.App2.Onboarding.hrBandsFooter.localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 手錶偏差提醒／自動更新／重算

    private static func title(for days: HeartRateRecomputeDays) -> String {
        switch days {
        case .fourteen: return NSLocalizedString("app2.hr_recompute.days_14", comment: "")
        case .thirty: return NSLocalizedString("app2.hr_recompute.days_30", comment: "")
        case .sixty: return NSLocalizedString("app2.hr_recompute.days_60", comment: "")
        }
    }

    private func reminderCard(_ reminder: HeartRateWatchReminder) -> some View {
        App2Card(spacing: 10) {
            Text(String(
                format: NSLocalizedString("app2.hr_recompute.reminder_text", comment: ""),
                reminder.watchMaxHr, reminder.profileMaxHr, reminder.deviationPct
            ))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(App2Theme.inkPrimary)
            .fixedSize(horizontal: false, vertical: true)
            Button {
                maxHR = min(220, max(120, reminder.watchMaxHr))
                save()
            } label: {
                Text(String(format: NSLocalizedString("app2.hr_recompute.reminder_action", comment: ""), reminder.watchMaxHr))
                    .font(.system(size: 14, weight: .heavy))
            }
            .disabled(isSaving)
            .accessibilityIdentifier("App2_HeartRateZoneReminderUpdate")
            Button {
                Task { await recompute.dismissReminder() }
            } label: {
                Text(NSLocalizedString("app2.hr_recompute.reminder_dismiss", comment: ""))
                    .font(.system(size: 14, weight: .semibold))
            }
            .accessibilityIdentifier("App2_HeartRateZoneReminderDismiss")
        }
        .accessibilityIdentifier("App2_HeartRateZoneReminder")
    }

    /// 手錶自動更新後的說明＋同一條重算入口（HZ-INV-18）；更新本身不會重算。
    private func autoUpdateNoteCard(_ note: HeartRateWatchAutoUpdate) -> some View {
        App2Card(spacing: 10) {
            Text(String(format: NSLocalizedString("app2.hr_recompute.auto_update_note", comment: ""), note.localDate, note.maxHr))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("App2_HeartRateZoneAutoUpdateNote")
            Button {
                closeAfterPrompt = false
                recompute.isPromptPresented = true
            } label: {
                Text(NSLocalizedString("app2.hr_recompute.entry_title", comment: ""))
                    .font(.system(size: 14, weight: .heavy))
            }
            .disabled(!recompute.canStart)
            .accessibilityIdentifier("App2_HeartRateZoneAutoUpdateRecompute")
        }
    }

    private var autoUpdateCard: some View {
        App2Card(spacing: 6) {
            Toggle(
                NSLocalizedString("app2.hr_recompute.auto_title", comment: ""),
                isOn: Binding(
                    get: { recompute.autoUpdateMaxHR },
                    set: { value in Task { await recompute.setAutoUpdate(value) } }
                )
            )
            .font(.system(size: 15, weight: .heavy))
            .accessibilityIdentifier("App2_HeartRateZoneAutoUpdate")
            Text(NSLocalizedString("app2.hr_recompute.auto_footer", comment: ""))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recomputeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                closeAfterPrompt = false
                recompute.isPromptPresented = true
            } label: {
                Text(NSLocalizedString("app2.hr_recompute.entry_title", comment: ""))
                    .font(.system(size: 15, weight: .heavy))
            }
            .disabled(!recompute.canStart)
            .accessibilityIdentifier("App2_HeartRateZoneRecompute")

            Text(NSLocalizedString("app2.hr_recompute.entry_footer", comment: ""))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            recomputeStatus
        }
    }

    @ViewBuilder
    private var recomputeStatus: some View {
        switch recompute.phase {
        case .idle:
            EmptyView()
        case .starting:
            statusLine(NSLocalizedString("app2.hr_recompute.starting", comment: ""))
        case .notice(let text):
            statusLine(text)
        case .job(let job, let message):
            VStack(alignment: .leading, spacing: 8) {
                if job.isActive, job.total > 0 {
                    ProgressView(value: Double(job.done), total: Double(job.total))
                }
                statusLine(message ?? fallbackText(for: job))
                if job.status == .failed {
                    retryButton
                }
            }
        case .failed(let text):
            VStack(alignment: .leading, spacing: 8) {
                statusLine(text)
                retryButton
            }
        }
    }

    private var retryButton: some View {
        Button(NSLocalizedString("app2.hr_recompute.retry", comment: "")) {
            closeAfterPrompt = false
            recompute.isPromptPresented = true
        }
        .font(.system(size: 14, weight: .heavy))
        .accessibilityIdentifier("App2_HeartRateZoneRecomputeRetry")
    }

    private func statusLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(App2Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("App2_HeartRateZoneRecomputeStatus")
    }

    private func fallbackText(for job: HeartRateRecomputeJob) -> String {
        job.status == .queued ? NSLocalizedString("app2.hr_recompute.queued", comment: "") : "\(job.done)/\(job.total)"
    }

    // MARK: - 狀態

    private func resolveFreshProfile() async {
        let age = UserDefaults.standard.object(forKey: "age") as? Int ?? 30
        guard let defaults = await viewModel.loadHeartRateDefaults(age: age) else {
            profileLoadFailed = true
            return
        }
        maxHR = defaults.maxHR
        restingHR = defaults.restingHR
        originalMaxHR = maxHR
        originalRestingHR = restingHR
        didLoadInitial = true
        profileResolved = true
        profileLoadFailed = false
    }

    private func loadInitialIfNeeded() async {
        guard !profileResolved else { return }
        profileLoadFailed = false
        await resolveFreshProfile()
    }

    private func save() {
        guard !isSaving, profileResolved, isValid else { return }
        isSaving = true
        Task {
            var updates: [String: Any] = [:]
            if originalMaxHR != maxHR { updates["max_hr"] = maxHR }
            if originalRestingHR != restingHR { updates["relaxing_hr"] = restingHR }
            if updates.isEmpty { isSaving = false; onClose(); return }
            let changed = await viewModel.saveHeartRate(maxHR: maxHR, restingHR: restingHR, updates: updates)
            isSaving = false
            guard let changed else {
                errorMessage = NSLocalizedString("error.unknown", comment: "")
                return
            }
            // 存永遠先成功；「有沒有變」只看後端。變了就問一次要不要重算，沒變照舊收頁。
            await recompute.loadWatchCheck()
            guard Self.applySettingsSaveResult(changed, recompute: recompute) else {
                onClose()
                return
            }
            closeAfterPrompt = true
        }
    }
}
