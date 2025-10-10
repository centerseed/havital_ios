import SwiftUI

/// 訓練分享卡主視圖 - 整合所有版型
struct WorkoutShareCardView: View {
    let data: WorkoutShareCardData
    let size: ShareCardSize

    var body: some View {
        ZStack {
            // 黑色背景作為最底層
            Color.black
                .edgesIgnoringSafeArea(.all)

            // 背景照片層
            if let photo = data.userPhoto {
                BackgroundPhotoLayer(
                    photo: photo,
                    size: size,
                    scale: data.photoScale,
                    offset: data.photoOffset
                )
            } else {
                // 無照片時的預設背景
                DefaultBackgroundLayer()
                    .frame(width: size.width, height: size.height)
            }

            // 資訊浮層 (統一使用底部版型)
            BottomInfoOverlay(data: data)
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
    }
}

// MARK: - Background Layers

/// 背景照片層
struct BackgroundPhotoLayer: View {
    let photo: UIImage
    let size: ShareCardSize
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero

    var body: some View {
        ZStack {
            // 使用略大的黑色底色確保覆蓋所有區域
            Color.black
                .frame(width: size.width * 1.1, height: size.height * 1.1)

            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - UIImage Extension for Average Color

extension UIImage {
    /// 計算圖片的平均顏色（主色調）
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                     y: inputImage.extent.origin.y,
                                     z: inputImage.extent.size.width,
                                     w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage",
                                     parameters: [kCIInputImageKey: inputImage,
                                                kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
}

/// 預設背景層 (無照片時)
struct DefaultBackgroundLayer: View {
    var body: some View {
        // 使用 Assets 中的 share_bg 圖片作為預設背景
        if let defaultImage = UIImage(named: "share_bg") {
            Image(uiImage: defaultImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        } else {
            // 備用漸層背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.4),
                    Color(red: 0.1, green: 0.2, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
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
