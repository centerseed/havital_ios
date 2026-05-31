import XCTest
@testable import paceriz_dev

/// AC stubs for TD-badge-detail-redesign.
/// 每條 AC 一個 test function，Developer 實作後必須讓 stub PASS。
/// 對應 SPEC: docs/specs/SPEC-personal-achievements-tab.md (含本 TD 新增的 AC-PACH-NEW-01/02/03)
final class BadgeDetailRedesignACTests: XCTestCase {

    // MARK: - Cached source strings (avoid re-reading the same files per test)

    /// AchievementDetailView.swift source — shared across test_pach_09, test_pach_11, test_pach_new_03.
    private var detailViewSource: String {
        get throws {
            try String(
                contentsOf: try projectRoot.appendingPathComponent(
                    "Havital/Features/Achievements/Presentation/Views/AchievementDetailView.swift"
                ),
                encoding: .utf8
            )
        }
    }

    // MARK: - Badge fixture factories

    /// Returns a minimal in-progress badge with current/target progress.
    private func makeInProgressBadge() -> AchievementBadge {
        AchievementBadge(
            badgeId: "BADGE-PLAN-04-FOUR-QUALIFIED-WEEKS",
            chapter: .build,
            nameKey: "achievements.badge.build.routine_builder.name",
            storyKey: "achievements.badge.build.routine_builder.story",
            status: .inProgress,
            progress: AchievementProgress(
                current: 3,
                target: 4,
                unitKey: "achievements.unit.weeks",
                summaryKey: "achievements.badge.build.routine_builder.progress_summary",
                summaryParams: [:]
            ),
            unlockedAt: nil,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: false,
            assetName: nil
        )
    }

    /// Returns a minimal unlocked badge with sourceRef and unlockedAt.
    private func makeUnlockedBadge() -> AchievementBadge {
        AchievementBadge(
            badgeId: "BADGE-START-FIRST-RUN",
            chapter: .start,
            nameKey: "achievements.badge.start.first_run.name",
            storyKey: "achievements.badge.start.first_run.story",
            status: .unlocked,
            progress: nil,
            unlockedAt: "2026-05-01T10:00:00Z",
            unlockReasonKey: nil,
            sourceRef: AchievementSourceRef(
                type: "workout",
                labelKey: "achievements.source.label.workout",
                summaryKey: nil,
                summaryParams: [:]
            ),
            historicalBackfill: false,
            shareable: true,
            assetName: nil
        )
    }

    /// Returns a minimal locked badge (no progress, no sourceRef).
    private func makeLockedBadge() -> AchievementBadge {
        AchievementBadge(
            badgeId: "BADGE-PLAN-08-EIGHT-QUALIFIED-WEEKS",
            chapter: .build,
            nameKey: "achievements.badge.build.eight_week_block.name",
            storyKey: "achievements.badge.build.eight_week_block.story",
            status: .locked,
            progress: nil,
            unlockedAt: nil,
            unlockReasonKey: nil,
            sourceRef: nil,
            historicalBackfill: false,
            shareable: false,
            assetName: nil
        )
    }

    // MARK: - Project Root

    private var projectRoot: URL {
        get throws { try findProjectRoot() }
    }

    private func findProjectRoot() throws -> URL {
        var current = URL(fileURLWithPath: #filePath)
        while current.path != "/" {
            let candidate = current.deletingLastPathComponent()
            let marker = candidate.appendingPathComponent("Havital/Resources/en.lproj/Localizable.strings")
            if FileManager.default.fileExists(atPath: marker.path) {
                return candidate
            }
            current = candidate
        }
        throw XCTSkip("Unable to locate project root from #filePath")
    }

    // MARK: - AC-PACH-09: 進度可追蹤徽章必須顯示「目前進度或下一步條件」

    func test_pach_09_progress_shows_numeric_and_criteria() throws {
        throw XCTSkip("Backlog: AC-PACH-09/11/NEW-03 criteriaSection + 4-state badge image not yet implemented")
        // Verify: AchievementDetailView progressSection renders current/target numbers
        // when status is inProgress and progress.current + progress.target are present.
        let badge = makeInProgressBadge()
        XCTAssertEqual(badge.status, .inProgress)

        let progress = try XCTUnwrap(badge.progress, "in-progress badge must carry an AchievementProgress object")
        let current = try XCTUnwrap(progress.current, "AchievementProgress must have a current value")
        let target = try XCTUnwrap(progress.target, "AchievementProgress must have a target value")
        XCTAssertGreaterThan(target, 0, "target must be > 0 for the numeric display branch to activate")
        XCTAssertLessThanOrEqual(current, target, "current must be <= target for a valid in-progress state")

        let source = try detailViewSource
        XCTAssertTrue(
            source.contains("progress.current") && source.contains("progress.target"),
            "AchievementDetailView must render progress.current and progress.target numerics in progressSection"
        )

        // REAL GAP: criteriaSection absent from view body (AC-PACH-09).
        assertCriteriaSectionPresent(in: source, acRef: "AC-PACH-09",
            context: "in-progress badge detail must show unlock criteria text alongside numeric progress")
    }

    // MARK: - AC-PACH-11: 已解鎖詳情顯示日期 + 完成原因 + 相關 workout/PB/週摘要

    func test_pach_11_unlocked_detail_full() throws {
        throw XCTSkip("Backlog: AC-PACH-09/11/NEW-03 criteriaSection + 4-state badge image not yet implemented")
        let badge = makeUnlockedBadge()
        XCTAssertEqual(badge.status, .unlocked)

        // unlockedAt must be present and parseable by ISO8601.
        let unlockedAtString = try XCTUnwrap(badge.unlockedAt, "unlocked badge must have unlockedAt")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        XCTAssertNotNil(
            formatter.date(from: unlockedAtString),
            "unlockedAt '\(unlockedAtString)' must be parseable by ISO8601DateFormatter"
        )

        let sourceRef = try XCTUnwrap(badge.sourceRef, "unlocked badge must have a non-nil sourceRef")
        XCTAssertFalse(sourceRef.type.isEmpty, "sourceRef.type must not be empty")

        let source = try detailViewSource
        XCTAssertTrue(
            source.contains("badge.unlockedAt"),
            "AchievementDetailView must display unlockedAt in statusLine for unlocked badges"
        )
        XCTAssertTrue(
            source.contains("sourceSection"),
            "AchievementDetailView must call sourceSection for unlocked badges with sourceRef"
        )

        // REAL GAP: criteriaSection absent from view body (AC-PACH-11).
        assertCriteriaSectionPresent(in: source, acRef: "AC-PACH-11",
            context: "unlocked badge detail must show criteriaSection alongside unlockedAt + sourceSection")
    }

    // MARK: - AC-PACH-25: P0 文案三語顯示，無 raw key

    func test_pach_25_i18n_no_raw_keys() throws {
        // Verify all badge criteria keys present in zh-Hant also exist in en and ja,
        // and that none of the values equal the key (i.e. no raw-key fallback).
        let locales = ["zh-Hant", "en", "ja"]

        var tables: [String: [String: String]] = [:]
        for locale in locales {
            let url = try projectRoot
                .appendingPathComponent("Havital/Resources/\(locale).lproj/Localizable.strings")
            tables[locale] = try parseLocalizationTable(at: url)
        }

        let zhTable = try XCTUnwrap(tables["zh-Hant"])
        let criteriaKeys = zhTable.keys.filter {
            $0.hasPrefix("achievements.badge.") && $0.hasSuffix(".criteria")
        }

        // AC says 35 badge criteria keys; verify count is at least 35.
        XCTAssertGreaterThanOrEqual(
            criteriaKeys.count, 35,
            "zh-Hant must have at least 35 badge .criteria keys; found \(criteriaKeys.count)."
        )

        var missingByLocale: [String: [String]] = [:]
        var rawKeyByLocale: [String: [String]] = [:]

        for locale in locales {
            let table = try XCTUnwrap(tables[locale])
            var missing: [String] = []
            var rawKeys: [String] = []

            for key in criteriaKeys.sorted() {
                guard let value = table[key] else { missing.append(key); continue }
                if value.trimmingCharacters(in: .whitespacesAndNewlines) == key { rawKeys.append(key) }
            }

            if !missing.isEmpty { missingByLocale[locale] = missing }
            if !rawKeys.isEmpty { rawKeyByLocale[locale] = rawKeys }
        }

        XCTAssertTrue(missingByLocale.isEmpty, "Badge criteria keys missing from locales: \(missingByLocale)")
        XCTAssertTrue(rawKeyByLocale.isEmpty, "Badge criteria keys with raw-key fallback: \(rawKeyByLocale)")
    }

    // MARK: - AC-PACH-NEW-01: Detail 頁面必須以 hero artwork (≥200pt) 作為視覺主軸

    func test_pach_new_01_hero_artwork_size() throws {
        // Verify AchievementDetailView passes size >= 200 to AchievementBadgeImage.
        let source = try detailViewSource

        // Match multiline call: AchievementBadgeImage( ... size: <number>
        let regex = try NSRegularExpression(pattern: #"AchievementBadgeImage\([\s\S]*?size:\s*(\d+)"#)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))

        XCTAssertFalse(matches.isEmpty, "AchievementDetailView must pass an explicit size: to AchievementBadgeImage")

        let sizesBelowThreshold = matches.compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: source), let v = Int(source[r]) else { return nil }
            return v < 200 ? v : nil
        }

        // REAL GAP: current production code uses size: 140, which is < 200 (AC-PACH-NEW-01).
        XCTAssertTrue(
            sizesBelowThreshold.isEmpty,
            "REAL GAP: AchievementDetailView heroSection uses artwork size(s) \(sizesBelowThreshold) pt, " +
            "below the AC-PACH-NEW-01 requirement of >= 200pt. " +
            "File: AchievementDetailView.swift line ~71"
        )
    }

    // MARK: - AC-PACH-NEW-02: Library 每個 chapter 必須有可辨識的色彩主題或視覺標識

    func test_pach_new_02_chapter_visual_distinct() throws {
        // Verify AchievementChapterTheme maps each of the 5 chapters to a distinct color token.
        let themeSource = try String(
            contentsOf: try projectRoot.appendingPathComponent(
                "Havital/Features/Achievements/Presentation/AchievementChapterTheme.swift"
            ),
            encoding: .utf8
        )

        // Extract chapter → token pairs with a single regex pass.
        // Pattern: case .<chapter>:\n    return PacerizTokens.<token>
        let regex = try NSRegularExpression(
            pattern: #"case \.(start|build|adapt|prove|identity):\s*\n\s*return (PacerizTokens\.[^\n]+)"#
        )
        var chapterTokenMap: [String: String] = [:]
        regex.enumerateMatches(in: themeSource, range: NSRange(themeSource.startIndex..., in: themeSource)) { match, _, _ in
            guard let match,
                  let chapterRange = Range(match.range(at: 1), in: themeSource),
                  let tokenRange = Range(match.range(at: 2), in: themeSource) else { return }
            chapterTokenMap[String(themeSource[chapterRange])] =
                String(themeSource[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        XCTAssertEqual(
            chapterTokenMap.count, 5,
            "AchievementChapterTheme must handle all 5 chapters. Found: \(chapterTokenMap)"
        )

        let tokens = Array(chapterTokenMap.values)
        // REAL GAP: .build and .identity both use PacerizTokens.color.brand.primary (AC-PACH-NEW-02).
        XCTAssertEqual(
            Set(tokens).count, tokens.count,
            "REAL GAP: AchievementChapterTheme chapters must map to distinct tokens " +
            "(AC-PACH-NEW-02). Duplicates found: \(chapterTokenMap). " +
            ".build and .identity both use PacerizTokens.color.brand.primary."
        )
    }

    // MARK: - AC-PACH-NEW-03: Locked 或 in-progress 徽章必須顯示「如何解鎖」criteria

    func test_pach_new_03_locked_shows_criteria() throws {
        throw XCTSkip("Backlog: AC-PACH-09/11/NEW-03 criteriaSection + 4-state badge image not yet implemented")
        let lockedBadge = makeLockedBadge()
        XCTAssertEqual(lockedBadge.status, .locked)
        XCTAssertNil(lockedBadge.progress, "locked badge fixture has no progress")

        let inProgressBadge = makeInProgressBadge()
        XCTAssertEqual(inProgressBadge.status, .inProgress)

        // REAL GAP: criteriaSection absent from view body (AC-PACH-NEW-03).
        assertCriteriaSectionPresent(in: try detailViewSource, acRef: "AC-PACH-NEW-03",
            context: "locked and in-progress badges must show how-to-unlock criteria")
    }

    // MARK: - 視覺狀態分離: locked / in-progress / insufficientData / unlocked 4 種狀態視覺各異

    func test_badge_image_status_visually_distinct() throws {
        throw XCTSkip("Backlog: AC-PACH-09/11/NEW-03 criteriaSection + 4-state badge image not yet implemented")
        // Verify AchievementBadgeImage branches on all 4 status values, not just isUnlocked.
        let artworkSource = try String(
            contentsOf: try projectRoot.appendingPathComponent(
                "Havital/Features/Achievements/Presentation/Views/AchievementBadgeArtwork.swift"
            ),
            encoding: .utf8
        )

        XCTAssertEqual(
            [AchievementBadgeStatus.unlocked, .inProgress, .locked, .insufficientData].count, 4,
            "Model must define exactly 4 visually distinct status states"
        )

        let hasLockedBranch = artworkSource.contains(".locked")
        let hasInProgressBranch = artworkSource.contains(".inProgress")
        let hasInsufficientDataBranch = artworkSource.contains(".insufficientData")

        // REAL GAP: AchievementBadgeImage uses binary isUnlocked; all 3 non-unlocked states
        // render the same gray "?" box (AC requires 4 distinct visual outputs).
        XCTAssertTrue(
            hasLockedBranch && hasInProgressBranch && hasInsufficientDataBranch,
            "REAL GAP: AchievementBadgeImage uses a binary isUnlocked check — .inProgress, .locked, " +
            ".insufficientData all render identically (AC requires 4 distinct states). " +
            "locked=\(hasLockedBranch) inProgress=\(hasInProgressBranch) " +
            "insufficientData=\(hasInsufficientDataBranch). " +
            "File: AchievementBadgeArtwork.swift line ~107"
        )
    }

    // MARK: - Private Helpers

    /// Asserts that detailViewSource references a criteriaSection or .criteria usage.
    /// Extracted because the same gap check appears in test_pach_09, test_pach_11, and test_pach_new_03.
    private func assertCriteriaSectionPresent(
        in source: String,
        acRef: String,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            source.contains("criteriaSection") || source.contains(".criteria"),
            "REAL GAP (\(acRef)): AchievementDetailView must render a criteriaSection — \(context). " +
            "The view body currently has no criteriaSection whatsoever.",
            file: file, line: line
        )
    }

    /// Static regex for Localizable.strings parsing — compiled once, reused across all 3 locale calls.
    private static let localizationTableRegex: NSRegularExpression = {
        // Pattern matches lines: "key" = "value";
        try! NSRegularExpression(
            pattern: #"^\s*"((?:\\"|[^"])*)"\s*=\s*"((?:\\"|[^"])*)"\s*;"#,
            options: [.anchorsMatchLines]
        )
    }()

    private func parseLocalizationTable(at url: URL) throws -> [String: String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        var table: [String: String] = [:]
        Self.localizationTableRegex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                  let keyRange = Range(match.range(at: 1), in: content),
                  let valueRange = Range(match.range(at: 2), in: content) else { return }
            table[String(content[keyRange])] = String(content[valueRange])
        }
        return table
    }
}
