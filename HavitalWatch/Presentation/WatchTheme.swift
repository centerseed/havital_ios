import SwiftUI

/// Single source of truth for the watch app's visual language (watchOS-native running
/// style). Replaces the scattered `.green`/`.orange`/`Color.black` literals so every
/// screen shares one palette, typography scale, and background treatment.
enum WatchTheme {
    // MARK: Palette
    /// Paceriz brand green — used for the primary accent, CTAs, and "on target" states.
    static let brand = Color(red: 0.18, green: 0.82, blue: 0.45)
    static let onTarget = brand
    static let tooFast = Color(red: 1.0, green: 0.62, blue: 0.0)   // amber
    static let tooSlow = Color(red: 1.0, green: 0.27, blue: 0.27)  // red
    static let heartRate = Color(red: 1.0, green: 0.30, blue: 0.33)
    static let neutral = Color.white.opacity(0.55)

    // MARK: Backgrounds
    /// Rich near-black gradient with a faint brand tint — for non-active screens
    /// (today / welcome / summary / permission). Reads as intentional, not a debug black.
    static var ambientBackground: some View {
        LinearGradient(
            colors: [Color(white: 0.06), Color(red: 0.02, green: 0.10, blue: 0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// Pure black — for active workout metric screens, matching Apple Workout where the
    /// OLED black maximises glanceable contrast and saves battery.
    static var activeBackground: some View {
        Color.black.ignoresSafeArea()
    }

    // MARK: Typography
    static func metricValue(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static var metricLabel: Font {
        .system(size: 12, weight: .semibold, design: .rounded)
    }
}

/// A labelled metric: a small uppercase-ish label above a large rounded value.
/// The building block for the summary grid and metric screens.
struct WatchMetric: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    var valueSize: CGFloat = 30
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(WatchTheme.metricLabel)
                .foregroundStyle(WatchTheme.neutral)
            Text(value)
                .font(WatchTheme.metricValue(valueSize))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }
}
