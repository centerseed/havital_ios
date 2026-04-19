import XCTest
import UIKit
@testable import paceriz_dev

@MainActor
final class WorkoutShareCardViewModelTests: XCTestCase {
    private var sut: WorkoutShareCardViewModel!

    override func setUp() {
        super.setUp()
        sut = WorkoutShareCardViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testGenerateShareCardUsesBottomLayoutWhenAutoAndNoPhoto() async {
        await sut.generateShareCard(
            workout: makeWorkout(),
            workoutDetail: nil,
            userPhoto: nil
        )
        await waitUntil { self.sut.cardData != nil && self.sut.isGenerating == false }

        let cardData = try? XCTUnwrap(sut.cardData)
        XCTAssertEqual(cardData?.layoutMode, .bottom)
        XCTAssertNil(cardData?.cachedPhotoAverageColor)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isGenerating)
    }

    func testGenerateShareCardRespectsSelectedLayoutOverride() async {
        sut.selectedLayout = .top

        await sut.generateShareCard(
            workout: makeWorkout(),
            workoutDetail: nil,
            userPhoto: nil
        )
        await waitUntil { self.sut.cardData?.layoutMode == .top && self.sut.isGenerating == false }

        XCTAssertEqual(sut.cardData?.layoutMode, .top)
    }

    func testRegenerateWithLayoutRebuildsExistingCardData() async {
        await sut.generateShareCard(
            workout: makeWorkout(),
            workoutDetail: nil,
            userPhoto: nil
        )
        await waitUntil { self.sut.cardData != nil }

        await sut.regenerateWithLayout(.side)
        await waitUntil { self.sut.cardData?.layoutMode == .side && self.sut.isGenerating == false }

        XCTAssertEqual(sut.selectedLayout, .side)
        XCTAssertEqual(sut.cardData?.layoutMode, .side)
    }

    func testClearCardDataResetsState() async {
        await sut.generateShareCard(
            workout: makeWorkout(),
            workoutDetail: nil,
            userPhoto: nil
        )
        await waitUntil { self.sut.cardData != nil }
        sut.error = "something failed"
        sut.selectedLayout = .top

        sut.clearCardData()

        XCTAssertNil(sut.cardData)
        XCTAssertNil(sut.error)
        XCTAssertEqual(sut.selectedLayout, .auto)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 50_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
        XCTFail("Timed out waiting for condition")
    }

    private func makeWorkout() -> WorkoutV2 {
        WorkoutV2(
            id: "workout-1",
            provider: "garmin",
            activityType: "running",
            startTimeUtc: "2026-04-19T00:00:00Z",
            endTimeUtc: "2026-04-19T00:45:00Z",
            durationSeconds: 2700,
            distanceMeters: 10000,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: "Garmin",
            basicMetrics: BasicMetrics(avgHeartRateBpm: 150, avgPaceSPerKm: 300),
            advancedMetrics: AdvancedMetrics(trainingType: "tempo"),
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: nil
        )
    }
}
