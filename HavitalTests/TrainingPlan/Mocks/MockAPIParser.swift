//
//  MockAPIParser.swift
//  HavitalTests
//
//  Mock API Parser for unit testing
//

import Foundation
@testable import paceriz_dev

/// Mock API Parser for unit testing
/// - Simply uses JSONDecoder to parse data
/// - Can be configured to throw errors for testing error handling
final class MockAPIParser: APIParser {

    // MARK: - Properties

    /// If set, parse will throw this error
    var errorToThrow: Error?

    /// Track parse calls
    private(set) var parseCalls: [(type: Any.Type, dataSize: Int)] = []

    // MARK: - APIParser Protocol

    func parse<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        parseCalls.append((type, data.count))

        if let error = errorToThrow {
            throw error
        }

        let decoder = JSONDecoder()
        // Remove keyDecodingStrategy to match production DefaultAPIParser behavior
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Helper Methods

    /// Reset mock state
    func reset() {
        errorToThrow = nil
        parseCalls.removeAll()
    }

    /// Get the number of parse calls made
    var parseCount: Int {
        parseCalls.count
    }
}
