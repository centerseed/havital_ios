import Combine
import Foundation

// MARK: - App2SettingsViewModel
/// Presentation Layer — 2.0 設定頁與其子頁（設計 frame-21 ~ frame-29）。
///
/// **這一支不是第二份設定邏輯。** 它只做「把 1.4 既有的讀寫出口攤成 2.0 版面需要的
/// 形狀」：
///
/// | 資料 | 來源（既有） |
/// |---|---|
/// | 身分、週跑量、訓練日、心率、刪除帳戶 | `UserProfileFeatureViewModel`（同一支 VM，不新建 repository） |
/// | 訂閱狀態 | `SubscriptionStateManager.shared`（既有 SSOT） |
/// | 資料來源連接狀態 | `UserPreferencesRepository.dataSourcePreference` ＋ `GarminManager` |
/// | VDOT／配速區間 | `VDOTManager` ＋ `PaceCalculator`（唯讀，app 端沒有 VDOT 寫入口） |
/// | 語言／時區／單位 | `LanguageManager`／`UserPreferencesRepository`／`UnitManager` |
///
/// 巢狀 `ObservableObject` 不會自動往上冒泡，所以這裡把 `profile` 的
/// `objectWillChange` 轉發出去 —— 否則子頁存檔後設定首頁的摘要值不會更新。
@MainActor
final class App2SettingsViewModel: ObservableObject {

    /// 1.4 的 profile ViewModel —— 設定頁所有 profile 讀寫都經過它。
    let profile: UserProfileFeatureViewModel

    @Published private(set) var snapshot: App2Sourced<App2SettingsSnapshot>?

    /// 頭像／profile 卡要顯示的名字。身分只在這一支 ViewModel 讀 —— View 與其他頁
    /// 都從這裡拿，不各自去碰 `AuthenticationViewModel.shared`。
    var displayName: String? {
        if let name = profile.userData?.displayName, !name.isEmpty { return name }
        if let name = authViewModel.currentUser?.displayName, !name.isEmpty { return name }
        return accountEmail
    }

    /// 頭像上的單字（設計 frame-01／21 是姓氏首字）。
    var avatarInitial: String {
        guard let first = displayName?.first else { return "P" }
        return String(first).uppercased()
    }

    /// email：先看後端 profile，再退回 Firebase session（與 1.4 設定頁同一條判定）。
    var accountEmail: String? {
        let text = ProfileIdentityDisplay.emailText(
            profileEmail: profile.userData?.email,
            firebaseEmail: authViewModel.currentUser?.email
        )
        return text.isEmpty ? nil : text
    }

    /// 目前的主要資料來源（設定首頁與數據來源子頁共用）。
    var currentDataSource: DataSourceType { profile.currentDataSource }

    var maxHeartRate: Int? { profile.userData?.maxHr }
    var maxHeartRateSource: HeartRateParameterSource { profile.userData?.maxHrSource ?? .unrecorded }
    var restingHeartRate: Int? { profile.userData?.relaxingHr }
    var restingHeartRateSource: HeartRateParameterSource { profile.userData?.relaxingHrSource ?? .unrecorded }
    var currentVDOT: Double { profile.currentVDOT }

    /// 訓練日（1=一 … 7=日），與 `EditTrainingDaysView` 同一套編碼。
    var trainingWeekdays: Set<Int> { Set(profile.userData?.preferWeekDays ?? []) }
    var longRunWeekday: Int { profile.userData?.preferWeekDaysLongrun?.first ?? 6 }
    var weeklyDistanceKm: Int { Int(profile.userData?.currentWeekDistance ?? 0) }

    private let authViewModel: AuthenticationViewModel
    private let subscriptionState: SubscriptionStateManager
    private var cancellables = Set<AnyCancellable>()

    init(
        profile: UserProfileFeatureViewModel? = nil,
        authViewModel: AuthenticationViewModel = .shared,
        subscriptionState: SubscriptionStateManager = .shared
    ) {
        self.profile = profile ?? DependencyContainer.shared.makeUserProfileFeatureViewModel()
        self.authViewModel = authViewModel
        self.subscriptionState = subscriptionState

        // 巢狀 ObservableObject 的變更要手動往上轉發，子頁存檔後首頁摘要才會跟著換。
        self.profile.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
                self?.rebuildSnapshot()
            }
            .store(in: &cancellables)
    }

    /// 首次進頁載入；已經有快照就不重算（切 tab 回來不閃）。
    func loadIfNeeded() {
        guard snapshot == nil else {
            refresh()
            return
        }
        refresh()
    }

    /// 重新讀 profile（含心率區間與 VDOT）。子頁存檔後也呼叫這支。
    func refresh() {
        rebuildSnapshot()
        Task { [weak self] in
            guard let self else { return }
            await self.profile.loadUserProfile()
            await self.profile.loadHeartRateZones()
            self.profile.loadVDOT()
            self.rebuildSnapshot()
        }
    }

    // MARK: - Snapshot

    private func rebuildSnapshot() {
        snapshot = App2Sourced(
            App2SettingsSnapshot(
                accountEmail: accountEmail,
                subscriptionLabel: SubscriptionStatusEntity.compactStateLabel(
                    for: subscriptionState.currentStatus
                ),
                dataSources: dataSourceStatuses(),
                weeklyDistanceKm: profile.userData?.currentWeekDistance.map(Double.init),
                trainingDays: weekdayShortNames(),
                raceCountdownDays: RaceCountdownPreference.summaryDays
            ),
            // profile 還沒回來之前不謊報 live。
            origin: profile.userData == nil
                ? .stub(pendingSection: App2StubFixtures.Section.offline)
                : .live(endpoint: "GET /user/profile")
        )
    }

    /// 設計 frame-21 的兩列：Garmin Connect ／ Apple Health。
    /// Strava 已下架（T-0238），只有既有綁定者才多一列 —— 與 1.4 設定頁同一條判定。
    private func dataSourceStatuses() -> [App2DataSourceStatus] {
        let current = profile.currentDataSource
        var rows: [App2DataSourceStatus] = [
            App2DataSourceStatus(
                name: "Garmin Connect",
                statusLabel: NSLocalizedString("datasource.garmin_subtitle", comment: ""),
                isConnected: current == .garmin
            ),
            App2DataSourceStatus(
                name: "Apple Health",
                statusLabel: NSLocalizedString("datasource.apple_health_subtitle", comment: ""),
                isConnected: current == .appleHealth
            )
        ]
        if current == .strava {
            rows.append(
                App2DataSourceStatus(
                    name: "Strava",
                    statusLabel: NSLocalizedString("datasource.strava_subtitle", comment: ""),
                    isConnected: true
                )
            )
        }
        return rows
    }

    private func weekdayShortNames() -> [String] {
        (profile.userData?.preferWeekDays ?? [])
            .sorted()
            .map { App2OnboardingFormat.weekdayShort($0) }
    }

    // MARK: - Writes（全部落到既有出口）

    /// 目標週跑量 ＋ 訓練日一起存（設計 frame-23 只有一顆「儲存」）。
    /// 兩個欄位都走 `UpdateUserProfileUseCase`，與 1.4 的
    /// `WeeklyDistanceEditorView`／`EditTrainingDaysView` 是同一條寫入路徑。
    func saveTrainingSettings(
        weeklyDistanceKm: Int,
        weekdays: Set<Int>,
        longRunWeekday: Int
    ) async -> Bool {
        let ok = await profile.updateUserProfile([
            "current_week_distance": weeklyDistanceKm,
            "prefer_week_days": Array(weekdays).sorted(),
            "prefer_week_days_longrun": [longRunWeekday]
        ])
        if ok { rebuildSnapshot() }
        return ok
    }

    /// 心率區間 —— 走既有的 `UpdateHeartRateZonesUseCase`。
    /// 它底下的 repository 已經把 `max_hr`／`relaxing_hr` 寫進 profile
    /// 並重算快取區間，所以這裡**不再另外 PATCH 一次**，只重讀 profile 讓摘要跟上。
    ///
    /// - Returns: 存成功時是後端回報的「心率有沒有變」；失敗回 nil。
    func saveHeartRate(maxHR: Int, restingHR: Int) async -> Bool? {
        let changed = await profile.updateHeartRateZones(maxHR: maxHR, restingHR: restingHR)
        if changed != nil {
            await profile.loadUserProfile(forceRefresh: true)
            rebuildSnapshot()
        }
        return changed
    }

    /// 「自動更新最大心率」目前的值：只有明確開過才是 true（沒設過在 UI 顯示為關）。
    var autoUpdateMaxHeartRate: Bool { profile.userData?.autoUpdateMaxHr == true }

    func deleteAccount() async throws {
        try await profile.deleteAccount()
    }

    func signOut() async {
        await AuthenticationViewModel.shared.signOut()
    }
}

// MARK: - RaceCountdownPreference
/// 賽事倒數卡顯示偏好的讀取面。**寫入面仍是 1.4 設定頁的 `@AppStorage`**
/// （`RaceCountdownDisplayMode` / `RaceCountdownGate` 是既有型別），這裡只讀，
/// 2.0 設定首頁那一列才顯示得出「賽前 N 天」。
enum RaceCountdownPreference {
    static var mode: RaceCountdownDisplayMode {
        RaceCountdownDisplayMode(
            rawValueOrDefault: UserDefaults.standard.string(forKey: "raceCountdownMode") ?? ""
        )
    }

    static var daysBefore: Int {
        let stored = UserDefaults.standard.integer(forKey: "raceCountdownDaysBefore")
        return stored > 0 ? stored : RaceCountdownGate.defaultDaysBefore
    }

    /// 設定首頁那一列的右側值要顯示的天數（`always`／`off` 沒有天數概念）。
    static var summaryDays: Int { daysBefore }
}
