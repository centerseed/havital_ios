import SwiftUI

/// SPEC-cross-store-subscription §3：會開本平台商店的動作，別商店訂閱者改顯示說明。
enum OtherStoreManagement {
    /// 訂閱狀態還沒讀回來之前，管理與兌換不可點。
    static func isStoreActionEnabled(status: SubscriptionStatusEntity?) -> Bool {
        status != nil
    }

    static func run(
        status: SubscriptionStatusEntity?,
        message: Binding<String?>,
        action: () -> Void
    ) {
        guard let status else { return }
        if status.isSubscribedOnOtherStore {
            message.wrappedValue = status.otherStoreManagementMessage
            return
        }
        action()
    }
}

struct OtherStoreManagementAlertModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert(
            "",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

private struct OtherStoreManagementAvailabilityModifier: ViewModifier {
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared

    func body(content: Content) -> some View {
        content.disabled(!OtherStoreManagement.isStoreActionEnabled(status: subscriptionState.currentStatus))
    }
}

extension View {
    func otherStoreManagementAlert(message: Binding<String?>) -> some View {
        modifier(OtherStoreManagementAlertModifier(message: message))
    }

    func otherStoreManagementDisabledUntilReady() -> some View {
        modifier(OtherStoreManagementAvailabilityModifier())
    }
}
