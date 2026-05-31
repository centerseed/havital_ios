import SwiftUI

/// Apple Health Attribution View
/// Displays Apple Health branding as a data source badge.
/// Follows the same extensible pattern as GarminAttributionView and ConditionalStravaAttributionView.
struct AppleHealthAttributionView: View {
    let displayStyle: DisplayStyle
    @Environment(\.colorScheme) private var colorScheme

    enum DisplayStyle {
        case titleLevel
        case secondary
        case compact
    }

    init(displayStyle: DisplayStyle = .compact) {
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

    // MARK: - Title Level

    private var titleLevelAttribution: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 16)
                .foregroundColor(.red)
            Text(L10n.DataSource.appleHealth.localized)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Secondary

    private var secondaryAttribution: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 12)
                .foregroundColor(.red)
            Text(L10n.DataSource.appleHealth.localized)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Compact

    private var compactAttribution: some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundColor(.red)
            Text(L10n.DataSource.appleHealth.localized)
                .font(AppFont.caption())
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AppleHealthAttributionView(displayStyle: .titleLevel)
        AppleHealthAttributionView(displayStyle: .secondary)
        AppleHealthAttributionView(displayStyle: .compact)
    }
    .padding()
}
