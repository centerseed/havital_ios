import SwiftUI
import XCTest
@testable import paceriz_dev

/// T-0176 驗收：把「兩張卡 × {4:5, 9:16}」四種組合真的 render 成 PNG。
///
/// 這個功能是視覺的 —— 單元測試綠燈證明不了版面沒破。這裡吐出真實圖檔（含匯出尺寸），
/// 落地 /tmp/share_card_shots/ 供人眼與截圖驗收。
@MainActor
final class ShareCardAspectSnapshotTests: XCTestCase {

    private let outDir = "/tmp/share_card_shots"

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(
            atPath: outDir, withIntermediateDirectories: true
        )
    }

    private func render(_ view: some View, size: CGSize, name: String) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2.0
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("render failed: \(name)")
        }
        let path = "\(outDir)/\(name).png"
        XCTAssertNoThrow(try data.write(to: URL(fileURLWithPath: path)))
        print("[SHARE-CARD-SHOT] \(path)  \(Int(image.size.width))x\(Int(image.size.height))")
    }

    /// 造一張有內容的假照片，才看得出縮放/裁切有沒有壞。
    private func makePhoto(width: CGFloat, height: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.systemOrange.setFill()
            // 對角條紋 → 一眼看出縮放與位移
            for i in stride(from: -Int(height), to: Int(width), by: 60) {
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: CGFloat(i), y: 0)
                ctx.cgContext.rotate(by: .pi / 6)
                ctx.fill(CGRect(x: 0, y: -height, width: 24, height: height * 3))
                ctx.cgContext.restoreGState()
            }
        }
    }

    private var recapContent: WorkoutRecapContent {
        WorkoutRecapContent(
            id: "snapshot-workout",
            date: Date(timeIntervalSince1970: 1_784_000_000),
            trainingTypeName: "Tempo Run",
            distanceText: "12.4 km",
            paceText: "5:01 /km",
            durationText: "1:02:15",
            vdot: 48.2,
            rpe: 6,
            aiAnalysis: nil,
            celebrationTitle: nil,
            encouragement: nil,
            streakDays: nil,
            isPremium: true
        )
    }

    // MARK: - 運動回顧卡

    func test_recapCard_bothAspects_withPhoto() throws {
        let photo = makePhoto(width: 1200, height: 900)

        for aspect in ShareCardAspect.allCases {
            let size = aspect.exportSize(width: 360)
            render(
                RecapShareCard(
                    content: recapContent,
                    photo: photo,
                    cornerRadius: 0,
                    photoScale: 1.0,
                    aspect: aspect
                ),
                size: size,
                name: "recap_photo_\(aspect.rawValue)"
            )
        }
    }

    func test_recapCard_zoomedPhoto_staysFullBleed() throws {
        let photo = makePhoto(width: 1200, height: 900)

        // 放大 2.5x 並推到角落 —— 夾制若壞掉，這張圖會露出卡片外的空白。
        for aspect in ShareCardAspect.allCases {
            let size = aspect.exportSize(width: 360)
            render(
                RecapShareCard(
                    content: recapContent,
                    photo: photo,
                    cornerRadius: 0,
                    photoOffset: CGSize(width: 9999, height: 9999),
                    photoScale: 2.5,
                    aspect: aspect
                ),
                size: size,
                name: "recap_zoom2.5_corner_\(aspect.rawValue)"
            )
        }
    }

    func test_recapCard_noPhoto_gradientFallback() throws {
        for aspect in ShareCardAspect.allCases {
            let size = aspect.exportSize(width: 360)
            render(
                RecapShareCard(
                    content: recapContent,
                    photo: nil,
                    cornerRadius: 0,
                    aspect: aspect
                ),
                size: size,
                name: "recap_nophoto_\(aspect.rawValue)"
            )
        }
    }

    // MARK: - 成就卡（letterbox）

    func test_achievementCard_bothAspects() throws {
        let shareable = AchievementShareable(
            materialId: "snapshot-badge",
            materialType: .badge,
            titleKey: "Season Rhythm Runner",
            summaryKey: "12 consecutive weeks of effective training rhythm",
            summaryParams: [:],
            publicFields: [
                AchievementPublicField(key: "distance", labelKey: "Distance", value: "32.4km"),
                AchievementPublicField(key: "count", labelKey: "Sessions", value: "5")
            ],
            defaultSensitiveFieldsEnabled: false,
            badgeId: "BADGE-RHYTHM-12-SEASON-RUNNER",
            chapter: .build
        )

        // 成就卡 4:5 = 既有 340×460；9:16 = 340×604（背景延伸、內容居中）
        for (aspect, size) in [
            (ShareCardAspect.portrait45, CGSize(width: 340, height: 460)),
            (ShareCardAspect.story916, CGSize(width: 340, height: 604)),
        ] {
            render(
                AchievementShareCardView(
                    shareable: shareable,
                    dateString: "2026.07.14",
                    badgeAssetName: "achievement_badge_rhythm_12_season_runner",
                    roundedCorners: false,
                    aspect: aspect
                ),
                size: size,
                name: "achievement_\(aspect.rawValue)"
            )
        }
    }
}
