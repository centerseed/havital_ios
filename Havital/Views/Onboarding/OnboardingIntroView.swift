// Havital/Views/Onboarding/OnboardingIntroView.swift
import SwiftUI

struct OnboardingIntroView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    @State private var showTitle = false
    @State private var showOverview = false
    @State private var pathProgress: CGFloat = 0
    @State private var showWeeklyPair = false
    @State private var showLoopBadge = false

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.start_setup", comment: "Start Setup"),
            ctaEnabled: true,
            isLoading: false,
            skipTitle: nil,
            ctaAccessibilityId: "OnboardingStartButton",
            ctaAction: {
                coordinator.navigate(to: .acquisitionChannel)
            },
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("onboarding.intro_title", comment: "How Paceriz coaches you"))
                        .font(AppFont.title1())
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(NSLocalizedString("onboarding.intro_loop_caption", comment: "Loop caption"))
                        .font(AppFont.body())
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 8)
                .padding(.top, 12)

                VStack(spacing: 0) {
                    overviewCard
                        .opacity(showOverview ? 1 : 0)
                        .offset(y: showOverview ? 0 : 10)

                    ConnectorPath(progress: pathProgress)
                        .stroke(
                            Color.accentColor.opacity(0.45),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7])
                        )
                        .frame(height: 36)

                    HStack(alignment: .center, spacing: 10) {
                        weeklyCard(
                            icon: "calendar",
                            title: NSLocalizedString("onboarding.intro_weekly_plan_title", comment: "Weekly Plan"),
                            description: NSLocalizedString("onboarding.intro_weekly_plan_desc", comment: "")
                        )
                        loopBadge
                            .opacity(showLoopBadge ? 1 : 0)
                            .scaleEffect(showLoopBadge ? 1 : 0.6)
                        weeklyCard(
                            icon: "checkmark.circle",
                            title: NSLocalizedString("onboarding.intro_weekly_review_title", comment: "Weekly Review"),
                            description: NSLocalizedString("onboarding.intro_weekly_review_desc", comment: "")
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showWeeklyPair ? 1 : 0)
                    .offset(y: showWeeklyPair ? 0 : 10)

                    Text(NSLocalizedString("onboarding.intro_cycle_label", comment: "Repeats every week"))
                        .font(AppFont.captionMedium())
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                        .padding(.top, 16)
                        .opacity(showLoopBadge ? 1 : 0)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("OnboardingIntro_Screen")
        .navigationBarHidden(true)
        .onAppear { runEntranceAnimation() }
    }

    // MARK: - Cards（沿用 app 既有卡片語言：白圓角卡 + 淡陰影 + 藍 accent icon）

    private var overviewCard: some View {
        HStack(spacing: 14) {
            iconChip("map", size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("onboarding.intro_overview_title", comment: "Training Overview"))
                    .font(AppFont.bodyStrong())
                Text(NSLocalizedString("onboarding.intro_overview_desc", comment: ""))
                    .font(AppFont.captionRegular())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(cardSurface)
    }

    private func weeklyCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            iconChip(icon, size: 40)
            Text(title)
                .font(AppFont.bodyStrong())
            Text(description)
                .font(AppFont.captionRegular())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardSurface)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private func iconChip(_ systemName: String, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(.accentColor)
        }
        .frame(width: size, height: size)
    }

    private var loopBadge: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 34, height: 34)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 6, x: 0, y: 3)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Animation

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.4)) { showTitle = true }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) { showOverview = true }
        withAnimation(.easeInOut(duration: 0.45).delay(0.55)) { pathProgress = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(0.85)) { showWeeklyPair = true }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(1.1)) { showLoopBadge = true }
    }
}

/// 訓練總覽 → 週循環 的虛線連接線（由上往下描繪）
private struct ConnectorPath: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.midX
        path.move(to: CGPoint(x: x, y: rect.minY + 4))
        path.addLine(to: CGPoint(x: x, y: rect.minY + 4 + (rect.height - 8) * progress))
        return path
    }
}

struct OnboardingIntroView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OnboardingIntroView()
        }
    }
}
