import XCTest
@testable import paceriz_dev

@MainActor
final class LanguageManagerPreLoginTests: XCTestCase {
    private let languageKey = "app_language_preference"
    private let userSelectedKey = "app_language_user_selected"
    private var originalLanguage: SupportedLanguage!
    private var originalLanguagePreference: String?
    private var originalAppleLanguages: [String]?
    private var originalUserSelected: Bool?

    override func setUp() {
        super.setUp()
        originalLanguage = LanguageManager.shared.currentLanguage
        originalLanguagePreference = UserDefaults.standard.string(forKey: languageKey)
        originalAppleLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages")
        originalUserSelected = UserDefaults.standard.object(forKey: userSelectedKey) as? Bool
        UserDefaults.standard.removeObject(forKey: languageKey)
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        // 「使用者自己選的」這個旗標一定要一起清：`tearDown` 會呼叫
        // `applyPreLoginLanguage` 復原語言，那條路徑會把它設成 true，於是它會殘留到
        // 下一個測試。2026-09-02 換到乾淨的測試模擬器才發現——`explicitLanguage` 的
        // 那條測試一直是靠這個殘留值變綠的。
        UserDefaults.standard.removeObject(forKey: userSelectedKey)
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
        if let originalUserSelected {
            UserDefaults.standard.set(originalUserSelected, forKey: userSelectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userSelectedKey)
        }
        originalLanguage = nil
        originalLanguagePreference = nil
        originalAppleLanguages = nil
        originalUserSelected = nil
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

    // MARK: - 後端語言偏好的回程（backend → 本地）
    //
    // 後端是語言的 SSOT，但只有「讀得到、且真的寫進本地」整條鏈子才成立。
    // 這一段鎖的是唯一會**靜默**失敗的兩處：回應形狀（包不包 `data` envelope）、
    // 以及語言碼（後端給 `zh-TW`，`SupportedLanguage` 的 raw value 是 lproj 名 `zh-Hant`）。

    private func preferencesResponse(_ json: String) -> Data {
        Data(json.utf8)
    }

    func test_parseLanguage_readsEnvelopedBackendShape() {
        let data = preferencesResponse(#"{"success":true,"data":{"language":"ja-JP","timezone":"Asia/Tokyo"}}"#)
        XCTAssertEqual(LanguageManager.parseLanguage(fromPreferencesResponse: data), .japanese)
    }

    func test_parseLanguage_readsTopLevelBackendShape() {
        let data = preferencesResponse(#"{"language":"en-US","timezone":"Asia/Taipei"}"#)
        XCTAssertEqual(LanguageManager.parseLanguage(fromPreferencesResponse: data), .english)
    }

    /// 後端送的是 API code（`zh-TW`），不是 lproj 目錄名（`zh-Hant`）。
    /// 用 `init?(rawValue:)` 讀它會恆為 nil —— 看起來就像「後端沒設語言」。
    func test_parseLanguage_mapsApiCodeNotRawValue() {
        let data = preferencesResponse(#"{"data":{"language":"zh-TW"}}"#)
        XCTAssertEqual(LanguageManager.parseLanguage(fromPreferencesResponse: data), .traditionalChinese)
        XCTAssertNil(SupportedLanguage(rawValue: "zh-TW"))
    }

    func test_parseLanguage_returnsNilWhenLanguageMissingOrUnknown() {
        XCTAssertNil(LanguageManager.parseLanguage(
            fromPreferencesResponse: preferencesResponse(#"{"data":{"timezone":"Asia/Taipei"}}"#)
        ))
        XCTAssertNil(LanguageManager.parseLanguage(
            fromPreferencesResponse: preferencesResponse(#"{"data":{"language":"ko-KR"}}"#)
        ))
        XCTAssertNil(LanguageManager.parseLanguage(fromPreferencesResponse: Data("not json".utf8)))
    }

    /// 讀到值之後真的要寫進本地：`app_language_preference` 換掉、`AppleLanguages` 換掉、
    /// `currentLanguage` 換掉。少任何一項，下次冷啟就又是舊語言。
    func test_applyFromBackend_writesLocalPreferenceWhenBackendDiffers() {
        LanguageManager.shared.applyPreLoginLanguage(.traditionalChinese)
        XCTAssertEqual(UserDefaults.standard.string(forKey: languageKey), "zh-Hant")

        LanguageManager.shared.applyFromBackend(.japanese)

        XCTAssertEqual(LanguageManager.shared.currentLanguage, .japanese)
        XCTAssertEqual(UserDefaults.standard.string(forKey: languageKey), "ja")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "AppleLanguages"), ["ja"])
    }

    /// **從後端套回來的語言不算「使用者親手選的」**（`LanguageManager.markUserSelected`
    /// 只有登入前的語言鈕與設定頁的語言切換會呼叫）。那個旗標的用途是「登入時要不要把
    /// 本地語言推給後端」——後端自己給的值再推回去沒有意義，推錯了反而會蓋掉。
    ///
    /// 這條原本斷言相反（期望它標記成 explicit），靠同 class 其他測試 `tearDown` 留在
    /// UserDefaults 的旗標假綠；2026-09-02 換到乾淨的測試模擬器才露出來。
    func test_applyFromBackend_doesNotMarkLanguageAsUserSelected() {
        LanguageManager.shared.applyFromBackend(.english)

        XCTAssertEqual(LanguageManager.shared.currentLanguage, .english)
        XCTAssertNil(LanguageManager.shared.explicitLanguage)
    }

    /// 對照組：使用者親手選的那條路徑要標記。
    func test_applyPreLoginLanguage_marksLanguageAsUserSelected() {
        LanguageManager.shared.applyPreLoginLanguage(.japanese)

        XCTAssertEqual(LanguageManager.shared.explicitLanguage, .japanese)
    }
}
