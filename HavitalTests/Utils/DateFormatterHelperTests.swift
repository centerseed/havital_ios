//
//  DateFormatterHelperTests.swift
//  HavitalTests
//
//  時區轉換單元測試
//

import XCTest
@testable import Havital

final class DateFormatterHelperTests: XCTestCase {

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        // 確保測試環境乾淨
        UserPreferenceManager.shared.timezonePreference = nil
    }

    override func tearDown() {
        // 清理測試數據
        UserPreferenceManager.shared.timezonePreference = nil
        super.tearDown()
    }

    // MARK: - 時區設定測試

    func testFormatterUsesUserTimezone() {
        // Given: 設定用戶時區為東京
        UserPreferenceManager.shared.timezonePreference = "Asia/Tokyo"

        // When: 創建 formatter
        let formatter = DateFormatterHelper.formatter(dateFormat: "HH:mm")

        // Then: formatter 應該使用東京時區
        XCTAssertEqual(formatter.timeZone.identifier, "Asia/Tokyo")
    }

    func testFormatterUsesCurrentTimezoneWhenUserTimezoneNotSet() {
        // Given: 未設定用戶時區
        UserPreferenceManager.shared.timezonePreference = nil

        // When: 創建 formatter
        let formatter = DateFormatterHelper.formatter(dateFormat: "HH:mm")

        // Then: formatter 應該使用當前時區
        XCTAssertEqual(formatter.timeZone, TimeZone.current)
    }

    // MARK: - 日期格式化測試

    func testFormatDateTime() {
        // Given: 固定的 UTC 時間 (2025-11-19 14:30:00 UTC)
        let utcDate = Date(timeIntervalSince1970: 1732025400)

        // When: 使用台北時區格式化
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let formatted = DateFormatterHelper.formatDateTime(utcDate)

        // Then: 應該顯示台北時間 (UTC+8)
        // 2025-11-19 14:30:00 UTC = 2025-11-19 22:30:00 台北
        XCTAssertTrue(formatted.contains("22:30"), "Expected Taiwan time to be 22:30, got \(formatted)")
    }

    func testFormatShortDate() {
        // Given: 固定日期
        let date = Date(timeIntervalSince1970: 1732025400)  // 2025-11-19 14:30:00 UTC

        // When: 格式化為短日期
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let formatted = DateFormatterHelper.formatShortDate(date)

        // Then: 應該顯示 MM/dd 格式
        XCTAssertEqual(formatted, "11/19")
    }

    func testFormatTime() {
        // Given: 固定時間
        let date = Date(timeIntervalSince1970: 1732025400)  // 2025-11-19 14:30:00 UTC

        // When: 使用台北時區格式化時間
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let formatted = DateFormatterHelper.formatTime(date)

        // Then: 應該顯示台北時間 22:30
        XCTAssertEqual(formatted, "22:30")
    }

    func testFormatFullDate() {
        // Given: 固定日期
        let date = Date(timeIntervalSince1970: 1732025400)  // 2025-11-19 14:30:00 UTC

        // When: 格式化為完整日期
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let formatted = DateFormatterHelper.formatFullDate(date)

        // Then: 應該顯示 yyyy-MM-dd 格式（台北日期）
        XCTAssertEqual(formatted, "2025-11-19")
    }

    // MARK: - 跨時區測試

    func testTimezoneConversionFromUTCToTokyo() {
        // Given: UTC 時間 2025-11-19 00:00:00
        let utcDate = Date(timeIntervalSince1970: 1731974400)

        // When: 使用東京時區 (UTC+9) 格式化
        UserPreferenceManager.shared.timezonePreference = "Asia/Tokyo"
        let formatted = DateFormatterHelper.formatDateTime(utcDate)

        // Then: 應該顯示東京時間 09:00
        XCTAssertTrue(formatted.contains("09:00"), "Expected Tokyo time to be 09:00, got \(formatted)")
    }

    func testTimezoneConversionFromUTCToNewYork() {
        // Given: UTC 時間 2025-11-19 00:00:00
        let utcDate = Date(timeIntervalSince1970: 1731974400)

        // When: 使用紐約時區 (UTC-5) 格式化
        UserPreferenceManager.shared.timezonePreference = "America/New_York"
        let formatted = DateFormatterHelper.formatDateTime(utcDate)

        // Then: 應該顯示前一天的 19:00
        XCTAssertTrue(formatted.contains("2025/11/18"), "Expected date to be 11/18")
        XCTAssertTrue(formatted.contains("19:00"), "Expected New York time to be 19:00, got \(formatted)")
    }

    // MARK: - 解析測試

    func testParseDate() {
        // Given: 日期字串 "2025-11-19"
        let dateString = "2025-11-19"

        // When: 使用台北時區解析
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let parsed = DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd")

        // Then: 應該成功解析
        XCTAssertNotNil(parsed)

        // 驗證解析後的日期在台北時區是正確的
        let formatter = DateFormatterHelper.formatter(dateFormat: "yyyy-MM-dd")
        let formatted = formatter.string(from: parsed!)
        XCTAssertEqual(formatted, "2025-11-19")
    }

    func testParseDateWithInvalidFormat() {
        // Given: 無效的日期字串
        let dateString = "invalid-date"

        // When: 嘗試解析
        let parsed = DateFormatterHelper.parseDate(from: dateString, format: "yyyy-MM-dd")

        // Then: 應該返回 nil
        XCTAssertNil(parsed)
    }

    // MARK: - Date Extension 測試

    func testDateExtensionFormattedDateTime() {
        // Given: 固定日期
        let date = Date(timeIntervalSince1970: 1732025400)

        // When: 使用 extension 格式化
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let formatted = date.formattedDateTime

        // Then: 應該包含台北時間
        XCTAssertTrue(formatted.contains("22:30"))
    }

    func testDateExtensionFormattedShortDate() {
        // Given: 固定日期
        let date = Date(timeIntervalSince1970: 1732025400)

        // When: 使用 extension 格式化
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"
        let formatted = date.formattedShortDate

        // Then: 應該顯示短日期
        XCTAssertEqual(formatted, "11/19")
    }

    // MARK: - 相對時間測試

    func testFormatRelativeTimeJustNow() {
        // Given: 30 秒前的時間
        let date = Date().addingTimeInterval(-30)

        // When: 格式化為相對時間
        let formatted = DateFormatterHelper.formatRelativeTime(date)

        // Then: 應該顯示"剛剛"
        XCTAssertTrue(formatted.contains("剛剛") || formatted.contains("just"))
    }

    func testFormatRelativeTimeMinutesAgo() {
        // Given: 5 分鐘前的時間
        let date = Date().addingTimeInterval(-5 * 60)

        // When: 格式化為相對時間
        let formatted = DateFormatterHelper.formatRelativeTime(date)

        // Then: 應該顯示"5分鐘前"
        XCTAssertTrue(formatted.contains("5") && (formatted.contains("分鐘") || formatted.contains("minute")))
    }

    // MARK: - 調試工具測試

    func testGetCurrentTimezoneInfo() {
        // Given: 設定用戶時區為台北
        UserPreferenceManager.shared.timezonePreference = "Asia/Taipei"

        // When: 獲取時區資訊
        let info = DateFormatterHelper.getCurrentTimezoneInfo()

        // Then: 應該包含台北時區資訊
        XCTAssertTrue(info.contains("Asia/Taipei"))
        XCTAssertTrue(info.contains("GMT"))
    }

    // MARK: - 邊界條件測試

    func testHandleInvalidTimezoneIdentifier() {
        // Given: 無效的時區 ID
        UserPreferenceManager.shared.timezonePreference = "Invalid/Timezone"

        // When: 創建 formatter
        let formatter = DateFormatterHelper.formatter(dateFormat: "HH:mm")

        // Then: 應該回退到當前時區
        XCTAssertEqual(formatter.timeZone, TimeZone.current)
    }

    func testHandleNilDate() {
        // Given: nil 日期字串
        let parsed = DateFormatterHelper.parseDate(from: "", format: "yyyy-MM-dd")

        // Then: 應該返回 nil
        XCTAssertNil(parsed)
    }
}
