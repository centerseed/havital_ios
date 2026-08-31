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

    // MARK: - 產生視窗未開就不給那顆鈕（T-0362）

    /// **本次 P0 的端到端形狀**：週一（平日）打開**本週**回顧 → 後端 404「還沒產生」，
    /// 但 `POST /v2/summary/weekly` 平日只准產 `current_week − 1`
    /// （`core/training_rules/plan_generation_window.py:37`），所以那顆「產生週回顧」
    /// 是註定 400 的鈕。修復後 `canGenerateReview` 為 false，畫面改顯示「要等這一週跑完」。
    func test_weekdayCurrentWeekReview_hasNoGenerateButton() async {
        // **回顧 404、plan status 正常**——那正是真實組合。
        // `weeklySummaryV2ToReturn = nil` 走的是 mock 裡**照抄正式 repository**
        // 的那一格：`getWeeklySummary` 在 404 時 fallback 到 POST（計數 +1），
        // `fetchWeeklySummary` 回 nil（不計數）。所以這一支同時驗得到
        // 「載入有沒有偷偷送出生成請求」。
        //
        // 不用全域的 `errorToThrow`：那一格會連 `getPlanStatus` 也一起丟，
        // 判準就永遠落在 status 為 nil 的 fail-open 分支上（假綠）。
        repository.weeklySummaryV2ToReturn = nil
        // 2026-08-31 是週一（Asia/Taipei）——使用者實機那一天。
        repository.planStatusToReturn = Self.planStatus(
            currentWeek: 5,
            serverTime: "2026-08-31T02:00:00Z"
        )
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)

        await viewModel.load()

        XCTAssertTrue(viewModel.needsGeneration, "404 仍是『還沒產生』的空態，不是錯誤畫面")
        XCTAssertFalse(
            viewModel.canGenerateReview,
            "平日不能產本週回顧——畫面不得獻上一顆按下去必然 400 的鈕"
        )
        // **E05**：正式 repository 的 `getWeeklySummary` 在 404 時會 fallback 到
        // `POST`，所以「只是打開這一頁」就會送出那個註定 400 的請求。視窗未開時
        // 載入必須走唯讀路徑。
        XCTAssertEqual(
            repository.generateWeeklySummaryCallCount, 0,
            "視窗未開時，光是載入就不得在背後送出生成請求"
        )
    }

    /// 對照組：視窗開著時，載入仍走既有的「404 → 產生」路徑（1.4 既有流程不變）。
    /// 沒有這一支，上面那條唯讀斷言可能只是因為整條路都壞了才綠。
    func test_windowOpen_loadStillUsesGenerateFallback() async {
        repository.weeklySummaryV2ToReturn = nil
        repository.planStatusToReturn = Self.planStatus(
            currentWeek: 5,
            serverTime: "2026-08-31T02:00:00Z"
        )
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 4, repository: repository)

        await viewModel.load()

        XCTAssertEqual(
            repository.generateWeeklySummaryCallCount, 1,
            "視窗開著時載入沿用既有的 404 → 產生 fallback"
        )
    }

    /// 同一天（週一）打開**上週**回顧就是後端允許的那一週 —— 鈕照給。
    func test_weekdayPreviousWeekReview_keepsGenerateButton() async {
        repository.weeklySummaryV2ToReturn = nil
        repository.planStatusToReturn = Self.planStatus(
            currentWeek: 5,
            serverTime: "2026-08-31T02:00:00Z"
        )
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 4, repository: repository)

        await viewModel.load()

        XCTAssertTrue(viewModel.needsGeneration)
        XCTAssertTrue(viewModel.canGenerateReview, "平日的可產週次就是 current_week − 1")
    }

    /// VM 自己也不送那個請求 —— 判準不只住在畫面上。
    func test_generate_whenWindowClosed_sendsNoRequest() async {
        repository.weeklySummaryV2ToReturn = nil
        repository.planStatusToReturn = Self.planStatus(
            currentWeek: 5,
            serverTime: "2026-08-31T02:00:00Z"
        )
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)
        await viewModel.load()

        await viewModel.generate()

        XCTAssertEqual(
            repository.generateWeeklySummaryCallCount, 0,
            "視窗未開時不得送出註定 400 的生成請求"
        )
    }

    /// 後端週日的 `server_time` → 本週回顧就是這一天要做的事，鈕在。
    func test_sundayCurrentWeekReview_keepsGenerateButton() async {
        repository.weeklySummaryV2ToReturn = nil
        // 2026-08-30 是週日（Asia/Taipei）。
        repository.planStatusToReturn = Self.planStatus(
            currentWeek: 5,
            serverTime: "2026-08-30T02:00:00Z"
        )
        let viewModel = App2WeeklyReviewViewModel(weekOfPlan: 5, repository: repository)

        await viewModel.load()

        XCTAssertTrue(viewModel.canGenerateReview)
    }

    // MARK: - 畫面層（E11：判準對、但 view 沒接上，上面那些照樣綠）

    /// 三格空態的**畫面契約**：那句話、那顆鈕在不在、identifier 是哪一個。
    /// 同 `showsGeneratingAnimation` 的做法——具名判準，view 直接用它。
    func test_emptyState_contractForEachOfTheThreeCases() {
        // 唯讀回看
        XCTAssertEqual(
            App2WeeklyReviewView.emptyStateBody(isReadOnly: true, canGenerate: false),
            L10n.App2.WeeklyReview.historyNotGeneratedBody.localized
        )
        XCTAssertFalse(App2WeeklyReviewView.showsGenerateButton(isReadOnly: true, canGenerate: false))
        XCTAssertEqual(
            App2WeeklyReviewView.emptyStateIdentifier(isReadOnly: true, canGenerate: false),
            "App2_WeeklyReviewNotGenerated"
        )

        // 可以產生
        XCTAssertEqual(
            App2WeeklyReviewView.emptyStateBody(isReadOnly: false, canGenerate: true),
            L10n.App2.WeeklyReview.notGeneratedBody.localized
        )
        XCTAssertTrue(App2WeeklyReviewView.showsGenerateButton(isReadOnly: false, canGenerate: true))
        XCTAssertEqual(
            App2WeeklyReviewView.emptyStateIdentifier(isReadOnly: false, canGenerate: true),
            "App2_WeeklyReviewNotGenerated"
        )

        // 產生視窗未開（T-0362）
        XCTAssertEqual(
            App2WeeklyReviewView.emptyStateBody(isReadOnly: false, canGenerate: false),
            L10n.App2.WeeklyReview.generationWindowClosed.localized,
            "視窗未開要說得出『什麼時候才能產生』"
        )
        XCTAssertFalse(
            App2WeeklyReviewView.showsGenerateButton(isReadOnly: false, canGenerate: false),
            "視窗未開不得畫產生鈕"
        )
        XCTAssertEqual(
            App2WeeklyReviewView.emptyStateIdentifier(isReadOnly: false, canGenerate: false),
            "App2_WeeklyReviewWindowClosed"
        )
    }

    /// 週日與否**只看後端給的 `server_time` ＋ `user_timezone`**，不看裝置星期
    /// （設計 §A.1／§A.5）。這裡的 `can_generate_next_week` 是 false（例如已是最後一週），
    /// 所以判定完全落在 metadata 那條路上。
    private static func planStatus(
        currentWeek: Int,
        serverTime: String
    ) -> PlanStatusV2Response {
        PlanStatusV2Response(
            currentWeek: currentWeek,
            totalWeeks: 22,
            nextAction: "view_plan",
            canGenerateNextWeek: false,
            currentWeekPlanId: "ov_\(currentWeek)",
            previousWeekSummaryId: nil,
            targetType: "race",
            methodologyId: "paceriz",
            nextWeekInfo: nil,
            metadata: PlanStatusV2Metadata(
                trainingStartDate: nil,
                currentWeekStartDate: nil,
                currentWeekEndDate: nil,
                userTimezone: "Asia/Taipei",
                serverTime: serverTime
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
