import XCTest
@testable import paceriz_dev

/// Guardrail for goal/methodology/stage weekly-plan fixtures that the app must
/// be able to decode, map, and render without getting stuck on missing fields.
final class WeeklyPlanV2LifecycleFixtureMatrixTests: XCTestCase {

    private let partialFixtureNames: Set<String> = [
        "climate_adjusted_week"
    ]

    private struct FixtureCase {
        let name: String
        let dto: WeeklyPlanV2DTO
        let entity: WeeklyPlanV2
    }

    func test_allWeeklyPlanFixturesDecodeMapAndRemainRenderSafe() throws {
        let cases = try loadAllFixtureCases()

        XCTAssertFalse(cases.isEmpty, "WeeklyPlan fixture matrix should not be empty.")

        for fixture in cases {
            assertRenderSafeWeeklyPlan(fixture.entity, fixtureName: fixture.name)
        }
    }

    func test_currentFixtureMatrixCoversKnownLifecycleCombos() throws {
        let cases = try loadAllFixtureCases()
        let coveredPairs = Set(cases.compactMap { fixture -> String? in
            guard let methodologyId = fixture.dto.methodologyId,
                  let stageId = fixture.dto.stageId else {
                return nil
            }
            return "\(methodologyId):\(stageId)"
        })

        XCTAssertTrue(coveredPairs.contains("paceriz:base"))
        XCTAssertTrue(coveredPairs.contains("paceriz:peak"))
        XCTAssertTrue(coveredPairs.contains("polarized:build"))
        XCTAssertTrue(coveredPairs.contains("complete_10k:conversion"))
    }

    // MARK: - Plan Invariants

    private func assertRenderSafeWeeklyPlan(_ plan: WeeklyPlanV2, fixtureName: String) {
        XCTAssertFalse(plan.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, fixtureName)
        XCTAssertGreaterThanOrEqual(plan.totalDistance, 0, fixtureName)
        if !partialFixtureNames.contains(fixtureName) {
            XCTAssertEqual(plan.days.count, 7, fixtureName)
            XCTAssertEqual(plan.days.map(\.dayIndex).sorted(), Array(1...7), fixtureName)
        } else {
            XCTAssertFalse(plan.days.isEmpty, fixtureName)
            XCTAssertEqual(Set(plan.days.map(\.dayIndex)).count, plan.days.count, fixtureName)
            XCTAssertTrue(plan.days.allSatisfy { (1...7).contains($0.dayIndex) }, fixtureName)
        }

        for day in plan.days {
            assertRenderSafeDay(day, fixtureName: fixtureName)
        }
    }

    private func assertRenderSafeDay(_ day: DayDetail, fixtureName: String) {
        let context = "\(fixtureName) day \(day.dayIndex)"
        XCTAssertFalse(day.dayTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, context)
        XCTAssertFalse(day.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, context)

        if day.category == .rest || day.session == nil {
            XCTAssertNil(day.session, "\(context) rest day should not carry a trainable session.")
            return
        }

        guard let session = day.session else {
            XCTFail("\(context) trainable day is missing session.")
            return
        }

        switch session.primary {
        case .run(let run):
            XCTAssertTrue(day.category == nil || day.category == .run, context)
            assertRenderSafeRun(run, context: context)
        case .strength(let strength):
            XCTAssertTrue(day.category == nil || day.category == .strength, context)
            assertRenderSafeStrength(strength, context: context)
        case .cross(let cross):
            XCTAssertTrue(day.category == nil || day.category == .cross, context)
            assertRenderSafeCross(cross, context: context)
        }

        if let warmup = session.warmup {
            assertRenderSafeRunSegment(warmup, context: "\(context) warmup")
        }
        if let cooldown = session.cooldown {
            assertRenderSafeRunSegment(cooldown, context: "\(context) cooldown")
        }
        for supplementary in session.supplementary ?? [] {
            assertRenderSafeSupplementary(supplementary, context: context)
        }
    }

    private func assertRenderSafeRun(_ run: RunActivity, context: String) {
        XCTAssertFalse(run.runType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, context)

        let hasDistance = positive(run.distanceKm) || positive(run.distanceDisplay)
        let hasDuration = positive(run.durationMinutes) || positive(run.durationSeconds)
        let hasStructuredWorkout = run.interval != nil || !(run.segments ?? []).isEmpty
        let hasDescription = !(run.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        XCTAssertTrue(hasDistance || hasDuration || hasStructuredWorkout || hasDescription, context)

        if let interval = run.interval {
            assertRenderSafeInterval(interval, context: "\(context) interval")
        }
        for segment in run.segments ?? [] {
            assertRenderSafeRunSegment(segment, context: "\(context) segment")
        }
    }

    private func assertRenderSafeInterval(_ interval: IntervalBlock, context: String) {
        XCTAssertGreaterThan(interval.repeats, 0, context)

        let hasWorkTarget = positive(interval.workDistanceKm)
            || positive(interval.workDistanceM)
            || positive(interval.workDistanceDisplay)
            || positive(interval.workDurationMinutes)
            || !(interval.workPace ?? "").isEmpty
            || !(interval.workDescription ?? "").isEmpty
        XCTAssertTrue(hasWorkTarget, "\(context) missing work target.")

        let hasRecoveryTarget = positive(interval.recoveryDistanceKm)
            || positive(interval.recoveryDistanceM)
            || positive(interval.recoveryDurationMinutes)
            || positive(interval.recoveryDurationSeconds)
            || !(interval.recoveryPace ?? "").isEmpty
            || !(interval.recoveryDescription ?? "").isEmpty
        XCTAssertTrue(hasRecoveryTarget, "\(context) missing recovery target.")
    }

    private func assertRenderSafeRunSegment(_ segment: RunSegment, context: String) {
        let hasDistance = positive(segment.distanceKm)
            || positive(segment.distanceM)
            || positive(segment.distanceDisplay)
        let hasDuration = positive(segment.durationMinutes) || positive(segment.durationSeconds)
        let hasDescription = !(segment.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        XCTAssertTrue(hasDistance || hasDuration || hasDescription, context)
    }

    private func assertRenderSafeStrength(_ strength: StrengthActivity, context: String) {
        XCTAssertFalse(strength.strengthType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, context)
        XCTAssertTrue(positive(strength.durationMinutes) || !strength.exercises.isEmpty, context)

        for exercise in strength.exercises {
            XCTAssertFalse(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, context)
            let hasPrescription = positive(exercise.sets)
                || !(exercise.reps ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || positive(exercise.durationSeconds)
                || !(exercise.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            XCTAssertTrue(hasPrescription, "\(context) exercise \(exercise.name) missing prescription.")
        }
    }

    private func assertRenderSafeCross(_ cross: CrossActivity, context: String) {
        XCTAssertFalse(cross.crossType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, context)
        XCTAssertGreaterThan(cross.durationMinutes, 0, context)
    }

    private func assertRenderSafeSupplementary(_ supplementary: SupplementaryActivity, context: String) {
        switch supplementary {
        case .strength(let strength):
            assertRenderSafeStrength(strength, context: "\(context) supplementary strength")
        case .cross(let cross):
            assertRenderSafeCross(cross, context: "\(context) supplementary cross")
        }
    }

    // MARK: - Fixtures

    private func loadAllFixtureCases() throws -> [FixtureCase] {
        let decoder = JSONDecoder()
        return try fixtureURLs().map { url in
            let data = try Data(contentsOf: url)
            let dto = try decoder.decode(WeeklyPlanV2DTO.self, from: data)
            return FixtureCase(
                name: url.deletingPathExtension().lastPathComponent,
                dto: dto,
                entity: WeeklyPlanV2Mapper.toEntity(from: dto)
            )
        }
    }

    private func fixtureURLs() throws -> [URL] {
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let fixturesDir = testDir.appendingPathComponent("Fixtures/WeeklyPlan")
        let urls = try FileManager.default.contentsOfDirectory(
            at: fixturesDir,
            includingPropertiesForKeys: nil
        )
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func positive(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value > 0
    }

    private func positive(_ value: Int?) -> Bool {
        guard let value else { return false }
        return value > 0
    }
}
