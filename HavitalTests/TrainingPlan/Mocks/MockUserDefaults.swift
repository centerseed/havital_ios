//
//  MockUserDefaults.swift
//  HavitalTests
//
//  Mock UserDefaults for unit testing - isolates tests from real storage
//

import Foundation

/// Mock UserDefaults for unit testing
/// - Stores data in memory instead of persisting
/// - Allows isolated tests without affecting real UserDefaults
final class MockUserDefaults: UserDefaults {

    // MARK: - Storage

    private var storage: [String: Any] = [:]

    // MARK: - Initialization

    init() {
        // Use a random suite name to ensure isolation
        super.init(suiteName: "MockUserDefaults_\(UUID().uuidString)")!
    }

    // MARK: - Overrides

    override func set(_ value: Any?, forKey defaultName: String) {
        if let value = value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }

    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }

    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }

    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }

    override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }

    override func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }

    override func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] {
        return storage
    }

    // MARK: - Helper Methods

    /// Clear all stored data
    func clear() {
        storage.removeAll()
    }

    /// Get all keys in storage
    var allKeys: [String] {
        Array(storage.keys)
    }

    /// Check if a key exists
    func hasKey(_ key: String) -> Bool {
        storage.keys.contains(key)
    }
}
