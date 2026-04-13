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
    let price: Decimal
    let currencyCode: String?
    let localeIdentifier: String?
    let period: SubscriptionPeriod
    let billingPeriodValue: Int
    let billingPeriodUnit: SubscriptionOfferPeriodUnit
    let officialOffer: SubscriptionOfficialOffer?
}

// MARK: - SubscriptionPeriod
enum SubscriptionPeriod: String {
    case monthly
    case yearly
}

// MARK: - SubscriptionOfficialOffer
struct SubscriptionOfficialOffer {
    let type: SubscriptionOfferType
    let paymentMode: SubscriptionOfferPaymentMode
    let price: Decimal
    let localizedPrice: String
    let periodValue: Int
    let periodUnit: SubscriptionOfferPeriodUnit
    let numberOfPeriods: Int
}

enum SubscriptionOfferType: String {
    case introductory
    case promotional
    case winBack
}

enum SubscriptionOfferPaymentMode: String {
    case payAsYouGo
    case payUpFront
    case freeTrial
}

enum SubscriptionOfferPeriodUnit: String {
    case day
    case week
    case month
    case year
}
