//
//  OnboardingBottomCTA.swift
//  Havital
//
//  Fixed bottom CTA component shared by all onboarding screens.
//  Supports a primary action button and an optional secondary skip link.
//

import SwiftUI

/// Fixed bottom call-to-action area for onboarding screens.
///
/// Layout (top → bottom):
/// 1. `Divider` — visual separator from scroll content
/// 2. Primary CTA button — full width, accentColor when enabled, gray when disabled
/// 3. Optional skip text link — secondary colour, 14pt (bodySmall)
/// 4. Bottom spacer — `OnboardingLayout.ctaBottomPadding`
///
/// Usage:
/// ```swift
/// OnboardingBottomCTA(
///     ctaTitle: "下一步",
///     ctaEnabled: viewModel.isReady,
///     isLoading: viewModel.isLoading,
///     skipTitle: "跳過",
///     ctaAction: { viewModel.advance() },
///     skipAction: { coordinator.skip() }
/// )
/// ```
struct OnboardingBottomCTA: View {

    // MARK: - Properties

    let ctaTitle: String
    let ctaEnabled: Bool
    let isLoading: Bool

    /// Pass `nil` to hide the skip link entirely (D2 design decision).
    let skipTitle: String?

    /// Optional accessibility identifier for the CTA button (used by Maestro tests).
    let ctaAccessibilityId: String?

    let ctaAction: () -> Void

    /// Must be provided when `skipTitle` is non-nil; ignored otherwise.
    let skipAction: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            // Primary CTA button
            Button(action: ctaAction) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text(ctaTitle)
                        .font(AppFont.headline())
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!ctaEnabled || isLoading)
            // Minimum touch target height >= 44pt (HIG).
            .frame(minHeight: 44)
            .padding(.vertical, OnboardingLayout.ctaBottomPadding)
            .background(
                ctaEnabled
                    ? Color.accentColor
                    : Color.gray.opacity(0.4)
            )
            .animation(.easeInOut, value: ctaEnabled)
            .foregroundColor(.white)
            .cornerRadius(OnboardingLayout.ctaCornerRadius)
            .padding(.horizontal, OnboardingLayout.ctaHorizontalPadding)
            .accessibilityIdentifier(ctaAccessibilityId ?? "Onboarding_CTA")

            // Optional skip text link (D2: secondary text link below primary CTA)
            if let skipTitle = skipTitle, let skipAction = skipAction {
                Button(action: skipAction) {
                    Text(skipTitle)
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
                // Minimum touch target height >= 44pt (HIG).
                .frame(minHeight: 44)
            }

            Spacer().frame(height: OnboardingLayout.ctaBottomPadding)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview("Enabled with skip") {
    OnboardingBottomCTA(
        ctaTitle: "下一步",
        ctaEnabled: true,
        isLoading: false,
        skipTitle: "跳過",
        ctaAccessibilityId: "Test_CTA",
        ctaAction: {},
        skipAction: {}
    )
}

#Preview("Disabled, no skip") {
    OnboardingBottomCTA(
        ctaTitle: "下一步",
        ctaEnabled: false,
        isLoading: false,
        skipTitle: nil,
        ctaAccessibilityId: nil,
        ctaAction: {},
        skipAction: nil
    )
}

#Preview("Loading") {
    OnboardingBottomCTA(
        ctaTitle: "下一步",
        ctaEnabled: true,
        isLoading: true,
        skipTitle: nil,
        ctaAccessibilityId: nil,
        ctaAction: {},
        skipAction: nil
    )
}
