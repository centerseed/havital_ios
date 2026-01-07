//
//  HavitalUITests.swift
//  HavitalUITests
//
//  Created by 吳柏宗 on 2024/12/9.
//

import XCTest

final class HavitalUITests: XCTestCase {

    override func setUpWithError() throws {
        // 在 UI 測試中，通常希望一旦失敗就立即停止
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // 每個測試結束後的清理代碼
    }

    @MainActor
    func testAppLaunchAndVerifyUI() throws {
        // UI 測試必須啟動應用
        let app = XCUIApplication()
        app.launch()

        // 驗證應用是否已啟動
        XCTAssertTrue(app.exists, "應用應該成功啟動")
        
        // 示例：查找 Tab Bar (如果有的話)
        // 提示：在 SwiftUI 中，為 View 添加 .accessibilityIdentifier("MyID") 可以更容易找到元素
        // let tabBar = app.tabBars.firstMatch
        // if tabBar.exists {
        //     XCTAssertTrue(tabBar.exists)
        // }
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // 測量啟動時間
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
