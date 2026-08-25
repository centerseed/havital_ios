import SwiftUI

// MARK: - App2DeleteAccountView
/// 2.0「刪除帳戶」（設計 frame-29）：會刪什麼的清單 ＋ 訂閱提醒 ＋ 打字確認 ＋ 永久刪除。
///
/// 刪除本體走 `UserProfileFeatureViewModel.deleteAccount()`（先 reset onboarding →
/// 後端刪帳號 → 統一登出路徑），與 1.4 設定頁同一支，不另寫一份。
/// 2.0 多的只有「輸入確認詞」這道人為關卡，取代 1.4 的系統 alert。
struct App2DeleteAccountView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @State private var typed = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var keyword: String { L10n.App2.Settings.deleteKeyword.localized }

    private var canDelete: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(keyword) == .orderedSame
    }

    /// 有生效中的訂閱才提醒去取消（沒有訂閱就不擺一句不適用的話）。
    private var hasActiveSubscription: Bool {
        guard let status = subscriptionState.currentStatus else { return false }
        return status.status == .active || status.status == .gracePeriod || status.status == .trial
    }

    var body: some View {
        App2SettingsPageScaffold(
            title: NSLocalizedString("settings.delete_account", comment: "Delete Account"),
            onBack: onClose,
            backIdentifier: "App2_DeleteAccountClose",
            titleIdentifier: "App2_DeleteAccountView",
            ctaTitle: L10n.App2.Settings.deletePermanent.localized,
            ctaEnabled: canDelete,
            ctaBusy: isDeleting,
            ctaIdentifier: "App2_DeleteAccountConfirm",
            ctaIsDestructive: true,
            ctaAction: { delete() },
            secondaryTitle: NSLocalizedString("common.cancel", comment: "Cancel"),
            secondaryIdentifier: "App2_DeleteAccountCancel",
            secondaryAction: onClose
        ) {
            VStack(alignment: .leading, spacing: 16) {
                hero
                itemsCard
                if hasActiveSubscription {
                    subscriptionNote
                }
                confirmField
            }
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

    private var hero: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(App2Theme.accentRed.opacity(0.14))
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "trash")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(App2Theme.accentRed)
                )
            Text(L10n.App2.Settings.deleteConfirmTitle.localized)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
                .multilineTextAlignment(.center)
            Text(L10n.App2.Settings.deleteConfirmBody.localized)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var itemsCard: some View {
        App2GroupedList {
            let items = [
                L10n.App2.Settings.deleteItemWorkouts.localized,
                L10n.App2.Settings.deleteItemAchievements.localized,
                L10n.App2.Settings.deleteItemDataSources.localized
            ]
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(App2Theme.accentRed)
                            .frame(width: 20)
                        Text(item)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(App2Theme.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 14)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(App2Theme.insetBorder)
                            .frame(height: 1)
                            .padding(.leading, 47)
                    }
                }
            }
        }
        .accessibilityIdentifier("App2_DeleteAccountItems")
    }

    private var subscriptionNote: some View {
        Text(L10n.App2.Settings.deleteSubscriptionNote.localized)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(App2Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(App2Theme.accentBlue.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(App2Theme.accentBlue.opacity(0.3), lineWidth: 1)
            )
    }

    private var confirmField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: L10n.App2.Settings.deleteTypeHint.localized, keyword))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(App2Theme.inkTertiary)

            TextField(keyword, text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(App2Theme.inkPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(App2Theme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            canDelete ? App2Theme.accentRed : App2Theme.accentRed.opacity(0.25),
                            lineWidth: 1
                        )
                )
                .accessibilityIdentifier("App2_DeleteAccountField")
        }
    }

    private func delete() {
        guard canDelete, !isDeleting else { return }
        isDeleting = true
        Task {
            do {
                try await viewModel.deleteAccount()
                // 成功後既有路徑會登出並導回登入畫面，這裡不再自行導航。
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}
