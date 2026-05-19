import SwiftUI

// MARK: - Paceriz Redesign Design System (introduced 2026-05)
//
// Single source of truth for all visual tokens used in the Paceriz V2 redesign.
// Do NOT define ad-hoc hex values in feature views — always reference tokens here.
// Design source: /tmp/paceriz-design/paceriz-app/project/styles.css + training-plan.jsx
//
// Phase B will extend this file with badge data layer tokens and race-header tokens.

// MARK: - Color Tokens

enum PacerizColor {
    // Base blue — #3F86F6 (--p-blue)
    static let blue = Color(red: 0x3F / 255.0, green: 0x86 / 255.0, blue: 0xF6 / 255.0)

    // Deep blue — #1E62D0 (--p-blue-deep) / adaptive: dark mode uses lighter #7AA8F8 for contrast
    static let blueDeep = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x7A / 255.0, green: 0xA8 / 255.0, blue: 0xF8 / 255.0, alpha: 1)
            : UIColor(red: 0x1E / 255.0, green: 0x62 / 255.0, blue: 0xD0 / 255.0, alpha: 1)
    })

    // Blue 12% opacity — adaptive (light: 0.12 / dark: 0.22) per styles.css dark variant
    // Must use UIColor trait-based adaptive — NOT .opacity(0.12)
    static let blue12 = Color(UIColor { trait in
        let base = UIColor(red: 0x3F / 255.0, green: 0x86 / 255.0, blue: 0xF6 / 255.0, alpha: 1.0)
        return base.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.22 : 0.12)
    })

    // Base green — #76C893 (--p-green)
    static let green = Color(red: 0x76 / 255.0, green: 0xC8 / 255.0, blue: 0x93 / 255.0)

    // Deep green — #4FA070 (--p-green-deep) / adaptive: dark mode uses lighter #9AD3AE for contrast
    static let greenDeep = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x9A / 255.0, green: 0xD3 / 255.0, blue: 0xAE / 255.0, alpha: 1)
            : UIColor(red: 0x4F / 255.0, green: 0xA0 / 255.0, blue: 0x70 / 255.0, alpha: 1)
    })

    // Green 12% opacity — adaptive (light: 0.14 / dark: 0.20) per styles.css dark variant
    static let green12 = Color(UIColor { trait in
        let base = UIColor(red: 0x76 / 255.0, green: 0xC8 / 255.0, blue: 0x93 / 255.0, alpha: 1.0)
        return base.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.20 : 0.14)
    })

    // Base orange — #FF7F50 (--p-orange)
    static let orange = Color(red: 0xFF / 255.0, green: 0x7F / 255.0, blue: 0x50 / 255.0)

    // Deep orange — #E5613A (--p-orange-deep) / adaptive: dark mode uses lighter #FFA987 for contrast
    static let orangeDeep = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF / 255.0, green: 0xA9 / 255.0, blue: 0x87 / 255.0, alpha: 1)
            : UIColor(red: 0xE5 / 255.0, green: 0x61 / 255.0, blue: 0x3A / 255.0, alpha: 1)
    })

    // Orange 12% opacity — adaptive (light: 0.14 / dark: 0.22) per styles.css dark variant
    static let orange12 = Color(UIColor { trait in
        let base = UIColor(red: 0xFF / 255.0, green: 0x7F / 255.0, blue: 0x50 / 255.0, alpha: 1.0)
        return base.withAlphaComponent(trait.userInterfaceStyle == .dark ? 0.22 : 0.14)
    })

    // Error red — #F44336 (--s-error)
    static let error = Color(red: 0xF4 / 255.0, green: 0x43 / 255.0, blue: 0x36 / 255.0)
}

// MARK: - Radius Tokens

enum PacerizRadius {
    /// Card-level corner radius (14pt)
    static let card: CGFloat = 14
    /// Inner component corner radius (10pt)
    static let inner: CGFloat = 10
}

// MARK: - PRChip

/// Capsule label component used for week badge, percentage chip, and placeholder chips.
/// - Parameters:
///   - text: Display string
///   - fg: Foreground (text) color
///   - bg: Background color
///   - fontSize: Point size (default 10pt bold)
struct PRChip: View {
    let text: String
    let fg: Color
    let bg: Color
    var fontSize: CGFloat = 10
    var leadingSymbol: String? = nil  // SF Symbol name; use instead of emoji prefix in text

    var body: some View {
        HStack(spacing: 3) {
            if let sym = leadingSymbol {
                // F4.b: SF Symbol (e.g. sparkles) needs min 13pt + bold to render correctly; smaller sizes look like "+"
                Image(systemName: sym)
                    .font(.system(size: max(fontSize, 13), weight: .bold))
                    .symbolRenderingMode(.hierarchical)
            }
            Text(text)
                .font(.system(size: fontSize, weight: .bold))
                .tracking(0.3)
        }
        .foregroundColor(fg)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(bg, in: Capsule())
        .lineLimit(1)
    }
}

// MARK: - PRDotLegendItem

/// Small square dot + label used in intensity legend rows.
struct PRDotLegendItem: View {
    let dotColor: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - PRSegmentedIntensityBar

/// Horizontal 3-segment intensity bar (green / orange / red) with gray background.
/// All inputs must be in the same unit (minutes). Proportional widths based on total.
struct PRSegmentedIntensityBar: View {
    let low: Int
    let medium: Int
    let high: Int
    let total: Int   // used as denominator; if 0 bar shows empty

    private var barHeight: CGFloat { 8 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let denom = max(total, 1)
            let lowW = width * CGFloat(low) / CGFloat(denom)
            let medW = width * CGFloat(medium) / CGFloat(denom)
            let highW = width * CGFloat(high) / CGFloat(denom)

            ZStack(alignment: .leading) {
                // Background track — adaptive: white 12% in dark mode, black 8% in light mode
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.12)
                            : UIColor.black.withAlphaComponent(0.08)
                    }))
                    .frame(height: barHeight)

                // Filled segments
                HStack(spacing: 0) {
                    if lowW > 0 {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(PacerizColor.green)
                            .frame(width: lowW, height: barHeight)
                    }
                    if medW > 0 {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(PacerizColor.orange)
                            .frame(width: medW, height: barHeight)
                    }
                    if highW > 0 {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(PacerizColor.error)
                            .frame(width: highW, height: barHeight)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: barHeight)
                .clipShape(RoundedRectangle(cornerRadius: barHeight / 2))
            }
        }
        .frame(height: barHeight)
    }
}

// MARK: - PRPlaceholderBadge
//
// PHASE_B_BADGE: This is a placeholder for the real badge component.
// Phase B will replace this with BadgeRepository-backed data and real badge assets.
// Do NOT use real badge data here — keep it decoupled until Phase B TD is dispatched.

/// Placeholder badge: SF Symbol `rosette` with blue gradient tint and drop shadow.
/// - Parameter size: Badge size in points (default 72)
struct PRPlaceholderBadge: View {
    var size: CGFloat = 72

    var body: some View {
        Image(systemName: "rosette")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.55, height: size * 0.55)
            .foregroundStyle(
                LinearGradient(
                    colors: [PacerizColor.blue, PacerizColor.blueDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(PacerizColor.blue12)
            )
            .shadow(
                color: PacerizColor.blue.opacity(0.30),
                radius: 9,
                x: 0,
                y: 8
            )
    }
}
