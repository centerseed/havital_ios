import SwiftUI

/// 頂部置中版型 - 資訊區位於照片頂部,使用漸層遮罩
struct TopInfoOverlay: View {
    let data: WorkoutShareCardData
    let safeAreaInset: CGFloat = 48  // 安全區域距離

    var body: some View {
        VStack(spacing: 0) {
            // 頂部資訊區域
            VStack(alignment: .center, spacing: 12) {
                // 成就主語句
                Text(data.achievementTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(data.colorScheme.textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)

                // 核心數據
                HStack(spacing: 20) {
                    ForEach(data.workout.coreMetrics.prefix(3), id: \.self) { metric in
                        Text(metric)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(data.colorScheme.textColor)
                    }
                }

                // 鼓勵語
                Text("💬 \(data.encouragementText)")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(data.colorScheme.textColor.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // 連續訓練資訊 (可選)
                if let streakInfo = data.streakInfo {
                    Text(streakInfo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(data.colorScheme.textColor.opacity(0.8))
                }
            }
            .padding(.horizontal, safeAreaInset)
            .padding(.top, 60)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background(
                // 漸層遮罩 (由黑色漸變到透明)
                LinearGradient(
                    gradient: Gradient(colors: [
                        data.colorScheme.backgroundColor.opacity(data.colorScheme.overlayOpacity),
                        data.colorScheme.backgroundColor.opacity(data.colorScheme.overlayOpacity * 0.7),
                        data.colorScheme.backgroundColor.opacity(0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // 底部品牌標示
            HStack {
                Spacer()
                BrandingFooter(textColor: data.colorScheme.textColor.opacity(0.7))
                    .padding(.bottom, 32)
                    .padding(.horizontal, safeAreaInset)
                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        data.colorScheme.backgroundColor.opacity(0),
                        data.colorScheme.backgroundColor.opacity(data.colorScheme.overlayOpacity * 0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    TopInfoOverlay(data: WorkoutShareCardData(
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
                encouragementText: "呼吸順暢,這節奏正好。",
                streakDays: 7,
                achievementBadge: nil
            )
        ),
        workoutDetail: nil,
        userPhoto: nil,
        layoutMode: .top,
        colorScheme: .topGradient
    ))
    .frame(width: 1080, height: 1920)
    .background(Color.gray)
}
