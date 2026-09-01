import SwiftUI

// MARK: - App2OnboardingContainerView
/// 2.0 onboarding 的 NavigationStack 殼（設計 frame-30 ~ frame-39）。
///
/// 取代 1.x 的 `OnboardingContainerView`**只在 2.0 分支**；`main` 發版線仍用 1.x 那支
/// （同 `App2RootView` 的做法，見那支檔頭）。流程與提交全部走
/// `App2OnboardingViewModel` → `OnboardingFeatureViewModel` / `OnboardingCoordinator`。
struct App2OnboardingContainerView: View {

    @ObservedObject private var appearanceStore = App2AppearanceStore.shared
    @StateObject private var viewModel: App2OnboardingViewModel
    /// 從設定頁「重新設定目標賽事」進來時，完成後要把 cover 關掉。
    let onFinished: (() -> Void)?
    /// **還沒提交就想離開**時把 cover 關掉（2026-08-31 用戶實機回報，T-0364）。
    ///
    /// re-onboarding 的第一頁（目標類型）是 `NavigationStack` 的**根頁**，沒有上一頁可退；
    /// 而整條流程開在 `fullScreenCover`、`navigationBarHidden`，所以既沒有系統返回鍵、
    /// 也沒有邊緣滑回。在補上這條之前，從訓練計劃按「重新設定計畫」之後**唯一的出口是
    /// 把整條流程走完**——使用者的原話是「直接卡死」。
    /// nil ＝ 呼叫端沒有提供出口（那一頁的返回鍵維持 disabled，與補這條之前相同）。
    let onCancel: (() -> Void)?

    init(
        isReonboarding: Bool,
        onFinished: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: App2OnboardingViewModel(isReonboarding: isReonboarding))
        self.onFinished = onFinished
        self.onCancel = onCancel
    }

    /// 目標類型頁返回鍵要做什麼。**同一頁在兩條流程裡的身分不同**，所以不是同一個動作：
    ///
    /// - 首次 onboarding：它是從開場頁推出來的第二頁 → 返回＝`pop()` 退回開場頁。
    /// - re-onboarding：它是根頁 → 返回＝關掉整個 cover，回到進來的那一頁。
    ///
    /// 抽成純函式是為了讓「re-onboarding 的第一頁必須有出口」這條可以被單獨鎖住
    /// （`App2OnboardingBackActionTests`）——它是這張票要防的退化。
    static func goalTypeBackAction(
        isReonboarding: Bool,
        onCancel: (() -> Void)?,
        pop: @escaping () -> Void
    ) -> (() -> Void)? {
        isReonboarding ? onCancel : pop
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            root
                .navigationBarHidden(true)
                .navigationDestination(for: App2OnboardingViewModel.Step.self) { step in
                    page(step)
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true)
                }
        }
        .environmentObject(viewModel.flow)
        .task {
            await viewModel.loadInitial()
        }
        .alert(
            L10n.Common.error.localized,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.Common.ok.localized, role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .preferredColorScheme(appearanceStore.preference.colorScheme)
    }

    @ViewBuilder
    private var root: some View {
        if viewModel.isReonboarding {
            App2OnboardingGoalTypeView(viewModel: viewModel, onCancel: onCancel)
        } else {
            App2OnboardingWelcomeView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func page(_ step: App2OnboardingViewModel.Step) -> some View {
        switch step {
        // 被推出來的那一次（首次 onboarding）不帶 `onCancel`：那時它不是根頁，
        // 返回就是退回開場頁。
        case .goalType:     App2OnboardingGoalTypeView(viewModel: viewModel)
        case .raceSetup:    App2OnboardingRaceSetupView(viewModel: viewModel)
        case .heartRate:    App2OnboardingHeartRateView(viewModel: viewModel)
        case .deviceLink:   App2OnboardingDeviceLinkView(viewModel: viewModel)
        case .recentResult: App2OnboardingRecentResultView(viewModel: viewModel)
        case .methodology:  App2OnboardingMethodologyView(viewModel: viewModel)
        case .trainingDays: App2OnboardingTrainingDaysView(viewModel: viewModel)
        case .mileage:      App2OnboardingMileageView(viewModel: viewModel)
        case .completion:   App2OnboardingCompletionView(viewModel: viewModel, onFinished: onFinished)
        }
    }
}

// MARK: - 共用小工具

enum App2OnboardingFormat {

    /// repo 慣例：1 = 週一 … 7 = 週日（`prefer_week_days`）。
    static func weekdayShort(_ weekday: Int) -> String {
        let keys = ["weekday.mon_short", "weekday.tue_short", "weekday.wed_short",
                    "weekday.thu_short", "weekday.fri_short", "weekday.sat_short", "weekday.sun_short"]
        guard (1...7).contains(weekday) else { return "" }
        return NSLocalizedString(keys[weekday - 1], comment: "")
    }

    static func weekdayFull(_ weekday: Int) -> String {
        let keys = ["weekday.monday", "weekday.tuesday", "weekday.wednesday",
                    "weekday.thursday", "weekday.friday", "weekday.saturday", "weekday.sunday"]
        guard (1...7).contains(weekday) else { return "" }
        return NSLocalizedString(keys[weekday - 1], comment: "")
    }

    /// 設計用 `2026-12-06`。
    static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func weeksFromNow(to date: Date) -> Int {
        TrainingWeeksCalculator.calculateTrainingWeeks(startDate: Date(), raceDate: date)
    }

    /// 秒 → `H:MM:SS`／`MM:SS`。
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// 距離顯示名。
    ///
    /// 用既有的 **`race_filter.*`**（`5K`／`10K`／`半馬`／`全馬`）而不是 `distance.*`
    /// （`5公里`／`半程馬拉松`）：設計 frame-32／35 的 chip 是短式，長式在 390pt 寬會折行。
    /// 兩組詞條都是既有的，這裡只是選對那一組，沒有新增。
    /// 賽事庫回來的距離會有 21.0 / 42.0 這種整數值，一併容差比對。
    /// 標準賽距以外的 fallback 跟著用戶單位制走（`12 km`／`7.5 mi`）——
    /// 標準賽距是**名字**（全馬就是全馬），不換算。
    ///
    /// 2026-09-01 收斂：`App2HomeViewModel.distanceLabel(km:)` 與
    /// `App2PlanEndProjection.distanceLabel(km:)` 原本各留一份 `Int` 版（容差更差、
    /// fallback 一樣寫死 `km`），兩份都刪掉改叫這一支。
    static func distanceLabel(
        km: Double,
        unitSystem: UnitSystem? = nil
    ) -> String {
        let unitSystem = unitSystem ?? .current
        // 容差 0.25：後端的 `distance_km` 常是整數（`42` 而不是 `42.195`），
        // 太緊的容差會讓完成頁的徽章印成「42 km」而不是「全馬」。
        func isNear(_ target: Double) -> Bool { abs(km - target) < 0.25 }
        if isNear(5)       { return NSLocalizedString("race_filter.5k", comment: "") }
        if isNear(10)      { return NSLocalizedString("race_filter.10k", comment: "") }
        if isNear(21.0975) { return NSLocalizedString("race_filter.half_marathon", comment: "") }
        if isNear(42.195)  { return NSLocalizedString("race_filter.full_marathon", comment: "") }
        // 公制維持原樣（`42.195` 要看得出小數）；英制換算後取一位小數，
        // 否則 `%g` 會把 12 km 印成 `7.45645 mi`。
        let value = unitSystem == .metric
            ? kmValue(km)
            : String(format: "%.1f", unitSystem.convertedDistance(km))
        return value + " " + unitSystem.distanceSuffix
    }

    /// `42.195` / `21.0975` 要看得出小數，`10` 不要變成 `10.0`。
    static func kmValue(_ km: Double) -> String {
        km == km.rounded() ? String(Int(km)) : String(format: "%g", km)
    }

    /// 設計 frame-32／35 的四個距離 chip。
    static let raceDistanceKeys: [String] = ["5", "10", "21.0975", "42.195"]
}

// MARK: - frame-30 開場

struct App2OnboardingWelcomeView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel

    /// `linear-gradient(180deg,#0a4f96 0%, #1774cf 30%, #3f8fdb 44%, #cfe0f0 60%, #eef2f7 66%, …)`
    private var backdrop: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: App2Theme.skyDeep, location: 0),
                .init(color: App2Theme.skyMid, location: 0.30),
                .init(color: App2Theme.skyLight, location: 0.44),
                .init(color: App2Theme.skyPale, location: 0.60),
                .init(color: App2Theme.pageBottom, location: 0.66),
                .init(color: App2Theme.pageBottom, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("RIZO")
                    .font(.system(size: 14, weight: .black))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.85))
                    // 頁面標記掛在這一顆葉節點上，不掛在外層 —— 掛外層會把
                    // 底下每一顆按鈕的 identifier 都蓋成同一個（見 `App2OnboardingTitleBlock`）。
                    .accessibilityIdentifier("App2_OnboardingWelcome")

                Text(L10n.App2.Onboarding.welcomeTitle.localized)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                Text(L10n.App2.Onboarding.welcomeSubtitle.localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 24)

            ScrollView {
                VStack(spacing: 12) {
                    stepCard(1, L10n.App2.Onboarding.welcomeStep1Title, L10n.App2.Onboarding.welcomeStep1Body, highlighted: false)
                    arrow
                    stepCard(2, L10n.App2.Onboarding.welcomeStep2Title, L10n.App2.Onboarding.welcomeStep2Body, highlighted: false)
                    arrow
                    stepCard(3, L10n.App2.Onboarding.welcomeStep3Title, L10n.App2.Onboarding.welcomeStep3Body, highlighted: true)

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .bold))
                        Text(L10n.App2.Onboarding.welcomeNote.localized)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(App2Theme.inkMuted)
                    .padding(.top, 20)
                }
                .padding(.horizontal, 26)
                .padding(.top, 30)
                .padding(.bottom, 20)
            }

            VStack(spacing: 12) {
                App2OnboardingPrimaryButton(
                    title: L10n.App2.Onboarding.welcomeCta.localized,
                    trailingArrow: true,
                    identifier: "App2_OnboardingWelcomeCta"
                ) {
                    viewModel.push(.goalType)
                }

                Text(L10n.App2.Onboarding.welcomeDuration.localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backdrop.ignoresSafeArea())
    }

    private var arrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(App2Theme.onbHintOnDark)
    }

    private func stepCard(_ number: Int, _ titleKey: String, _ bodyKey: String, highlighted: Bool) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(highlighted ? App2Theme.accentBlue : App2Theme.accentBlue.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(number)")
                        .font(.app2Mono(17, weight: .black))
                        .foregroundStyle(highlighted ? Color.white : App2Theme.accentBlueDeep)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey.localized)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(bodyKey.localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(highlighted ? App2Theme.inkSecondary : App2Theme.inkSubtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlighted
                      ? AnyShapeStyle(App2Theme.accentCardGradient(strength: 0.10))
                      : AnyShapeStyle(App2Theme.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    highlighted ? App2Theme.accentBlue.opacity(0.35) : App2Theme.cardBorder,
                    lineWidth: highlighted ? 1.5 : 1
                )
        )
        .shadow(color: App2Theme.shadowInk.opacity(0.16), radius: 12, x: 0, y: 8)
    }
}

// MARK: - frame-31 目標類型

struct App2OnboardingGoalTypeView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    /// re-onboarding 時這一頁是根頁，返回＝離開整條流程（見容器的 `onCancel`）。
    var onCancel: (() -> Void)?
    @EnvironmentObject private var flow: OnboardingFeatureViewModel

    /// 設計 frame-31 的三張卡（文案與圖示是設計 SSOT；語意映射到既有 `target_type`）。
    private static let designCopy: [String: (icon: String, title: String, body: String)] = [
        "race_run":    ("flag.fill",       L10n.App2.Onboarding.goalRaceTitle,        L10n.App2.Onboarding.goalRaceBody),
        "maintenance": ("waveform.path.ecg", L10n.App2.Onboarding.goalMaintenanceTitle, L10n.App2.Onboarding.goalMaintenanceBody),
        "beginner":    ("figure.run",      L10n.App2.Onboarding.goalBeginnerTitle,    L10n.App2.Onboarding.goalBeginnerBody)
    ]
    private static let designOrder = ["race_run", "maintenance", "beginner"]

    private var orderedTargetTypes: [TargetTypeV2] {
        flow.availableTargetTypes.sorted { lhs, rhs in
            let l = Self.designOrder.firstIndex(of: lhs.id) ?? Int.max
            let r = Self.designOrder.firstIndex(of: rhs.id) ?? Int.max
            return l < r
        }
    }

    var body: some View {
        App2OnboardingPage(
            segment: .goal,
            progressWithinSegment: viewModel.progress(for: .goalType),
            onBack: App2OnboardingContainerView.goalTypeBackAction(
                isReonboarding: viewModel.isReonboarding,
                onCancel: onCancel,
                pop: { viewModel.pop() }
            ),
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaEnabled: flow.selectedTargetTypeV2 != nil,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingGoalTypeCta",
            ctaAction: { Task { await viewModel.confirmGoalType() } }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.goalTitle.localized,
                    subtitle: L10n.App2.Onboarding.goalSubtitle.localized,
                    identifier: "App2_OnboardingGoalType"
                )

                if flow.isLoadingTargetTypes && flow.availableTargetTypes.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    ForEach(orderedTargetTypes) { targetType in
                        card(for: targetType)
                    }
                }
            }
        }
    }

    private func card(for targetType: TargetTypeV2) -> some View {
        // 設計有指定文案的三型用設計文案；後端若新增第四型，退回後端自己的 name/description。
        let copy = Self.designCopy[targetType.id]
        return App2OnboardingOptionCard(
            title: copy.map { $0.title.localized } ?? targetType.name,
            subtitle: copy.map { $0.body.localized } ?? targetType.description,
            iconSystemName: copy?.icon ?? "target",
            isSelected: flow.selectedTargetTypeV2?.id == targetType.id,
            identifier: "App2_OnboardingGoalOption_\(targetType.id)"
        ) {
            viewModel.selectGoalType(targetType)
        }
    }
}

// MARK: - frame-32 目標賽事

struct App2OnboardingRaceSetupView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @EnvironmentObject private var flow: OnboardingFeatureViewModel

    @State private var isShowingRaceSearch = false

    var body: some View {
        App2OnboardingPage(
            segment: .goal,
            progressWithinSegment: viewModel.progress(for: .raceSetup),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaEnabled: viewModel.canContinueFromRaceSetup,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingRaceSetupCta",
            ctaAction: { Task { await viewModel.confirmRaceSetup() } }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.raceTitle.localized,
                    subtitle: L10n.App2.Onboarding.raceSubtitle.localized,
                    identifier: "App2_OnboardingRaceSetup"
                )

                supportedRaces
                divider
                manualForm
                targetTimeSection
            }
        }
        .sheet(isPresented: $isShowingRaceSearch) {
            // 賽事搜尋走既有畫面（`RacePickerDataSource` 已由 flow 實作），不重做一份。
            NavigationStack {
                RaceEventListView(dataSource: flow)
            }
        }
    }

    // MARK: 支援賽事橫捲

    private var supportedRaces: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                App2OnboardingFieldLabel(text: L10n.App2.Onboarding.raceSupported.localized)
                Spacer()
                Button { isShowingRaceSearch = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .black))
                        Text(L10n.App2.Onboarding.raceSearch.localized)
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(App2Theme.accentBlue))
                    .shadow(color: App2Theme.accentBlue.opacity(0.4), radius: 10, x: 0, y: 6)
                }
                .accessibilityIdentifier("App2_OnboardingRaceSearchButton")
            }

            if flow.isLoadingRaces && flow.raceEvents.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else if flow.raceEvents.isEmpty {
                // 賽事庫不可用時不擺空卡 —— 直接讓使用者自行填寫。
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(raceCards.enumerated()), id: \.offset) { _, pair in
                            raceCard(pair.0, pair.1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    /// 一張卡 ＝ 一場賽事的一個距離（設計 frame-32 的卡上有距離 pill）。上限 12 張。
    private var raceCards: [(RaceEvent, RaceDistance)] {
        var result: [(RaceEvent, RaceDistance)] = []
        for event in flow.raceEvents {
            for distance in event.distances {
                result.append((event, distance))
                if result.count >= 12 { return result }
            }
        }
        return result
    }

    private func raceCard(_ event: RaceEvent, _ distance: RaceDistance) -> some View {
        let isSelected = flow.selectedRaceEvent?.raceId == event.raceId
            && flow.selectedRaceDistance?.distanceKm == distance.distanceKm

        return Button {
            viewModel.selectRaceEvent(event, distance: distance)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // 距離名優先用賽事庫自己的 `name`（有「半程馬拉松」這種賽會自訂稱呼），
                    // 沒有才退回本地短式。
                    Text("\(distance.name.isEmpty ? App2OnboardingFormat.distanceLabel(km: distance.distanceKm) : distance.name) · \(App2OnboardingFormat.kmValue(distance.distanceKm)) km")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(isSelected ? App2Theme.accentBlueDeep : App2Theme.inkSubtle)
                    Spacer(minLength: 4)
                    Text(isSelected
                         ? L10n.App2.Onboarding.raceGoalBadge.localized
                         : L10n.App2.Onboarding.raceSetAsGoal.localized)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(isSelected ? .white : App2Theme.inkSubtle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(isSelected ? App2Theme.accentBlue : App2Theme.neutralFill)
                        )
                }

                Text(event.name)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)

                Text("\(App2OnboardingFormat.isoDate(event.eventDate)) · \(String(format: L10n.App2.Onboarding.raceWeeksAway.localized, App2OnboardingFormat.weeksFromNow(to: event.eventDate)))")
                    .font(.app2Mono(13, weight: .bold))
                    .foregroundStyle(App2Theme.inkSubtle)
            }
            .frame(width: 270, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(App2Theme.accentBlue.opacity(0.10))
                          : AnyShapeStyle(App2Theme.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? App2Theme.accentBlue : App2Theme.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("App2_OnboardingRaceCard_\(event.raceId)_\(Int(distance.distanceKm))")
    }

    // MARK: 或自行填寫

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(App2Theme.hairline).frame(height: 1)
            Text(L10n.App2.Onboarding.raceManualDivider.localized)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)
            Rectangle().fill(App2Theme.hairline).frame(height: 1)
        }
    }

    private var manualForm: some View {
        VStack(spacing: 12) {
            TextField(L10n.App2.Onboarding.raceNamePlaceholder.localized, text: $flow.raceName)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(App2Theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("App2_OnboardingRaceNameField")

            HStack(spacing: 10) {
                ForEach(App2OnboardingFormat.raceDistanceKeys, id: \.self) { key in
                    App2OnboardingChip(
                        title: App2OnboardingFormat.distanceLabel(km: Double(key) ?? 0),
                        isSelected: flow.selectedDistance == key,
                        identifier: "App2_OnboardingRaceDistance_\(key)"
                    ) {
                        flow.selectedDistance = key
                        flow.clearSelectedRace()
                    }
                }
            }

            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(App2OnboardingFormat.kmValue(Double(flow.selectedDistance) ?? 0))
                        .font(.app2Mono(19, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 4)
                    Text("km")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(fieldSurface)

                DatePicker("", selection: $flow.raceDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(fieldSurface)
                    .accessibilityIdentifier("App2_OnboardingRaceDateField")
            }
        }
    }

    private var fieldSurface: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(App2Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
    }

    // MARK: 目標完賽時間

    private var targetTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                App2OnboardingFieldLabel(text: L10n.App2.Onboarding.raceTargetTime.localized)
                Spacer()
                paceChip
            }

            // 輪盤取代三個自由輸入框（2026-08-27 使用者回報游標問題，
            // 與賽事表單同一顆 `App2FinishTimeRow`）。
            App2FinishTimeRow(
                hours: $flow.targetHours,
                minutes: $flow.targetMinutes,
                seconds: $viewModel.raceTargetSeconds,
                identifier: "App2_OnboardingRaceTargetTime"
            )
        }
    }

    /// 配速用既有的 `OnboardingFeatureViewModel.targetPace`（不另寫換算）。
    private var paceChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .black))
            Text(flow.targetPace)
                .font(.app2Mono(17, weight: .black))
            Text("/km")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(App2Theme.accentBlueDeep)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(App2Theme.accentBlue.opacity(0.28), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_OnboardingRacePaceChip")
    }
}

// MARK: - frame-33 心率

struct App2OnboardingHeartRateView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel

    /// 設計 frame-33 的五條色帶（`rgba(...,0.95)`）。
    private static let bandColors: [Color] = [
        App2Theme.trackAhead, App2Theme.trackOnTrack, App2Theme.bandAmber,
        App2Theme.bandOrange, App2Theme.bandRed
    ]

    var body: some View {
        App2OnboardingPage(
            segment: .goal,
            progressWithinSegment: viewModel.progress(for: .heartRate),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingHeartRateCta",
            ctaAction: { Task { await viewModel.confirmHeartRate() } }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.hrTitle.localized,
                    subtitle: L10n.App2.Onboarding.hrSubtitle.localized,
                    identifier: "App2_OnboardingHeartRate"
                )

                HStack(spacing: 12) {
                    wheelCard(
                        title: L10n.App2.Onboarding.hrMax.localized,
                        hint: L10n.App2.Onboarding.hrMaxHint.localized,
                        range: 120...220,
                        value: $viewModel.maxHeartRate,
                        identifier: "App2_OnboardingHrMaxWheel"
                    )
                    wheelCard(
                        title: L10n.App2.Onboarding.hrResting.localized,
                        hint: L10n.App2.Onboarding.hrRestingHint.localized,
                        range: 30...120,
                        value: $viewModel.restingHeartRate,
                        identifier: "App2_OnboardingHrRestingWheel"
                    )
                }

                bands
            }
        }
    }

    private func wheelCard(
        title: String,
        hint: String,
        range: ClosedRange<Int>,
        value: Binding<Int>,
        identifier: String
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(App2Theme.inkTertiary)

            App2OnboardingNumberWheel(range: range, value: value, identifier: identifier)

            Text(L10n.App2.Onboarding.hrBpm.localized)
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(App2Theme.inkTertiary)

            Text(hint)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .app2CardSurface(cornerRadius: 20)
    }

    private var bands: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.App2.Onboarding.hrBandsTitle.localized)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)

            HStack(spacing: 0) {
                ForEach(Array(viewModel.heartRateBands.enumerated()), id: \.element.id) { index, band in
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
                    .strokeBorder(App2Theme.insetBorder, lineWidth: 1)
            )
            .shadow(color: App2Theme.shadowInk.opacity(0.16), radius: 10, x: 0, y: 8)
            .accessibilityIdentifier("App2_OnboardingHrBands")

            HStack(spacing: 0) {
                ForEach(viewModel.heartRateBands) { band in
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
}

// MARK: - frame-34 連結裝置

struct App2OnboardingDeviceLinkView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @ObservedObject private var garmin = GarminManager.shared

    var body: some View {
        App2OnboardingPage(
            segment: .goal,
            progressWithinSegment: viewModel.progress(for: .deviceLink),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingDeviceLinkCta",
            ctaAction: { viewModel.continueFromDeviceLink() },
            skipTitle: L10n.App2.Onboarding.deviceSkip.localized,
            skipAction: { Task { await viewModel.skipDeviceLink() } }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.deviceTitle.localized,
                    subtitle: L10n.App2.Onboarding.deviceSubtitle.localized,
                    identifier: "App2_OnboardingDeviceLink"
                )

                garminRow
                appleHealthRow

                if garmin.isConnected {
                    syncNote
                }

                App2OnboardingNotice(
                    systemImage: "lock",
                    text: L10n.App2.Onboarding.devicePrivacy.localized
                )
            }
        }
        .task {
            await garmin.checkConnectionStatusIfNeeded()
        }
    }

    private var garminRow: some View {
        App2DataSourceRow(
            leading: { App2DataSourceTile.garmin },
            title: "Garmin",
            subtitle: L10n.App2.Onboarding.deviceGarminSub.localized,
            isConnected: garmin.isConnected,
            actionTitle: garmin.isConnected
                ? L10n.App2.Onboarding.deviceDisconnect.localized
                : L10n.App2.Onboarding.deviceConnect.localized,
            actionIdentifier: "App2_OnboardingDeviceGarminAction",
            action: {
                Task {
                    if garmin.isConnected {
                        await viewModel.disconnectGarmin()
                    } else {
                        await viewModel.connectGarmin()
                    }
                }
            }
        )
        .accessibilityIdentifier("App2_OnboardingDeviceGarminRow")
    }

    private var appleHealthRow: some View {
        let connected = viewModel.profile.currentDataSource == .appleHealth
        return App2DataSourceRow(
            leading: { App2DataSourceTile.appleHealth },
            title: "Apple Health",
            subtitle: L10n.App2.Onboarding.deviceAppleHealthSub.localized,
            isConnected: connected,
            actionTitle: connected ? nil : L10n.App2.Onboarding.deviceConnect.localized,
            actionIdentifier: "App2_OnboardingDeviceAppleHealthAction",
            action: { Task { await viewModel.connectAppleHealth() } }
        )
        .accessibilityIdentifier("App2_OnboardingDeviceAppleHealthRow")
    }

    private var syncNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(App2Theme.accentGreenBright)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                    )
                Text(String(format: L10n.App2.Onboarding.deviceSyncNoteTitle.localized, "Garmin"))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
                HStack(spacing: 5) {
                    Circle().fill(App2Theme.accentGreenDot).frame(width: 6, height: 6)
                    Text(L10n.App2.Onboarding.deviceSyncing.localized)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(App2Theme.accentGreenDot)
                }
            }

            Text(L10n.App2.Onboarding.deviceSyncNoteBody.localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(App2Theme.accentGreenBright.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(App2Theme.accentGreenBright.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_OnboardingDeviceSyncNote")
    }
}

// MARK: - frame-35 近期成績

struct App2OnboardingRecentResultView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @EnvironmentObject private var flow: OnboardingFeatureViewModel

    var body: some View {
        App2OnboardingPage(
            segment: .training,
            progressWithinSegment: viewModel.progress(for: .recentResult),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaEnabled: viewModel.canContinueFromRecentResult,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingRecentResultCta",
            ctaAction: { Task { await viewModel.confirmRecentResult() } },
            skipTitle: L10n.App2.Onboarding.resultSkip.localized,
            skipAction: { Task { await viewModel.skipRecentResult() } }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.resultTitle.localized,
                    subtitle: L10n.App2.Onboarding.resultSubtitle.localized,
                    identifier: "App2_OnboardingRecentResult"
                )

                VStack(alignment: .leading, spacing: 10) {
                    App2OnboardingFieldLabel(text: L10n.App2.Onboarding.resultDistance.localized)
                    HStack(spacing: 10) {
                        ForEach(App2OnboardingFormat.raceDistanceKeys, id: \.self) { key in
                            App2OnboardingChip(
                                title: App2OnboardingFormat.distanceLabel(km: Double(key) ?? 0),
                                isSelected: flow.selectedPBDistance == key,
                                identifier: "App2_OnboardingResultDistance_\(key)"
                            ) {
                                flow.selectedPBDistance = key
                                viewModel.recomputeEstimates()
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    App2OnboardingFieldLabel(text: L10n.App2.Onboarding.resultFinishTime.localized)
                    App2FinishTimeRow(
                        hours: $flow.personalBestHours,
                        minutes: $flow.personalBestMinutes,
                        seconds: $flow.personalBestSeconds,
                        identifier: "App2_OnboardingResultFinishTime"
                    )
                }

                estimateCard

                VStack(alignment: .leading, spacing: 10) {
                    App2OnboardingFieldLabel(text: L10n.App2.Onboarding.resultWhen.localized)
                    HStack(spacing: 10) {
                        App2OnboardingOutlineChip(
                            title: L10n.App2.Onboarding.resultWithinYear.localized,
                            isSelected: viewModel.resultIsWithinYear,
                            identifier: "App2_OnboardingResultWithinYear"
                        ) { viewModel.resultIsWithinYear = true }

                        App2OnboardingOutlineChip(
                            title: L10n.App2.Onboarding.resultOverYear.localized,
                            isSelected: !viewModel.resultIsWithinYear,
                            identifier: "App2_OnboardingResultOverYear"
                        ) { viewModel.resultIsWithinYear = false }
                    }
                    if !viewModel.resultIsWithinYear {
                        Text(L10n.App2.Onboarding.resultOverYearNote.localized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(App2Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onAppear { viewModel.recomputeEstimates() }
        .onChange(of: flow.personalBestHours) { _, _ in viewModel.recomputeEstimates() }
        .onChange(of: flow.personalBestMinutes) { _, _ in viewModel.recomputeEstimates() }
        .onChange(of: flow.personalBestSeconds) { _, _ in viewModel.recomputeEstimates() }
    }

    private var estimateCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(App2Theme.accentBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.App2.Onboarding.resultAvgPace.localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(viewModel.recentResultPace.isEmpty ? "—" : viewModel.recentResultPace)
                        .font(.app2Mono(24, weight: .black))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                    Text("/km")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.App2.Onboarding.resultVdot.localized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                Text(viewModel.estimatedVDOT.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.app2Mono(24, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(App2Theme.accentBlue.opacity(0.25), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_OnboardingResultEstimateCard")
    }
}

// MARK: - frame-36 訓練方法

struct App2OnboardingMethodologyView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @EnvironmentObject private var flow: OnboardingFeatureViewModel

    private var recommended: MethodologyV2? {
        guard let id = viewModel.recommendedMethodologyId else { return flow.availableMethodologies.first }
        return flow.availableMethodologies.first(where: { $0.id == id }) ?? flow.availableMethodologies.first
    }

    private var others: [MethodologyV2] {
        flow.availableMethodologies.filter { $0.id != recommended?.id }
    }

    var body: some View {
        App2OnboardingPage(
            segment: .training,
            progressWithinSegment: viewModel.progress(for: .methodology),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingMethodologyCta",
            ctaAction: { Task { await viewModel.confirmMethodology() } }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.methodTitle.localized,
                    subtitle: L10n.App2.Onboarding.methodSubtitle.localized,
                    identifier: "App2_OnboardingMethodology"
                )

                if flow.isLoadingMethodologies && flow.availableMethodologies.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                }

                if let recommended {
                    App2OnboardingOptionCard(
                        title: recommended.name,
                        subtitle: recommended.description,
                        badge: L10n.App2.Onboarding.methodRecommended.localized,
                        isSelected: selectedId == recommended.id,
                        identifier: "App2_OnboardingMethodologyRecommended"
                    ) {
                        viewModel.selectMethodology(recommended)
                    }
                }

                if !others.isEmpty {
                    HStack(spacing: 12) {
                        Rectangle().fill(App2Theme.hairline).frame(height: 1)
                        Text(L10n.App2.Onboarding.methodPickOwn.localized)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(App2Theme.inkMuted)
                        Rectangle().fill(App2Theme.hairline).frame(height: 1)
                    }
                    .padding(.vertical, 6)

                    ForEach(others) { methodology in
                        App2OnboardingOptionCard(
                            title: methodology.name,
                            subtitle: methodology.description,
                            isSelected: selectedId == methodology.id,
                            identifier: "App2_OnboardingMethodology_\(methodology.id)"
                        ) {
                            viewModel.selectMethodology(methodology)
                        }
                    }
                }
            }
        }
        .onAppear {
            // 設計 frame-36：推薦項預設就是選中的（「自動為你選擇」）。
            if flow.selectedMethodology == nil, let recommended {
                viewModel.selectMethodology(recommended)
            }
        }
    }

    private var selectedId: String? {
        flow.selectedMethodology?.id ?? viewModel.recommendedMethodologyId
    }
}

// MARK: - frame-37 訓練日

struct App2OnboardingTrainingDaysView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @EnvironmentObject private var flow: OnboardingFeatureViewModel

    var body: some View {
        App2OnboardingPage(
            segment: .training,
            progressWithinSegment: viewModel.progress(for: .trainingDays),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.continueCta.localized,
            ctaEnabled: viewModel.canContinueFromTrainingDays,
            ctaBusy: viewModel.isBusy,
            ctaIdentifier: "App2_OnboardingTrainingDaysCta",
            ctaAction: { Task { await viewModel.confirmTrainingDays() } }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.daysTitle.localized,
                    subtitle: L10n.App2.Onboarding.daysSubtitle.localized,
                    identifier: "App2_OnboardingTrainingDays"
                )

                HStack(spacing: 7) {
                    ForEach(1...7, id: \.self) { weekday in
                        App2OnboardingChip(
                            title: App2OnboardingFormat.weekdayShort(weekday),
                            isSelected: flow.selectedWeekdays.contains(weekday),
                            identifier: "App2_OnboardingWeekday_\(weekday)"
                        ) {
                            viewModel.toggleWeekday(weekday)
                        }
                    }
                }

                countHint
                longRunSection

                App2OnboardingNotice(
                    systemImage: "info.circle",
                    text: L10n.App2.Onboarding.daysNote.localized
                )
            }
        }
    }

    private var countHint: some View {
        let count = flow.selectedWeekdays.count
        let suggested = App2OnboardingProjection.suggestedTrainingDays
        let inBand = App2OnboardingProjection.isTrainingDayCountSuggested(count)
        return HStack(spacing: 8) {
            Circle()
                .fill(inBand ? App2Theme.accentBlue : App2Theme.inkMuted)
                .frame(width: 7, height: 7)
            Text(String(
                format: L10n.App2.Onboarding.daysSelectedFormat.localized,
                count, suggested.lowerBound, suggested.upperBound
            ))
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(inBand ? App2Theme.accentBlueDeep : App2Theme.inkSubtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("App2_OnboardingDaysCountHint")
    }

    private var longRunSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            App2OnboardingFieldLabel(text: L10n.App2.Onboarding.daysLongRun.localized)

            let options = flow.selectedWeekdays.sorted()
            if options.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(options, id: \.self) { weekday in
                            App2OnboardingOutlineChip(
                                title: App2OnboardingFormat.weekdayFull(weekday),
                                isSelected: flow.selectedLongRunDay == weekday,
                                identifier: "App2_OnboardingLongRunDay_\(weekday)"
                            ) {
                                flow.selectedLongRunDay = weekday
                            }
                            .frame(width: 96)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text(L10n.App2.Onboarding.daysLongRunNote.localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - frame-38 跑量確認

struct App2OnboardingMileageView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @EnvironmentObject private var flow: OnboardingFeatureViewModel

    var body: some View {
        App2OnboardingPage(
            segment: .training,
            progressWithinSegment: viewModel.progress(for: .mileage),
            onBack: { viewModel.pop() },
            ctaTitle: L10n.App2.Onboarding.mileageCta.localized,
            ctaBusy: viewModel.isGeneratingPlan,
            ctaIdentifier: "App2_OnboardingMileageCta",
            ctaAction: { Task { await viewModel.generatePlan() } }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                App2OnboardingTitleBlock(
                    title: L10n.App2.Onboarding.mileageTitle.localized,
                    subtitle: viewModel.hasSyncedMileage
                        ? L10n.App2.Onboarding.mileageSubtitle.localized
                        : L10n.App2.Onboarding.mileageNoHistory.localized,
                    identifier: "App2_OnboardingMileage"
                )

                // 沒有同步紀錄就不出來源徽章（不謊稱「來自你的 Garmin 紀錄」）。
                if let source = viewModel.mileageSourceName {
                    sourceBadge(source)
                }

                averageCard
                slider
                startAndPeak

                App2OnboardingNotice(
                    systemImage: "chart.line.uptrend.xyaxis",
                    text: L10n.App2.Onboarding.mileageNote.localized
                )
            }
        }
    }

    private func sourceBadge(_ source: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
            Text(String(format: L10n.App2.Onboarding.mileageSourceFormat.localized, source))
                .font(.system(size: 14, weight: .heavy))
        }
        .foregroundStyle(App2Theme.successTextDeep)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(App2Theme.accentGreenBright.opacity(0.13)))
    }

    private var averageCard: some View {
        VStack(spacing: 12) {
            // 沒有同步紀錄時不得說「最近 4 週平均」—— 那個數字是預設值，不是平均。
            Text(viewModel.hasSyncedMileage
                 ? L10n.App2.Onboarding.mileageRecentAvg.localized
                 : L10n.App2.Onboarding.mileageManualLabel.localized)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.inkMuted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(flow.weeklyDistance.rounded()))")
                    .font(.app2Mono(56, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(L10n.App2.Onboarding.mileageUnit.localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
            }
            .accessibilityIdentifier("App2_OnboardingMileageAverage")

            Text(L10n.App2.Onboarding.mileageConfirmQuestion.localized)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)

            HStack(spacing: 10) {
                App2OnboardingOutlineChip(
                    title: L10n.App2.Onboarding.mileageAboutRight.localized,
                    systemImage: "checkmark",
                    isSelected: viewModel.mileageIsConfirmed,
                    identifier: "App2_OnboardingMileageConfirm"
                ) { viewModel.mileageIsConfirmed = true }

                App2OnboardingOutlineChip(
                    title: L10n.App2.Onboarding.mileageAdjust.localized,
                    isSelected: !viewModel.mileageIsConfirmed,
                    identifier: "App2_OnboardingMileageAdjust"
                ) { viewModel.mileageIsConfirmed = false }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .app2CardSurface(cornerRadius: App2Theme.cardCornerRadius)
    }

    private var slider: some View {
        let preview = viewModel.mileagePreview
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.App2.Onboarding.mileageSliderTitle.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkSubtle)
                Spacer()
                Text("\(Int(flow.weeklyDistance.rounded())) km")
                    .font(.app2Mono(17, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
            }

            Slider(
                value: $flow.weeklyDistance,
                in: preview.sliderRange,
                step: 1
            )
            .tint(App2Theme.accentBlue)
            .accessibilityIdentifier("App2_OnboardingMileageSlider")

            HStack {
                Text("\(Int(preview.sliderRange.lowerBound))")
                    .font(.app2Mono(12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                Spacer()
                Text(String(
                    format: L10n.App2.Onboarding.mileageSuggestedFormat.localized,
                    preview.suggestedBand.lowerBound, preview.suggestedBand.upperBound
                ))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(App2Theme.accentBlueDeep)
                Spacer()
                Text("\(Int(preview.sliderRange.upperBound))")
                    .font(.app2Mono(12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(App2Theme.disabledFill.opacity(0.7))
        )
        .opacity(viewModel.mileageIsConfirmed ? 0.55 : 1)
        .allowsHitTesting(!viewModel.mileageIsConfirmed)
    }

    private var startAndPeak: some View {
        HStack(spacing: 12) {
            statTile(
                title: L10n.App2.Onboarding.mileageStart.localized,
                value: "\(Int(flow.weeklyDistance.rounded())) km",
                tint: App2Theme.inkPrimary,
                identifier: "App2_OnboardingMileageStartCard"
            )
            statTile(
                title: L10n.App2.Onboarding.mileagePeak.localized,
                value: "\(viewModel.mileagePreview.peakKm) km",
                tint: App2Theme.accentBlueDeep,
                identifier: "App2_OnboardingMileagePeakCard"
            )
        }
    }

    private func statTile(title: String, value: String, tint: Color, identifier: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
            Text(value)
                .font(.app2Mono(22, weight: .black))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .app2CardSurface(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - frame-39 完成

struct App2OnboardingCompletionView: View {
    @ObservedObject var viewModel: App2OnboardingViewModel
    @EnvironmentObject private var flow: OnboardingFeatureViewModel
    let onFinished: (() -> Void)?

    private var overview: PlanOverviewV2? { viewModel.overview }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let overview {
                        goalCard(overview)
                        stagesSection(overview)
                    }
                    rhythmCard
                    App2OnboardingNotice(
                        systemImage: "sparkles",
                        text: L10n.App2.Onboarding.doneFooterNote.localized
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }

            App2OnboardingPrimaryButton(
                title: viewModel.isStartingFirstWeek
                    ? L10n.App2.Onboarding.doneGenerating.localized
                    : L10n.App2.Onboarding.doneCta.localized,
                busy: viewModel.isStartingFirstWeek,
                trailingArrow: true,
                identifier: "App2_OnboardingCompletionCta"
            ) {
                Task {
                    await viewModel.startFirstWeek()
                    onFinished?()
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(completionBackdrop.ignoresSafeArea())
    }

    /// `linear-gradient(180deg,#0a4f96 0%, #1774cf 14%, #4f9ae0 24%, #b9d3ec 30%, #eef2f7 33%, …)`
    private var completionBackdrop: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: App2Theme.skyDeep, location: 0),
                .init(color: App2Theme.skyMid, location: 0.14),
                .init(color: App2Theme.skyLightCompact, location: 0.24),
                .init(color: App2Theme.skyPaleCompact, location: 0.30),
                .init(color: App2Theme.pageBottom, location: 0.33),
                .init(color: App2Theme.pageBottom, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.95))
                            .frame(height: 5)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                    Text(L10n.App2.Onboarding.doneBadge.localized)
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.App2.Onboarding.doneKicker.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(String(
                    format: L10n.App2.Onboarding.doneWeeksFormat.localized,
                    overview?.totalWeeks ?? 0
                ))
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .accessibilityIdentifier("App2_OnboardingCompletionHeader")
    }

    // MARK: 目標賽事卡

    private func goalCard(_ overview: PlanOverviewV2) -> some View {
        App2Card(padding: 18, spacing: 14) {
            HStack {
                Text(L10n.App2.Onboarding.doneGoalRace.localized)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(App2Theme.accentBlueDeep)
                Spacer()
                if let km = overview.distanceKm {
                    Text(App2OnboardingFormat.distanceLabel(km: km))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(App2Theme.accentBlue))
                }
            }

            Text(overview.targetName ?? overview.targetDescription ?? "")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(goalSubline(overview))
                .font(.app2Mono(14, weight: .bold))
                .foregroundStyle(App2Theme.inkSubtle)

            comparison(overview)

            if let insight = overview.targetEvaluate ?? overview.approachSummary, !insight.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(App2Theme.accentBlue)
                    Text(insight)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(App2Theme.accentBlue.opacity(0.07))
                )
            }
        }
    }

    private func goalSubline(_ overview: PlanOverviewV2) -> String {
        var parts: [String] = []
        if let date = overview.raceDateValue {
            parts.append(App2OnboardingFormat.isoDate(date))
        }
        parts.append(String(
            format: L10n.App2.Onboarding.doneRemainingWeeksFormat.localized,
            overview.totalWeeks
        ))
        return parts.joined(separator: " · ")
    }

    /// 「現在的你」只在 readiness 真的有預估時才出現；沒有就只顯示目標欄，
    /// **不本機推一個完賽預估頂替**（那是 readiness 擁有的語意）。
    private func comparison(_ overview: PlanOverviewV2) -> some View {
        HStack(spacing: 10) {
            if let now = viewModel.currentEstimatedFinish {
                comparisonTile(
                    label: L10n.App2.Onboarding.doneNow.localized,
                    value: now,
                    caption: String(
                        format: L10n.App2.Onboarding.doneWeeklyKmFormat.localized,
                        Int(flow.weeklyDistance.rounded())
                    ),
                    highlighted: false
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(App2Theme.inkMuted)
            }

            comparisonTile(
                label: L10n.App2.Onboarding.doneTarget.localized,
                value: overview.targetTime.map(App2OnboardingFormat.duration) ?? "—",
                caption: overview.distanceKm.map {
                    String(format: L10n.App2.Onboarding.doneFinishSuffix.localized,
                           App2OnboardingFormat.distanceLabel(km: $0))
                },
                highlighted: true
            )
        }
    }

    private func comparisonTile(label: String, value: String, caption: String?, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(highlighted ? App2Theme.accentBlueDeep : App2Theme.inkMuted)
            Text(value)
                .font(.app2Mono(21, weight: .black))
                .foregroundStyle(highlighted ? App2Theme.accentBlueDeep : App2Theme.inkPrimary)
            if let caption {
                Text(caption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlighted ? App2Theme.accentBlue.opacity(0.08) : App2Theme.insetBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    highlighted ? App2Theme.accentBlue.opacity(0.28) : App2Theme.insetBorder,
                    lineWidth: 1
                )
        )
    }

    // MARK: 階段卡

    @ViewBuilder
    private func stagesSection(_ overview: PlanOverviewV2) -> some View {
        if !overview.trainingStages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(
                        format: L10n.App2.Onboarding.doneStagesTitleFormat.localized,
                        overview.totalWeeks
                    ))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)

                    Text(L10n.App2.Onboarding.doneStagesSubtitle.localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSubtle)
                }

                ForEach(Array(overview.trainingStages.enumerated()), id: \.offset) { index, stage in
                    stageCard(stage, index: index)
                    if index < overview.trainingStages.count - 1 {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(App2Theme.onbHintOnDark)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityIdentifier("App2_OnboardingCompletionStages")
        }
    }

    private static let stageStripColors: [Color] = [
        App2Theme.accentBlue, App2Theme.accentGreenBright,
        App2Theme.accentOrangeBright, App2Theme.accentViolet
    ]

    private func stageCard(_ stage: TrainingStageV2, index: Int) -> some View {
        App2LeftStripCard(strip: Self.stageStripColors[index % Self.stageStripColors.count]) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stage.stageName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer()
                    Text(String(
                        format: L10n.App2.Onboarding.doneWeekRangeFormat.localized,
                        stage.weekStart, stage.weekEnd
                    ))
                    .font(.app2Mono(12, weight: .bold))
                    .foregroundStyle(App2Theme.inkSubtle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(App2Theme.insetBackground))
                }

                if !stage.trainingFocus.isEmpty {
                    Text(stage.trainingFocus)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !stage.stageDescription.isEmpty {
                    Text(stage.stageDescription)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(App2Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: 訓練節奏卡

    private var rhythmCard: some View {
        App2Card(spacing: 10) {
            Text(L10n.App2.Onboarding.doneRhythmTitle.localized)
                .font(.app2CardTitle)
                .foregroundStyle(App2Theme.inkPrimary)

            rhythmRow(
                icon: "calendar",
                title: L10n.App2.Onboarding.doneRhythmDays.localized,
                value: String(
                    format: L10n.App2.Onboarding.doneRhythmDaysFormat.localized,
                    flow.selectedWeekdays.count
                )
            )
            rhythmRow(
                icon: "figure.run",
                title: L10n.App2.Onboarding.doneRhythmLongRun.localized,
                value: App2OnboardingFormat.weekdayFull(flow.selectedLongRunDay)
            )
            rhythmRow(
                icon: "chart.bar",
                title: L10n.App2.Onboarding.doneRhythmMethod.localized,
                value: flow.selectedMethodology?.name
                    ?? overview?.methodologyOverview?.name
                    ?? overview?.methodologyId
                    ?? "—"
            )
        }
    }

    private func rhythmRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(App2Theme.accentBlue)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkSubtle)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
        }
    }
}
