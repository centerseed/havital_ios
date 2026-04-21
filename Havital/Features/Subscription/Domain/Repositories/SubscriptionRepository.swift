import Foundation

// MARK: - SubscriptionRepository Protocol
/// 訂閱資料存取介面 - Domain Layer
/// 只定義介面，不包含實作細節
protocol SubscriptionRepository {

    /// 取得訂閱狀態（緩存未過期則回傳緩存，否則從 API 取得）
    func getStatus() async throws -> SubscriptionStatusEntity

    /// 強制從 API 刷新訂閱狀態（跳過緩存）
    func refreshStatus() async throws -> SubscriptionStatusEntity

    /// 取得緩存的訂閱狀態（不觸發網路請求）
    /// - Returns: 緩存的狀態，nil 表示從未緩存過；過期資料仍會回傳
    func getCachedStatus() -> SubscriptionStatusEntity?

    /// 清除本地緩存（登出時調用）
    func clearCache()

    // MARK: - ADR-002: 購買介面（RevenueCat 就緒後啟用）

    /// 取得可用訂閱方案列表
    func fetchOfferings() async throws -> [SubscriptionOfferingEntity]

    /// 購買指定訂閱方案
    func purchase(request: SubscriptionPurchaseRequest) async throws -> PurchaseResultEntity

    /// 兌換 Apple Offer Code
    func redeemOfferCode() async throws -> PurchaseResultEntity

    /// 恢復購買記錄
    func restorePurchases() async throws
}

extension SubscriptionRepository {
    func purchase(offeringId: String, packageId: String) async throws -> PurchaseResultEntity {
        try await purchase(
            request: SubscriptionPurchaseRequest(
                offeringId: offeringId,
                packageId: packageId,
                offerType: nil,
                offerIdentifier: nil
            )
        )
    }
}
