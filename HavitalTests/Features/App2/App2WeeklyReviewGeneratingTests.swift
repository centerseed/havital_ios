import SwiftUI
import XCTest
@testable import paceriz_dev

/// 週回顧「生成中」要有動畫（SPEC-training-hub-and-weekly-plan-lifecycle
/// AC-TRAIN-HUB-11；T-0341 使用者實機回報「很沒有感覺」）。
///
/// 釘住的是**綁定**，不是動畫本身：後端還沒把這一週的回顧交回來的那段時間裡，
/// `App2WeeklyReviewView` 的內容區必須走 `App2GeneratingView` 那一支，而不是裸的
/// `ProgressView`。所以測試在請求「還在飛」的那一刻檢查判準，不是等生成完才檢查——
/// 終態永遠是 false，只驗終態等於沒驗。
@MainActor
final class App2WeeklyReviewGeneratingTests: XCTestCase {

    private var repository: MockTrainingPlanV2Repository!

    override func setUp() {
        super.setUp()
        repository = MockTrainingPlanV2Repository()
        // `App2WeeklyReviewViewModel.generate()` 會先問 Rizo 額度，額度沒有快取時它會從
        // DI 解析 `SubscriptionRepository`。測試環境沒有那一份註冊會直接 fatalError，
        // 所以塞一個「狀態不明、額度沒用完」的樁進去——這裡驗的是等待態，不是付費閘門。
        DependencyContainer.shared.register(
            StubSubscriptionRepository(),
            forProtocol: SubscriptionRepository.self
        )
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    // MARK: - 綁定

    /// 產生週回顧的請求還在飛 ⇒ 判準為真（畫面畫的是生成動畫）。
    func test_whileGenerating_showsGeneratingAnimation() async {
        repository.weeklySummaryV2ToReturn = Self.summary()
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)

        var inFlight: Bool?
        repository.onGenerateWeeklySummary = { @MainActor in
            inFlight = App2WeeklyReviewView.showsGeneratingAnimation(
                hasProjection: viewModel.projection != nil,
                isLoading: viewModel.isLoading
            )
        }

        await viewModel.generate()

        XCTAssertEqual(repository.generateWeeklySummaryCallCount, 1, "生成請求沒送出，這一輪什麼都沒驗到")
        XCTAssertEqual(inFlight, true, "生成期間必須顯示生成動畫，不是通用 spinner")
    }

    /// 載入既有回顧的請求還在飛 ⇒ 同一個等待態。
    ///
    /// 這一頁只有一種等待：`load()` 與 `generate()` 都把 `isLoading` 翻真到 `projection`
    /// 出現為止。Android 的 `SummaryUiState.Generating` 同樣涵蓋 GET 與 POST 兩條路，
    /// 兩台不得對「在等後端給這一週的回顧」各有一套狀態。
    func test_whileLoading_showsGeneratingAnimation() async {
        repository.weeklySummaryV2ToReturn = Self.summary()
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)

        var inFlight: Bool?
        repository.onGetWeeklySummary = { @MainActor in
            inFlight = App2WeeklyReviewView.showsGeneratingAnimation(
                hasProjection: viewModel.projection != nil,
                isLoading: viewModel.isLoading
            )
        }

        await viewModel.load()

        XCTAssertEqual(repository.getWeeklySummaryCallCount, 1)
        XCTAssertEqual(inFlight, true)
    }

    /// 回顧回來之後就不是等待態了——動畫必須讓位給內容。
    func test_afterGeneration_animationIsGone() async {
        repository.weeklySummaryV2ToReturn = Self.summary()
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)

        await viewModel.generate()

        XCTAssertNotNil(viewModel.projection, "生成成功卻沒有 projection，後面的斷言會變成假綠")
        XCTAssertFalse(
            App2WeeklyReviewView.showsGeneratingAnimation(
                hasProjection: viewModel.projection != nil,
                isLoading: viewModel.isLoading
            )
        )
    }

    /// 「這一週還沒有回顧」（404）不是等待態，也不是錯誤——那一格畫的是產生鈕。
    func test_notGeneratedYet_isNotTheGeneratingState() async {
        repository.weeklySummaryV2ToReturn = nil
        // 後端對「這一週還沒產生」回 404 → `DomainError.notFound`（`HTTPError.toDomainError`）。
        repository.errorToThrow = DomainError.notFound("Weekly summary not found")
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)

        await viewModel.load()

        XCTAssertTrue(viewModel.needsGeneration)
        XCTAssertFalse(
            App2WeeklyReviewView.showsGeneratingAnimation(
                hasProjection: viewModel.projection != nil,
                isLoading: viewModel.isLoading
            )
        )
    }

    // MARK: - 真的畫出來了嗎（render 層，外審 E02／E11）

    /// **這一支才是「動畫元件被畫出來」的證明。** 上面那幾支驗的是判準的值；判準對、
    /// 但 view 的那一支接錯或被刪掉，它們照樣綠。所以這裡實際 host
    /// `App2WeeklyReviewView`（走它自己的 `@StateObject` VM → DI 的 repository，
    /// 不是測試自己捏的 VM），在請求還在飛的那一刻把畫面畫成點陣圖來看。
    ///
    /// RED 驗證（2026-08-31 實跑）：把 `content` 那一支換回裸 `ProgressView()`，
    /// 中段主色像素從數千掉到 0，這支測試失敗；換回 `App2GeneratingView` 才綠。
    func test_whileLoading_actuallyRendersTheGeneratingComponent() async throws {
        repository.weeklySummaryV2ToReturn = Self.summary()
        // view 內部自己 resolve repository，所以要從 DI 餵進去，不能只注入 VM。
        DependencyContainer.shared.register(
            repository as TrainingPlanV2Repository,
            forProtocol: TrainingPlanV2Repository.self
        )

        // 讓 GET 停在半空中，畫面才會維持在等待態夠久給我們檢查。
        let inFlight = expectation(description: "GET in flight")
        repository.onGetWeeklySummary = {
            inFlight.fulfill()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        let host = UIHostingController(
            rootView: App2WeeklyReviewView(weekOfPlan: 1, isCurrentWeek: true, onClose: {})
        )
        // 掛進 window：離屏的 hosting controller 不保證會跑完整的 layout／draw。
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        await fulfillment(of: [inFlight], timeout: 5)
        // 讓 SwiftUI 把等待態那一幀 commit 出來。
        for _ in 0..<10 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.view.layoutIfNeeded()
        }

        let blue = Self.accentBluePixelCount(in: Self.render(host))
        XCTAssertGreaterThan(
            blue, 500,
            "生成中的內容區必須畫出 App2GeneratingView（跑鞋＋進度條，主色 #1890FF）；"
                + "裸 ProgressView 是灰的，藍色像素只會有零星幾點。實測到 \(blue) 點"
        )

        window.isHidden = true
    }

    /// 把 host 的畫面真的畫成點陣圖（同 `App2RenderingTests` 的做法）。
    private static func render(_ host: UIHostingController<some View>) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: host.view.bounds.size)
        return renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }

    /// 畫面中段（動畫所在的區域）有多少點是 app2 主色 `#1890FF`。
    ///
    /// **為什麼用像素而不是 accessibility identifier**：在 unit test 的 hosting controller 上
    /// SwiftUI 根本沒有建 accessibility 樹（實測收集到的 identifier 是空陣列，連頁首標題的
    /// 都沒有），所以那條路查不到任何東西。主色是這個元件與裸 `ProgressView`（系統灰）
    /// 之間看得出來的差別，而且它正是「動畫有沒有被畫出來」的直接證據。
    private static func accentBluePixelCount(in image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let width = cgImage.width
        let height = cgImage.height
        // 只看中段：頁首與分頁切換器不在範圍內，避免它們的顏色混進來。
        let top = height / 3
        let bottom = height * 2 / 3
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var count = 0
        for y in top..<bottom {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                // #1890FF 附近：藍很高、紅很低、綠居中。
                if blue > 200, red < 90, green > 110, green < 190 { count += 1 }
            }
        }
        return count
    }

    // MARK: - 文案

    /// 動畫用的是 1.4 既有的三則週回顧文案，不是新造的一組字串。
    func test_generatingMessages_reuseTheExistingReviewCopy() {
        let messages = LoadingAnimationView.LoadingType.generateReview.messages
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(
            messages,
            [
                L10n.Training.LoadingAnimation.analyzingTrainingData.localized,
                L10n.Training.LoadingAnimation.evaluatingProgress.localized,
                L10n.Training.LoadingAnimation.preparingReview.localized
            ]
        )
        XCTAssertFalse(
            messages.contains(where: { $0.isEmpty }),
            "文案缺翻譯就退化成空白畫面，比 spinner 更糟"
        )
    }

    // MARK: - Fixtures

    private static func summary(week: Int = 5) -> WeeklySummaryV2 {
        WeeklySummaryV2(
            id: "summary-1",
            uid: "user-1",
            weeklyPlanId: "plan-1",
            trainingOverviewId: "overview-1",
            weekOfTraining: week,
            createdAt: nil,
            planContext: nil,
            trainingCompletion: TrainingCompletionV2(
                percentage: 85.0,
                plannedKm: 40.0,
                completedKm: 34.0,
                plannedSessions: 4,
                completedSessions: 3,
                evaluation: "Good week"
            ),
            trainingAnalysis: TrainingAnalysisV2(
                heartRate: nil,
                pace: nil,
                distance: nil,
                intensityDistribution: nil
            ),
            readinessSummary: nil,
            capabilityProgression: nil,
            milestoneProgress: nil,
            historicalComparison: nil,
            weeklyHighlights: WeeklyHighlightsV2(
                highlights: ["Completed long run"],
                achievements: [],
                areasForImprovement: []
            ),
            upcomingRaceEvaluation: nil,
            nextWeekAdjustments: NextWeekAdjustmentsV2(
                items: [],
                summary: "Increase volume slightly",
                methodologyConstraintsConsidered: true,
                basedOnFlags: [],
                userNlEdit: nil,
                userNlEditStatus: .none,
                userNlEditFailReason: nil
            ),
            restWeekRecommendation: nil,
            finalTrainingReview: nil,
            promptAuditId: nil,
            observations: nil,
            weeklyStory: nil
        )
    }
}

// MARK: - Stub

/// 只為了讓額度檢查有東西可解析。狀態 `.none` ⇒ 沒有 `rizoUsage` ⇒ 不算耗盡。
private final class StubSubscriptionRepository: SubscriptionRepository {
    func getStatus() async throws -> SubscriptionStatusEntity { SubscriptionStatusEntity(status: .none) }
    func refreshStatus() async throws -> SubscriptionStatusEntity { SubscriptionStatusEntity(status: .none) }
    func getCachedStatus() -> SubscriptionStatusEntity? { nil }
    func clearCache() {}
    func fetchOfferings() async throws -> [SubscriptionOfferingEntity] { [] }
    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity {
        throw NSError(domain: "Stub", code: 0)
    }
    func redeemOfferCode() async throws -> PurchaseResultEntity {
        throw NSError(domain: "Stub", code: 0)
    }
    func restorePurchases() async throws {}
}
