import XCTest
@testable import paceriz_dev

/// 2.0 畫面上「帶千分位的量」的格式（`App2NumberFormat`）。
///
/// 這一組存在的理由是一個真缺陷（2026-08-25 用戶截圖退件）：成就頁原本用
/// `maximumFractionDigits = value < 100 ? 1 : 0`，於是週數這種本來就是整數的量
/// 被印成 **`11.0 / 24.0 週 · 還差 13.0 週`** —— 看起來像量測誤差。
///
/// 判準一條：**值是整數就不得帶小數點**；真的有小數才顯示小數。
///
/// 順帶鎖住收斂結果：紀錄頁與成就頁原本各有一份私有 `grouped(_:)`（規則還不同），
/// 現在兩邊都轉呼叫 `App2NumberFormat`。挑選邏輯（最新解鎖／下一個目標）與 1.4 相同，
/// 不在這裡另立判準 —— 用戶裁決：成就頁基本上跟 1.4 一樣，2.0 只改外型。
@MainActor
final class App2AchievementsFormatTests: XCTestCase {

    // MARK: - 共用格式器

    func test_grouped_wholeNumbersHaveNoDecimalPoint() {
        for value in [0.0, 1.0, 11.0, 13.0, 24.0, 99.0, 100.0, 2_400.0] {
            let text = App2NumberFormat.grouped(value, maximumFractionDigits: 1)
            XCTAssertFalse(text.contains("."), "整數 \(value) 不該印成 \(text)")
        }
    }

    func test_grouped_keepsFractionWhenValueIsNotWhole() {
        XCTAssertEqual(App2NumberFormat.grouped(11.5, maximumFractionDigits: 1), "11.5")
        XCTAssertEqual(App2NumberFormat.grouped(99.4, maximumFractionDigits: 1), "99.4")
    }

    func test_grouped_defaultsToNoFraction() {
        XCTAssertEqual(App2NumberFormat.grouped(1_141.5), "1,142")
    }

    func test_grouped_usesThousandSeparator() {
        XCTAssertEqual(App2NumberFormat.grouped(2_400), "2,400")
    }

    // MARK: - 成就頁的呼叫點

    /// 退件截圖裡的那三個數字。
    func test_achievementsGrouped_reproducesRejectedWeekCountsWithoutDecimals() {
        XCTAssertEqual(App2AchievementsView.grouped(11), "11")
        XCTAssertEqual(App2AchievementsView.grouped(24), "24")
        XCTAssertEqual(App2AchievementsView.grouped(13), "13")
    }

    /// 累積里程這種真的有小數的量仍然保留一位（設計 frame-11 的 `1,141.5`）。
    func test_achievementsGrouped_keepsOneFractionBelowHundred() {
        XCTAssertEqual(App2AchievementsView.grouped(37.3), "37.3")
    }

    /// 同一行的三個數字同精度。原本按大小切精度（<100 一位、其餘取整），
    /// hero 量化列就出現 `263 / 300 公里 · 還差 37.3 公里` —— 263 + 37.3 ≠ 300。
    func test_achievementsGrouped_sameRowKeepsConsistentPrecision() {
        let current = 262.7, target = 300.0
        XCTAssertEqual(App2AchievementsView.grouped(current), "262.7")
        XCTAssertEqual(App2AchievementsView.grouped(target), "300")
        XCTAssertEqual(App2AchievementsView.grouped(target - current), "37.3")
    }

    // MARK: - 紀錄頁的呼叫點

    /// 本月跑量／今年累積保留一位小數 —— 四捨五入成 `73` 會跟同一份資料在
    /// Android 上顯示的 `72.6` 對不上。
    func test_recordsGrouped_keepsOneFraction() {
        XCTAssertEqual(App2RecordsView.grouped(72.6), "72.6")
        XCTAssertEqual(App2RecordsView.grouped(585.5), "585.5")
        XCTAssertEqual(App2RecordsView.grouped(1_284), "1,284")
    }

    // MARK: - PB 詳情資料

    func test_pbCardTapUsesRaceRunDistanceKeyAndPreservesBackendOrder() throws {
        let defaults = UserDefaults.standard
        let profileCacheKey = "user_profile_cache_v3"
        let profileTimestampKey = "user_profile_cache_v3_timestamp"
        let previousProfile = defaults.object(forKey: profileCacheKey)
        let previousTimestamp = defaults.object(forKey: profileTimestampKey)
        defer {
            if let previousProfile {
                defaults.set(previousProfile, forKey: profileCacheKey)
            } else {
                defaults.removeObject(forKey: profileCacheKey)
            }
            if let previousTimestamp {
                defaults.set(previousTimestamp, forKey: profileTimestampKey)
            } else {
                defaults.removeObject(forKey: profileTimestampKey)
            }
        }

        let fiveKRecords = [
            pb("backend-rank-1", seconds: 1_600),
            pb("backend-rank-2", seconds: 1_400),
            pb("backend-rank-3", seconds: 1_500),
            pb("backend-rank-4", seconds: 1_300)
        ]
        let twentyOneKRecords = [pb("wrong-distance", seconds: 5_000)]
        let profilePayload: [String: Any] = [
            "personal_best_v2": [
                "race_run": [
                    "5": try JSONSerialization.jsonObject(with: JSONEncoder().encode(fiveKRecords)),
                    "21": try JSONSerialization.jsonObject(with: JSONEncoder().encode(twentyOneKRecords))
                ]
            ]
        ]
        let profileData = try JSONSerialization.data(withJSONObject: profilePayload)
        let cachedUser = try JSONDecoder().decode(User.self, from: profileData)
        UserProfileLocalDataSource().saveUserProfile(cachedUser)

        let view = App2AchievementsView(viewModel: PersonalAchievementsViewModel())
        let detailItem = view.openPBDetail(for: AchievementPBRecord(
            distance: "5",
            displayDistance: "5K",
            time: "26:40",
            achievedAt: "2026-09-23",
            isRecent: false
        ))

        XCTAssertEqual(detailItem?.distance.rawValue, "5")
        XCTAssertEqual(detailItem?.records, fiveKRecords)
    }

    private func pb(_ workoutId: String, seconds: Int) -> PersonalBestRecordV2 {
        PersonalBestRecordV2(
            completeTime: seconds,
            pace: "5:00",
            recordedAt: "2026-09-23T00:00:00Z",
            workoutDate: "2026-09-23",
            workoutId: workoutId
        )
    }
}
