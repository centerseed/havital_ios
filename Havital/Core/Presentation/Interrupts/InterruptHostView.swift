import SwiftUI

struct InterruptHostView: View {
    @ObservedObject var coordinator: InterruptCoordinator
    let onGoToDataSourceSettings: () -> Void

    init(
        coordinator: InterruptCoordinator = .shared,
        onGoToDataSourceSettings: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.onGoToDataSourceSettings = onGoToDataSourceSettings
    }

    var body: some View {
        Color.clear
            .accessibilityIdentifier("GlobalInterruptHost")
            .overlay {
                if coordinator.currentItem?.type == .dataSourceBindingReminder {
                    DataSourceBindingReminderOverlay(
                        onGoToSettings: {
                            coordinator.dismissCurrent(reason: .primaryAction)
                            onGoToDataSourceSettings()
                        },
                        onLater: {
                            coordinator.dismissCurrent(reason: .secondaryAction)
                        }
                    )
                }
            }
            .sheet(item: currentSheetItemBinding) { item in
                switch item.payload {
                case .announcement(let announcement):
                    AnnouncementPopupView(
                        announcement: announcement,
                        onCTA: {
                            item.primaryAction?()
                            coordinator.dismissCurrent(reason: .primaryAction)
                        },
                        onDismiss: {
                            coordinator.dismissCurrent(reason: .secondaryAction)
                        }
                    )
                case .paywall(let trigger):
                    PaywallView(trigger: trigger)
                case .dataSourceBindingReminder, .subscriptionReminder:
                    EmptyView()
                }
            }
            .alert(item: currentAlertItemBinding) { item in
                switch item.payload {
                case .subscriptionReminder(let reminder):
                    return subscriptionAlert(for: reminder)
                case .announcement, .paywall, .dataSourceBindingReminder:
                    return Alert(title: Text(""))
                }
            }
    }

    private var currentSheetItemBinding: Binding<InterruptItem?> {
        Binding(
            get: {
                guard coordinator.currentItem?.presentationStyle == .sheet else { return nil }
                return coordinator.currentItem
            },
            set: { nextValue in
                guard nextValue == nil, coordinator.currentItem?.presentationStyle == .sheet else { return }
                coordinator.dismissCurrent(reason: .dismissed)
            }
        )
    }

    private var currentAlertItemBinding: Binding<InterruptItem?> {
        Binding(
            get: {
                guard coordinator.currentItem?.presentationStyle == .alert else { return nil }
                return coordinator.currentItem
            },
            set: { nextValue in
                guard nextValue == nil, coordinator.currentItem?.presentationStyle == .alert else { return }
                coordinator.dismissCurrent(reason: .dismissed)
            }
        )
    }

    private func subscriptionAlert(for reminder: SubscriptionReminder) -> Alert {
        Alert(
            title: Text(subscriptionReminderTitle(for: reminder)),
            message: Text(subscriptionReminderMessage(for: reminder)),
            primaryButton: .default(Text(NSLocalizedString("paywall.title", comment: "Upgrade"))) {
                coordinator.dismissCurrent(reason: .primaryAction)
            },
            secondaryButton: .cancel(Text(NSLocalizedString("common.later", comment: "Later"))) {
                coordinator.dismissCurrent(reason: .secondaryAction)
            }
        )
    }

    private func subscriptionReminderTitle(for reminder: SubscriptionReminder) -> String {
        switch reminder {
        case .trialExpiring:
            return NSLocalizedString("reminder.trial_expiring_title", comment: "Trial Expiring Soon")
        case .expired:
            return NSLocalizedString("reminder.expired_title", comment: "Subscription Expired")
        }
    }

    private func subscriptionReminderMessage(for reminder: SubscriptionReminder) -> String {
        switch reminder {
        case .trialExpiring(let days, let endsAt):
            let dateStr = endsAt.map {
                DateFormatter.localizedString(
                    from: Date(timeIntervalSince1970: $0),
                    dateStyle: .medium,
                    timeStyle: .none
                )
            } ?? ""
            return String(
                format: NSLocalizedString("reminder.trial_expiring_message", comment: ""),
                days,
                dateStr
            )
        case .expired:
            return NSLocalizedString("reminder.expired_message", comment: "")
        }
    }
}
