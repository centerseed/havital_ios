import XCTest
@testable import paceriz_dev

/// AC stubs for TD-badge-detail-redesign.
/// 每條 AC 一個 test function，Developer 實作後必須讓 stub PASS。
/// 對應 SPEC: docs/specs/SPEC-personal-achievements-tab.md (含本 TD 新增的 AC-PACH-NEW-01/02/03)
final class BadgeDetailRedesignACTests: XCTestCase {

    // MARK: - AC-PACH-09: 進度可追蹤徽章必須顯示「目前進度或下一步條件」

    func test_pach_09_progress_shows_numeric_and_criteria() throws {
        XCTFail("NOT IMPLEMENTED — Developer: in-progress badge detail 必須顯示 current/target 數字（如「3/5 週」）+ criteriaSection 文案")
    }

    // MARK: - AC-PACH-11: 已解鎖詳情顯示日期 + 完成原因 + 相關 workout/PB/週摘要

    func test_pach_11_unlocked_detail_full() throws {
        XCTFail("NOT IMPLEMENTED — Developer: unlocked badge detail 必須顯示 unlockedAt + sourceSection(非空) + criteriaSection")
    }

    // MARK: - AC-PACH-25: P0 文案三語顯示，無 raw key

    func test_pach_25_i18n_no_raw_keys() throws {
        XCTFail("NOT IMPLEMENTED — Developer: 35 個 badge 的 criteria key 在 zh-Hant/en/ja 均有翻譯，無 raw key fallback")
    }

    // MARK: - AC-PACH-NEW-01: Detail 頁面必須以 hero artwork (≥200pt) 作為視覺主軸

    func test_pach_new_01_hero_artwork_size() throws {
        XCTFail("NOT IMPLEMENTED — Developer: AchievementDetailView heroSection artwork size >= 200pt，置於頁面頂部")
    }

    // MARK: - AC-PACH-NEW-02: Library 每個 chapter 必須有可辨識的色彩主題或視覺標識

    func test_pach_new_02_chapter_visual_distinct() throws {
        XCTFail("NOT IMPLEMENTED — Developer: 5 chapter (Start/Build/Adapt/Prove/Identity) 各對應不同 AchievementChapterTheme token，視覺可區分")
    }

    // MARK: - AC-PACH-NEW-03: Locked 或 in-progress 徽章必須顯示「如何解鎖」criteria

    func test_pach_new_03_locked_shows_criteria() throws {
        XCTFail("NOT IMPLEMENTED — Developer: locked / in-progress badge detail 都必須顯示 criteriaSection（不只 unlocked）")
    }

    // MARK: - 視覺狀態分離: locked / in-progress / insufficientData / unlocked 4 種狀態視覺各異

    func test_badge_image_status_visually_distinct() throws {
        XCTFail("NOT IMPLEMENTED — Developer: AchievementBadgeImage 對 4 種 status 各有不同視覺處理（不可 inProgress 與 unlocked 相同）")
    }
}
