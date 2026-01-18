import Foundation

// MARK: - TrainingVersionRouter
/// 訓練計劃版本路由器
/// 職責：根據 User 的 training_version 欄位判斷應使用 V1 或 V2 API
/// 位置：Core Layer（基礎設施）
/// 使用場景：
/// - ViewModel 初始化時決定注入哪個 Repository
/// - 需要根據版本執行不同邏輯的地方
///
/// 版本識別邏輯：
/// - "v2" → 使用 Training Plan V2 API
/// - "v1" 或 null → 使用 Training Plan V1 API（預設）
/// - 錯誤時預設使用 V1（向下相容）
final class TrainingVersionRouter {

    // MARK: - Dependencies

    private let userProfileRepository: UserProfileRepository

    // MARK: - Initialization

    init(userProfileRepository: UserProfileRepository) {
        self.userProfileRepository = userProfileRepository
    }

    // MARK: - Version Detection

    /// 獲取當前使用者的訓練計劃版本
    /// - Returns: "v1" 或 "v2"
    /// - Note: 錯誤時預設返回 "v1" 以保持向下相容
    func getTrainingVersion() async -> String {
        do {
            let user = try await userProfileRepository.getUserProfile()
            let version = user.trainingVersion ?? "v1"
            Logger.debug("[TrainingVersionRouter] User training version: \(version)")
            return version
        } catch {
            Logger.error("[TrainingVersionRouter] Failed to get user profile, defaulting to v1: \(error)")
            return "v1"  // 預設使用 v1 以保持向下相容
        }
    }

    /// 檢查當前使用者是否為 V2 版本
    /// - Returns: true 表示使用 V2，false 表示使用 V1
    func isV2User() async -> Bool {
        return await getTrainingVersion() == "v2"
    }

    /// 檢查當前使用者是否為 V1 版本
    /// - Returns: true 表示使用 V1，false 表示使用 V2
    func isV1User() async -> Bool {
        return await getTrainingVersion() == "v1"
    }
}

// MARK: - DI Registration Extension
extension DependencyContainer {

    /// 註冊 TrainingVersionRouter
    func registerTrainingVersionRouter() {
        let userProfileRepo: UserProfileRepository = resolve()
        let router = TrainingVersionRouter(userProfileRepository: userProfileRepo)
        register(router, for: TrainingVersionRouter.self)
        Logger.debug("[DI] TrainingVersionRouter registered")
    }
}
