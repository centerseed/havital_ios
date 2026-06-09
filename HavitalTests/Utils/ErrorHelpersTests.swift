//
//  ErrorHelpersTests.swift
//  HavitalTests
//
//  鎖定 Error 擴展的分類行為，特別是 isTransientNetworkError——
//  achievements 逾時降噪（記為 .warn 而非 .error）依賴它正確區分
//  「瞬時網路錯誤」與「真正的問題（decode / server）」。
//

import XCTest
@testable import paceriz_dev

final class ErrorHelpersTests: XCTestCase {

    // MARK: - isTransientNetworkError

    func test_transient_urlError_timeout_and_connection_are_transient() {
        XCTAssertTrue(URLError(.timedOut).isTransientNetworkError)
        XCTAssertTrue(URLError(.networkConnectionLost).isTransientNetworkError)
        XCTAssertTrue(URLError(.notConnectedToInternet).isTransientNetworkError)
    }

    func test_transient_httpError_timeout_and_noConnection_are_transient() {
        XCTAssertTrue(HTTPError.timeout.isTransientNetworkError)
        XCTAssertTrue(HTTPError.noConnection.isTransientNetworkError)
    }

    func test_transient_domainError_timeout_and_noConnection_are_transient() {
        XCTAssertTrue(DomainError.timeout.isTransientNetworkError)
        XCTAssertTrue(DomainError.noConnection.isTransientNetworkError)
    }

    func test_transient_excludes_real_problems() {
        // decode / schema 問題 — 必須維持 .error，不可被當成瞬時網路錯誤吞掉
        let decodeError = DecodingError.keyNotFound(
            DummyKey.success,
            .init(codingPath: [], debugDescription: "missing success")
        )
        XCTAssertFalse(decodeError.isTransientNetworkError)

        // server / 業務錯誤
        XCTAssertFalse(HTTPError.serverError(500, "boom").isTransientNetworkError)
        XCTAssertFalse(HTTPError.unauthorized("401").isTransientNetworkError)
        XCTAssertFalse(URLError(.badServerResponse).isTransientNetworkError)
    }

    func test_transient_excludes_cancellation() {
        // 取消有獨立的 isCancellationError 通道，不應同時被歸為瞬時網路錯誤
        XCTAssertFalse(URLError(.cancelled).isTransientNetworkError)
        XCTAssertFalse(HTTPError.cancelled.isTransientNetworkError)
    }

    // MARK: - isCancellationError 與 isTransientNetworkError 互斥（行為界線）

    func test_cancellation_and_transient_are_disjoint() {
        XCTAssertTrue(URLError(.cancelled).isCancellationError)
        XCTAssertFalse(URLError(.cancelled).isTransientNetworkError)

        XCTAssertTrue(URLError(.timedOut).isTransientNetworkError)
        XCTAssertFalse(URLError(.timedOut).isCancellationError)
    }

    private enum DummyKey: String, CodingKey {
        case success
    }
}
