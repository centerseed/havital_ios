enum WorkoutFlowType: Equatable {
    case directStart
    case warmupMainCooldown
    case rest
    case unsupported

    init(runType: String) {
        switch runType {
        case "easy_run", "easy", "long_run", "lsd", "recovery_run":
            self = .directStart
        case "interval", "combination", "tempo", "threshold", "progression", "benchmark", "race":
            self = .warmupMainCooldown
        case "rest":
            self = .rest
        case "strength", "yoga", "cycling", "hiking", "cross_training":
            self = .unsupported
        default:
            self = .rest
        }
    }
}
