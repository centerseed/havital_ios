import Foundation

/// 卡片副標的 view-state：由產品實際 `officialOffer` 決定，三態互斥。
enum PaywallCardOfferDisplay: Equatable {
    case freeTrial(durationDays: Int)
    case discount(originalPriceStruck: String, offerPrice: String, durationDays: Int)
    case none
}

/// 純函式：把 `SubscriptionOfficialOffer?` 映射成卡片 view-state。
/// 分流依據 `paymentMode`：freeTrial → 試用；其餘（付費型）→ 折扣。
enum PaywallCardOfferDisplayBuilder {
    static func make(
        offer: SubscriptionOfficialOffer?,
        regularLocalizedPrice: String
    ) -> PaywallCardOfferDisplay {
        guard let offer else { return .none }
        let days = totalDays(offer)
        switch offer.paymentMode {
        case .freeTrial:
            return .freeTrial(durationDays: days)
        case .payUpFront, .payAsYouGo:
            return .discount(
                originalPriceStruck: regularLocalizedPrice,
                offerPrice: offer.localizedPrice,
                durationDays: days
            )
        }
    }

    private static func totalDays(_ offer: SubscriptionOfficialOffer) -> Int {
        let perPeriod = offer.periodUnit.lengthInDays(value: offer.periodValue)
        let total = perPeriod * Double(max(1, offer.numberOfPeriods))
        return Int(total.rounded())
    }
}
