import SwiftUI

/// Personal Best 慶祝動畫視圖
struct PersonalBestCelebrationView: View {
    let update: PersonalBestUpdate
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiOpacity: Double = 0
    @State private var trophyRotation: Double = 0

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            // 主卡片
            VStack(spacing: 20) {
                // Trophy 圖標
                Image(systemName: "trophy.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(trophyRotation))
                    .shadow(color: .yellow.opacity(0.5), radius: 10)

                Text(L10n.MyAchievement.Celebration.newRecord.localized)
                    .font(AppFont.title1())
                    .fontWeight(.bold)

                VStack(spacing: 8) {
                    if let distance = RaceDistanceV2(rawValue: update.distance) {
                        Text(distance.displayName)
                            .font(AppFont.headline())
                            .foregroundColor(.secondary)
                    }

                    Text(formatTime(update.newTime))
                        .font(AppFont.systemScaled(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    if update.improvementSeconds > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.green)
                            Text(L10n.MyAchievement.Celebration.improved.localized)
                                .foregroundColor(.secondary)
                            Text(formatImprovement(update.improvementSeconds))
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .font(AppFont.bodySmall())
                    }
                }

                Button {
                    dismissWithAnimation()
                } label: {
                    Text(L10n.Common.done.localized)
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
                .padding(.top, 12)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .scaleEffect(scale)
            .opacity(opacity)

            // Confetti
            ConfettiView()
                .opacity(confettiOpacity)
        }
        .onAppear { startAnimation() }
    }

    // MARK: - Animation

    private func startAnimation() {
        // Trophy 旋轉動畫
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            trophyRotation = 15
        }

        // 卡片彈出動畫
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }

        // Confetti 延遲出現
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.5)) {
                confettiOpacity = 1.0
            }
        }

        // 5秒後自動消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            dismissWithAnimation()
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0
            confettiOpacity = 0
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

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatImprovement(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confettiParticles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .rotationEffect(.degrees(particle.rotation))
                }
            }
            .onAppear { generateConfetti(in: geometry.size) }
        }
    }

    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

        for _ in 0..<50 {
            let particle = ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...0),
                size: CGFloat.random(in: 5...15),
                color: colors.randomElement() ?? .blue,
                rotation: Double.random(in: 0...360)
            )

            confettiParticles.append(particle)

            withAnimation(.linear(duration: Double.random(in: 2...4))) {
                if let index = confettiParticles.firstIndex(where: { $0.id == particle.id }) {
                    confettiParticles[index].y = size.height + 100
                    confettiParticles[index].rotation += 720
                }
            }
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var rotation: Double
}
