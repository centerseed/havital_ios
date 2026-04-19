import XCTest
@testable import paceriz_dev

// MARK: - TrainingPlanV2RemoteDataSourceTests

final class TrainingPlanV2RemoteDataSourceTests: XCTestCase {

    // MARK: - Properties

    private var sut: TrainingPlanV2RemoteDataSource!
    private var mockHTTPClient: MockHTTPClient!

    // MARK: - Setup & Teardown

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

    // MARK: - getPlanStatus Tests

    func test_getPlanStatus_success_returnsResponse() async throws {
        // Given
        let json = planStatusJSON()
        mockHTTPClient.setResponse(for: "/v2/plan/status", method: .GET, data: json)

        // When
        let result = try await sut.getPlanStatus()

        // Then
        XCTAssertEqual(result.currentWeek, 3)
        XCTAssertEqual(result.totalWeeks, 12)
        XCTAssertEqual(result.nextAction, "view_plan")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/plan/status", method: .GET))
    }

    func test_getPlanStatus_networkError_throwsError() async {
        // Given
        mockHTTPClient.setError(for: "/v2/plan/status", method: .GET, error: HTTPError.noConnection)

        // When / Then
        do {
            _ = try await sut.getPlanStatus()
            XCTFail("Should have thrown network error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - getTargetTypes Tests

    func test_getTargetTypes_success_usesDTOAndReturnsEntities() async throws {
        // Given
        let json = targetTypesJSON()
        mockHTTPClient.setResponse(for: "/v2/target/types", method: .GET, data: json)

        // When
        let result = try await sut.getTargetTypes()

        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, "race_run")
        XCTAssertEqual(result[1].id, "beginner")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/target/types", method: .GET))
    }

    func test_getTargetTypes_emptyList_returnsEmptyEntities() async throws {
        // Given
        let json = Data("""
        { "target_types": [] }
        """.utf8)
        mockHTTPClient.setResponse(for: "/v2/target/types", method: .GET, data: json)

        // When
        let result = try await sut.getTargetTypes()

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - getMethodologies Tests

    func test_getMethodologies_success_usesDTOAndReturnsEntities() async throws {
        // Given
        let json = methodologiesJSON()
        mockHTTPClient.setResponse(for: "/v2/methodologies", method: .GET, data: json)

        // When
        let result = try await sut.getMethodologies(targetType: nil)

        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, "paceriz")
        XCTAssertEqual(result[1].id, "polarized")
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/methodologies", method: .GET))
    }

    func test_getMethodologies_withTargetType_buildsCorrectPath() async throws {
        // Given
        let json = methodologiesJSON()
        mockHTTPClient.setResponse(for: "/v2/methodologies?target_type=race_run", method: .GET, data: json)

        // When
        let result = try await sut.getMethodologies(targetType: "race_run")

        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(
            mockHTTPClient.wasPathCalled("/v2/methodologies?target_type=race_run", method: .GET),
            "Path must include ?target_type= query parameter"
        )
    }

    // MARK: - getOverview Tests

    func test_getOverview_success_returnsPlanOverviewV2DTO() async throws {
        // Given
        let json = overviewJSON()
        mockHTTPClient.setResponse(for: "/v2/plan/overview", method: .GET, data: json)

        // When
        let result = try await sut.getOverview()

        // Then
        XCTAssertEqual(result.id, "overview_001")
        XCTAssertEqual(result.targetType, "race_run")
        XCTAssertEqual(result.totalWeeks, 16)
        XCTAssertTrue(mockHTTPClient.wasPathCalled("/v2/plan/overview", method: .GET))
    }

    // MARK: - generateWeeklyPlan Tests

    func test_generateWeeklyPlan_networkError_throwsError() async {
        // Given
        mockHTTPClient.setError(
            for: "/v2/plan/weekly",
            method: .POST,
            error: HTTPError.serverError(500, "Internal server error")
        )

        // When / Then
        do {
            _ = try await sut.generateWeeklyPlan(
                weekOfTraining: 1,
                forceGenerate: nil,
                promptVersion: nil,
                methodology: nil
            )
            XCTFail("Should have thrown server error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - JSON Fixtures

private extension TrainingPlanV2RemoteDataSourceTests {

    func planStatusJSON() -> Data {
        Data("""
        {
            "current_week": 3,
            "total_weeks": 12,
            "next_action": "view_plan",
            "can_generate_next_week": false,
            "current_week_plan_id": "plan_001_3",
            "previous_week_summary_id": null,
            "target_type": "race_run",
            "methodology_id": "paceriz",
            "next_week_info": null,
            "metadata": null
        }
        """.utf8)
    }

    func targetTypesJSON() -> Data {
        Data("""
        {
            "target_types": [
                {
                    "id": "race_run",
                    "name": "Race Run",
                    "description": "Training for a race event",
                    "default_methodology": "paceriz",
                    "available_methodologies": ["paceriz", "polarized", "hansons"]
                },
                {
                    "id": "beginner",
                    "name": "Beginner",
                    "description": "New to running",
                    "default_methodology": "aerobic_endurance",
                    "available_methodologies": ["aerobic_endurance", "balanced_fitness"]
                }
            ]
        }
        """.utf8)
    }

    func methodologiesJSON() -> Data {
        Data("""
        {
            "methodologies": [
                {
                    "id": "paceriz",
                    "name": "Paceriz Method",
                    "description": "Balanced training",
                    "target_types": ["race_run"],
                    "phases": ["base", "build", "peak", "taper"],
                    "cross_training_enabled": true
                },
                {
                    "id": "polarized",
                    "name": "Polarized",
                    "description": "High-low intensity split",
                    "target_types": ["race_run", "maintenance"],
                    "phases": ["base", "build"],
                    "cross_training_enabled": false
                }
            ]
        }
        """.utf8)
    }

    func overviewJSON() -> Data {
        Data("""
        {
            "id": "overview_001",
            "target_id": "target_abc",
            "target_type": "race_run",
            "target_description": null,
            "methodology_id": "paceriz",
            "total_weeks": 16,
            "start_from_stage": "base",
            "race_date": 1800000000,
            "distance_km": 42.195,
            "distance_km_display": null,
            "distance_unit": null,
            "target_pace": "5:30",
            "target_time": null,
            "is_main_race": true,
            "target_name": "Tokyo Marathon",
            "methodology_overview": null,
            "target_evaluate": null,
            "approach_summary": null,
            "training_stages": [],
            "milestones": [],
            "created_at": null,
            "methodology_version": null,
            "milestone_basis": null
        }
        """.utf8)
    }
}
