import SwiftUI

/// Strava Attribution View
/// Displays Strava branding and attribution as required by Strava API Agreement
/// Used wherever Strava-sourced data is displayed
struct StravaAttributionView: View {
    let displayStyle: DisplayStyle
    @Environment(\.colorScheme) private var colorScheme

    enum DisplayStyle {
        case titleLevel      // For primary displays (dashboards, overview cards)
        case secondary       // For detailed views, reports, settings
        case compact         // For smaller UI elements
    }

    init(displayStyle: DisplayStyle = .secondary) {
        self.displayStyle = displayStyle
    }

    var body: some View {
        switch displayStyle {
        case .titleLevel:
            titleLevelAttribution
        case .secondary:
            secondaryAttribution
        case .compact:
            compactAttribution
        }
    }

    // MARK: - Title Level Attribution
    private var titleLevelAttribution: some View {
        Image(stravaLogoImageName)
            .resizable()
            .scaledToFit()
            .frame(height: 14)  // 比 Garmin (16) 稍小
    }

    // MARK: - Secondary Attribution
    private var secondaryAttribution: some View {
        Image(stravaLogoImageName)
            .resizable()
            .scaledToFit()
            .frame(height: 10)  // 比 Garmin (12) 稍小
    }

    // MARK: - Compact Attribution
    private var compactAttribution: some View {
        Image(stravaLogoImageName)
            .resizable()
            .scaledToFit()
            .frame(height: 12)  // 比 Garmin (14) 稍小
    }

    // MARK: - Logo Selection
    private var stravaLogoImageName: String {
        switch colorScheme {
        case .dark:
            return "api_logo_pwrdBy_strava_horiz_white"
        case .light:
            return "api_logo_pwrdBy_strava_horiz_black"
        @unknown default:
            return "api_logo_pwrdBy_strava_horiz_black"
        }
    }
}

// MARK: - Environment-aware Attribution
/// A view that automatically shows Strava attribution when appropriate
struct ConditionalStravaAttributionView: View {
    let dataProvider: String?
    let displayStyle: StravaAttributionView.DisplayStyle

    init(dataProvider: String?, displayStyle: StravaAttributionView.DisplayStyle = .secondary) {
        self.dataProvider = dataProvider
        self.displayStyle = displayStyle
    }

    var body: some View {
        // Only show Strava attribution if data is from Strava
        if let provider = dataProvider, provider.lowercased() == "strava" {
            StravaAttributionView(displayStyle: displayStyle)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title Level")
                .font(.headline)
            StravaAttributionView(displayStyle: .titleLevel)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Secondary")
                .font(.headline)
            StravaAttributionView(displayStyle: .secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Compact")
                .font(.headline)
            StravaAttributionView(displayStyle: .compact)
        }
    }
    .padding()
}
