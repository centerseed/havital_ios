enum ActiveSegmentEvent: Equatable {
    case countdownCue
    case advanced(toIndex: Int)
    case finished
}
