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
        let email = authViewModel.currentUser?.email

        snapshot = App2Sourced(
            App2SettingsSnapshot(
                accountEmail: email ?? stub.accountEmail,
                subscriptionLabel: subscriptionLabel() ?? stub.subscriptionLabel,
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

    /// 訂閱狀態顯示字。到期時間是 Unix timestamp（UTC），換算剩餘天數用裝置日曆。
    private func subscriptionLabel() -> String? {
        guard let status = subscriptionState.currentStatus else { return nil }
        guard let expiresAt = status.expiresAt else {
            return status.planType
        }
        let expiry = Date(timeIntervalSince1970: expiresAt)
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: expiry)
        ).day ?? 0
        let plan = status.planType ?? status.status.rawValue
        return "\(plan) · \(max(0, days))d"
    }
}
