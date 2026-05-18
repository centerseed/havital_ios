#!/usr/bin/env bash
# generate-tokens.sh — Build-time code generation for Paceriz Design Tokens
#
# Reads design/tokens.json from the monorepo root and emits
# Havital/Theme/GeneratedTokens.swift with type-safe Swift constants.
#
# Usage (from apps/ios/Havital/):
#   bash Scripts/generate-tokens.sh
#
# Usage as Xcode Run Script Build Phase:
#   bash "${SRCROOT}/Scripts/generate-tokens.sh"
#
# Requirements: jq (brew install jq)
# No runtime JSON parsing — all constants are baked in at build time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MONOREPO_ROOT="$(cd "${IOS_ROOT}/../../.." && pwd)"
TOKENS_JSON="${MONOREPO_ROOT}/design/tokens.json"
OUT_FILE="${IOS_ROOT}/Havital/Theme/GeneratedTokens.swift"

if ! command -v jq &>/dev/null; then
  echo "error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

if [[ ! -f "${TOKENS_JSON}" ]]; then
  echo "error: design/tokens.json not found at ${TOKENS_JSON}" >&2
  exit 1
fi

echo "Generating ${OUT_FILE} from ${TOKENS_JSON} ..."

# ---------------------------------------------------------------------------
# Read values
# ---------------------------------------------------------------------------

# Color — brand
COLOR_BRAND_PRIMARY=$(jq -r '.color.brand.primary' "${TOKENS_JSON}")
COLOR_BRAND_SECONDARY=$(jq -r '.color.brand.secondary' "${TOKENS_JSON}")
COLOR_BRAND_ACCENT=$(jq -r '.color.brand.accent' "${TOKENS_JSON}")

# Color — semantic
COLOR_SEMANTIC_SUCCESS=$(jq -r '.color.semantic.success' "${TOKENS_JSON}")
COLOR_SEMANTIC_WARNING=$(jq -r '.color.semantic.warning' "${TOKENS_JSON}")
COLOR_SEMANTIC_ERROR=$(jq -r '.color.semantic.error' "${TOKENS_JSON}")

# Color — surface
COLOR_SURFACE_BACKGROUND=$(jq -r '.color.surface.background' "${TOKENS_JSON}")
COLOR_SURFACE_CARD=$(jq -r '.color.surface.card' "${TOKENS_JSON}")

# Color — text
COLOR_TEXT_PRIMARY=$(jq -r '.color.text.primary' "${TOKENS_JSON}")
COLOR_TEXT_SECONDARY=$(jq -r '.color.text.secondary' "${TOKENS_JSON}")

# Color — dark surface
COLOR_DARK_SURFACE_BACKGROUND=$(jq -r '.color.dark.surface.background' "${TOKENS_JSON}")
COLOR_DARK_SURFACE_CARD=$(jq -r '.color.dark.surface.card' "${TOKENS_JSON}")
COLOR_DARK_TEXT_PRIMARY=$(jq -r '.color.dark.text.primary' "${TOKENS_JSON}")
COLOR_DARK_TEXT_SECONDARY=$(jq -r '.color.dark.text.secondary' "${TOKENS_JSON}")
COLOR_DARK_BRAND_PRIMARY=$(jq -r '.color.dark.brand.primary' "${TOKENS_JSON}")
COLOR_DARK_BRAND_SECONDARY=$(jq -r '.color.dark.brand.secondary' "${TOKENS_JSON}")

# Spacing
SPACING_XXS=$(jq '.spacing.xxs' "${TOKENS_JSON}")
SPACING_XS=$(jq '.spacing.xs' "${TOKENS_JSON}")
SPACING_S=$(jq '.spacing.s' "${TOKENS_JSON}")
SPACING_M=$(jq '.spacing.m' "${TOKENS_JSON}")
SPACING_L=$(jq '.spacing.l' "${TOKENS_JSON}")
SPACING_XL=$(jq '.spacing.xl' "${TOKENS_JSON}")
SPACING_XXL=$(jq '.spacing.xxl' "${TOKENS_JSON}")
SPACING_XXXL=$(jq '.spacing.xxxl' "${TOKENS_JSON}")
SPACING_HUGE=$(jq '.spacing.huge' "${TOKENS_JSON}")
SPACING_SCREEN=$(jq '.spacing.screen' "${TOKENS_JSON}")

# Radius
RADIUS_NONE=$(jq '.radius.none' "${TOKENS_JSON}")
RADIUS_XS=$(jq '.radius.xs' "${TOKENS_JSON}")
RADIUS_SMALL=$(jq '.radius.small' "${TOKENS_JSON}")
RADIUS_MEDIUM=$(jq '.radius.medium' "${TOKENS_JSON}")
RADIUS_LARGE=$(jq '.radius.large' "${TOKENS_JSON}")
RADIUS_XL=$(jq '.radius.xl' "${TOKENS_JSON}")
RADIUS_XXL=$(jq '.radius.xxl' "${TOKENS_JSON}")
RADIUS_FULL=$(jq '.radius.full' "${TOKENS_JSON}")

# Elevation
ELEVATION_NONE=$(jq '.elevation.none' "${TOKENS_JSON}")
ELEVATION_CARD=$(jq '.elevation.card' "${TOKENS_JSON}")
ELEVATION_CARD_SOFT=$(jq '.elevation.cardSoft' "${TOKENS_JSON}")
ELEVATION_SHEET=$(jq '.elevation.sheet' "${TOKENS_JSON}")
ELEVATION_DIALOG=$(jq '.elevation.dialog' "${TOKENS_JSON}")

# Typography helpers (size / weight / lineHeight)
typo_size() { jq ".typography.${1}.size" "${TOKENS_JSON}"; }
typo_weight() { jq ".typography.${1}.weight" "${TOKENS_JSON}"; }
typo_lh() { jq ".typography.${1}.lineHeight" "${TOKENS_JSON}"; }

# ---------------------------------------------------------------------------
# Emit Swift file
# ---------------------------------------------------------------------------
cat > "${OUT_FILE}" << SWIFT_EOF
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
            public static let primary = Color(hex: "${COLOR_BRAND_PRIMARY}")
            /// Secondary brand color — success, progress accents
            public static let secondary = Color(hex: "${COLOR_BRAND_SECONDARY}")
            /// Accent color — highlights, badges
            public static let accent = Color(hex: "${COLOR_BRAND_ACCENT}")
        }

        public enum semantic {
            public static let success = Color(hex: "${COLOR_SEMANTIC_SUCCESS}")
            public static let warning = Color(hex: "${COLOR_SEMANTIC_WARNING}")
            public static let error = Color(hex: "${COLOR_SEMANTIC_ERROR}")
        }

        public enum surface {
            public static let background = Color(hex: "${COLOR_SURFACE_BACKGROUND}")
            public static let card = Color(hex: "${COLOR_SURFACE_CARD}")
        }

        public enum text {
            public static let primary = Color(hex: "${COLOR_TEXT_PRIMARY}")
            public static let secondary = Color(hex: "${COLOR_TEXT_SECONDARY}")
        }

        public enum dark {
            public enum surface {
                public static let background = Color(hex: "${COLOR_DARK_SURFACE_BACKGROUND}")
                public static let card = Color(hex: "${COLOR_DARK_SURFACE_CARD}")
            }
            public enum text {
                public static let primary = Color(hex: "${COLOR_DARK_TEXT_PRIMARY}")
                public static let secondary = Color(hex: "${COLOR_DARK_TEXT_SECONDARY}")
            }
            public enum brand {
                public static let primary = Color(hex: "${COLOR_DARK_BRAND_PRIMARY}")
                public static let secondary = Color(hex: "${COLOR_DARK_BRAND_SECONDARY}")
            }
        }
    }

    // MARK: - Spacing

    public enum spacing {
        public static let xxs: CGFloat = ${SPACING_XXS}
        public static let xs: CGFloat  = ${SPACING_XS}
        public static let s: CGFloat   = ${SPACING_S}
        public static let m: CGFloat   = ${SPACING_M}
        public static let l: CGFloat   = ${SPACING_L}
        public static let xl: CGFloat  = ${SPACING_XL}
        public static let xxl: CGFloat = ${SPACING_XXL}
        public static let xxxl: CGFloat = ${SPACING_XXXL}
        public static let huge: CGFloat  = ${SPACING_HUGE}
        public static let screen: CGFloat = ${SPACING_SCREEN}
    }

    // MARK: - Radius

    public enum radius {
        public static let none: CGFloat   = ${RADIUS_NONE}
        public static let xs: CGFloat     = ${RADIUS_XS}
        public static let small: CGFloat  = ${RADIUS_SMALL}
        public static let medium: CGFloat = ${RADIUS_MEDIUM}
        public static let large: CGFloat  = ${RADIUS_LARGE}
        public static let xl: CGFloat     = ${RADIUS_XL}
        public static let xxl: CGFloat    = ${RADIUS_XXL}
        public static let full: CGFloat   = ${RADIUS_FULL}
    }

    // MARK: - Elevation

    /// Shadow radius values for semantic elevation levels.
    public enum elevation {
        public static let none: CGFloat     = ${ELEVATION_NONE}
        public static let card: CGFloat     = ${ELEVATION_CARD}
        public static let cardSoft: CGFloat = ${ELEVATION_CARD_SOFT}
        public static let sheet: CGFloat    = ${ELEVATION_SHEET}
        public static let dialog: CGFloat   = ${ELEVATION_DIALOG}
    }
}
SWIFT_EOF

echo "Done: ${OUT_FILE}"
