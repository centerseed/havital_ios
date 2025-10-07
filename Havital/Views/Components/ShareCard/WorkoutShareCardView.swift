import SwiftUI

/// 訓練分享卡主視圖 - 整合所有版型
struct WorkoutShareCardView: View {
    let data: WorkoutShareCardData
    let size: ShareCardSize

    var body: some View {
        ZStack {
            // 背景照片層
            if let photo = data.userPhoto {
                BackgroundPhotoLayer(photo: photo, size: size)
            } else {
                // 無照片時的預設背景
                DefaultBackgroundLayer()
            }

            // 資訊浮層 (根據版型切換)
            switch data.layoutMode {
            case .bottom:
                BottomInfoOverlay(data: data)
            case .side:
                SideInfoOverlay(data: data)
            case .top:
                TopInfoOverlay(data: data)
            case .auto:
                // Auto 模式在生成時已決定具體版型,不應到達此分支
                BottomInfoOverlay(data: data)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Background Layers

/// 背景照片層
struct BackgroundPhotoLayer: View {
    let photo: UIImage
    let size: ShareCardSize

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

/// 預設背景層 (無照片時)
struct DefaultBackgroundLayer: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.8),
                Color.purple.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview

#Preview("Bottom Layout") {
    WorkoutShareCardView(
        data: WorkoutShareCardData(
            workout: WorkoutV2(
                id: "preview-1",
                provider: "apple_health",
                activityType: "running",
                startTimeUtc: ISO8601DateFormatter().string(from: Date()),
                endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(5400)),
                durationSeconds: 5400,
                distanceMeters: 13200,
                deviceName: "Apple Watch",
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
        ),
        size: .instagram916
    )
    .previewLayout(.fixed(width: 360, height: 640))
}

#Preview("Side Layout") {
    WorkoutShareCardView(
        data: WorkoutShareCardData(
            workout: WorkoutV2(
                id: "preview-2",
                provider: "garmin",
                activityType: "running",
                startTimeUtc: ISO8601DateFormatter().string(from: Date()),
                endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                durationSeconds: 3600,
                distanceMeters: 10000,
                deviceName: "Garmin",
                basicMetrics: BasicMetrics(
                    avgPaceSPerKm: 360
                ),
                advancedMetrics: AdvancedMetrics(
                    trainingType: "tempo"
                ),
                createdAt: nil,
                schemaVersion: nil,
                storagePath: nil,
                dailyPlanSummary: nil,
                aiSummary: nil,
                shareCardContent: ShareCardContent(
                    achievementTitle: "節奏跑 60 分鐘完成!",
                    encouragementText: "今天的節奏剛剛好。",
                    streakDays: 3,
                    achievementBadge: nil
                )
            ),
            workoutDetail: nil,
            userPhoto: nil,
            layoutMode: .side,
            colorScheme: .default
        ),
        size: .instagram916
    )
    .previewLayout(.fixed(width: 360, height: 640))
}

#Preview("Top Layout") {
    WorkoutShareCardView(
        data: WorkoutShareCardData(
            workout: WorkoutV2(
                id: "preview-3",
                provider: "apple_health",
                activityType: "running",
                startTimeUtc: ISO8601DateFormatter().string(from: Date()),
                endTimeUtc: ISO8601DateFormatter().string(from: Date().addingTimeInterval(2700)),
                durationSeconds: 2700,
                distanceMeters: 8000,
                deviceName: "Apple Watch",
                basicMetrics: BasicMetrics(
                    avgPaceSPerKm: 337
                ),
                advancedMetrics: AdvancedMetrics(
                    trainingType: "easy"
                ),
                createdAt: nil,
                schemaVersion: nil,
                storagePath: nil,
                dailyPlanSummary: nil,
                aiSummary: nil,
                shareCardContent: ShareCardContent(
                    achievementTitle: "輕鬆跑 45 分鐘完成!",
                    encouragementText: "呼吸順暢,這節奏正好。",
                    streakDays: nil,
                    achievementBadge: nil
                )
            ),
            workoutDetail: nil,
            userPhoto: nil,
            layoutMode: .top,
            colorScheme: .topGradient
        ),
        size: .instagram916
    )
    .previewLayout(.fixed(width: 360, height: 640))
}
