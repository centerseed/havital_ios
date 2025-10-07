import SwiftUI

/// 底部橫條版型 - 資訊區位於照片底部,占比 25-30%
struct BottomInfoOverlay: View {
    let data: WorkoutShareCardData
    let safeAreaInset: CGFloat = 48  // 安全區域距離

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 資訊區域
            VStack(alignment: .leading, spacing: 12) {
                // 成就主語句
                Text(data.achievementTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(data.colorScheme.textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // 核心數據 (最多兩項)
                HStack(spacing: 16) {
                    ForEach(data.workout.coreMetrics.prefix(2), id: \.self) { metric in
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

                // 連續訓練資訊 (可選)
                if let streakInfo = data.streakInfo {
                    Text(streakInfo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(data.colorScheme.textColor.opacity(0.8))
                }

                // 品牌標示
                BrandingFooter(textColor: data.colorScheme.textColor.opacity(0.7))
            }
            .padding(.horizontal, safeAreaInset)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                data.colorScheme.backgroundColor
                    .opacity(data.colorScheme.overlayOpacity)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    BottomInfoOverlay(data: WorkoutShareCardData(
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
        layoutMode: .bottom,
        colorScheme: .default
    ))
    .frame(width: 1080, height: 1920)
    .background(Color.gray)
}
