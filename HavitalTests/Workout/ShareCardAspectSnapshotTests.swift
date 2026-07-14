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

    // MARK: - 三個 overlay（標題 / 配速曲線 / 路線）在 9:16 下是否還正常
    //
    // 這三個是使用者可開關、可拖曳的元件。座標是正規化的（centerX/Y × cardSize），
    // 但「座標會自動重排」不等於「畫出來沒事」——尺寸算法各自不同：
    //   route  = cardWidth / 6        → 只吃寬度，兩種比例同大小
    //   chart  = (w × wf, h × hf)     → 吃高度，9:16 會被拉高約 42%
    // 所以必須真的畫出來看，不能只信正規化這句話。

    private var canvasWithBoth: ShareCardCanvasData {
        let pace = (0..<40).map { i in
            ShareCardPaceSample(
                offsetSeconds: i * 60,
                paceSecondsPerKm: 300 + 40 * sin(Double(i) / 4.0)
            )
        }
        let route = (0..<60).map { i -> ShareCardRoutePoint in
            let t = Double(i) / 59.0
            return ShareCardRoutePoint(
                latitude: 25.03 + 0.01 * sin(t * .pi * 2),
                longitude: 121.56 + 0.014 * t
            )
        }
        return ShareCardCanvasData(paceSamples: pace, routePoints: route)
    }

    private var allOverlaysVisible: ShareCardEditorState {
        var state = ShareCardEditorState.default
        state.titleLayout.isVisible = true
        state.paceChartLayout.isVisible = true
        state.routeLayout.isVisible = true
        return state
    }

    func test_recapCard_allOverlaysVisible_bothAspects() throws {
        let photo = makePhoto(width: 1200, height: 900)

        for aspect in ShareCardAspect.allCases {
            let size = aspect.exportSize(width: 360)
            render(
                RecapShareCard(
                    content: recapContent,
                    photo: photo,
                    cornerRadius: 0,
                    photoScale: 1.0,
                    aspect: aspect,
                    canvasData: canvasWithBoth,
                    editorState: allOverlaysVisible
                ),
                size: size,
                name: "recap_overlays_\(aspect.rawValue)"
            )
        }
    }

    /// 路線是正方形且只吃寬度 → 兩種比例必須一樣大（不能因為卡變高就變形）。
    func test_routeGlyphSize_isIndependentOfAspect() {
        let w: CGFloat = 360
        XCTAssertEqual(
            ShareCardRouteMath.squareSize(cardWidth: w, scale: 1.0),
            ShareCardRouteMath.squareSize(cardWidth: w, scale: 1.0),
            accuracy: 0.0001
        )
        XCTAssertEqual(ShareCardRouteMath.squareSize(cardWidth: w, scale: 1.0), w / 6, accuracy: 0.0001)
    }

    /// 配速曲線的尺寸只吃寬度 → 兩種比例下完全一樣大，同一段配速不會在 9:16 裡看起來更陡。
    func test_paceChartSize_isIdenticalAcrossAspects() {
        let s45 = ShareCardPaceChartMath.chartSize(cardSize: ShareCardAspect.portrait45.exportSize(width: 360))
        let s916 = ShareCardPaceChartMath.chartSize(cardSize: ShareCardAspect.story916.exportSize(width: 360))

        XCTAssertEqual(s45.width, s916.width, accuracy: 0.0001)
        XCTAssertEqual(s45.height, s916.height, accuracy: 0.0001,
                       "chart height must not follow the card height, or the same run looks steeper at 9:16")

        // 4:5 的尺寸必須跟改動前一模一樣：舊式 0.12 x cardHeight（450）= 54
        XCTAssertEqual(s45.height, 54, accuracy: 0.0001, "4:5 chart size must be unchanged")
        XCTAssertEqual(s45.width, 198, accuracy: 0.0001)
    }

    /// 路線的預設位置不得與標題重疊（兩者都可見時，一打開就撞在一起）。
    func test_routeAndTitleDefaults_doNotOverlap() {
        let card = ShareCardAspect.portrait45.exportSize(width: 360)
        let route = ShareCardLayoutMath.defaultPosition(for: .routeGlyph)
        let title = ShareCardLayoutMath.defaultPosition(for: .title)

        let routeSide = ShareCardRouteMath.squareSize(cardWidth: card.width, scale: 1.0)
        let routeRect = CGRect(
            x: card.width * route.x - routeSide / 2,
            y: card.height * route.y - routeSide / 2,
            width: routeSide, height: routeSide
        )
        // 標題的命中/佔位區：寬 0.80w、高 40（同 WorkoutRecapView.titleHitSize）
        let titleRect = CGRect(
            x: card.width * title.x - card.width * 0.40,
            y: card.height * title.y - 20,
            width: card.width * 0.80, height: 40
        )
        XCTAssertFalse(routeRect.intersects(titleRect),
                       "route default \(routeRect) must not sit on top of the title \(titleRect)")
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
