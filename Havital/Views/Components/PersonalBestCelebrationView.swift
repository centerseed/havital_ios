import SwiftUI
import UIKit

// MARK: - PB Celebration Modal

struct PersonalBestCelebrationView: View {
    let update: PersonalBestUpdate
    let onDismiss: () -> Void
    let onShare: () -> Void

    init(
        update: PersonalBestUpdate,
        onDismiss: @escaping () -> Void,
        onShare: @escaping () -> Void = {}
    ) {
        self.update = update
        self.onDismiss = onDismiss
        self.onShare = onShare
    }

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var trophyScale: CGFloat = 0.3
    @State private var trophyOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    HStack(spacing: 10) {
                        PBMomentModalTrophyMark()
                            .scaleEffect(trophyScale)
                            .opacity(trophyOpacity)

                        Text(L10n.MyAchievement.Celebration.newPB.localized)
                            .font(AppFont.systemScaled(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#B8860B"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(hex: "#FFD700").opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text(update.workoutDate)
                        .font(AppFont.captionMedium())
                        .foregroundStyle(PacerizTokens.color.text.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let distance = RaceDistanceV2(rawValue: update.distance) {
                        Text(distance.displayName)
                            .font(AppFont.title3())
                            .foregroundStyle(PacerizTokens.color.text.secondary)
                            .lineLimit(1)
                    }

                    Text(formatTime(update.newTime))
                        .font(.system(size: 76, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(PacerizTokens.color.text.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                }

                Group {
                    if update.isFirstRecord {
                        Label(L10n.MyAchievement.Celebration.firstRecord.localized, systemImage: "flag.checkered.circle.fill")
                    } else {
                        Label("\(L10n.MyAchievement.Celebration.improved.localized) \(formatImprovement(update.improvementSeconds))", systemImage: "chevron.down.circle.fill")
                    }
                }
                .font(AppFont.systemScaled(size: 18, weight: .bold))
                .foregroundStyle(update.isFirstRecord ? PacerizTokens.color.brand.primary : Color(hex: "#27AE60"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                if update.relatedUpdateCount > 0 {
                    Text(L10n.MyAchievement.Celebration.otherPBs.localized(with: update.relatedUpdateCount))
                        .font(AppFont.captionMedium())
                        .foregroundStyle(PacerizTokens.color.text.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        onShare()
                    } label: {
                        Label(L10n.MyAchievement.Celebration.share.localized, systemImage: "square.and.arrow.up")
                            .font(AppFont.bodySmall())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        dismissWithAnimation()
                    } label: {
                        Text(L10n.Common.close.localized)
                            .font(AppFont.bodySmall())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 370, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, PacerizTokens.color.brand.primary.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(PacerizTokens.color.brand.primary.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 32, y: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Animation

    private func startAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) {
            trophyScale = 1.0
            trophyOpacity = 1.0
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    // MARK: - Helper

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    private func formatImprovement(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, secs) : "\(secs)s"
    }
}

// MARK: - Modal Trophy

private struct PBMomentModalTrophyMark: View {
    @State private var pulse: CGFloat = 0.8
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FFD700").opacity(0.35))
                .frame(width: 52, height: 52)
                .scaleEffect(pulse)
                .opacity(pulseOpacity)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .shadow(color: Color(hex: "#FFD700").opacity(0.55), radius: 16, y: 6)

            Image(systemName: "trophy.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(hex: "#3D2000"))
                .offset(y: -1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = 1.5
                pulseOpacity = 0
            }
        }
    }
}

// MARK: - PB Share Card

struct PBMomentShareCardView: View {
    let update: PersonalBestUpdate

    var body: some View {
        ZStack {
            PBMomentShareCardBackground()

            VStack(spacing: 34) {
                PBMomentShareCardHeader()

                PBMomentScorePanel(
                    isFirstRecord: update.isFirstRecord,
                    distanceName: distanceName,
                    timeText: formatTime(update.newTime),
                    subtitle: subtitle
                )

                HStack(spacing: 26) {
                    PBMomentShareCardField(title: L10n.MyAchievement.Celebration.date.localized, value: update.workoutDate)
                    PBMomentShareCardField(title: previousTitle, value: previousValue)
                    PBMomentShareCardField(title: L10n.MyAchievement.Celebration.result.localized, value: formatTime(update.newTime))
                }

                HStack {
                    Text("Built with Paceriz")
                        .font(PBMomentShareTypography.metricTitle(23))
                        .foregroundStyle(Color.white.opacity(0.45))

                    Spacer()

                    Text("paceriz")
                        .font(PBMomentShareTypography.brand(30))
                        .foregroundStyle(Color(hex: "#FFD700"))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 76)
            .padding(.vertical, 70)
        }
        .frame(width: 1080, height: 1350)
        .accessibilityIdentifier("pb_only_share_card")
    }

    private var distanceName: String {
        RaceDistanceV2(rawValue: update.distance)?.displayName ?? update.distance
    }

    private var subtitle: String {
        if update.isFirstRecord {
            return L10n.MyAchievement.Celebration.firstRecord.localized
        }
        return "\(L10n.MyAchievement.Celebration.improved.localized) \(formatImprovement(update.improvementSeconds))"
    }

    private var previousTitle: String {
        update.oldTime == nil ? L10n.MyAchievement.Celebration.newPB.localized : "Previous"
    }

    private var previousValue: String {
        guard let oldTime = update.oldTime else { return L10n.MyAchievement.Celebration.firstRecord.localized }
        return formatTime(oldTime)
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    private func formatImprovement(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, secs) : "\(secs)s"
    }
}

// MARK: - Share Card Sub-views

private struct PBMomentShareCardHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            Text("Paceriz")
                .font(PBMomentShareTypography.brand(38))
                .foregroundStyle(Color(hex: "#FFD700"))

            Spacer()

            Text("RUNNING RESULT")
                .font(PBMomentShareTypography.metricTitle(24))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
        }
    }
}

private struct PBMomentScorePanel: View {
    let isFirstRecord: Bool
    let distanceName: String
    let timeText: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 38) {
            HStack(alignment: .top, spacing: 26) {
                PBMomentTrophyMark()

                VStack(alignment: .leading, spacing: 13) {
                    Text(isFirstRecord ? L10n.MyAchievement.Celebration.firstRecord.localized : "Personal Best")
                        .font(PBMomentShareTypography.chip(40))
                        .foregroundStyle(Color(hex: "#FFD700"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    Text(distanceName)
                        .font(PBMomentShareTypography.distance(70))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 84)

            Text(timeText)
                .font(PBMomentShareTypography.time(238))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.36)

            HStack(spacing: 14) {
                Image(systemName: isFirstRecord ? "flag.checkered" : "chevron.down")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(hex: "#3D2000"))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: "#FFD700"))
                    .clipShape(Circle())

                Text(subtitle)
                    .font(PBMomentShareTypography.badge(38))
                    .foregroundStyle(Color(hex: "#FFD700"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 716, alignment: .bottomLeading)
    }
}

private struct PBMomentTrophyMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD700"), Color(hex: "#FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 130, height: 130)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 5)
                .frame(width: 104, height: 104)

            Image(systemName: "trophy.fill")
                .font(.system(size: 56, weight: .black))
                .foregroundStyle(Color(hex: "#3D2000"))
                .offset(y: -1)
        }
        .shadow(color: Color(hex: "#FFD700").opacity(0.55), radius: 40, y: 20)
    }
}

private struct PBMomentShareCardBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "#0B1A3E")

            RadialGradient(
                colors: [PacerizTokens.color.brand.primary.opacity(0.4), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 700
            )

            RadialGradient(
                colors: [Color(hex: "#1a237e").opacity(0.35), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 500
            )

            PBMomentTrackLines()
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .offset(x: 40, y: 470)

            Text("PB")
                .font(PBMomentShareTypography.watermark(420))
                .foregroundStyle(Color.white.opacity(0.03))
                .offset(x: 246, y: -246)
        }
    }
}

private struct PBMomentShareCardField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(PBMomentShareTypography.metricTitle(22))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(value)
                .font(PBMomentShareTypography.metricValue(34))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Typography

private enum PBMomentShareTypography {
    static func brand(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func distance(_ size: CGFloat) -> Font { AppFont.systemScaled(size: size, weight: .black) }
    static func time(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .default) }
    static func badge(_ size: CGFloat) -> Font { AppFont.systemScaled(size: size, weight: .heavy) }
    static func chip(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func watermark(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func metricTitle(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func metricValue(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

// MARK: - Track Lines Shape

private struct PBMomentTrackLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = rect.height * 0.24
        for index in 0..<4 {
            let y = startY + CGFloat(index) * 108
            path.move(to: CGPoint(x: -80, y: y))
            path.addCurve(
                to: CGPoint(x: rect.width + 120, y: y + 430),
                control1: CGPoint(x: rect.width * 0.23, y: y - 130),
                control2: CGPoint(x: rect.width * 0.66, y: y + 560)
            )
        }
        return path
    }
}

// MARK: - Share Card Sheet

struct PBMomentShareCardSheetView: View {
    let update: PersonalBestUpdate
    let onShare: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    @State private var showActivity = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PBMomentShareCardPreview(update: update)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        Task { await shareCard() }
                    } label: {
                        Label(L10n.MyAchievement.Celebration.share.localized, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await saveCard() }
                    } label: {
                        Label(L10n.MyAchievement.Celebration.saveImage.localized, systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle(L10n.MyAchievement.Celebration.shareCardTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Common.close.localized) { dismiss() }
                }
            }
            .sheet(isPresented: $showActivity) {
                if let renderedImage {
                    ActivityViewController(activityItems: [renderedImage])
                }
            }
        }
    }

    @MainActor
    private func renderCardImage() -> UIImage? {
        let renderer = ImageRenderer(content: PBMomentShareCardView(update: update))
        renderer.scale = 1
        return renderer.uiImage
    }

    @MainActor
    private func shareCard() async {
        renderedImage = renderCardImage()
        if renderedImage != nil {
            onShare()
            showActivity = true
        }
    }

    @MainActor
    private func saveCard() async {
        guard let image = renderCardImage() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        onSave()
    }
}

// MARK: - Share Card Preview

struct PBMomentShareCardPreview: View {
    let update: PersonalBestUpdate

    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1350

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / cardWidth, proxy.size.height / cardHeight)

            PBMomentShareCardView(update: update)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: cardWidth * scale, height: cardHeight * scale, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .accessibilityIdentifier("pb_share_card_scaled_preview")
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    private let celebrationColors: [Color] = [
        PacerizTokens.color.brand.primary,
        Color(hex: "#FFD700"),
        Color(hex: "#FF8C00"),
        Color.white,
        Color.cyan,
        Color(hex: "#4CAF50"),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(particle: particle)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear { generate(in: geometry.size) }
        }
    }

    private func generate(in size: CGSize) {
        for i in 0..<60 {
            let delay = Double(i) * 0.04
            var particle = ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -200...(-20)),
                size: CGFloat.random(in: 6...14),
                color: celebrationColors.randomElement() ?? .blue,
                rotation: Double.random(in: 0...360),
                shape: ConfettiShape.allCases.randomElement() ?? .circle
            )
            particles.append(particle)

            let targetY = size.height + 120
            withAnimation(.linear(duration: Double.random(in: 2.2...4.0)).delay(delay)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].y = targetY
                    particles[index].rotation += Double.random(in: 540...1080)
                }
            }
        }
    }
}

private struct ConfettiParticleView: View {
    let particle: ConfettiParticle

    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            case .ribbon:
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: particle.size * 0.5, height: particle.size * 2)
            case .capsule:
                Capsule()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.5)
            }
        }
        .rotationEffect(.degrees(particle.rotation))
    }
}

enum ConfettiShape: CaseIterable {
    case circle, ribbon, capsule
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var rotation: Double
    let shape: ConfettiShape
}
