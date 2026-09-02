import XCTest
@testable import paceriz_dev

/// `POST /v2/decision-chain/week/{as_of}/run` 是真 LLM：dev 實測 43.7s，票面量到的
/// 範圍是 45–130s。共用的 60s 逾時會把一次**正常的** run 判成失敗，讓規劃分頁
/// fail-open 回既有路徑——使用者看到的是「決策鏈壞了」，其實只是還沒算完。
///
/// 這一組釘住：run 拿到自己的 180s，其他每一支端點仍走共用預設（`nil` ＝ 60s）。
final class TrainingPlanV2RemoteDataSourceTimeoutTests: XCTestCase {

    private var sut: TrainingPlanV2RemoteDataSource!
    private var mockHTTPClient: MockHTTPClient!

    override func setUp() {
        super.setUp()
        mockHTTPClient = MockHTTPClient()
        sut = TrainingPlanV2RemoteDataSource(
            httpClient: mockHTTPClient,
            parser: DefaultAPIParser.shared
        )
    }

    override func tearDown() {
        mockHTTPClient.reset()
        sut = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    /// 回應解不開沒關係——請求在那之前就已經記進 history 了。
    private func requestedTimeout(forPathContaining fragment: String) -> TimeInterval? {
        guard let recorded = mockHTTPClient.requestedTimeout(forPathContaining: fragment) else {
            XCTFail("沒有發出含 \(fragment) 的請求")
            return nil
        }
        return recorded
    }

    // MARK: - run 用自己的 180s

    func test_runDecisionChainWeek_asksFor180sTimeout() async {
        _ = try? await sut.runDecisionChainWeek(asOf: "2026-09-03", weekOfTraining: 5)

        XCTAssertEqual(
            requestedTimeout(forPathContaining: "/decision-chain/week/2026-09-03/run"),
            180,
            "真 LLM 的 run 要 180s；60s 會把正常的 run 誤判成失敗"
        )
        XCTAssertEqual(TrainingPlanV2RemoteDataSource.decisionChainRunTimeout, 180)
    }

    // MARK: - 其他端點不受影響，仍是共用的 60s

    func test_decisionChainReadEndpoints_useSharedDefaultTimeout() async {
        _ = try? await sut.getDecisionChainChecklist(asOf: "2026-09-03")
        _ = try? await sut.getDecisionChainIntentCard()

        XCTAssertNil(
            mockHTTPClient.requestedTimeout(forPathContaining: "/checklist").flatMap { $0 },
            "清單是普通讀取，不指定逾時"
        )
        XCTAssertNil(
            mockHTTPClient.requestedTimeout(forPathContaining: "/intent/active").flatMap { $0 },
            "意圖卡是普通讀取，不指定逾時"
        )
    }

    func test_checklistStanceAndWeeklyPlan_useSharedDefaultTimeout() async {
        _ = try? await sut.postDecisionChainChecklistStance(
            asOf: "2026-09-03",
            itemId: "knob.weekly_km_pct@2026-09-03",
            body: DecisionChainChecklistStanceRequestDTO(status: "accepted", adjustedValue: nil)
        )
        _ = try? await sut.generateWeeklyPlan(
            weekOfTraining: 5,
            forceGenerate: nil,
            promptVersion: nil,
            methodology: nil
        )

        XCTAssertNil(
            mockHTTPClient.requestedTimeout(forPathContaining: "knob.weekly_km_pct").flatMap { $0 },
            "逐條表態是一次寫入，不指定逾時"
        )
        XCTAssertNil(
            mockHTTPClient.requestedTimeout(forPathContaining: "/v2/plan/weekly").flatMap { $0 },
            "產生課表沿用共用預設——這一票沒有改它的行為"
        )
    }

    // MARK: - 沒指定就是 60

    func test_defaultHTTPClient_resolvesNilTimeoutTo60() {
        XCTAssertEqual(DefaultHTTPClient.defaultTimeoutInterval, 60)
        XCTAssertEqual(DefaultHTTPClient.resolvedTimeout(nil), 60)
        XCTAssertEqual(DefaultHTTPClient.resolvedTimeout(180), 180)
    }
}
