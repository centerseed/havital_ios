import Foundation

enum InterruptDismissReason: Equatable {
    case primaryAction
    case secondaryAction
    case dismissed
    case cancelled
}

enum InterruptType: Hashable {
    // Reserved for a future route-level/session-blocking interrupt.
    // Do not instantiate until payload + host rendering are implemented together.
    case sessionBlocking
    case paywall
    case announcement
    case dataSourceBindingReminder
    case subscriptionReminder
    case otherNudge

    var policy: InterruptPolicy {
        switch self {
        case .sessionBlocking:
            return InterruptPolicy(priority: .sessionBlocking, presentationStyle: .sheet)
        case .paywall:
            return InterruptPolicy(priority: .paywall, presentationStyle: .sheet)
        case .announcement:
            return InterruptPolicy(priority: .announcement, presentationStyle: .sheet)
        case .dataSourceBindingReminder:
            return InterruptPolicy(priority: .dataSourceBindingReminder, presentationStyle: .overlay)
        case .subscriptionReminder:
            return InterruptPolicy(priority: .paywall, presentationStyle: .alert)
        case .otherNudge:
            return InterruptPolicy(priority: .otherNudge, presentationStyle: .alert)
        }
    }
}

struct InterruptItem: Identifiable {
    enum Payload {
        case paywall(PaywallTrigger)
        case announcement(Announcement)
        case dataSourceBindingReminder
        case subscriptionReminder(SubscriptionReminder)
    }

    static let dataSourceBindingReminderStableID = "interrupt.data_source_binding_reminder"

    let id = UUID()
    let stableID: String
    let type: InterruptType
    let payload: Payload
    let primaryAction: (() -> Void)?
    let onPresented: (() -> Void)?
    let onDismiss: ((InterruptDismissReason) -> Void)?

    var priority: InterruptPriority {
        type.policy.priority
    }

    var presentationStyle: InterruptPresentationStyle {
        type.policy.presentationStyle
    }

    var paywallTrigger: PaywallTrigger? {
        guard case .paywall(let trigger) = payload else { return nil }
        return trigger
    }

    var announcement: Announcement? {
        guard case .announcement(let announcement) = payload else { return nil }
        return announcement
    }

    var subscriptionReminder: SubscriptionReminder? {
        guard case .subscriptionReminder(let reminder) = payload else { return nil }
        return reminder
    }

    var debugLabel: String {
        "\(type)-\(stableID)"
    }

    private init(
        stableID: String,
        type: InterruptType,
        payload: Payload,
        primaryAction: (() -> Void)?,
        onPresented: (() -> Void)?,
        onDismiss: ((InterruptDismissReason) -> Void)?
    ) {
        self.stableID = stableID
        self.type = type
        self.payload = payload
        self.primaryAction = primaryAction
        self.onPresented = onPresented
        self.onDismiss = onDismiss
    }

    static func paywall(
        _ trigger: PaywallTrigger,
        onDismiss: ((InterruptDismissReason) -> Void)? = nil
    ) -> InterruptItem {
        InterruptItem(
            stableID: "interrupt.paywall.\(trigger.analyticsString)",
            type: .paywall,
            payload: .paywall(trigger),
            primaryAction: nil,
            onPresented: nil,
            onDismiss: onDismiss
        )
    }

    static func announcement(
        _ announcement: Announcement,
        onPresented: (() -> Void)? = nil,
        onCTA: (() -> Void)? = nil,
        onDismiss: ((InterruptDismissReason) -> Void)? = nil
    ) -> InterruptItem {
        InterruptItem(
            stableID: "interrupt.announcement.\(announcement.id)",
            type: .announcement,
            payload: .announcement(announcement),
            primaryAction: onCTA,
            onPresented: onPresented,
            onDismiss: onDismiss
        )
    }

    static func dataSourceBindingReminder(
        onDismiss: ((InterruptDismissReason) -> Void)? = nil
    ) -> InterruptItem {
        InterruptItem(
            stableID: dataSourceBindingReminderStableID,
            type: .dataSourceBindingReminder,
            payload: .dataSourceBindingReminder,
            primaryAction: nil,
            onPresented: nil,
            onDismiss: onDismiss
        )
    }

    static func subscriptionReminder(
        _ reminder: SubscriptionReminder,
        onDismiss: ((InterruptDismissReason) -> Void)? = nil
    ) -> InterruptItem {
        InterruptItem(
            stableID: "interrupt.subscription_reminder.\(reminder.id)",
            type: .subscriptionReminder,
            payload: .subscriptionReminder(reminder),
            primaryAction: nil,
            onPresented: nil,
            onDismiss: onDismiss
        )
    }
}
