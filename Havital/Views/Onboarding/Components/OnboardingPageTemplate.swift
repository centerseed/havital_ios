//
//  OnboardingPageTemplate.swift
//  Havital
//
//  Generic page template for all onboarding screens.
//  Provides consistent layout: scrollable content area + fixed bottom CTA.
//

import SwiftUI

/// Generic page template used by every onboarding screen.
///
/// Structure:
/// ```
/// VStack(spacing: 0)
/// ├─ ScrollView
/// │   └─ content()
/// │       .padding(.horizontal, 24)
/// │       .padding(.bottom, 120)   ← space for CTA overlay
/// └─ OnboardingBottomCTA
/// ```
///
/// The `NavigationStack` title display mode is forced to `.inline` so that
/// every onboarding page shares the same compact navigation bar appearance.
///
/// Usage:
/// ```swift
/// OnboardingPageTemplate(
///     ctaTitle: "下一步",
///     ctaEnabled: viewModel.canProceed,
///     isLoading: viewModel.isLoading,
///     skipTitle: nil,
///     ctaAction: { viewModel.advance() },
///     skipAction: nil
/// ) {
///     // Your page content here — no need to add horizontal padding
///     VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
///         Text("標題").font(OnboardingLayout.titleFont)
///         // …
///     }
/// }
/// ```
struct OnboardingPageTemplate<Content: View>: View {

    // MARK: - Properties

    let ctaTitle: String
    let ctaEnabled: Bool
    let isLoading: Bool

    /// Pass `nil` to hide the skip link entirely.
    let skipTitle: String?

    /// Optional accessibility identifier for the CTA button (used by Maestro tests).
    let ctaAccessibilityId: String?

    let ctaAction: () -> Void

    /// Must be provided when `skipTitle` is non-nil; ignored otherwise.
    let skipAction: (() -> Void)?

    @ViewBuilder let content: () -> Content

    /// Drives the fade-in animation on page appearance.
    @State private var isVisible = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content region
            ScrollView {
                content()
                    // Horizontal padding applied here so callers don't repeat it.
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    // Bottom padding ensures content is not obscured by the CTA.
                    .padding(.bottom, OnboardingLayout.contentBottomPadding)
            }
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: isVisible)

            // Fixed bottom CTA — always visible regardless of scroll position
            OnboardingBottomCTA(
                ctaTitle: ctaTitle,
                ctaEnabled: ctaEnabled,
                isLoading: isLoading,
                skipTitle: skipTitle,
                ctaAccessibilityId: ctaAccessibilityId,
                ctaAction: ctaAction,
                skipAction: skipAction
            )
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: isVisible)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// MARK: - Preview

#Preview("Basic page") {
    NavigationStack {
        OnboardingPageTemplate(
            ctaTitle: "下一步",
            ctaEnabled: true,
            isLoading: false,
            skipTitle: "跳過",
            ctaAccessibilityId: nil,
            ctaAction: {},
            skipAction: {}
        ) {
            VStack(alignment: .leading, spacing: OnboardingLayout.sectionSpacing) {
                Text("選擇你的目標")
                    .font(OnboardingLayout.titleFont)
                    .fontWeight(.bold)

                Text("我們會根據你的目標制定合適的訓練計劃。")
                    .font(OnboardingLayout.descriptionFont)
                    .foregroundColor(.secondary)

                ForEach(0..<6) { i in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 80)
                        .overlay(Text("選項 \(i + 1)").foregroundColor(.secondary))
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("訓練目標")
    }
}

#Preview("CTA disabled") {
    NavigationStack {
        OnboardingPageTemplate(
            ctaTitle: "下一步",
            ctaEnabled: false,
            isLoading: false,
            skipTitle: nil,
            ctaAccessibilityId: nil,
            ctaAction: {},
            skipAction: nil
        ) {
            Text("尚未選擇任何選項")
                .foregroundColor(.secondary)
                .padding(.top, 40)
        }
        .navigationTitle("選擇目標")
    }
}
