//
//  CompleteOnboardingUseCaseTests.swift
//  HavitalTests
//
//  Unit tests for CompleteOnboardingUseCase
//

import XCTest
@testable import paceriz_dev

final class CompleteOnboardingUseCaseTests: XCTestCase {

    // MARK: - Properties

    private var sut: CompleteOnboardingUseCase!
    private var mockRepository: MockTrainingPlanRepository!
    private var mockV2Repository: MockTrainingPlanV2Repository!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanRepository()
        mockV2Repository = MockTrainingPlanV2Repository()
        sut = CompleteOnboardingUseCase(
            trainingPlanRepository: mockRepository,
            trainingPlanV2Repository: mockV2Repository
        )
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        mockV2Repository = nil
        super.tearDown()
    }

    // MARK: - Helper

    /// Create a V1-style Input (no V2 parameters)
    private func makeV1Input(
        startFromStage: String? = nil,
        isBeginner: Bool = false,
        isReonboarding: Bool = false
    ) -> CompleteOnboardingUseCase.Input {
        CompleteOnboardingUseCase.Input(
            startFromStage: startFromStage,
            isBeginner: isBeginner,
            isReonboarding: isReonboarding,
            targetTypeId: nil,
            targetId: nil,
            methodologyId: nil,
            trainingWeeks: nil,
            availableDays: nil
        )
    }

    // MARK: - Success Cases

    func test_execute_createsWeeklyPlan_success() async throws {
        // Given
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan1
        mockRepository.weeklyPlanToReturn = expectedPlan

        let input = makeV1Input()

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan?.id, expectedPlan.id)
        XCTAssertEqual(output.wasReonboarding, false)
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_passesCorrectParameters_toRepository() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = makeV1Input(startFromStage: "stage_2", isBeginner: true)

        // When
        _ = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_handlesReonboardingMode() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = makeV1Input(isReonboarding: true)

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.wasReonboarding, true)
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_handlesBeginnerMode() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = makeV1Input(isBeginner: true)

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan?.id, TrainingPlanTestFixtures.weeklyPlan1.id)
        XCTAssertEqual(output.wasReonboarding, false)
    }

    // MARK: - Error Cases

    func test_execute_throwsError_whenPlanCreationFails() async {
        // Given
        mockRepository.errorToThrow = TrainingPlanError.noPlan

        let input = makeV1Input()

        // When / Then
        do {
            _ = try await sut.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingError)
        }
    }

    func test_execute_throwsError_whenRepositoryReturnsNil() async {
        // Given
        mockRepository.weeklyPlanToReturn = nil

        let input = makeV1Input()

        // When / Then
        do {
            _ = try await sut.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingError)
        }
    }

    // MARK: - Output Verification

    func test_execute_returnsCorrectOutput_withStartFromStage() async throws {
        // Given
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan2
        mockRepository.weeklyPlanToReturn = expectedPlan

        let input = makeV1Input(startFromStage: "advanced_stage", isReonboarding: true)

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan?.id, expectedPlan.id)
        XCTAssertEqual(output.weeklyPlan?.weekOfPlan, expectedPlan.weekOfPlan)
        XCTAssertEqual(output.wasReonboarding, true)
    }
}
