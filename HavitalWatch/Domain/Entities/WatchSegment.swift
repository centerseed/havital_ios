struct WatchSegment: Equatable {
    enum Kind: Equatable {
        case warmup
        case run
        case rest
        case cooldown
        case work
    }

    enum Measure: Equatable {
        case distance
        case time
    }

    let kind: Kind
    let measure: Measure
    let targetMeters: Double?
    let targetSeconds: Int?
    let paceLowSecPerKm: Int?
    let paceHighSecPerKm: Int?
    let label: String
    let repIndex: Int?
    let repTotal: Int?
}
