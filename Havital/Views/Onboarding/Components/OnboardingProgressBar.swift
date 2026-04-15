//
//  OnboardingProgressBar.swift
//  Havital
//
//  A full-width progress bar displayed at the top of every onboarding screen.
//  Progress only advances forward — it never retreats when the user goes back.
//

import SwiftUI

/// Thin horizontal progress bar for the onboarding flow.
///
/// - Parameter progress: A value in `0.0 ... 1.0` representing how far the user
///   has progressed. The bar animates smoothly when this value increases.
struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)

                // Filled portion
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
        .accessibilityIdentifier("OnboardingProgressBar")
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingProgressBar(progress: 0.0)
        OnboardingProgressBar(progress: 0.3)
        OnboardingProgressBar(progress: 0.5)
        OnboardingProgressBar(progress: 0.75)
        OnboardingProgressBar(progress: 1.0)
    }
    .padding()
}
