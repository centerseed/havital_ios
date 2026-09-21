import SwiftUI

/// SPEC-cross-store-subscription §3：會開本平台商店的動作，別商店訂閱者改顯示說明。
enum OtherStoreManagement {
    static func run(
        status: SubscriptionStatusEntity?,
        message: Binding<String?>,
        action: () -> Void
    ) {
        if let status, status.isSubscribedOnOtherStore {
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

extension View {
    func otherStoreManagementAlert(message: Binding<String?>) -> some View {
        modifier(OtherStoreManagementAlertModifier(message: message))
    }
}
