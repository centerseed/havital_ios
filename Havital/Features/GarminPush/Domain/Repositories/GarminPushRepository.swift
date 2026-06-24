import Foundation

/// Pushes a planned running workout to the user's Garmin watch (via backend →
/// Garmin Connect) and removes it. T-0044. Manual, per-workout. Not subscription-gated
/// (access is gated upstream at plan generation — no subscription → no plan to push).
///
/// ViewModel depends on THIS protocol, never the concrete impl (iOS arch rule #3).
protocol GarminPushRepository {
    /// POST /v2/integrations/garmin/push-workout  {day_index, date:"YYYY-MM-DD"}
    func pushWorkout(dayIndex: Int, date: String) async throws

    /// DELETE /v2/integrations/garmin/push-workout  {day_index}
    func removeWorkout(dayIndex: Int) async throws
}
