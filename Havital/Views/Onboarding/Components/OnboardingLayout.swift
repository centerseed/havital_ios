//
//  OnboardingLayout.swift
//  Havital
//
//  Layout constants for unified onboarding UI consistency.
//

import CoreGraphics
import SwiftUI

/// Shared layout constants used across all onboarding screens.
/// Centralising these values ensures spacing, padding, and corner radii
/// remain consistent without scattering magic numbers in individual Views.
enum OnboardingLayout {
    /// Horizontal content padding applied to all onboarding pages (24pt).
    static let horizontalPadding: CGFloat = 24

    /// Corner radius applied to all CTA buttons (12pt).
    static let ctaCornerRadius: CGFloat = 12

    /// Bottom padding below the CTA button inside OnboardingBottomCTA (16pt).
    static let ctaBottomPadding: CGFloat = 16

    /// Horizontal padding applied to the CTA button (24pt).
    static let ctaHorizontalPadding: CGFloat = 24

    /// Bottom padding added to scroll content to ensure it is not hidden
    /// behind the fixed OnboardingBottomCTA overlay (120pt).
    static let contentBottomPadding: CGFloat = 120

    /// Vertical spacing between major sections inside a page (24pt).
    static let sectionSpacing: CGFloat = 24

    /// Standard title font for onboarding pages.
    /// Uses computed property to respect runtime language changes (AppFont.cachedLanguage).
    static var titleFont: Font { AppFont.title2() }

    /// Standard description / body-small font for onboarding pages.
    static var descriptionFont: Font { AppFont.bodySmall() }
}
