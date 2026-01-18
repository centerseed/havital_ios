//
//  URLBuilderHelper.swift
//  Havital
//
//  Created by Clean Architecture Refactoring
//

import Foundation

/// URL Builder Helper
///
/// Core Layer utility for constructing URLs with query parameters.
/// This helper eliminates duplicated URL building logic across RemoteDataSources.
///
/// **Architecture Context**:
/// - Layer: Core (Network Utilities)
/// - Dependencies: Foundation (URLComponents, URLQueryItem)
/// - Used by: Data Layer (RemoteDataSources)
///
/// **Usage Example**:
/// ```swift
/// let queryItems = [URLQueryItem(name: "year", value: "2024")]
/// let path = URLBuilderHelper.buildPath("/v2/workouts", queryItems: queryItems)
/// // Result: "/v2/workouts?year=2024"
/// ```
struct URLBuilderHelper {

    // MARK: - URL Building

    /// Build URL path with query parameters from URLQueryItem array
    ///
    /// - Parameters:
    ///   - basePath: Base path string (e.g., "/v2/workouts")
    ///   - queryItems: Array of URLQueryItem objects
    /// - Returns: Complete URL path with encoded query string
    ///
    /// **Behavior**:
    /// - If queryItems is empty, returns basePath unchanged
    /// - Automatically handles URL encoding via URLComponents
    /// - Returns basePath if URLComponents construction fails
    static func buildPath(_ basePath: String, queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else {
            return basePath
        }

        var components = URLComponents(string: basePath)
        components?.queryItems = queryItems
        return components?.string ?? basePath
    }

    /// Build URL path with query parameters from dictionary
    ///
    /// - Parameters:
    ///   - basePath: Base path string
    ///   - parameters: Dictionary of query parameter key-value pairs
    /// - Returns: Complete URL path with encoded query string
    ///
    /// **Usage Example**:
    /// ```swift
    /// let params = ["year": "2024", "month": "01"]
    /// let path = URLBuilderHelper.buildPath("/v2/stats", parameters: params)
    /// ```
    static func buildPath(_ basePath: String, parameters: [String: String]) -> String {
        let queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        return buildPath(basePath, queryItems: queryItems)
    }
}
