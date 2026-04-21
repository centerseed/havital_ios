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
    let offerIdentifier: String?
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

    /// 將期間長度轉換為天數（用於折扣計算）
    func lengthInDays(value: Int) -> Double {
        let units = Double(max(1, value))
        switch self {
        case .day:   return units
        case .week:  return units * 7
        case .month: return units * 30.4375
        case .year:  return units * 365.25
        }
    }
}
