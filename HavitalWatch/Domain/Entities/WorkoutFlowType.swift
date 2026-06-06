enum WorkoutFlowType: Equatable {
    case directStart
    case warmupMainCooldown
    case rest
    case unsupported

    init(runType: String) {
        switch runType {
        case "easy_run", "easy", "long_run", "lsd", "recovery_run":
            self = .directStart
        case "interval",
             "short_interval",
             "long_interval",
             "short_intervals",
             "long_intervals",
             "tempo",
             "tempo_run",
             "threshold",
             "threshold_run",
             "fartlek",
             "progression",
             "combination",
             "benchmark",
             "race",
             "race_pace",
             "strides",
             "strides_session",
             "hill_repeats",
             "hill_sprints",
             "cruise_intervals",
             "norwegian_4x4",
             "norwegian_singles",
             "norwegian_doubles",
             "norwegian_threshold",
             "yasso_800",
             "mile_repeats",
             "fast_finish":
            self = .warmupMainCooldown
        case "rest":
            self = .rest
        case "strength", "yoga", "cycling", "hiking", "swimming", "elliptical", "rowing", "cross_training":
            self = .unsupported
        default:
            self = .rest
        }
    }
}
