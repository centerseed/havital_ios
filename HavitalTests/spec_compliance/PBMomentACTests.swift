import XCTest

final class PBMomentACTests: XCTestCase {
    private let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func read(_ relativePath: String) throws -> String {
        let url = projectRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertContains(_ haystack: String, _ needle: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(haystack.contains(needle), "Missing expected source fragment: \(needle)", file: file, line: line)
    }

    func test_ac_pbm_01_standardDistancePBRefreshIsDetected() throws {
        let model = try read("Havital/Models/PersonalBestCelebration.swift")
        let repo = try read("Havital/Features/UserProfile/Data/Repositories/UserProfileRepositoryImpl.swift")

        ["1.6", "3", "5", "10", "21", "42"].forEach { assertContains(model, "case", line: #line); assertContains(model, $0, line: #line) }
        assertContains(repo, "newBest.completeTime < oldBest.completeTime")
        assertContains(repo, "workoutId: newBest.workoutId")
    }

    func test_ac_pbm_02_noStandardDistanceDoesNotShowMoment() throws {
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")

        assertContains(viewModel, "guard let newData else { return [] }")
        assertContains(viewModel, "guard let newBest = newRecords.first, newBest.workoutId == workoutId else { continue }")
        assertContains(viewModel, "personalBestUpdatesForWorkout = workoutUpdates")
    }

    func test_ac_pbm_03_processingWorkoutDoesNotClaimPB() throws {
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")
        let view = try read("Havital/Views/Training/WorkoutDetailViewV2.swift")

        assertContains(viewModel, "self.state = .loaded(response)\n            await refreshPersonalBestMomentIfNeeded()")
        assertContains(viewModel, "guard state.hasData else { return }")
        XCTAssertFalse(view.contains("loadingView") && view.contains("New PB"), "Loading UI must not claim New PB before trusted profile refresh")
    }

    func test_ac_pbm_04_firstRecordCopyAvoidsRefreshLanguage() throws {
        let model = try read("Havital/Models/PersonalBestCelebration.swift")
        let en = try read("Havital/Resources/en.lproj/Localizable.strings")

        assertContains(model, "var isFirstRecord: Bool = false")
        assertContains(en, "\"my_achievement.celebration.first_record\" = \"First standard-distance record\";")
        let firstRecordLine = en.components(separatedBy: "\n").first { $0.contains("my_achievement.celebration.first_record") } ?? ""
        XCTAssertFalse(firstRecordLine.localizedCaseInsensitiveContains("refresh"))
        XCTAssertFalse(firstRecordLine.localizedCaseInsensitiveContains("faster"))
        XCTAssertFalse(firstRecordLine.localizedCaseInsensitiveContains("improved"))
    }

    func test_ac_pbm_05_workoutDetailShowsPBMoment() throws {
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")
        let view = try read("Havital/Views/Training/WorkoutDetailViewV2.swift")

        assertContains(viewModel, "pendingPBMomentUpdate = userProfileRepository.getPendingCelebrationUpdate()")
        // Task 8: migrated to pendingCelebrationContent + CelebrationSheet
        assertContains(view, ".onChange(of: viewModel.pendingCelebrationContent)")
        assertContains(view, "CelebrationSheet(")
    }

    func test_ac_pbm_06_momentContainsRequiredFields() throws {
        // Task 12: PersonalBestCelebrationView struct removed (legacy modal replaced by CelebrationSheet).
        // Assertions now target CelebrationSheet.swift only.
        let celebrationSheet = try read("Havital/Views/Components/CelebrationSheet.swift")
        assertContains(celebrationSheet, "newPB")
        XCTAssertTrue(
            celebrationSheet.contains("RaceDistanceV2(rawValue: update.distance)") ||
            celebrationSheet.contains("RaceDistanceV2(rawValue: pb.distance)"),
            "CelebrationSheet must derive race distance from PB update"
        )
        assertContains(celebrationSheet, "formatTime(")
        XCTAssertTrue(
            celebrationSheet.contains(".workoutDate") || celebrationSheet.contains("workoutDate"),
            "CelebrationSheet must reference workoutDate"
        )
    }

    func test_ac_pbm_07_multiplePBPrioritizesLargestImprovement() throws {
        let repo = try read("Havital/Features/UserProfile/Data/Repositories/UserProfileRepositoryImpl.swift")
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")

        assertContains(repo, "return $0.improvementSeconds < $1.improvementSeconds")
        assertContains(viewModel, "return $0.improvementSeconds > $1.improvementSeconds")
        assertContains(repo, "bestUpdate.relatedUpdateCount = max(updates.count - 1, 0)")
        assertContains(viewModel, "mutable.relatedUpdateCount = max(sorted.count - 1, 0)")
    }

    func test_ac_pbm_08_seenWorkoutDoesNotBlockAgain() throws {
        let model = try read("Havital/Models/PersonalBestCelebration.swift")
        let storage = try read("Havital/Storage/PersonalBestCelebrationStorage.swift")

        assertContains(model, "var dedupeKey: String")
        assertContains(model, "shownWorkoutUpdateKeys")
        assertContains(storage, "hasShownCelebration(for update: PersonalBestUpdate)")
        assertContains(storage, "cache.shownWorkoutUpdateKeys.contains(update.dedupeKey)")
    }

    func test_ac_pbm_09_shareCardContainsPBFields() throws {
        let shareCard = try read("Havital/Views/Components/PersonalBestCelebrationView.swift")

        assertContains(shareCard, "struct PBMomentShareCardView")
        assertContains(shareCard, "Paceriz")
        assertContains(shareCard, "distanceName")
        assertContains(shareCard, "formatTime(update.newTime)")
        assertContains(shareCard, "update.workoutDate")
        assertContains(shareCard, "formatImprovement(update.improvementSeconds)")
    }

    func test_ac_pbm_10_shareCardExcludesSensitiveFields() throws {
        let shareCard = try read("Havital/Views/Components/PersonalBestCelebrationView.swift")
        let cardOnly = shareCard.components(separatedBy: "struct PBMomentShareCardView").dropFirst().joined()

        ["heartRate", "routeData", "location", "latitude", "longitude", "userId", "userName", "userDisplayName", "email"].forEach {
            XCTAssertFalse(cardOnly.contains($0), "PB-only share card must not read sensitive field \($0)")
        }
    }

    func test_ac_pbm_11_shareFallbackSaveOrScreenshot() throws {
        let shareCard = try read("Havital/Views/Components/PersonalBestCelebrationView.swift")

        assertContains(shareCard, "ActivityViewController(activityItems: [renderedImage])")
        assertContains(shareCard, "UIImageWriteToSavedPhotosAlbum")
        assertContains(shareCard, "saveCard()")
    }

    func test_ac_pbm_12_shareCardReadableConstraints() throws {
        let shareCard = try read("Havital/Views/Components/PersonalBestCelebrationView.swift")

        assertContains(shareCard, ".frame(width: 1080, height: 1350)")
        assertContains(shareCard, ".aspectRatio(4.0 / 5.0, contentMode: .fit)")
        assertContains(shareCard, ".lineLimit(1)")
        assertContains(shareCard, ".minimumScaleFactor")
    }

    func test_ac_pbm_12a_threeLanguageLocalization() throws {
        let keys = [
            "my_achievement.celebration.new_pb",
            "my_achievement.celebration.first_record",
            "my_achievement.celebration.other_pbs",
            "my_achievement.celebration.share",
            "my_achievement.celebration.save",
            "my_achievement.celebration.date",
            "my_achievement.celebration.result",
            "my_achievement.celebration.share_card_title"
        ]
        for locale in ["zh-Hant", "en", "ja"] {
            let strings = try read("Havital/Resources/\(locale).lproj/Localizable.strings")
            keys.forEach { assertContains(strings, "\"\($0)\"", line: #line) }
        }
    }

    func test_ac_pbm_14_workoutDetailPBBadge() throws {
        let view = try read("Havital/Views/Training/WorkoutDetailViewV2.swift")
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")

        assertContains(viewModel, "personalBestUpdatesForWorkout")
        assertContains(view, "workout_detail_pb_badge")
        assertContains(view, "viewModel.personalBestUpdatesForWorkout.first")
    }

    func test_ac_pbm_16_pbMomentEventsTracked() throws {
        let view = try read("Havital/Views/Training/WorkoutDetailViewV2.swift")
        let viewModel = try read("Havital/Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift")

        ["view", "share", "save", "close"].forEach { assertContains(view + viewModel, "action: \"\($0)\"", line: #line) }
        assertContains(viewModel, "analyticsService.track(.pbMoment")
    }

    func test_ac_pbm_17_analyticsPayloadPrivacy() throws {
        let analytics = try read("Havital/Core/Analytics/AnalyticsEvent.swift")
        assertContains(analytics, "case pbMoment(action: String, distance: String, entry: String, isFirstRecord: Bool)")
        assertContains(analytics, "\"distance\": distance")
        assertContains(analytics, "\"entry\": entry")
        assertContains(analytics, "\"is_first_record\": isFirstRecord")

        let pbMomentSection = analytics.components(separatedBy: "case .pbMoment(let action").dropFirst().joined()
        ["workout_id", "route", "location", "latitude", "longitude", "email", "user_id"].forEach {
            XCTAssertFalse(pbMomentSection.contains($0), "PB Moment analytics must not include sensitive parameter \($0)")
        }
    }
}
