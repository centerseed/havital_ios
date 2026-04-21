import SwiftUI

// MARK: - PaywallView

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackageId: String? = nil
    @State private var showPurchaseSuccess = false

    init(trigger: PaywallTrigger) {
        _viewModel = StateObject(wrappedValue: PaywallViewModel(trigger: trigger))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 12)
                        .padding(.horizontal, 24)

                    if let days = viewModel.trialDaysRemaining {
                        trialBanner(daysRemaining: days)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    featuresSection
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    offeringsSection
                        .padding(.top, 20)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 28)

                    Button {
                        Task { await viewModel.redeemOfferCode() }
                    } label: {
                        Label(
                            NSLocalizedString("paywall.redeem_offer_code", comment: "Redeem Offer Code"),
                            systemImage: "ticket"
                        )
                        .font(AppFont.bodySmall())
                    }
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("Paywall_RedeemOfferCodeButton")
                    .padding(.bottom, viewModel.shouldShowRestoreButton ? 8 : 24)

                    if viewModel.shouldShowRestoreButton {
                        Button(NSLocalizedString("paywall.restore_purchases", comment: "Restore Purchases")) {
                            Task { try? await viewModel.restorePurchases() }
                        }
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("Paywall_RestoreButton")
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.close", comment: "Close")) { dismiss() }
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("Paywall_CloseButton")
                }
                ToolbarItem(placement: .principal) {
                    Text(NSLocalizedString("paywall.title", comment: "Upgrade"))
                        .font(AppFont.headline())
                }
            }
            .task { await viewModel.loadOfferings() }
            .onAppear { viewModel.trackPaywallView() }
            .onChange(of: viewModel.purchaseState) { _, newState in
                if case .success = newState {
                    showPurchaseSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if showPurchaseSuccess { dismiss() }
                    }
                }
            }
            .overlay {
                if showPurchaseSuccess {
                    purchaseSuccessOverlay
                }
            }
            .alert(
                NSLocalizedString("paywall.purchase_error_title", comment: "Purchase Error"),
                isPresented: Binding(
                    get: {
                        if case .failed = viewModel.purchaseState { return true }
                        return false
                    },
                    set: { isPresented in
                        if !isPresented { viewModel.purchaseState = .idle }
                    }
                )
            ) {
                Button(NSLocalizedString("common.ok", comment: "OK")) {
                    viewModel.purchaseState = .idle
                }
            } message: {
                if case .failed(let message) = viewModel.purchaseState {
                    Text(message)
                }
            }
        }
    }

    // MARK: - Purchase Success Overlay

    private var purchaseSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppFont.systemScaled(size: 64))
                    .foregroundColor(.green)

                Text(NSLocalizedString("paywall.purchase_success_title", comment: "Purchase Successful"))
                    .font(AppFont.systemScaled(size: 22, weight: .bold, design: .rounded))

                if let planName = subscriptionState.currentStatus?.planType {
                    Text(planName)
                        .font(AppFont.subheadline())
                        .foregroundColor(.secondary)
                }

                if viewModel.trigger == .featureLocked || viewModel.trigger == .trialExpired,
                   let status = subscriptionState.currentStatus,
                   status.status == .trial {
                    Text(NSLocalizedString("paywall.purchase_success_trial_note", comment: "Paid plan activates after trial ends"))
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    dismiss()
                } label: {
                    Text(NSLocalizedString("paywall.purchase_success_start", comment: "Start Using"))
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .accessibilityIdentifier("Paywall_StartUsingButton")
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: showPurchaseSuccess)
        .accessibilityIdentifier("Paywall_SuccessOverlay")
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.2), Color.orange.opacity(0.05)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "trophy.fill")
                    .font(AppFont.systemScaled(size: 38, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.7, blue: 0.1), Color(red: 0.95, green: 0.45, blue: 0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text(headerTitle)
                .font(AppFont.systemScaled(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("paywall.subtitle", comment: "解鎖專屬訓練計畫，突破個人極限"))
                .font(AppFont.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Paywall_Header")
    }

    private var headerTitle: String {
        switch viewModel.trigger {
        case .apiGated:      return NSLocalizedString("paywall.header.api_gated", comment: "")
        case .trialExpired:  return NSLocalizedString("paywall.header.trial_expired", comment: "")
        case .featureLocked: return NSLocalizedString("paywall.header.feature_locked", comment: "")
        case .resubscribe:   return NSLocalizedString("paywall.header.resubscribe", comment: "")
        case .changePlan:    return NSLocalizedString("paywall.header.change_plan", comment: "")
        }
    }

    // MARK: - Trial Banner

    private func trialBanner(daysRemaining: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill").foregroundColor(.orange)
            Text(String(format: NSLocalizedString("paywall.trial_days_remaining", comment: ""), daysRemaining))
                .font(AppFont.subheadline())
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(icon: "figure.run",
                       text: NSLocalizedString("paywall.feature.training_plan", comment: ""))
            Divider().padding(.leading, 38)
            FeatureRow(icon: "chart.line.uptrend.xyaxis",
                       text: NSLocalizedString("paywall.feature.analytics", comment: ""))
            Divider().padding(.leading, 38)
            FeatureRow(icon: "slider.horizontal.3",
                       text: NSLocalizedString("paywall.feature.customization", comment: ""))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Offerings

    @ViewBuilder
    private var offeringsSection: some View {
        switch viewModel.offerings {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 48)

        case .loaded(let offerings):
            VStack(spacing: 12) {
                let allPackages = offerings.flatMap { $0.packages }
                let yearly = allPackages.first(where: { $0.period == .yearly })
                let monthly = allPackages.first(where: { $0.period == .monthly })

                if let yearly,
                   let yearlyOfferingId = offerings.first(where: { $0.packages.contains { $0.id == yearly.id } })?.id {
                    let offerInfo = officialOfferDisplayInfo(for: yearly)
                    YearlyCard(package: yearly,
                               offerInfo: offerInfo,
                               actionTitle: purchaseActionTitle(for: yearly),
                               isSelected: selectedPackageId == yearly.id,
                               purchaseState: viewModel.purchaseState) {
                        selectedPackageId = yearly.id
                        Task {
                            await viewModel.purchase(
                                request: SubscriptionPurchaseRequest(
                                    offeringId: yearlyOfferingId,
                                    packageId: yearly.id,
                                    offerType: yearly.officialOffer?.type,
                                    offerIdentifier: yearly.officialOffer?.offerIdentifier
                                )
                            )
                        }
                    }
                }
                if let monthly,
                   let monthlyOfferingId = offerings.first(where: { $0.packages.contains { $0.id == monthly.id } })?.id {
                    let offerInfo = officialOfferDisplayInfo(for: monthly)
                    MonthlyCard(package: monthly,
                                offerInfo: offerInfo,
                                actionTitle: purchaseActionTitle(for: monthly),
                                isSelected: selectedPackageId == monthly.id,
                                purchaseState: viewModel.purchaseState) {
                        selectedPackageId = monthly.id
                        Task {
                            await viewModel.purchase(
                                request: SubscriptionPurchaseRequest(
                                    offeringId: monthlyOfferingId,
                                    packageId: monthly.id,
                                    offerType: monthly.officialOffer?.type,
                                    offerIdentifier: monthly.officialOffer?.offerIdentifier
                                )
                            )
                        }
                    }
                }
            }

        case .error:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(AppFont.title2()).foregroundColor(.secondary)
                Text(NSLocalizedString("paywall.offerings_unavailable", comment: ""))
                    .foregroundColor(.secondary).font(AppFont.subheadline()).multilineTextAlignment(.center)
            }
            .padding(.vertical, 32)
            .accessibilityIdentifier("Paywall_OfferingsUnavailable")

        case .empty:
            Text(NSLocalizedString("paywall.offerings_coming_soon", comment: ""))
                .foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 32)
        }
    }

    private func officialOfferText(for package: SubscriptionPackageEntity) -> String? {
        guard let offer = package.officialOffer else { return nil }
        let durationText = localizedOfferDuration(offer)

        switch offer.type {
        case .introductory:
            switch offer.paymentMode {
            case .freeTrial:
                return String(
                    format: NSLocalizedString("paywall.offer.intro_free_trial", comment: "Free trial for %@"),
                    durationText
                )
            case .payAsYouGo:
                return String(
                    format: NSLocalizedString("paywall.offer.intro_pay_as_you_go", comment: "Intro offer %@ / %@"),
                    offer.localizedPrice,
                    durationText
                )
            case .payUpFront:
                return String(
                    format: NSLocalizedString("paywall.offer.intro_pay_up_front", comment: "Intro offer %@ for %@"),
                    offer.localizedPrice,
                    durationText
                )
            }
        case .promotional:
            return String(
                format: NSLocalizedString("paywall.offer.promotional", comment: "Promotional offer %@ for %@"),
                offer.localizedPrice,
                durationText
            )
        case .winBack:
            return String(
                format: NSLocalizedString("paywall.offer.win_back", comment: "Win-back offer %@ for %@"),
                offer.localizedPrice,
                durationText
            )
        }
    }

    private func officialOfferDisplayInfo(for package: SubscriptionPackageEntity) -> OfficialOfferDisplayInfo? {
        guard let offer = package.officialOffer,
              let detailText = officialOfferText(for: package) else { return nil }

        let displayPriceText: String = {
            switch offer.paymentMode {
            case .freeTrial:
                return NSLocalizedString("paywall.offer.free", comment: "Free")
            case .payAsYouGo, .payUpFront:
                return offer.localizedPrice
            }
        }()

        let discountPercentText = officialDiscountPercent(for: package).map {
            String(format: NSLocalizedString("paywall.offer.discount_percent", comment: "Official discount %d%%"), $0)
        }

        return OfficialOfferDisplayInfo(
            displayPriceText: displayPriceText,
            originalPriceText: package.localizedPrice,
            detailText: detailText,
            discountPercentText: discountPercentText,
            endDateText: nil
        )
    }

    private func localizedOfferDuration(_ offer: SubscriptionOfficialOffer) -> String {
        let totalUnits = max(1, offer.periodValue) * max(1, offer.numberOfPeriods)
        switch offer.periodUnit {
        case .day:
            return String(format: NSLocalizedString("paywall.offer.duration.day", comment: "%d day(s)"), totalUnits)
        case .week:
            return String(format: NSLocalizedString("paywall.offer.duration.week", comment: "%d week(s)"), totalUnits)
        case .month:
            return String(format: NSLocalizedString("paywall.offer.duration.month", comment: "%d month(s)"), totalUnits)
        case .year:
            return String(format: NSLocalizedString("paywall.offer.duration.year", comment: "%d year(s)"), totalUnits)
        }
    }

    private func officialDiscountPercent(for package: SubscriptionPackageEntity) -> Int? {
        guard let offer = package.officialOffer else { return nil }
        if offer.paymentMode == .freeTrial { return 100 }

        let baseDays = package.billingPeriodUnit.lengthInDays(value: package.billingPeriodValue)
        let offerSinglePeriodDays = offer.periodUnit.lengthInDays(value: offer.periodValue)
        let offerTotalPeriods = max(1, offer.numberOfPeriods)
        let offerTotalDays = offerSinglePeriodDays * Double(offerTotalPeriods)

        guard baseDays > 0, offerTotalDays > 0 else { return nil }

        let regularPrice = NSDecimalNumber(decimal: package.price).doubleValue
        let regularTotal = regularPrice * (offerTotalDays / baseDays)

        let offerPrice = NSDecimalNumber(decimal: offer.price).doubleValue
        let offerTotal: Double = {
            switch offer.paymentMode {
            case .payAsYouGo:
                return offerPrice * Double(offerTotalPeriods)
            case .payUpFront:
                return offerPrice
            case .freeTrial:
                return 0
            }
        }()

        guard regularTotal > 0, offerTotal < regularTotal else { return nil }
        let percent = Int(((regularTotal - offerTotal) / regularTotal * 100).rounded())
        return percent > 0 ? percent : nil
    }

    private func purchaseActionTitle(for package: SubscriptionPackageEntity) -> String {
        switch package.officialOffer?.type {
        case .introductory:
            return NSLocalizedString("paywall.cta.start_offer", comment: "Start Offer")
        case .promotional:
            return NSLocalizedString("paywall.cta.claim_offer", comment: "Claim Offer")
        case .winBack:
            return NSLocalizedString("paywall.cta.return_with_offer", comment: "Return with Offer")
        case nil:
            return NSLocalizedString("paywall.cta.subscribe", comment: "Subscribe")
        }
    }

}

private struct OfficialOfferDisplayInfo {
    let displayPriceText: String
    let originalPriceText: String
    let detailText: String
    let discountPercentText: String?
    let endDateText: String?
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppFont.systemScaled(size: 15, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 22)
            Text(text)
                .font(AppFont.subheadline())
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "checkmark")
                .font(AppFont.systemScaled(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - YearlyCard

private struct YearlyCard: View {
    let package: SubscriptionPackageEntity
    let offerInfo: OfficialOfferDisplayInfo?
    let actionTitle: String
    let isSelected: Bool
    let purchaseState: PurchaseState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Best Value Banner
                HStack {
                    Spacer()
                    Text("★  \(NSLocalizedString("paywall.badge.best_value", comment: "最超值"))  ★")
                        .font(AppFont.systemScaled(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .kerning(0.5)
                    Spacer()
                }
                .padding(.vertical, 7)
                .background(Color(red: 0.82, green: 0.32, blue: 0.0))

                // Card Body
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("paywall.plan.yearly", comment: "年訂閱"))
                            .font(AppFont.systemScaled(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        if let offerInfo {
                            Text(
                                String(
                                    format: NSLocalizedString("paywall.plan.original_price", comment: "Original %@"),
                                    offerInfo.originalPriceText
                                )
                            )
                            .font(AppFont.caption())
                            .foregroundColor(.white.opacity(0.72))
                            .strikethrough()
                        }
                        Text(offerInfo?.displayPriceText ?? package.localizedPrice)
                            .font(AppFont.systemScaled(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if let offerInfo {
                            Text(NSLocalizedString("paywall.offer.badge_official", comment: "Official Offer"))
                                .font(AppFont.caption2())
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.95))
                            Text(offerInfo.detailText)
                                .font(AppFont.caption2())
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.9))
                            if let discountPercentText = offerInfo.discountPercentText {
                                Text(discountPercentText)
                                    .font(AppFont.caption2())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            if let endDateText = offerInfo.endDateText {
                                Text(endDateText)
                                    .font(AppFont.caption2())
                                    .foregroundColor(.white.opacity(0.82))
                            }
                        }
                        Text(NSLocalizedString("paywall.plan.yearly_note", comment: "年繳方案說明"))
                            .font(AppFont.caption())
                            .foregroundColor(.white.opacity(0.75))
                    }
                    Spacer()
                    if case .purchasing = purchaseState, isSelected {
                        ProgressView().tint(.white)
                    } else {
                        Text(actionTitle)
                            .font(AppFont.caption())
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.95, green: 0.42, blue: 0.0))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.52, blue: 0.08),
                            Color(red: 0.95, green: 0.42, blue: 0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Paywall_YearlyOption")
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.orange.opacity(0.35), radius: 10, x: 0, y: 4)
    }
}

// MARK: - MonthlyCard

private struct MonthlyCard: View {
    let package: SubscriptionPackageEntity
    let offerInfo: OfficialOfferDisplayInfo?
    let actionTitle: String
    let isSelected: Bool
    let purchaseState: PurchaseState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("paywall.plan.monthly", comment: "月訂閱"))
                        .font(AppFont.systemScaled(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                    if let offerInfo {
                        Text(
                            String(
                                format: NSLocalizedString("paywall.plan.original_price", comment: "Original %@"),
                                offerInfo.originalPriceText
                            )
                        )
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                        .strikethrough()
                    }
                    Text(offerInfo?.displayPriceText ?? package.localizedPrice)
                        .font(AppFont.systemScaled(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    if let offerInfo {
                        Text(NSLocalizedString("paywall.offer.badge_official", comment: "Official Offer"))
                            .font(AppFont.caption2())
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text(offerInfo.detailText)
                            .font(AppFont.caption2())
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        if let discountPercentText = offerInfo.discountPercentText {
                            Text(discountPercentText)
                                .font(AppFont.caption2())
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        if let endDateText = offerInfo.endDateText {
                            Text(endDateText)
                                .font(AppFont.caption2())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                if case .purchasing = purchaseState, isSelected {
                    ProgressView().tint(.orange)
                } else {
                    Text(actionTitle)
                        .font(AppFont.caption())
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Paywall_MonthlyOption")
    }
}
