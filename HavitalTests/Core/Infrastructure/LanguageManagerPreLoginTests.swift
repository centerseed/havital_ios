import XCTest
@testable import paceriz_dev

@MainActor
final class LanguageManagerPreLoginTests: XCTestCase {
    private let languageKey = "app_language_preference"
    private var originalLanguage: SupportedLanguage!
    private var originalLanguagePreference: String?
    private var originalAppleLanguages: [String]?

    override func setUp() {
        super.setUp()
        originalLanguage = LanguageManager.shared.currentLanguage
        originalLanguagePreference = UserDefaults.standard.string(forKey: languageKey)
        originalAppleLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
        UserDefaults.standard.removeObject(forKey: languageKey)
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    override func tearDown() {
        LanguageManager.shared.applyPreLoginLanguage(originalLanguage)
        if let originalLanguagePreference {
            UserDefaults.standard.set(originalLanguagePreference, forKey: languageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: languageKey)
        }
        if let originalAppleLanguages {
            UserDefaults.standard.set(originalAppleLanguages, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        originalLanguage = nil
        originalLanguagePreference = nil
        originalAppleLanguages = nil
        super.tearDown()
    }

    func test_applyPreLoginLanguage_updatesLocalPreferenceAndAppleLanguages() {
        LanguageManager.shared.applyPreLoginLanguage(.english)

        XCTAssertEqual(LanguageManager.shared.currentLanguage, .english)
        XCTAssertEqual(UserDefaults.standard.string(forKey: languageKey), "en")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["en"])
    }

    func test_applyPreLoginLanguage_canSwitchToJapaneseBeforeAuthentication() {
        LanguageManager.shared.applyPreLoginLanguage(.japanese)

        XCTAssertEqual(LanguageManager.shared.currentLanguage, .japanese)
        XCTAssertEqual(UserDefaults.standard.string(forKey: languageKey), "ja")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["ja"])
    }
}
