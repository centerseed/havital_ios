import Foundation

/// Service for fetching training readiness data
final class TrainingReadinessService {
    static let shared = TrainingReadinessService()

    // MARK: - Dependencies
    private let httpClient: HTTPClient
    private let parser: APIParser

    private init(httpClient: HTTPClient = DefaultHTTPClient.shared,
                 parser: APIParser = DefaultAPIParser.shared) {
        self.httpClient = httpClient
        self.parser = parser
    }

    // MARK: - API Methods

    /// Get training readiness for a specific date
    /// - Parameters:
    ///   - date: The date to fetch readiness for (YYYY-MM-DD format)
    ///   - forceCalculate: Whether to force recalculation (skip cache)
    /// - Returns: Training readiness response
    func getReadiness(
        date: String,
        forceCalculate: Bool = false
    ) async throws -> TrainingReadinessResponse {
        var path = "/plan/readiness/\(date)"
        if forceCalculate {
            path += "?force_calculate=true"
        }

        return try await makeAPICall(TrainingReadinessResponse.self, path: path)
    }

    /// Get training readiness for today
    /// - Parameter forceCalculate: Whether to force recalculation
    /// - Returns: Training readiness response
    func getTodayReadiness(forceCalculate: Bool = false) async throws -> TrainingReadinessResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        return try await getReadiness(date: todayString, forceCalculate: forceCalculate)
    }

    // MARK: - Private Helper Methods

    /// Unified API call method
    private func makeAPICall<T: Codable>(
        _ type: T.Type,
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) async throws -> T {
        do {
            let rawData = try await httpClient.request(path: path, method: method, body: body)
            return try ResponseProcessor.extractData(type, from: rawData, using: parser)
        } catch let apiError as APIError where apiError.isCancelled {
            throw SystemError.taskCancelled
        } catch {
            throw error
        }
    }
}

// MARK: - Date Helper Extension
extension TrainingReadinessService {
    /// Format Date to API-compatible string
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
