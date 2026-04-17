// Havital/Views/Onboarding/OnboardingIntroView.swift
import SwiftUI

struct OnboardingIntroView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.start_setup", comment: "Start Setup"),
            ctaEnabled: true,
            isLoading: false,
            skipTitle: nil,
            ctaAccessibilityId: "OnboardingStartButton",
            ctaAction: {
                coordinator.navigate(to: .dataSource)
            },
            skipAction: nil
        ) {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Image("paceriz_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)

                    Text(NSLocalizedString("onboarding.welcome_to_paceriz", comment: "Welcome to Paceriz!"))
                        .font(AppFont.largeTitle())
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 24) {
                    Text(NSLocalizedString("onboarding.ready_to_start", comment: "Ready to start your running journey?"))
                        .font(AppFont.body())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(NSLocalizedString("onboarding.training_focus", comment: "Our training plans focus on:"))
                        .font(AppFont.headline())

                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "target",
                                   title: NSLocalizedString("onboarding.goal_oriented", comment: "Goal-Oriented"),
                                   description: NSLocalizedString("onboarding.goal_oriented_desc", comment: "Goal oriented description"))

                        featureRow(icon: "arrow.triangle.2.circlepath",
                                   title: NSLocalizedString("onboarding.progressive", comment: "Progressive Training"),
                                   description: NSLocalizedString("onboarding.progressive_desc", comment: "Progressive training description"))

                        featureRow(icon: "heart.text.square",
                                   title: NSLocalizedString("onboarding.heart_rate_guided", comment: "Heart Rate Guided"),
                                   description: NSLocalizedString("onboarding.heart_rate_guided_desc", comment: "Heart rate guided description"))
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 10)

                Text(NSLocalizedString("onboarding.setup_guide", comment: "Setup guide text"))
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("OnboardingIntro_Screen")
        .navigationBarHidden(true)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(AppFont.title3())
                .foregroundColor(.accentColor)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("**\(title)**")
                    .font(AppFont.bodySmall())
                Text(description)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingIntroView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OnboardingIntroView()
        }
    }
}
