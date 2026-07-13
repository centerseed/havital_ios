import Foundation
import XCTest
@testable import paceriz_dev

/// Pins the app's localization bundle for tests that assert on user-facing zh-Hant text.
///
/// `LanguageManager` swizzles `Bundle.main` so that `NSLocalizedString` resolves against the
/// language the *user* picked, not the device locale. In a unit-test host nobody picks one, so
/// resolution falls back to whatever the simulator happens to be set to — which is why the
/// dialog-builder and HRV suites started returning English after the i18n pass (76d88aee) turned
/// their hardcoded zh-TW sentences into `NSLocalizedString` lookups.
///
/// Pinning here restores determinism: the assertions are about *composition* (does the builder
/// slot the score and status into the right template), and they were written against zh-Hant.
enum AppLanguagePin {
    static func traditionalChinese() {
        Bundle.setLanguage("zh-Hant")
    }
}

/// Base class for suites whose expected values are zh-Hant strings.
class ZhHantLocalizedTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLanguagePin.traditionalChinese()
    }
}
