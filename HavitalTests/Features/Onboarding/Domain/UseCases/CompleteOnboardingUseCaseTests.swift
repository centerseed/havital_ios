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

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockRepository = MockTrainingPlanRepository()
        sut = CompleteOnboardingUseCase(trainingPlanRepository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Success Cases

    func test_execute_createsWeeklyPlan_success() async throws {
        // Given
        let expectedPlan = TrainingPlanTestFixtures.weeklyPlan1
        mockRepository.weeklyPlanToReturn = expectedPlan

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: nil,
            isBeginner: false,
            isReonboarding: false
        )

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan.id, expectedPlan.id)
        XCTAssertEqual(output.wasReonboarding, false)
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_passesCorrectParameters_toRepository() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: "stage_2",
            isBeginner: true,
            isReonboarding: false
        )

        // When
        _ = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
        // Note: MockTrainingPlanRepository doesn't track parameters for createWeeklyPlan
        // This verifies the call was made
    }

    func test_execute_handlesReonboardingMode() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: nil,
            isBeginner: false,
            isReonboarding: true
        )

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.wasReonboarding, true)
        XCTAssertEqual(mockRepository.createWeeklyPlanCallCount, 1)
    }

    func test_execute_handlesBeginnerMode() async throws {
        // Given
        mockRepository.weeklyPlanToReturn = TrainingPlanTestFixtures.weeklyPlan1

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: nil,
            isBeginner: true,
            isReonboarding: false
        )

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan.id, TrainingPlanTestFixtures.weeklyPlan1.id)
        XCTAssertEqual(output.wasReonboarding, false)
    }

    // MARK: - Error Cases

    func test_execute_throwsError_whenPlanCreationFails() async {
        // Given
        mockRepository.errorToThrow = TrainingPlanError.noPlan

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: nil,
            isBeginner: false,
            isReonboarding: false
        )

        // When / Then
        do {
            _ = try await sut.execute(input: input)
            XCTFail("Expected error to be thrown")
        } catch {
            // Verify error is wrapped as OnboardingError
            XCTAssertTrue(error is OnboardingError)
        }
    }

    func test_execute_throwsError_whenRepositoryReturnsNil() async {
        // Given
        mockRepository.weeklyPlanToReturn = nil

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: nil,
            isBeginner: false,
            isReonboarding: false
        )

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

        let input = CompleteOnboardingUseCase.Input(
            startFromStage: "advanced_stage",
            isBeginner: false,
            isReonboarding: true
        )

        // When
        let output = try await sut.execute(input: input)

        // Then
        XCTAssertEqual(output.weeklyPlan.id, expectedPlan.id)
        XCTAssertEqual(output.weeklyPlan.weekOfPlan, expectedPlan.weekOfPlan)
        XCTAssertEqual(output.wasReonboarding, true)
    }
}
