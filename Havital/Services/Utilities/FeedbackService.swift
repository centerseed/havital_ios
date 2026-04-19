import Foundation

/// 回報功能 API 服務
/// Uses APICallHelper for unified error handling
class FeedbackService {
    static let shared = FeedbackService()

    // MARK: - Dependencies

    private let apiHelper: APICallHelper

    init(httpClient: HTTPClient = DefaultHTTPClient.shared,
         parser: APIParser = DefaultAPIParser.shared) {
        self.apiHelper = APICallHelper(
            httpClient: httpClient,
            parser: parser,
            moduleName: "FeedbackService"
        )
    }

    // MARK: - Submit Feedback

    /// 提交回報
    /// - Parameters:
    ///   - type: 回報類型（問題/建議）
    ///   - category: 問題分類（必填）
    ///   - description: 描述內容
    ///   - email: Email（必填，可為空字串表示隱藏）
    ///   - images: 圖片陣列（base64 編碼）
    /// - Returns: FeedbackResponse
    func submitFeedback(
        type: FeedbackType,
        category: FeedbackCategory,
        description: String,
        email: String,
        images: [String]?
    ) async throws -> FeedbackResponse {
        let appVersion = AppVersionHelper.getAppVersion()
        let deviceInfo = DeviceInfoHelper.getDeviceInfo()

        let request = FeedbackRequest(
            type: type.rawValue,
            category: category.rawValue,
            description: description,
            email: email,
            appVersion: appVersion,
            deviceInfo: deviceInfo,
            images: images
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let body = try encoder.encode(request)

        // Debug: Print full request body
        if let jsonString = String(data: body, encoding: .utf8) {
            Logger.debug("提交回報 JSON: \(jsonString)")
        }
        Logger.debug("提交回報: type=\(type.rawValue), category=\(category.rawValue), description=\(description.prefix(50))...")

        return try await apiHelper.call(FeedbackResponse.self, path: "/feedback/report", method: .POST, body: body)
    }
}
