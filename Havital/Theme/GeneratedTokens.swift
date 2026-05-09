// GeneratedTokens.swift
// AUTO-GENERATED — do not edit manually.
// Source: design/tokens.json (monorepo root)
// Generator: apps/ios/Havital/Scripts/generate-tokens.sh
// Regenerate: bash Scripts/generate-tokens.sh  (or Xcode Run Script Build Phase)

import SwiftUI

// MARK: - PacerizTokens

/// Cross-platform design token constants for Paceriz.
/// Every value here is derived from design/tokens.json — the single source of truth.
public enum PacerizTokens {

    // MARK: - Color

    public enum color {

        public enum brand {
            /// Primary brand color — main CTAs, active states
            public static let primary = Color(hex: "#3F86F6")
            /// Secondary brand color — success, progress accents
            public static let secondary = Color(hex: "#76C893")
            /// Accent color — highlights, badges
            public static let accent = Color(hex: "#FF7F50")
        }

        public enum semantic {
            public static let success = Color(hex: "#4CAF50")
            public static let warning = Color(hex: "#FFC107")
            public static let error = Color(hex: "#F44336")
        }

        public enum surface {
            public static let background = Color(hex: "#FFFFFF")
            public static let card = Color(hex: "#F4F4F4")
        }

        public enum text {
            public static let primary = Color(hex: "#333333")
            public static let secondary = Color(hex: "#7D7D7D")
        }

        public enum dark {
            public enum surface {
                public static let background = Color(hex: "#121212")
                public static let card = Color(hex: "#1E1E1E")
            }
            public enum text {
                public static let primary = Color(hex: "#FFFFFF")
                public static let secondary = Color(hex: "#B3B3B3")
            }
            public enum brand {
                public static let primary = Color(hex: "#3F86F6")
                public static let secondary = Color(hex: "#76C893")
            }
        }
    }

    // MARK: - Spacing

    public enum spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat  = 4
        public static let s: CGFloat   = 8
        public static let m: CGFloat   = 12
        public static let l: CGFloat   = 16
        public static let xl: CGFloat  = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
        public static let huge: CGFloat  = 40
        public static let screen: CGFloat = 48
    }

    // MARK: - Radius

    public enum radius {
        public static let none: CGFloat   = 0
        public static let xs: CGFloat     = 4
        public static let small: CGFloat  = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat  = 16
        public static let xl: CGFloat     = 20
        public static let xxl: CGFloat    = 24
        public static let full: CGFloat   = 9999
    }

    // MARK: - Elevation

    /// Shadow radius values for semantic elevation levels.
    public enum elevation {
        public static let none: CGFloat     = 0
        public static let card: CGFloat     = 2
        public static let cardSoft: CGFloat = 8
        public static let sheet: CGFloat    = 8
        public static let dialog: CGFloat   = 16
    }
}
