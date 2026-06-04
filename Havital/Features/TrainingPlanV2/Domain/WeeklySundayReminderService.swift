import UserNotifications
import Foundation

// MARK: - WeeklySundayReminderService
/// Schedules a local notification at 20:00 every Sunday when:
///   1. Today is Sunday
///   2. The current week's Sunday has a non-rest training day
///   3. The user recorded at least one workout today
///
/// Idempotent: removes any pending notification with the same identifier
/// before scheduling. Safe to call multiple times per day.
@MainActor
final class WeeklySundayReminderService {

    static let shared = WeeklySundayReminderService()

    private let notificationIdentifier = "weekly_sunday_reminder"

    private init() {}

    func checkAndScheduleIfNeeded(weeklyPlan: WeeklyPlanV2, todayWorkoutExists: Bool) {
        guard isSunday() else { return }
        guard hasSundayTraining(in: weeklyPlan) else { return }
        guard todayWorkoutExists else { return }
        guard !isPast8pm() else { return }

        Task {
            await scheduleNotification()
        }
    }

    // MARK: - Condition Checks

    private func isSunday() -> Bool {
        Calendar.current.component(.weekday, from: Date()) == 1
    }

    private func isPast8pm() -> Bool {
        Calendar.current.component(.hour, from: Date()) >= 20
    }

    func hasSundayTraining(in plan: WeeklyPlanV2) -> Bool {
        guard let sunday = plan.days.first(where: { $0.dayIndex == 7 }) else { return false }
        return sunday.category != .rest && sunday.category != nil
    }

    // MARK: - Scheduling

    private func scheduleNotification() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L10n.Notification.SundayReminder.title.localized
        content.body  = L10n.Notification.SundayReminder.body.localized
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour   = 20
        components.minute = 0
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Logger.debug("[WeeklySundayReminderService] ✅ Sunday 20:00 notification scheduled")
        } catch {
            Logger.error("[WeeklySundayReminderService] ❌ Failed to schedule: \(error)")
        }
    }
}
