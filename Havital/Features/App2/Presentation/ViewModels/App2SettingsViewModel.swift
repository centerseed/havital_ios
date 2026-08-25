import Foundation

// MARK: - App2SettingsViewModel
/// Presentation Layer — 2.0 設定頁（`DESIGN-app2-decision-chain-api.md` §3.9a）。
///
/// 設計文件對這一頁的判定是「帳號、訂閱、數據來源連接狀態皆既有」，唯一的小洞是
/// 「賽事倒數卡 · 賽前 30 天」現況無此偏好欄位。骨架階段：
///
/// - 帳號 email 走 `AuthenticationViewModel`（既有 session 狀態，不另打端點）
/// - 訂閱狀態走 `SubscriptionStateManager.shared.currentStatus`（既有 SSOT）
/// - 數據來源連接狀態、訓練設定（週跑量旋鈕／訓練日）先用樣本 —— app 端目前沒有
///   單一的偏好讀口，接哪一條屬於本票範圍外，列在票面卡點
@MainActor
final class App2SettingsViewModel: ObservableObject {

    @Published private(set) var snapshot: App2Sourced<App2SettingsSnapshot>?

    /// 頭像／profile 卡要顯示的名字。身分只在這一支 ViewModel 讀 —— View 與其他頁
    /// 都從這裡拿，不各自去碰 `AuthenticationViewModel.shared`。
    var displayName: String? {
        if let name = authViewModel.currentUser?.displayName, !name.isEmpty { return name }
        return authViewModel.currentUser?.email
    }

    /// 頭像上的單字（設計 frame-01／21 是姓氏首字）。
    var avatarInitial: String {
        guard let first = displayName?.first else { return "P" }
        return String(first).uppercased()
    }

    private let authViewModel: AuthenticationViewModel
    private let subscriptionState: SubscriptionStateManager

    init(
        authViewModel: AuthenticationViewModel = .shared,
        subscriptionState: SubscriptionStateManager = .shared
    ) {
        self.authViewModel = authViewModel
        self.subscriptionState = subscriptionState
    }

    /// 首次進頁載入；已經有快照就不重算（切 tab 回來不閃）。
    func loadIfNeeded() {
        guard snapshot == nil else { return }
        load()
    }

    func load() {
        let stub = App2StubFixtures.settings
        // email 沒有就是沒有 —— profile 卡不得出現編造值（樣本 email 已從 fixture 刪掉）。
        let email = authViewModel.currentUser?.email
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        snapshot = App2Sourced(
            App2SettingsSnapshot(
                accountEmail: email,
                subscriptionLabel: subscriptionLabel(),
                // 連接狀態／訓練設定尚未接讀口 → 樣本。
                dataSources: stub.dataSources,
                weeklyDistanceKm: stub.weeklyDistanceKm,
                trainingDays: stub.trainingDays,
                raceCountdownDays: stub.raceCountdownDays
            ),
            // 帳號那格是真的，其餘是樣本 —— 整頁標成 stub 是保守的標法：
            // 標成 live 會讓「連接狀態」被誤讀成真實同步狀態。
            origin: email == nil
                ? .stub(pendingSection: App2StubFixtures.Section.offline)
                : .stub(pendingSection: App2StubFixtures.Section.raceCountdownPref)
        )
    }

    /// 訂閱狀態顯示字（三語）。
    ///
    /// 原本這裡直接印 `status.planType ?? status.status.rawValue` ＋硬寫的 `d`，
    /// 畫面會出現 `expired · 0d` —— 後端識別字上畫面、天數單位沒有在地化。
    /// 現在走 `SubscriptionStatusEntity.compactStateLabel`（1.x 設定頁的
    /// tier label 也已收斂到同一支），剩餘天數用既有的
    /// `profile.subscription.trial_remaining_days` 格式字。
    private func subscriptionLabel() -> String {
        SubscriptionStatusEntity.compactStateLabel(for: subscriptionState.currentStatus)
    }
}
