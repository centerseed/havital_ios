import XCTest

/// AC test stubs for StoreKit Test isolation (P0-21).
///
/// Spec source: cloud/api_service/docs/01-specs/SPEC-iap-subscription.md
/// Each test corresponds to one AC under "P0-21 StoreKit Test 隔離（2026-04-28 新增，iOS）".
///
/// AC-IAP-21-04 (CI lint guard) is implemented as a separate shell script:
/// `apps/ios/Havital/scripts/check_no_storekit_in_main_target.sh`
///
/// Developer must fill each body and confirm it PASSES.
final class StoreKitIsolationTests: XCTestCase {

    /// AC-IAP-21-01:
    /// Given iOS 專案結構，
    /// Then `apps/ios/Havital/Havital/` 目錄下不得存在 `*.storekit` file。
    ///
    /// NOTE: This test verifies the file-system constraint at test runtime
    /// by scanning the Havital source directory for .storekit files.
    func testAC_IAP_21_01_noStoreKitFileInMainTarget() {
        XCTFail("NOT IMPLEMENTED — Developer must fill this test")
    }

    /// AC-IAP-21-02:
    /// Given Xcode `*.xcscheme` files（含 user-specific `xcuserdata/`），
    /// Then 不得在 `Run > Options > StoreKit Configuration` 引用任何 `*.storekit` file。
    ///
    /// NOTE: This test reads xcscheme XML files and asserts no
    /// StoreKitConfiguration key references a .storekit path.
    func testAC_IAP_21_02_noSchemeReferencesStoreKitConfig() {
        XCTFail("NOT IMPLEMENTED — Developer must fill this test")
    }

    /// AC-IAP-21-03:
    /// Given `HavitalUITests/PacerizUITests.storekit` 保留作為 UI test 專用，
    /// When UI test 跑 `SKTestSession`，
    /// Then 必須在 `tearDown` 呼叫 `clearTransactions()` + `resetToDefaultState()` 並驗證。
    ///
    /// NOTE: Inspect HavitalUITests source to confirm tearDown contract is implemented.
    func testAC_IAP_21_03_uitestTearDownClearsTransactions() {
        XCTFail("NOT IMPLEMENTED — Developer must fill this test")
    }
}
