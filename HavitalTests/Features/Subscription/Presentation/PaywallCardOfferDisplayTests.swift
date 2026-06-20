import XCTest
@testable import paceriz_dev

final class PaywallCardOfferDisplayTests: XCTestCase {

    private func offer(
        type: SubscriptionOfferType,
        mode: SubscriptionOfferPaymentMode,
        localizedPrice: String = "NT$300",
        periodValue: Int = 1,
        periodUnit: SubscriptionOfferPeriodUnit = .month,
        numberOfPeriods: Int = 1
    ) -> SubscriptionOfficialOffer {
        SubscriptionOfficialOffer(
            offerIdentifier: "off1",
            type: type,
            paymentMode: mode,
            price: 300,
            localizedPrice: localizedPrice,
            periodValue: periodValue,
            periodUnit: periodUnit,
            numberOfPeriods: numberOfPeriods
        )
    }

    func test_noOffer_returnsNone() {
        let result = PaywallCardOfferDisplayBuilder.make(offer: nil, regularLocalizedPrice: "NT$1500")
        XCTAssertEqual(result, .none)
    }

    func test_freeTrial_oneMonth_returns30DayTrial() {
        let o = offer(type: .introductory, mode: .freeTrial, periodValue: 1, periodUnit: .month, numberOfPeriods: 1)
        let result = PaywallCardOfferDisplayBuilder.make(offer: o, regularLocalizedPrice: "NT$1500")
        XCTAssertEqual(result, .freeTrial(durationDays: 30))
    }

    func test_introductoryPayUpFront_returnsDiscount() {
        let o = offer(type: .introductory, mode: .payUpFront, localizedPrice: "NT$900", periodValue: 1, periodUnit: .year, numberOfPeriods: 1)
        let result = PaywallCardOfferDisplayBuilder.make(offer: o, regularLocalizedPrice: "NT$1500")
        XCTAssertEqual(result, .discount(originalPriceStruck: "NT$1500", offerPrice: "NT$900", durationDays: 365))
    }

    func test_promotional_payAsYouGo_returnsDiscount() {
        let o = offer(type: .promotional, mode: .payAsYouGo, localizedPrice: "NT$120", periodValue: 1, periodUnit: .month, numberOfPeriods: 3)
        let result = PaywallCardOfferDisplayBuilder.make(offer: o, regularLocalizedPrice: "NT$300")
        XCTAssertEqual(result, .discount(originalPriceStruck: "NT$300", offerPrice: "NT$120", durationDays: 91))
    }

    func test_winBack_payUpFront_returnsDiscount() {
        // winBack 是真實 Apple offer 型別；builder 依 paymentMode 分流 → 付費型應為 .discount
        let o = offer(type: .winBack, mode: .payUpFront, localizedPrice: "NT$800", periodValue: 1, periodUnit: .year, numberOfPeriods: 1)
        let result = PaywallCardOfferDisplayBuilder.make(offer: o, regularLocalizedPrice: "NT$1500")
        XCTAssertEqual(result, .discount(originalPriceStruck: "NT$1500", offerPrice: "NT$800", durationDays: 365))
    }
}
