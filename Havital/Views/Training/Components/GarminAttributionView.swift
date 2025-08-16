import SwiftUI

/// Garmin Attribution View
/// Displays Garmin branding and attribution as required by Garmin Developer API Brand Guidelines
/// Used wherever Garmin device-sourced data is displayed
struct GarminAttributionView: View {
    let deviceModel: String?
    let displayStyle: DisplayStyle
    @Environment(\.colorScheme) private var colorScheme
    
    enum DisplayStyle {
        case titleLevel      // For primary displays (dashboards, overview cards)
        case secondary       // For detailed views, reports, settings
        case compact         // For smaller UI elements
        case social          // For social media or exported visuals
    }
    
    init(deviceModel: String? = nil, displayStyle: DisplayStyle = .secondary) {
        self.deviceModel = deviceModel
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
        case .social:
            socialAttribution
        }
    }
    
    // MARK: - Title Level Attribution
    private var titleLevelAttribution: some View {
        HStack(spacing: 4) {
            // Garmin logo on the left
            Image(garminLogoImageName)
                .resizable()
                .scaledToFit()
                .frame(height: 16)
            
            // Device name on the right (without "Garmin" prefix)
            if let deviceModel = deviceModel {
                Text(deviceModel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Secondary Attribution
    private var secondaryAttribution: some View {
        HStack(spacing: 4) {
            // Garmin logo on the left
            Image(garminLogoImageName)
                .resizable()
                .scaledToFit()
                .frame(height: 12)
            
            // Device name on the right (without "Garmin" prefix)
            if let deviceModel = deviceModel {
                Text(deviceModel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Compact Attribution
    private var compactAttribution: some View {
        Image(garminLogoImageName)
            .resizable()
            .scaledToFit()
            .frame(height: 14)
    }
    
    // MARK: - Social Media Attribution
    private var socialAttribution: some View {
        Image("Garmin Tag-white-high-res")
            .resizable()
            .scaledToFit()
            .frame(height: 14)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
    }
    
    // MARK: - Logo Selection
    private var garminLogoImageName: String {
        switch colorScheme {
        case .dark:
            return "Garmin Tag-white-high-res"
        case .light:
            return "Garmin Tag-black-high-res"
        @unknown default:
            return "Garmin Tag-black-high-res"
        }
    }
}

// MARK: - Environment-aware Attribution
/// A view that automatically shows Garmin attribution when appropriate
struct ConditionalGarminAttributionView: View {
    let dataProvider: String?
    let deviceModel: String?
    let displayStyle: GarminAttributionView.DisplayStyle
    
    init(dataProvider: String?, deviceModel: String? = nil, displayStyle: GarminAttributionView.DisplayStyle = .secondary) {
        self.dataProvider = dataProvider
        self.deviceModel = deviceModel
        self.displayStyle = displayStyle
    }
    
    var body: some View {
        // Only show Garmin attribution if data is from Garmin
        if let provider = dataProvider, provider.lowercased().contains("garmin") {
            GarminAttributionView(deviceModel: deviceModel, displayStyle: displayStyle)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title Level")
                .font(.headline)
            GarminAttributionView(deviceModel: "Forerunner 955", displayStyle: .titleLevel)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Secondary")
                .font(.headline)
            GarminAttributionView(deviceModel: "Forerunner 955", displayStyle: .secondary)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Compact")
                .font(.headline)
            GarminAttributionView(deviceModel: "Forerunner 955", displayStyle: .compact)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Social")
                .font(.headline)
            GarminAttributionView(deviceModel: "Forerunner 955", displayStyle: .social)
        }
        .padding()
        .background(Color.blue)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("No Device Model")
                .font(.headline)
            GarminAttributionView(displayStyle: .secondary)
        }
    }
    .padding()
}