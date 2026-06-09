#if DEBUG
import Foundation

/// DEBUG-only fixture for the `-watchSyncSendTest` launch hook: lets us exercise the
/// real `WatchCompanionService.sendTodayPlan` transport on a paired simulator without
/// logging in or navigating the full UI.
enum WatchSyncSendTestFixture {
    static func todayPlanDTO() -> WatchPlanSnapshotDTO {
        WatchPlanSnapshotDTO(
            date: Self.todayString(),
            runType: "interval",
            totalDistanceMeters: nil,
            totalSeconds: nil,
            planId: "sync-test",
            segments: [
                WatchSegmentDTO(
                    kind: "work", measure: "distance",
                    targetMeters: 400, targetSeconds: nil,
                    paceLowSecPerKm: 300, paceHighSecPerKm: 300,
                    label: "400m", repIndex: 1, repTotal: 5
                ),
                WatchSegmentDTO(
                    kind: "rest", measure: "time",
                    targetMeters: nil, targetSeconds: 90,
                    paceLowSecPerKm: nil, paceHighSecPerKm: nil,
                    label: "Rest", repIndex: 1, repTotal: 5
                )
            ]
        )
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
#endif
