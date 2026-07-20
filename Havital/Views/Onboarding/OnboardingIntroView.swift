// Havital/Views/Onboarding/OnboardingIntroView.swift
import SwiftUI

struct OnboardingIntroView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    @State private var showTitle = false
    @State private var showOverview = false
    @State private var pathProgress: CGFloat = 0
    @State private var showWeeklyPair = false
    @State private var ringProgress: CGFloat = 0
    @State private var showCycleChip = false

    private let blueDeep = Color(red: 0.05, green: 0.45, blue: 0.95)
    private let blueLight = Color(red: 0.35, green: 0.66, blue: 1.0)

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
            VStack(alignment: .leading, spacing: 28) {
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

                diagram
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("OnboardingIntro_Screen")
        .navigationBarHidden(true)
        .onAppear { runEntranceAnimation() }
    }

    // MARK: - Diagram

    private var diagram: some View {
        VStack(spacing: 0) {
            overviewCard
                .opacity(showOverview ? 1 : 0)
                .offset(y: showOverview ? 0 : 12)

            CurvedConnector(progress: pathProgress)
                .stroke(
                    LinearGradient(colors: [blueDeep, blueLight], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [0.5, 8])
                )
                .frame(height: 44)
                .padding(.horizontal, 40)

            weeklyLoop
                .opacity(showWeeklyPair ? 1 : 0)
                .offset(y: showWeeklyPair ? 0 : 12)

            Text(NSLocalizedString("onboarding.intro_cycle_label", comment: "Repeats every week"))
                .font(AppFont.captionMedium())
                .foregroundColor(.white)
                .padding(.vertical, 7)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [blueDeep, blueLight], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: blueDeep.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .opacity(showCycleChip ? 1 : 0)
                .scaleEffect(showCycleChip ? 1 : 0.8)

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "waveform.path.ecg",
                           text: NSLocalizedString("onboarding.intro_feature_data", comment: "Data feature"))
                featureRow(icon: "bubble.left.and.text.bubble.right.fill",
                           text: NSLocalizedString("onboarding.intro_feature_rizo", comment: "Rizo feature"))
            }
            .padding(.top, 24)
            .opacity(showCycleChip ? 1 : 0)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(blueDeep)
                .frame(width: 22)
            Text(text)
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overviewCard: some View {
        HStack(spacing: 14) {
            gradientIcon("map.fill", size: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("onboarding.intro_overview_title", comment: "Training Overview"))
                    .font(AppFont.titleM())
                Text(NSLocalizedString("onboarding.intro_overview_desc", comment: ""))
                    .font(AppFont.captionRegular())
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            LinearGradient(
                                colors: [blueDeep.opacity(0.25), blueLight.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: blueDeep.opacity(0.12), radius: 14, x: 0, y: 6)
        )
    }

    /// 週課表 ⇄ 週回顧：兩張卡被一圈虛線循環環繞（環會描繪出現）
    private var weeklyLoop: some View {
        ZStack {
            CycleRing(progress: ringProgress)
                .stroke(
                    LinearGradient(colors: [blueDeep, blueLight], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 7])
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 18)

            HStack(alignment: .center, spacing: 44) {
                weeklyCard(
                    icon: "calendar",
                    title: NSLocalizedString("onboarding.intro_weekly_plan_title", comment: "Weekly Plan"),
                    description: NSLocalizedString("onboarding.intro_weekly_plan_desc", comment: "")
                )
                weeklyCard(
                    icon: "checkmark.seal.fill",
                    title: NSLocalizedString("onboarding.intro_weekly_review_title", comment: "Weekly Review"),
                    description: NSLocalizedString("onboarding.intro_weekly_review_desc", comment: "")
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 34)

            VStack {
                cycleArrow(pointingRight: true)
                Spacer()
                cycleArrow(pointingRight: false)
            }
            .padding(.vertical, 10)
            .opacity(showCycleChip ? 1 : 0)
        }
    }

    private func weeklyCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .center, spacing: 10) {
            gradientIcon(icon, size: 44)
            Text(title)
                .font(AppFont.bodyStrong())
            Text(description)
                .font(AppFont.captionRegular())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: blueDeep.opacity(0.1), radius: 12, x: 0, y: 5)
        )
    }

    private func gradientIcon(_ systemName: String, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(
                    LinearGradient(colors: [blueDeep, blueLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: blueDeep.opacity(0.35), radius: 7, x: 0, y: 4)
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private func cycleArrow(pointingRight: Bool) -> some View {
        Image(systemName: pointingRight ? "chevron.right" : "chevron.left")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(blueDeep)
            .padding(5)
            .background(Circle().fill(Color(.systemGroupedBackground)))
    }

    // MARK: - Animation

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.4)) { showTitle = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.2)) { showOverview = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.55)) { pathProgress = 1 }
        withAnimation(.easeOut(duration: 0.45).delay(0.9)) { showWeeklyPair = true }
        withAnimation(.easeInOut(duration: 0.8).delay(1.2)) { ringProgress = 1 }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7).delay(1.7)) { showCycleChip = true }
    }
}

/// 總覽 → 週循環 的 S 型虛線（由上往下描繪）
private struct CurvedConnector: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 30, y: rect.minY + 2))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY - 2),
            control1: CGPoint(x: rect.midX + 55, y: rect.minY + rect.height * 0.35),
            control2: CGPoint(x: rect.midX - 55, y: rect.minY + rect.height * 0.7)
        )
        return path.trimmedPath(from: 0, to: progress)
    }
}

/// 環繞兩張週卡的循環虛線環（順時針描繪）
private struct CycleRing: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let path = Path(ellipseIn: rect)
        return path.trimmedPath(from: 0, to: progress)
    }
}

struct OnboardingIntroView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OnboardingIntroView()
        }
    }
}
