import Foundation

// MARK: - RaceRemoteDataSourceProtocol
protocol RaceRemoteDataSourceProtocol {
    /// 查詢賽事列表
    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> RaceListResponseDTO
}

// MARK: - RaceRemoteDataSource
/// 賽事遠端資料來源 - Data Layer
/// 負責 GET /v2/races API 呼叫
final class RaceRemoteDataSource: RaceRemoteDataSourceProtocol {

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    // MARK: - Initialization

    init(
        httpClient: HTTPClient = DefaultHTTPClient.shared,
        parser: APIParser = DefaultAPIParser.shared
    ) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "RaceRemoteDS"
        )
    }

    // MARK: - API Methods

    /// 查詢賽事列表
    /// API: GET /v2/races
    /// - Parameters:
    ///   - region: 地區（tw / jp），nil 為全部
    ///   - distanceMin: 距離下限（km）
    ///   - distanceMax: 距離上限（km）
    ///   - dateFrom: 起始日期（YYYY-MM-DD）
    ///   - dateTo: 結束日期（YYYY-MM-DD）
    ///   - query: 賽事名稱關鍵字搜尋
    ///   - curatedOnly: 只回傳精選賽事
    ///   - limit: 每頁數量（1–200）
    ///   - offset: 分頁偏移
    /// - Returns: 賽事列表回應 DTO
    func getRaces(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) async throws -> RaceListResponseDTO {
        let path = buildPath(
            region: region,
            distanceMin: distanceMin,
            distanceMax: distanceMax,
            dateFrom: dateFrom,
            dateTo: dateTo,
            query: query,
            curatedOnly: curatedOnly,
            limit: limit,
            offset: offset
        )

        Logger.debug("[RaceRemoteDS] getRaces: GET \(path)")

        let response = try await tracked("RaceRemoteDS: getRaces") {
            try await apiHelper.get(RaceListResponseDTO.self, path: path)
        }

        Logger.info("[RaceRemoteDS] getRaces: \(response.races.count) races fetched (total=\(response.total))")
        return response
    }

    // MARK: - Private Helpers

    /// 組裝帶 query string 的 API path
    private func buildPath(
        region: String?,
        distanceMin: Double?,
        distanceMax: Double?,
        dateFrom: String?,
        dateTo: String?,
        query: String?,
        curatedOnly: Bool?,
        limit: Int?,
        offset: Int?
    ) -> String {
        var params: [String] = []

        if let region = region { params.append("region=\(region)") }
        if let distanceMin = distanceMin { params.append("distance_min=\(distanceMin)") }
        if let distanceMax = distanceMax { params.append("distance_max=\(distanceMax)") }
        if let dateFrom = dateFrom { params.append("date_from=\(dateFrom)") }
        if let dateTo = dateTo { params.append("date_to=\(dateTo)") }
        if let query = query, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            params.append("q=\(encoded)")
        }
        if let curatedOnly = curatedOnly { params.append("curated_only=\(curatedOnly)") }
        if let limit = limit { params.append("limit=\(limit)") }
        if let offset = offset { params.append("offset=\(offset)") }

        let basePath = "/v2/races"
        guard !params.isEmpty else { return basePath }
        return "\(basePath)?\(params.joined(separator: "&"))"
    }
}
