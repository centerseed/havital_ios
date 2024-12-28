import SwiftUI

struct AppTheme {
    static let shared = AppTheme()
    
    private init() {}
    
    // MARK: - Light Mode Colors
    let primaryColor = Color(hex: "#3AAFA9")
    let secondaryColor = Color(hex: "#76C893")
    let backgroundColor = Color(hex: "#FFFFFF")
    let cardBackgroundColor = Color(hex: "#F4F4F4")
    
    struct TextColors {
        static let primary = Color(hex: "#333333")
        static let secondary = Color(hex: "#7D7D7D")
    }
    
    let accentColor = Color(hex: "#FF7F50")
    
    struct StatusColors {
        static let success = Color(hex: "#4CAF50")
        static let warning = Color(hex: "#FFC107")
        static let error = Color(hex: "#F44336")
    }
    
    // MARK: - Dark Mode Colors
    struct DarkMode {
        static let primaryColor = Color(hex: "#3AAFA9")
        static let secondaryColor = Color(hex: "#76C893")
        static let backgroundColor = Color(hex: "#121212")
        static let cardBackgroundColor = Color(hex: "#1E1E1E")
        
        struct TextColors {
            static let primary = Color(hex: "#FFFFFF")
            static let secondary = Color(hex: "#B3B3B3")
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
