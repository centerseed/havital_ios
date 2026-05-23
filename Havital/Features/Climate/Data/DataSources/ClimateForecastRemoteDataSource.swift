import Foundation

final class ClimateForecastRemoteDataSource {
    private let httpClient: HTTPClient
    private let parser: APIParser
    private let authSessionRepository: AuthSessionRepository

    init(
        httpClient: HTTPClient = DependencyContainer.shared.resolve(),
        parser: APIParser = DefaultAPIParser.shared,
        authSessionRepository: AuthSessionRepository = DependencyContainer.shared.resolve()
    ) {
        self.httpClient = httpClient
        self.parser = parser
        self.authSessionRepository = authSessionRepository
    }

    func fetchForecast(days: Int = 7) async throws -> ClimateForecastResponse {
        let uid = try await resolveCurrentUid()
        let rawData = try await httpClient.request(
            path: "/v1/users/\(uid)/climate/forecast?days=\(days)",
            method: .GET,
            body: nil
        )
        return try ResponseProcessor.extractData(
            ClimateForecastResponse.self,
            from: rawData,
            using: parser
        )
    }

    private func resolveCurrentUid() async throws -> String {
        if let uid = authSessionRepository.getCurrentUser()?.uid {
            return uid
        }

        let currentUser = try await authSessionRepository.fetchCurrentUser()
        return currentUser.uid
    }
}
