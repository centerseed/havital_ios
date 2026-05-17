import Foundation

// MARK: - TimeFormatting

/// Shared time-formatting utilities used by celebration views.
/// These helpers were previously duplicated in CelebrationSheet and CelebrationShareCardView.
enum TimeFormatting {

    /// Format seconds as M:SS (under 1 hour) or H:MM:SS (1 hour or more).
    static func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// Format an improvement in seconds as M:SS (if ≥ 60 s) or NNs (under 60 s).
    static func formatImprovement(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, secs) : "\(secs)s"
    }
}
