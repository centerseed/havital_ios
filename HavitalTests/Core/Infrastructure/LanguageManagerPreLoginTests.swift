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

    // MARK: - 首啟（全新 container）的系統語言解析
    //
    // 這一段鎖的是 `LanguageManager` init 裡「沒有存過偏好時」走的那條路。
    // 系統給的是 BCP-47 標籤（`zh-Hant-TW`／`ja-JP`），`SupportedLanguage` 的 raw value
    // 是 lproj 目錄名（`zh-Hant`／`ja`）—— 直接 `init?(rawValue:)` 一定 miss，然後靜默
    // 落到 `?? .traditionalChinese`。對日文系統的用戶就是「系統日文、app 中文」，
    // 而且完全沒有 log 說它 miss 了。

    func test_resolveFromSystem_matchesScriptAndRegionQualifiedChinese() {
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(
                preferredLanguages: ["zh-Hant-TW", "ja-TW", "en-TW"],
                preferredLocalizations: ["en"]
            ),
            .traditionalChinese
        )
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(preferredLanguages: ["zh-TW"], preferredLocalizations: []),
            .traditionalChinese
        )
    }

    func test_resolveFromSystem_matchesRegionQualifiedJapaneseAndEnglish() {
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(preferredLanguages: ["ja-JP"], preferredLocalizations: []),
            .japanese
        )
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(preferredLanguages: ["en-GB"], preferredLocalizations: []),
            .english
        )
    }

    /// 使用者在系統設定裡排的順序才是系統語言。`preferredLocalizations` 是 bundle
    /// 比對過的結果，而且會被本 app 自己寫進 UserDefaults 的 `AppleLanguages` 蓋掉，
    /// 首啟時不該讓它壓過真正的系統偏好。
    func test_resolveFromSystem_prefersSystemOrderOverBundleMatch() {
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(
                preferredLanguages: ["ja-JP", "en-US"],
                preferredLocalizations: ["en"]
            ),
            .japanese
        )
    }

    /// 系統偏好裡一個都不支援時才往下走 bundle，再不行才是繁中
    /// （`CFBundleDevelopmentRegion` 就是 zh-Hant）。
    func test_resolveFromSystem_fallsBackThroughBundleThenDevelopmentRegion() {
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(preferredLanguages: ["ko-KR"], preferredLocalizations: ["ja"]),
            .japanese
        )
        XCTAssertEqual(
            SupportedLanguage.resolveFromSystem(preferredLanguages: ["ko-KR"], preferredLocalizations: []),
            .traditionalChinese
        )
    }

    /// 沒有簡體資源，硬要分只會讓簡中用戶掉到英文 —— 任何 `zh` 都收斂到繁中。
    func test_languageTag_simplifiedChineseFallsToTraditional() {
        XCTAssertEqual(SupportedLanguage(languageTag: "zh-Hans-CN"), .traditionalChinese)
    }

    func test_languageTag_rejectsUnsupportedLanguage() {
        XCTAssertNil(SupportedLanguage(languageTag: "ko-KR"))
        XCTAssertNil(SupportedLanguage(languageTag: ""))
    }
}
