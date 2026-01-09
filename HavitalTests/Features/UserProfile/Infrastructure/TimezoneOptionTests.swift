import XCTest
@testable import paceriz_dev

final class TimezoneOptionTests: XCTestCase {

    // MARK: - getDeviceTimezoneId Tests

    func testGetDeviceTimezoneId_ReturnsValidIANAIdentifier() {
        // When
        let timezoneId = TimezoneOption.getDeviceTimezoneId()

        // Then
        XCTAssertFalse(timezoneId.isEmpty, "Timezone ID should not be empty")
        XCTAssertNotNil(TimeZone(identifier: timezoneId), "Should return valid IANA timezone identifier")
    }

    func testGetDeviceTimezoneId_MatchesSystemTimezone() {
        // When
        let timezoneId = TimezoneOption.getDeviceTimezoneId()

        // Then
        XCTAssertEqual(timezoneId, TimeZone.current.identifier)
    }

    // MARK: - getDisplayName Tests

    func testGetDisplayName_ValidTimezone_ReturnsLocalizedName() {
        // Given
        let validTimezone = "Asia/Taipei"

        // When
        let displayName = TimezoneOption.getDisplayName(for: validTimezone)

        // Then
        XCTAssertFalse(displayName.isEmpty, "Display name should not be empty")
        XCTAssertNotEqual(displayName, validTimezone, "Display name should be localized, not raw identifier")
    }

    func testGetDisplayName_InvalidTimezone_ReturnsIdentifier() {
        // Given
        let invalidTimezone = "Invalid/Timezone"

        // When
        let displayName = TimezoneOption.getDisplayName(for: invalidTimezone)

        // Then
        XCTAssertEqual(displayName, invalidTimezone, "Invalid timezone should return the identifier itself")
    }

    func testGetDisplayName_CommonTimezones_AllReturnValidNames() {
        // Given
        let commonIds = ["Asia/Taipei", "Asia/Tokyo", "America/New_York", "Europe/London"]

        for timezoneId in commonIds {
            // When
            let displayName = TimezoneOption.getDisplayName(for: timezoneId)

            // Then
            XCTAssertFalse(displayName.isEmpty, "\(timezoneId) should have a display name")
        }
    }

    // MARK: - getCurrentOffset Tests

    func testGetCurrentOffset_ValidTimezone_ReturnsGMTFormat() {
        // Given
        let timezoneId = "Asia/Taipei"

        // When
        let offset = TimezoneOption.getCurrentOffset(for: timezoneId)

        // Then
        XCTAssertTrue(offset.hasPrefix("GMT"), "Offset should start with GMT")
    }

    func testGetCurrentOffset_InvalidTimezone_ReturnsGMT() {
        // Given
        let invalidTimezone = "Invalid/Timezone"

        // When
        let offset = TimezoneOption.getCurrentOffset(for: invalidTimezone)

        // Then
        XCTAssertEqual(offset, "GMT", "Invalid timezone should return plain GMT")
    }

    func testGetCurrentOffset_UTCTimezone_ReturnsGMTPlusZero() {
        // Given
        let utcTimezone = "UTC"

        // When
        let offset = TimezoneOption.getCurrentOffset(for: utcTimezone)

        // Then
        XCTAssertEqual(offset, "GMT+0", "UTC should return GMT+0")
    }

    func testGetCurrentOffset_PositiveOffset_FormatsCorrectly() {
        // Given - Asia/Taipei is GMT+8
        let timezoneId = "Asia/Taipei"

        // When
        let offset = TimezoneOption.getCurrentOffset(for: timezoneId)

        // Then
        XCTAssertTrue(offset.contains("+"), "Positive offset should contain +")
    }

    func testGetCurrentOffset_NegativeOffset_FormatsCorrectly() {
        // Given - America/New_York is GMT-5 or GMT-4 (DST)
        let timezoneId = "America/New_York"

        // When
        let offset = TimezoneOption.getCurrentOffset(for: timezoneId)

        // Then
        XCTAssertTrue(offset.contains("-"), "Negative offset should contain -")
    }

    // MARK: - commonTimezones Tests

    func testCommonTimezones_ContainsExpectedTimezones() {
        // When
        let timezones = TimezoneOption.commonTimezones

        // Then
        let ids = timezones.map { $0.id }
        XCTAssertTrue(ids.contains("Asia/Taipei"), "Should contain Asia/Taipei")
        XCTAssertTrue(ids.contains("Asia/Tokyo"), "Should contain Asia/Tokyo")
        XCTAssertTrue(ids.contains("America/New_York"), "Should contain America/New_York")
        XCTAssertTrue(ids.contains("Europe/London"), "Should contain Europe/London")
    }

    func testCommonTimezones_AllHaveValidData() {
        // When
        let timezones = TimezoneOption.commonTimezones

        // Then
        for timezone in timezones {
            XCTAssertFalse(timezone.id.isEmpty, "ID should not be empty")
            XCTAssertFalse(timezone.displayName.isEmpty, "Display name should not be empty")
            XCTAssertTrue(timezone.offset.hasPrefix("GMT"), "Offset should start with GMT")
            XCTAssertNotNil(TimeZone(identifier: timezone.id), "\(timezone.id) should be valid IANA identifier")
        }
    }

    func testCommonTimezones_HasExpectedCount() {
        // When
        let timezones = TimezoneOption.commonTimezones

        // Then
        XCTAssertEqual(timezones.count, 9, "Should have 9 common timezones")
    }

    // MARK: - makeTimezoneOption Tests

    func testMakeTimezoneOption_KnownTimezone_ReturnsLocalizedName() {
        // Given
        let timezoneId = "Asia/Taipei"

        // When
        let option = TimezoneOption.makeTimezoneOption(from: timezoneId)

        // Then
        XCTAssertEqual(option.id, timezoneId)
        XCTAssertFalse(option.displayName.isEmpty)
        XCTAssertTrue(option.offset.hasPrefix("GMT"))
    }

    func testMakeTimezoneOption_UnknownTimezone_ReturnsSystemLocalizedName() {
        // Given - A valid but uncommon timezone
        let timezoneId = "Pacific/Fiji"

        // When
        let option = TimezoneOption.makeTimezoneOption(from: timezoneId)

        // Then
        XCTAssertEqual(option.id, timezoneId)
        XCTAssertFalse(option.displayName.isEmpty)
        XCTAssertTrue(option.offset.hasPrefix("GMT"))
    }

    // MARK: - deviceTimezone Tests

    func testDeviceTimezone_ReturnsValidOption() {
        // When
        let deviceTz = TimezoneOption.deviceTimezone

        // Then
        XCTAssertFalse(deviceTz.id.isEmpty)
        XCTAssertFalse(deviceTz.displayName.isEmpty)
        XCTAssertTrue(deviceTz.offset.hasPrefix("GMT"))
        XCTAssertNotNil(TimeZone(identifier: deviceTz.id))
    }

    func testDeviceTimezone_MatchesCurrentTimezone() {
        // When
        let deviceTz = TimezoneOption.deviceTimezone

        // Then
        XCTAssertEqual(deviceTz.id, TimeZone.current.identifier)
    }

    // MARK: - Equatable Tests

    func testTimezoneOption_Equatable_SameValues_AreEqual() {
        // Given
        let option1 = TimezoneOption(id: "Asia/Taipei", displayName: "Taipei", offset: "GMT+8")
        let option2 = TimezoneOption(id: "Asia/Taipei", displayName: "Taipei", offset: "GMT+8")

        // Then
        XCTAssertEqual(option1, option2)
    }

    func testTimezoneOption_Equatable_DifferentIds_AreNotEqual() {
        // Given
        let option1 = TimezoneOption(id: "Asia/Taipei", displayName: "Taipei", offset: "GMT+8")
        let option2 = TimezoneOption(id: "Asia/Tokyo", displayName: "Tokyo", offset: "GMT+9")

        // Then
        XCTAssertNotEqual(option1, option2)
    }
}
