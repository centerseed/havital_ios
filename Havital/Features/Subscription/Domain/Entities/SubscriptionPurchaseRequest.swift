import Foundation

struct SubscriptionPurchaseRequest {
    let offeringId: String
    let packageId: String
    let offerType: SubscriptionOfferType?
}
