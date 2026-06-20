import XCTest
@testable import paceriz_dev

// MARK: - TrainingPlanV2RemoteDataSourceLangTests
//
// Verifies that V2 CONTENT-GENERATION requests carry an explicit `?lang=` query
// parameter. Backend resolves content-generation language strictly as
// `?lang=` query → user profile → default, and IGNORES the device
// `Accept-Language` header (which lies for 台/港 users whose phone system
// language is Chinese but app language is English). Sending an explicit
// `?lang=<app language>` guarantees content is generated in the app's current
// language regardless of device headers or profile-write timing.
//
// Pure READ requests must NOT carry `?lang=` (only content-generation ones).

final class TrainingPlanV2RemoteDataSourceLangTests: XCTestCase {

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

    // MARK: - Helpers

    /// The path captured for the first request whose path starts with `prefix`.
    private func capturedPath(startingWith prefix: String) -> String? {
        mockHTTPClient.requestHistory.first { $0.path.hasPrefix(prefix) }?.path
    }

    // MARK: - createOverviewForNonRace (POST /v2/plan/overview) — content generation

    func test_createOverviewForNonRace_appendsLangQuery() async {
        // Given a configured (success) response is unnecessary; we only need to
        // capture the requested path. The decode will fail, but the request is
        // still recorded in requestHistory before any response handling.
        _ = try? await sut.createOverviewForNonRace(
            targetType: "beginner",
            trainingWeeks: 8,
            availableDays: 3,
            methodologyId: nil,
            startFromStage: nil,
            intendedRaceDistanceKm: nil
        )

        // Then
        let path = capturedPath(startingWith: "/v2/plan/overview")
        XCTAssertNotNil(path, "createOverviewForNonRace should issue a /v2/plan/overview request")
        XCTAssertTrue(
            path?.contains("lang=") == true,
            "content-generation request must carry ?lang=, got: \(path ?? "nil")"
        )
        // No base query → must use `?` form
        XCTAssertTrue(
            path?.contains("?lang=") == true,
            "with no pre-existing query, lang must be appended with `?`, got: \(path ?? "nil")"
        )
    }

    // MARK: - createOverviewForRace (POST /v2/plan/overview) — content generation

    func test_createOverviewForRace_appendsLangQuery() async {
        _ = try? await sut.createOverviewForRace(
            targetId: "target_abc",
            startFromStage: nil,
            methodologyId: nil
        )

        let path = capturedPath(startingWith: "/v2/plan/overview")
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains("lang=") == true, "got: \(path ?? "nil")")
    }

    // MARK: - generateWeeklyPlan (POST /v2/plan/weekly) — content generation

    func test_generateWeeklyPlan_appendsLangQuery() async {
        _ = try? await sut.generateWeeklyPlan(
            weekOfTraining: 1,
            forceGenerate: nil,
            promptVersion: nil,
            methodology: nil
        )

        let path = capturedPath(startingWith: "/v2/plan/weekly")
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains("lang=") == true, "got: \(path ?? "nil")")
    }

    // MARK: - updateOverview (PUT /v2/plan/overview/{id}) — content generation

    func test_updateOverview_appendsLangQuery() async {
        _ = try? await sut.updateOverview(
            overviewId: "overview_001",
            startFromStage: nil,
            methodologyId: nil
        )

        let path = capturedPath(startingWith: "/v2/plan/overview/overview_001")
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains("lang=") == true, "got: \(path ?? "nil")")
    }

    // MARK: - getTargetTypes (GET /v2/target/types) — content generation

    func test_getTargetTypes_appendsLangQuery() async {
        _ = try? await sut.getTargetTypes()

        let path = capturedPath(startingWith: "/v2/target/types")
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains("?lang=") == true, "got: \(path ?? "nil")")
    }

    // MARK: - getMethodologies WITH targetType — must use `&lang=` (base query exists)

    func test_getMethodologies_withTargetType_usesAmpersandLangQuery() async {
        _ = try? await sut.getMethodologies(targetType: "race_run")

        let path = capturedPath(startingWith: "/v2/methodologies")
        XCTAssertNotNil(path)
        XCTAssertTrue(
            path?.contains("target_type=race_run") == true,
            "base target_type query must be preserved, got: \(path ?? "nil")"
        )
        XCTAssertTrue(
            path?.contains("&lang=") == true,
            "when a base query already exists, lang must be appended with `&`, got: \(path ?? "nil")"
        )
    }

    // MARK: - getMethodologies WITHOUT targetType — uses `?lang=`

    func test_getMethodologies_withoutTargetType_usesQuestionMarkLangQuery() async {
        _ = try? await sut.getMethodologies(targetType: nil)

        let path = capturedPath(startingWith: "/v2/methodologies")
        XCTAssertNotNil(path)
        XCTAssertTrue(path?.contains("?lang=") == true, "got: \(path ?? "nil")")
    }

    // MARK: - Pure READ requests must NOT carry ?lang=

    func test_getOverview_doesNotAppendLangQuery() async {
        _ = try? await sut.getOverview()

        let path = capturedPath(startingWith: "/v2/plan/overview")
        XCTAssertNotNil(path)
        XCTAssertFalse(
            path?.contains("lang=") == true,
            "pure READ getOverview must NOT carry ?lang=, got: \(path ?? "nil")"
        )
    }

    func test_getWeeklyPlan_doesNotAppendLangQuery() async {
        _ = try? await sut.getWeeklyPlan(planId: "plan_001")

        let path = capturedPath(startingWith: "/v2/plan/weekly/plan_001")
        XCTAssertNotNil(path)
        XCTAssertFalse(path?.contains("lang=") == true, "got: \(path ?? "nil")")
    }
}
