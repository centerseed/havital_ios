import SwiftUI

// MARK: - Display Mode Enum
enum HeartRateViewMode {
    case onboarding(targetDistance: Double) // Onboarding 模式，包含目標距離用於導航
    case profile // Profile 模式
}

struct HeartRateZoneInfoView: View {

    @MainActor
    static func applyProfileSaveResult(
        _ changed: Bool,
        recompute: App2HeartRateRecomputeViewModel
    ) -> Bool {
        recompute.applyBackendSaveResult(changed)
    }
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserProfileFeatureViewModel()
    @State private var maxHeartRate: Int = 190
    @State private var restingHeartRate: Int = 60
    @State private var maxHeartRateIsEstimated = false
    @State private var restingHeartRateIsEstimated = false
    @State private var isLoading = true
    @State private var profileReadFailed = false
    @State private var originalBackendMaxHR: Int?
    @State private var originalBackendRestingHR: Int?
    @State private var initialMaxHR = 190
    @State private var initialRestingHR = 60
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    @State private var navigateToPersonalBest = false
    @State private var navigateToBackfillPrompt = false
    @State private var closeAfterRecomputePrompt = false
    @StateObject private var recompute = App2HeartRateRecomputeViewModel(
        repository: DependencyContainer.shared.resolve() as HeartRateRecomputeRepository,
        autoUpdateMaxHR: false,
        updateProfile: { _ in false }
    )

    /// 心率區間從目前的最大/靜息心率即時計算 — picker 一變動，下方區間就跟著更新。
    private var zones: [HeartRateZone] {
        HeartRateZone.calculateZones(maxHR: maxHeartRate, restingHR: restingHeartRate)
    }

    private let backfillCoordinator = OnboardingBackfillCoordinator.shared
    private let mode: HeartRateViewMode

    // MARK: - Initializers
    init(mode: HeartRateViewMode = .profile) {
        self.mode = mode
    }

    // MARK: - Computed Properties
    private var isOnboardingMode: Bool {
        if case .onboarding = mode {
            return true
        }
        return false
    }

    private var targetDistance: Double? {
        if case .onboarding(let distance) = mode {
            return distance
        }
        return nil
    }

    @ObservedObject private var onboardingCoordinator = OnboardingCoordinator.shared

    var body: some View {
        contentView
            .accessibilityIdentifier("HeartRateZone_Screen")
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isOnboardingMode)
            .toolbar {
                // Onboarding 模式：顯示自訂返回按鈕
                if isOnboardingMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            onboardingCoordinator.goBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(NSLocalizedString("common.back", comment: "Back"))
                            }
                        }
                    }
                }
            }
            .toolbar {
                toolbarContent
            }
            .alert(NSLocalizedString("common.confirm", comment: "Confirm"), isPresented: $showingAlert) {
                Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .task {
                await loadZoneData()
                if !isOnboardingMode {
                    await recompute.loadWatchCheck()
                    await recompute.refresh()
                }
            }
            .confirmationDialog(
                NSLocalizedString("app2.hr_recompute.prompt_title", comment: ""),
                isPresented: $recompute.isPromptPresented,
                titleVisibility: .visible
            ) {
                ForEach(App2HeartRateRecomputeViewModel.promptChoices, id: \.self) { choice in
                    switch choice {
                    case .days(let days):
                        Button(Self.recomputeTitle(for: days)) {
                            closeAfterRecomputePrompt = false
                            Task { await recompute.choose(days) }
                        }
                    case .skip:
                        Button(NSLocalizedString("app2.hr_recompute.no_recompute", comment: "")) {
                            let shouldClose = closeAfterRecomputePrompt
                            closeAfterRecomputePrompt = false
                            Task {
                                await recompute.choose(.skip)
                                if shouldClose { dismiss() }
                            }
                        }
                    }
                }
            } message: {
                Text(NSLocalizedString("app2.hr_recompute.prompt_message", comment: ""))
            }
    }

    private static func recomputeTitle(for days: HeartRateRecomputeDays) -> String {
        switch days {
        case .fourteen: return NSLocalizedString("app2.hr_recompute.days_14", comment: "")
        case .thirty: return NSLocalizedString("app2.hr_recompute.days_30", comment: "")
        case .sixty: return NSLocalizedString("app2.hr_recompute.days_60", comment: "")
        }
    }

    // MARK: - View Components
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if profileReadFailed {
                    Text(NSLocalizedString("error.unknown", comment: ""))
                        .foregroundColor(.red)
                    Button(NSLocalizedString("common.retry", comment: "Retry")) {
                        Task { await loadZoneData() }
                    }
                    .accessibilityIdentifier("HeartRateZone_ProfileRetry")
                }
                descriptionText
                heartRateEditCards

                if isOnboardingMode {
                    howToKnowSection
                } else {
                    zoneSpectrumBar
                    zoneList
                    saveButton
                    recomputeStatus
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    @ViewBuilder
    private var descriptionText: some View {
        Text(isOnboardingMode ?
             NSLocalizedString("onboarding.heart_rate_description", comment: "Heart rate description") :
             NSLocalizedString("hr_zone.description", comment: "Heart rate zone description"))
            .font(AppFont.footnote())
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
    }

    // MARK: - How To Know (Onboarding only)

    /// Onboarding 專用：告訴用戶這兩個數字要去哪裡拿，以及填準了對他有什麼好處。
    /// 常駐顯示（不只在用預設值時），因為改過一次數值後仍可能想確認自己填得對不對。
    @ViewBuilder
    private var howToKnowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            howToRow(
                title: NSLocalizedString("hr_zone.max_hr", comment: "Max HR"),
                body: NSLocalizedString("hr_zone.how_to_max_hr", comment: "How to find max HR")
            )
            howToRow(
                title: NSLocalizedString("hr_zone.resting_hr", comment: "Resting HR"),
                body: NSLocalizedString("hr_zone.how_to_resting_hr", comment: "How to find resting HR")
            )

            Text(NSLocalizedString("hr_zone.accuracy_note", comment: "Why accuracy matters"))
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func howToRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(.primary)
            Text(body)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - HR Edit Cards (Hero)

    @ViewBuilder
    private var heartRateEditCards: some View {
        HStack(spacing: 12) {
            hrEditCard(
                iconName: "bolt.heart.fill",
                accent: .red,
                title: NSLocalizedString("hr_zone.max_hr", comment: "Max HR"),
                value: $maxHeartRate,
                range: 100...250,
                isEstimated: maxHeartRateIsEstimated
            )

            hrEditCard(
                iconName: "moon.zzz.fill",
                accent: .indigo,
                title: NSLocalizedString("hr_zone.resting_hr", comment: "Resting HR"),
                value: $restingHeartRate,
                range: 30...120,
                isEstimated: restingHeartRateIsEstimated
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func hrEditCard(iconName: String, accent: Color, title: String, value: Binding<Int>, range: ClosedRange<Int>, isEstimated: Bool) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.15), value: value.wrappedValue)
                Text("bpm")
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            if isEstimated {
                Text(NSLocalizedString("hr_zone.estimated_value", comment: "Estimated value"))
                    .font(AppFont.captionSmall())
                    .foregroundColor(.secondary)
            }

            Stepper("", value: value, in: range)
                .labelsHidden()
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Zone Spectrum Bar (Visual)

    @ViewBuilder
    private var zoneSpectrumBar: some View {
        let zoneLow = zones.first?.range.lowerBound ?? Double(restingHeartRate)
        let zoneHigh = zones.last?.range.upperBound ?? Double(maxHeartRate)
        let totalRange = max(1.0, zoneHigh - zoneLow)

        VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(zones, id: \.zone) { zone in
                        let proportion = (zone.range.upperBound - zone.range.lowerBound) / totalRange
                        let segmentWidth = max(14, geo.size.width * proportion - 2)
                        ZStack {
                            zoneColor(for: zone.zone).opacity(0.88)
                            Text("\(zone.zone)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: segmentWidth)
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("\(Int(zoneLow.rounded())) bpm")
                Spacer()
                Text("\(Int(zoneHigh.rounded())) bpm")
            }
            .font(AppFont.captionSmall())
            .foregroundColor(.secondary)
            .monospacedDigit()
        }
        .padding(.horizontal)
    }

    // MARK: - Compact Zone List

    @ViewBuilder
    private var zoneList: some View {
        VStack(spacing: 0) {
            ForEach(Array(zones.enumerated()), id: \.element.zone) { index, zone in
                HStack(spacing: 12) {
                    Circle()
                        .fill(zoneColor(for: zone.zone))
                        .frame(width: 10, height: 10)

                    Text("Z\(zone.zone)")
                        .font(AppFont.captionMedium())
                        .foregroundColor(.secondary)
                        .frame(width: 22, alignment: .leading)
                        .monospacedDigit()

                    Text(zone.name)
                        .font(AppFont.body())
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 3) {
                        Text("\(Int(zone.range.lowerBound.rounded()))-\(Int(zone.range.upperBound.rounded()))")
                            .font(AppFont.bodySmall())
                            .foregroundColor(.primary)
                            .monospacedDigit()
                        Text("bpm")
                            .font(AppFont.captionSmall())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if index < zones.count - 1 {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - Save Button

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task { await saveHeartRateZones() }
        } label: {
            ZStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(NSLocalizedString("hr_zone.save_settings", comment: "Save Settings"))
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.accentColor)
            .cornerRadius(14)
        }
        .disabled(isSaving || isLoading || profileReadFailed)
        .padding(.horizontal)
    }

    private var navigationTitle: String {
        isOnboardingMode ?
            NSLocalizedString("onboarding.heart_rate_title", comment: "Heart Rate Settings") :
            NSLocalizedString("hr_zone.info", comment: "Heart Rate Zone Info")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isOnboardingMode {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 略過按鈕
                    Button(action: {
                        onboardingCoordinator.navigate(to: .personalBest)
                    }) {
                        Text(NSLocalizedString("onboarding.skip", comment: "Skip"))
                            .foregroundColor(.secondary)
                    }
                    .disabled(isLoading || profileReadFailed)

                    // 下一步按鈕
                    Button(action: {
                        Task { await saveHeartRateZones() }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("onboarding.next", comment: "Next"))
                        }
                    }
                    .disabled(isSaving || isLoading || profileReadFailed)
                    .accessibilityIdentifier("HeartRateZone_ContinueButton")
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Private Functions

    /// 從本地存儲讀取用戶年齡，用於計算預設最大心率。
    /// 不需要 async 載入：age 直接從 UserDefaults 讀取，與 UserPreferencesLocalDataSource 使用相同 key。
    private var userAgeFromLocalStorage: Int {
        UserDefaults.standard.object(forKey: "age") as? Int ?? 30
    }

    @MainActor
    private func loadZoneData() async {
        isLoading = true

        // The legacy bridge may have a stale local zone cache. Load the profile from GET /user
        // first; the page's displayed values must not come from UserDefaults.
        await viewModel.refreshUserProfile()
        guard case .loaded(let user) = viewModel.profileState else {
            profileReadFailed = true
            isLoading = false
            return
        }
        originalBackendMaxHR = user.maxHr
        originalBackendRestingHR = user.relaxingHr
        await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
        loadCurrentValues()
        initialMaxHR = maxHeartRate
        initialRestingHR = restingHeartRate
        profileReadFailed = false

        isLoading = false
    }

    private func loadCurrentValues() {
        if let maxHR = viewModel.currentUser?.maxHr {
            maxHeartRate = maxHR
            maxHeartRateIsEstimated = false
        } else if isOnboardingMode {
            // Onboarding 首次進入且無心率記錄：使用基於年齡的預設值（220 - 年齡）。
            // 規則本體收斂在 App2OnboardingProjection.estimatedMaxHR —— 2.0 的心率頁用同一條。
            maxHeartRate = App2OnboardingProjection.estimatedMaxHR(age: userAgeFromLocalStorage)
            maxHeartRateIsEstimated = true
        } else {
            maxHeartRate = App2OnboardingProjection.estimatedMaxHR(age: userAgeFromLocalStorage)
            maxHeartRateIsEstimated = true
        }

        if let restingHR = viewModel.currentUser?.relaxingHr {
            restingHeartRate = restingHR
            restingHeartRateIsEstimated = false
        } else {
            // 靜息心率預設 60 bpm（常見健康成人靜息心率）
            restingHeartRate = 60
            restingHeartRateIsEstimated = true
        }
    }

    @MainActor
    private func saveHeartRateZones() async {
        guard !isLoading, !profileReadFailed else { return }
        if maxHeartRate <= restingHeartRate {
            alertMessage = NSLocalizedString("hr_zone.max_greater_than_resting", comment: "Max greater than resting")
            showingAlert = true
            return
        }

        if maxHeartRate > 250 || maxHeartRate < 100 {
            alertMessage = NSLocalizedString("hr_zone.max_hr_range", comment: "Max HR range")
            showingAlert = true
            return
        }

        if restingHeartRate < 30 || restingHeartRate > 120 {
            alertMessage = NSLocalizedString("hr_zone.resting_hr_range", comment: "Resting HR range")
            showingAlert = true
            return
        }

        isSaving = true

        do {
            var updates: [String: Any] = [:]
            if maxHeartRate != initialMaxHR { updates["max_hr"] = maxHeartRate }
            if restingHeartRate != initialRestingHR { updates["relaxing_hr"] = restingHeartRate }
            if isOnboardingMode, originalBackendMaxHR == nil, originalBackendRestingHR == nil {
                updates["max_hr"] = maxHeartRate
                updates["relaxing_hr"] = restingHeartRate
            }
            if updates.isEmpty {
                isSaving = false
                if isOnboardingMode { onboardingCoordinator.navigate(to: .personalBest) } else { dismiss() }
                return
            }
            let changed = await viewModel.updateHeartRateZones(maxHR: maxHeartRate, restingHR: restingHeartRate, updates: updates)
            if changed != nil { viewModel.updateHeartRateData(maxHR: maxHeartRate, restingHR: restingHeartRate) }

            isSaving = false
            guard let changed else {
                alertMessage = NSLocalizedString("hr_zone.save_failed_generic", comment: "Save failed")
                showingAlert = true
                return
            }

            HeartRateProfileRefreshNotifier.notifySaved(isOnboardingMode: isOnboardingMode)

            if isOnboardingMode {
                // Onboarding 模式：檢查是否需要顯示 backfill 提示並導航
                onboardingCoordinator.navigate(to: .personalBest)
            } else {
                // Profile 模式：存檔成功後只依後端 changed 決定是否詢問重算。
                closeAfterRecomputePrompt = true
                await recompute.loadWatchCheck()
                guard Self.applyProfileSaveResult(changed, recompute: recompute) else {
                    dismiss()
                    return
                }
            }

        } catch {
            isSaving = false
            alertMessage = String(format: NSLocalizedString("hr_zone.save_failed", comment: "Save failed"), error.localizedDescription)
            showingAlert = true
        }
    }

    @ViewBuilder
    private var recomputeStatus: some View {
        switch recompute.phase {
        case .idle:
            EmptyView()
        case .starting:
            recomputeStatusLine(NSLocalizedString("app2.hr_recompute.starting", comment: ""))
        case .notice(let text):
            recomputeStatusLine(text)
        case .job(let job, let message):
            VStack(alignment: .leading, spacing: 8) {
                if job.isActive, job.total > 0 {
                    ProgressView(value: Double(job.done), total: Double(job.total))
                }
                recomputeStatusLine(message ?? fallbackRecomputeText(for: job))
                if job.status == .failed {
                    recomputeRetryButton
                }
            }
        case .failed(let text):
            VStack(alignment: .leading, spacing: 8) {
                recomputeStatusLine(text)
                Button(NSLocalizedString("app2.hr_recompute.retry", comment: "")) {
                    recompute.isPromptPresented = true
                }
                .font(.system(size: 14, weight: .semibold))
                .accessibilityIdentifier("HeartRateZoneRecomputeRetry")
            }
        }
    }

    private func fallbackRecomputeText(for job: HeartRateRecomputeJob) -> String {
        switch job.status {
        case .queued:
            return NSLocalizedString("app2.hr_recompute.queued", comment: "")
        case .updating:
            return NSLocalizedString("app2.hr_recompute.updating", comment: "")
        default:
            return "\(job.done)/\(job.total)"
        }
    }

    private var recomputeRetryButton: some View {
        Button(NSLocalizedString("app2.hr_recompute.retry", comment: "")) {
            recompute.isPromptPresented = true
        }
        .font(.system(size: 14, weight: .semibold))
        .accessibilityIdentifier("HeartRateZoneRecomputeRetry")
    }

    private func recomputeStatusLine(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("HeartRateZoneRecomputeStatus")
    }

    private func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return .blue      // recovery
        case 2: return .green     // easy
        case 3: return .yellow    // tempo
        case 4: return .pink      // threshold
        case 5: return .purple    // anaerobic
        case 6: return .red       // interval
        default: return .gray
        }
    }
}

enum HeartRateProfileRefreshNotifier {
    static func notifySaved(isOnboardingMode: Bool) {
        guard !isOnboardingMode else { return }
        CacheEventBus.shared.publish(.dataChanged(.user))
    }
}

// MARK: - Previews
#Preview("Profile Mode") {
    HeartRateZoneInfoView(mode: .profile)
}

#Preview("Onboarding Mode") {
    HeartRateZoneInfoView(mode: .onboarding(targetDistance: 42.195))
}
