//
//  XCTestCase+WaitUntil.swift
//  HavitalTests
//
//  等待非同步條件成立的共用 helper（T-0461）。
//
//  為什麼要有這支：測試等非同步結果時如果寫成「固定 Task.sleep 然後斷言」，
//  那個秒數就是在賭機器夠快。全套跑起來負載一高就翻車，於是 suite 長期以
//  TEST FAILED 收尾、失敗的測試名每次還不一樣——gate 紅得沒有訊息量。
//  輪詢條件則是快時立刻返回、慢時才等到 timeout，兩邊都對。
//
//  收斂自三份一模一樣的 private 複本（AnnouncementViewModelTests、
//  MessageCenterViewExpansionTests、GlobalInterruptQueueACTests），
//  那三份已改為引用這裡。
//

import XCTest

extension XCTestCase {

    /// 輪詢直到 `condition` 成立；逾時則 `XCTFail`。
    ///
    /// - Parameters:
    ///   - timeout: 最長等待時間。預設 2 秒——夠一般背景 Task 完成，
    ///     又不會讓真正壞掉的測試拖著整套跑。
    ///   - pollInterval: 兩次檢查之間的間隔，預設 50ms。
    ///   - message: 逾時訊息，用來指出等的是什麼條件。
    func waitUntil(
        timeout: TimeInterval = 2.0,
        pollInterval: UInt64 = 50_000_000,
        message: String = "Timed out waiting for condition",
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @escaping @MainActor () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }

        // 最後再看一次：剛好卡在 deadline 那一刻成立的情況不該算失敗。
        if await condition() {
            return
        }

        XCTFail(message, file: file, line: line)
    }
}
