import XCTest
@testable import paceriz_dev

final class ShareCardModelsTests: XCTestCase {
    func testAchievementTitleUsesCustomValueEvenWhenEmpty() {
        var data = makeShareCardData(
            trainingType: "long_run",
            shareCardContent: ShareCardContent(
                achievementTitle: "API Title",
                encouragementText: "API Encouragement",
                streakDays: 3,
                achievementBadge: nil
            )
        )
        data.customAchievementTitle = ""

        XCTAssertEqual(data.achievementTitle, "")
    }

    func testAchievementTitleFallsBackToAPIThenLocalGeneration() {
        let apiBacked = makeShareCardData(
            trainingType: "tempo",
            shareCardContent: ShareCardContent(
                achievementTitle: "節奏跑完成",
                encouragementText: nil,
                streakDays: nil,
                achievementBadge: nil
            )
        )
        XCTAssertEqual(apiBacked.achievementTitle, "節奏跑完成")

        let local = makeShareCardData(trainingType: "long_run", shareCardContent: nil)
        XCTAssertEqual(local.achievementTitle, "LSD 45:00 完成!")
    }

    func testEncouragementTextUsesCustomValueAndOtherwiseFallsBackToKnownLocalCopy() {
        var custom = makeShareCardData(trainingType: "easy", shareCardContent: nil)
        custom.customEncouragementText = ""
        XCTAssertEqual(custom.encouragementText, "")

        let apiBacked = makeShareCardData(
            trainingType: "easy",
            shareCardContent: ShareCardContent(
                achievementTitle: nil,
                encouragementText: "今天的節奏剛剛好。",
                streakDays: nil,
                achievementBadge: nil
            )
        )
        XCTAssertEqual(apiBacked.encouragementText, "今天的節奏剛剛好。")

        let local = makeShareCardData(trainingType: "easy", shareCardContent: nil)
        XCTAssertTrue(Self.localEncouragements.contains(local.encouragementText))
    }

    func testStreakInfoReturnsNilForNonPositiveValues() {
        let noStreak = makeShareCardData(
            trainingType: "easy",
            shareCardContent: ShareCardContent(
                achievementTitle: nil,
                encouragementText: nil,
                streakDays: 0,
                achievementBadge: nil
            )
        )
        XCTAssertNil(noStreak.streakInfo)

        let withStreak = makeShareCardData(
            trainingType: "easy",
            shareCardContent: ShareCardContent(
                achievementTitle: nil,
                encouragementText: nil,
                streakDays: 5,
                achievementBadge: nil
            )
        )
        XCTAssertEqual(withStreak.streakInfo, "🏅 連續訓練 5 天")
    }

    func testWorkoutShareCardFormattingBuildsCoreMetrics() {
        let workout = makeWorkout(trainingType: "tempo", shareCardContent: nil)

        XCTAssertEqual(workout.formattedDistance, "10.0 km")
        XCTAssertEqual(workout.formattedDuration, "45:00")
        XCTAssertEqual(workout.coreMetrics, ["10.0 km", "45:00"])
        XCTAssertEqual(workout.avgHeartRateString, "150 bpm")
    }

    private func makeShareCardData(
        trainingType: String,
        shareCardContent: ShareCardContent?
    ) -> WorkoutShareCardData {
        WorkoutShareCardData(
            workout: makeWorkout(trainingType: trainingType, shareCardContent: shareCardContent),
            workoutDetail: nil,
            userPhoto: nil,
            layoutMode: .bottom,
            colorScheme: .default
        )
    }

    private func makeWorkout(
        trainingType: String,
        shareCardContent: ShareCardContent?
    ) -> WorkoutV2 {
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
            advancedMetrics: AdvancedMetrics(trainingType: trainingType),
            createdAt: nil,
            schemaVersion: nil,
            storagePath: nil,
            dailyPlanSummary: nil,
            aiSummary: nil,
            shareCardContent: shareCardContent
        )
    }

    private static let localEncouragements: Set<String> = [
        "配速穩定,進步正在累積。",
        "今天的節奏剛剛好。",
        "呼吸順暢,這節奏正好。",
        "保持這個步調,持續進步!",
        "穩健的步伐,踏實的進步。"
    ]
}
