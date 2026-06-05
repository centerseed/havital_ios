struct WatchPlanSnapshot: Equatable {
    let date: String
    let flowType: WorkoutFlowType
    let totalDistanceMeters: Double?
    let totalSeconds: Int?
    let planId: String
    let segments: [WatchSegment]
}
