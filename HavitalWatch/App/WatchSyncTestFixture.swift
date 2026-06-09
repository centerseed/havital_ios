#if DEBUG
import Foundation

/// Builds a today_plan payload in the exact wire shape the iPhone's
/// `WatchCompanionService.todayPlanUserInfo(for:)` produces, so the `-injectTodayPlan`
/// launch hook can exercise the real receive→store→display chain on the simulator.
enum WatchSyncTestFixture {
    static func todayPlanPayload() -> [String: Any] {
        let dto = WatchPlanSnapshotDTO(
            date: WatchFormatting.localDayString(),
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
        return [
            "type": "today_plan",
            "payload": (try? JSONEncoder().encode(dto)) ?? Data()
        ]
    }
}
#endif
