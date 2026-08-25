import SwiftUI

// MARK: - App2PlansView
/// 2.0「方案與訂閱」（設計 frame-22）。
///
/// **訂閱邏輯完全沿用 1.4**：狀態來自 `SubscriptionStateManager.shared`（既有 SSOT）、
/// 價格來自 `PaywallViewModel.displayPackages`（RevenueCat 在地化字串，不硬寫）、
/// 兌換走 `OfferRedemptionCoordinator`、升級／變更方案開既有 `PaywallView`、
/// 取消訂閱導到 Apple 的訂閱管理頁。這一頁只是第二個版面。
///
/// 設計與現況的差距（不硬造）：
/// - 設計的「付款方式 Apple ID」：後端 `SubscriptionStatusEntity` 沒有這個欄位 → 不擺這一列。
/// - 設計的「兌換優惠碼」是頁內輸入框；Apple 的兌換只能開系統 sheet
///   （`SKPaymentQueue.presentCodeRedemptionSheet`），所以這裡是一顆鈕。
struct App2PlansView: View {

    let onClose: () -> Void

    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @StateObject private var paywallViewModel = PaywallViewModel(trigger: .settingsTier)
    @State private var paywallTrigger: PaywallTrigger?
    @State private var redemptionMessage: String?
    private let redemptionCoordinator = OfferRedemptionCoordinator()

    private var status: SubscriptionStatusEntity? { subscriptionState.currentStatus }

    /// 年繳方案的在地化價格；還沒載到就不顯示（不填樣本價）。
    private var yearlyPrice: String? {
        paywallViewModel.displayPackages
            .first { $0.package.period == .yearly }?
            .displayPrice
    }

    var body: some View {
        App2SettingsPageScaffold(
            title: L10n.App2.Settings.plansTitle.localized,
            onBack: onClose,
            backIdentifier: "App2_PlansClose",
            titleIdentifier: "App2_PlansView",
            ctaTitle: primaryCtaTitle,
            ctaIdentifier: "App2_PlansPrimaryCta",
            ctaAction: { paywallTrigger = primaryCtaTrigger },
            secondaryTitle: showsCancel ? L10n.App2.Settings.cancelSubscription.localized : nil,
            secondaryIdentifier: "App2_PlansCancel",
            secondaryAction: showsCancel ? { openAppleSubscriptions() } : nil
        ) {
            VStack(alignment: .leading, spacing: 14) {
                planComparison
                currentSubscriptionCard
                redeemCard
            }
        }
        .task { await paywallViewModel.loadOfferings() }
        .fullScreenCover(item: $paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
        .alert(
            NSLocalizedString("profile.subscription.redeem_alert_title", comment: "Offer Code"),
            isPresented: Binding(
                get: { redemptionMessage != nil },
                set: { if !$0 { redemptionMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) { redemptionMessage = nil }
        } message: {
            Text(redemptionMessage ?? "")
        }
    }

    // MARK: - 兩張方案卡

    private var planComparison: some View {
        HStack(alignment: .top, spacing: 12) {
            planCard(
                // 免費方案沒有「價格」可印（RevenueCat 只給付費包的在地化價格），
                // 卡名本身就是「免費」，不再重複一行。
                name: L10n.App2.Settings.planFree.localized,
                price: nil,
                priceSuffix: nil,
                features: [
                    L10n.App2.Settings.planFreeFeature1.localized,
                    L10n.App2.Settings.planFreeFeature2.localized,
                    L10n.App2.Settings.planFreeFeature3.localized
                ],
                isCurrent: !isPremium,
                identifier: "App2_PlansFreeCard"
            )
            planCard(
                name: "Pro",
                // RevenueCat 的 `localizedPrice` 已經帶週期（實測是 `NT$1,790/年`），
                // 不再自己補一次週期字，否則會變成「/年 Yearly」。
                price: yearlyPrice,
                priceSuffix: nil,
                features: [
                    L10n.App2.Settings.planProFeature1.localized,
                    L10n.App2.Settings.planProFeature2.localized,
                    L10n.App2.Settings.planProFeature3.localized
                ],
                isCurrent: isPremium,
                identifier: "App2_PlansProCard"
            )
        }
    }

    private func planCard(
        name: String,
        price: String?,
        priceSuffix: String?,
        features: [String],
        isCurrent: Bool,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 目前方案的膠囊掛在卡片右上、壓在邊上（設計 frame-22），
            // 所以這張卡上緣要留出膠囊的高度，標題才不會被蓋住。
            if isCurrent { Spacer().frame(height: 10) }

            Text(name)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(isCurrent ? App2Theme.accentBlueDeep : App2Theme.inkPrimary)

            if let price {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.app2Numeric(24, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let priceSuffix {
                        Text(priceSuffix)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(features, id: \.self) { feature in
                    Text(feature)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isCurrent ? App2Theme.inkSecondary : App2Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrent
                      ? AnyShapeStyle(App2Theme.accentBlue.opacity(0.1))
                      : AnyShapeStyle(App2Theme.cardBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isCurrent ? App2Theme.accentBlue : App2Theme.cardBorder,
                    lineWidth: isCurrent ? 2 : 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if isCurrent {
                App2Pill(text: L10n.App2.Settings.planCurrentBadge.localized)
                    .padding(.trailing, 10)
                    .padding(.top, 6)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 目前訂閱

    private var currentSubscriptionCard: some View {
        App2Card {
            HStack(spacing: 9) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(App2Theme.accentBlue)
                Text(L10n.App2.Settings.currentSubscription.localized)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
                Text(SubscriptionStatusEntity.compactStateLabel(for: status))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(isPremium ? App2Theme.accentGreen : App2Theme.inkSubtle)
            }

            valueRow(
                title: L10n.App2.Settings.planRow.localized,
                value: planDisplayName
            )

            if let expiryTitle, let expiryValue {
                valueRow(title: expiryTitle, value: expiryValue, monospaced: true)
            }
        }
        .accessibilityIdentifier("App2_PlansCurrentCard")
    }

    private func valueRow(title: String, value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkTertiary)
            Spacer(minLength: 8)
            Text(value)
                .font(monospaced ? .app2Mono(14, weight: .bold) : .system(size: 14, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
        }
        .padding(.top, 10)
    }

    // MARK: - 兌換優惠碼

    private var redeemCard: some View {
        Button {
            Task {
                let result = await redemptionCoordinator.redeem(entryPoint: .profile)
                switch result {
                case .success:
                    redemptionMessage = NSLocalizedString(
                        "profile.subscription.redeem_success", comment: ""
                    )
                case .cancelled:
                    break
                case .pendingProcessing:
                    redemptionMessage = NSLocalizedString(
                        "paywall.offer_code_pending_processing", comment: ""
                    )
                case .failed(let error):
                    redemptionMessage = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "ticket")
                    .font(.system(size: 15, weight: .semibold))
                Text(L10n.App2.Settings.redeemCode.localized)
                    .font(.system(size: 14, weight: .heavy))
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(App2Theme.chevron)
            }
            .foregroundStyle(App2Theme.accentBlueDeep)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(App2Theme.insetBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("App2_PlansRedeem")
    }

    // MARK: - 狀態推導（與 1.4 設定頁同一組判定）

    private var isPremium: Bool {
        guard let status else { return false }
        if status.inGracePeriod { return false }
        return status.status == .active || status.status == .gracePeriod || status.status == .trial
    }

    private var planDisplayName: String {
        guard let status else {
            return NSLocalizedString("profile.subscription.free", comment: "Free")
        }
        switch status.status {
        case .active, .gracePeriod: return status.planDisplayName
        case .trial: return NSLocalizedString("profile.subscription.trial", comment: "")
        case .cancelled: return NSLocalizedString("profile.subscription.cancelled", comment: "")
        case .expired: return NSLocalizedString("profile.subscription.expired", comment: "")
        case .none: return NSLocalizedString("profile.subscription.free", comment: "")
        }
    }

    /// 「下次續訂／有效至／到期」——標題與值都跟著狀態走，沒有日期就整列不出現。
    private var expiryTitle: String? {
        guard let status else { return nil }
        switch status.status {
        case .active, .gracePeriod:
            return NSLocalizedString("profile.subscription.renews_on", comment: "")
        case .cancelled:
            return NSLocalizedString("profile.subscription.valid_until", comment: "")
        case .expired:
            return NSLocalizedString("profile.subscription.expires", comment: "")
        case .trial:
            return NSLocalizedString("profile.subscription.trial_ends", comment: "")
        case .none:
            return nil
        }
    }

    private var expiryValue: String? {
        guard let status else { return nil }
        let timestamp = status.status == .trial ? (status.trialEndAt ?? status.expiresAt) : status.expiresAt
        guard let timestamp else { return nil }
        return DateFormatterHelper.formatSubscriptionExpiryDate(
            Date(timeIntervalSince1970: timestamp)
        )
    }

    private var primaryCtaTitle: String {
        switch status?.status {
        case .active:
            return NSLocalizedString("profile.subscription.change_plan", comment: "")
        case .cancelled, .expired:
            return NSLocalizedString("profile.subscription.resubscribe", comment: "")
        default:
            return NSLocalizedString("paywall.title", comment: "Upgrade")
        }
    }

    private var primaryCtaTrigger: PaywallTrigger {
        switch status?.status {
        case .active: return .changePlan
        case .cancelled, .expired: return .resubscribe
        default: return .featureLocked
        }
    }

    /// Apple 的訂閱只能在系統設定取消——與 1.4「管理訂閱」同一條。
    private var showsCancel: Bool {
        guard let status else { return false }
        return status.status == .active || status.status == .gracePeriod
    }

    private func openAppleSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
}
