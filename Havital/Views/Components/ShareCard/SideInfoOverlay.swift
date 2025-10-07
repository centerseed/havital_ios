import SwiftUI

/// 側邊浮層版型 - 資訊區位於照片側邊,占比約 35%
struct SideInfoOverlay: View {
    let data: WorkoutShareCardData
    let safeAreaInset: CGFloat = 48  // 安全區域距離
    let overlayWidthRatio: CGFloat = 0.35  // 浮層寬度占比

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()

                // 側邊資訊浮層
                VStack(alignment: .leading, spacing: 12) {
                    Spacer()

                    // 成就主語句
                    Text(data.achievementTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(data.colorScheme.textColor)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)

                    // 核心數據
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(data.workout.coreMetrics.prefix(2), id: \.self) { metric in
                            Text(metric)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(data.colorScheme.textColor)
                        }
                    }

                    // 鼓勵語
                    Text("💬 \(data.encouragementText)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(data.colorScheme.textColor.opacity(0.9))
                        .lineLimit(3)

                    // 連續訓練資訊 (可選)
                    if let streakInfo = data.streakInfo {
                        Text(streakInfo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(data.colorScheme.textColor.opacity(0.8))
                    }

                    Spacer()

                    // 品牌標示
                    BrandingFooter(textColor: data.colorScheme.textColor.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(width: geometry.size.width * overlayWidthRatio)
                .background(
                    ZStack {
                        // 模糊背景
                        data.colorScheme.backgroundColor
                            .opacity(data.colorScheme.overlayOpacity)

                        // 毛玻璃效果 (backdrop blur)
                        BlurView(style: .systemUltraThinMaterialDark)
                            .opacity(0.5)
                    }
                )
            }
        }
    }
}

/// UIKit 毛玻璃效果包裝
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Preview

#Preview {
    SideInfoOverlay(data: WorkoutShareCardData(
        workout: WorkoutV2(
            id: "preview-1",
            provider: "Garmin",
            activityType: "running",
            startTimeUtc: ISO8601DateFormatter().string(from: Date()),
            endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(5400)),
            durationSeconds: 5400,
            distanceMeters: 13200,
            deviceName: "Garmin",
            basicMetrics: BasicMetrics(
                avgPaceSPerKm: 392
            ),
            advancedMetrics: AdvancedMetrics(
                trainingType: "long_run"
            ),
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: ShareCardContent(
                achievementTitle: "LSD 90 分鐘完成!",
                encouragementText: "配速穩定,進步正在累積。",
                streakDays: 7,
                achievementBadge: nil
            )
        ),
        workoutDetail: nil,
        userPhoto: nil,
        layoutMode: .side,
        colorScheme: .default
    ))
    .frame(width: 1080, height: 1920)
    .background(Color.gray)
}
