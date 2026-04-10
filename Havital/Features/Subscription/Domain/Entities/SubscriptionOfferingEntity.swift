import Foundation

// MARK: - SubscriptionOfferingEntity
/// 訂閱方案實體 - Domain Layer
struct SubscriptionOfferingEntity {
    let id: String
    let title: String
    let description: String
    let packages: [SubscriptionPackageEntity]
}

// MARK: - SubscriptionPackageEntity
/// 訂閱套餐實體 - Domain Layer
struct SubscriptionPackageEntity: Identifiable {
    let id: String
    let productId: String
    let localizedPrice: String
    let period: SubscriptionPeriod
}

// MARK: - SubscriptionPeriod
enum SubscriptionPeriod: String {
    case monthly
    case yearly
}
