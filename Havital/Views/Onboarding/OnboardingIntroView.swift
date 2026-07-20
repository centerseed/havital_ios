// Havital/Views/Onboarding/OnboardingIntroView.swift
import SwiftUI

struct OnboardingIntroView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    @State private var showTitle = false
    @State private var showOverview = false
    @State private var pathProgress: CGFloat = 0
    @State private var showWeeklyPair = false
    @State private var showLoopArrows = false
    @State private var showCaption = false

    private let slateTop = Color(red: 0x3D / 255, green: 0x46 / 255, blue: 0x63 / 255)
    private let slateBottom = Color(red: 0x52 / 255, green: 0x5C / 255, blue: 0x7F / 255)

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
            VStack(alignment: .leading, spacing: 20) {
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

                blueprintPanel
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("OnboardingIntro_Screen")
        .navigationBarHidden(true)
        .onAppear { runEntranceAnimation() }
    }

    // MARK: - Blueprint panel (signature element)

    private var blueprintPanel: some View {
        VStack(spacing: 0) {
            overviewNode
                .opacity(showOverview ? 1 : 0)
                .offset(y: showOverview ? 0 : 10)

            ConnectorPath(progress: pathProgress)
                .stroke(
                    Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7])
                )
                .frame(height: 40)

            HStack(alignment: .center, spacing: 10) {
                weeklyNode(
                    icon: "calendar",
                    title: NSLocalizedString("onboarding.intro_weekly_plan_title", comment: "Weekly Plan"),
                    description: NSLocalizedString("onboarding.intro_weekly_plan_desc", comment: "")
                )
                loopArrows
                    .opacity(showLoopArrows ? 1 : 0)
                weeklyNode(
                    icon: "arrow.uturn.backward",
                    title: NSLocalizedString("onboarding.intro_weekly_review_title", comment: "Weekly Review"),
                    description: NSLocalizedString("onboarding.intro_weekly_review_desc", comment: "")
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(showWeeklyPair ? 1 : 0)
            .offset(y: showWeeklyPair ? 0 : 10)

            Text(NSLocalizedString("onboarding.intro_cycle_label", comment: "Repeats every week"))
                .font(AppFont.micro())
                .foregroundColor(.white.opacity(0.8))
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(
                    Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 16)
                .opacity(showLoopArrows ? 1 : 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                LinearGradient(
                    colors: [slateTop, slateBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // 細緻的等高線紋理感：右上一圈大而淡的圓弧
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 40)
                    .frame(width: 340, height: 340)
                    .offset(x: 130, y: -140)
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 24)
                    .frame(width: 200, height: 200)
                    .offset(x: -150, y: 170)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .shadow(color: slateTop.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    private var overviewNode: some View {
        HStack(spacing: 14) {
            nodeIcon("map", size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("onboarding.intro_overview_title", comment: "Training Overview"))
                    .font(AppFont.bodyStrong())
                    .foregroundColor(.white)
                Text(NSLocalizedString("onboarding.intro_overview_desc", comment: ""))
                    .font(AppFont.captionRegular())
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(glassCard)
    }

    private func weeklyNode(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            nodeIcon(icon, size: 38)
            Text(title)
                .font(AppFont.bodyStrong())
                .foregroundColor(.white)
            Text(description)
                .font(AppFont.captionRegular())
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(glassCard)
    }

    private func nodeIcon(_ systemName: String, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(Color.white.opacity(0.22))
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.13))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }

    private var loopArrows: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 34, height: 34)
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
        withAnimation(.easeOut(duration: 0.35).delay(1.15)) { showLoopArrows = true }
        withAnimation(.easeOut(duration: 0.35).delay(1.3)) { showCaption = true }
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
