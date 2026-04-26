import SwiftUI

// MARK: - PaywallCardType
/// Identifies which card is currently focused by the user.
/// Used to drive Trial Timeline / Disclosure / CTA switching (AC-07/08/20/21).
enum PaywallCardType: Equatable {
    case defaultYearly
    case defaultMonthly
    case earlyBirdYearly
    case earlyBirdMonthly

    var isYearly: Bool {
        self == .defaultYearly || self == .earlyBirdYearly
    }
}

// MARK: - PaywallView

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @ObservedObject private var subscriptionState = SubscriptionStateManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showPurchaseSuccess = false

    /// Focused card — drives Trial Timeline, Disclosure, and CTA copy.
    /// Default = .defaultYearly (AC-07: Yearly card pre-selected on open).
    @State private var focusedCard: PaywallCardType = .defaultYearly

    init(trigger: PaywallTrigger) {
        _viewModel = StateObject(wrappedValue: PaywallViewModel(trigger: trigger))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Hero
                    heroSection
                        .padding(.top, 12)
                        .padding(.horizontal, 24)

                    // 2. Conditional: Trial Banner (if in Apple intro trial) OR
                    //    Trial Timeline (if Yearly focused and NOT in trial)
                    if viewModel.isInAppleIntroTrial {
                        // AC-PAYWALL-18: trial banner shown during Apple intro trial
                        PaywallTrialBanner(daysRemaining: viewModel.introTrialDaysRemaining ?? 0)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    } else if focusedCard.isYearly {
                        // AC-PAYWALL-07: timeline shown when yearly card is focused and not in trial
                        PaywallTrialTimelineView()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // 3. Features 4 groups
                    featuresSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    // 4 + 5. Offerings (Default section + Early-bird section)
                    offeringsSection
                        .padding(.top, 20)
                        .padding(.horizontal, 20)

                    // 6. Disclosure (switches by focused card)
                    disclosureSection
                        .padding(.top, 12)
                        .padding(.horizontal, 20)

                    // 7. Footer: Redeem + Restore
                    Spacer(minLength: 20)

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
                    .padding(.bottom, 8)

                    // AC-PAYWALL-03: Restore Purchases always in footer
                    Button(NSLocalizedString("paywall.restore_purchases", comment: "Restore Purchases")) {
                        Task { try? await viewModel.restorePurchases() }
                    }
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("Paywall_RestoreButton")
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(NSLocalizedString("paywall.premium.nav_title", comment: "Paceriz Premium"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.close", comment: "Close")) { dismiss() }
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("Paywall_CloseButton")
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

    // MARK: - Hero (S02: state-aware — AC-04/05/06)

    private var heroSection: some View {
        VStack(spacing: 10) {
            Text(heroTitle)
                .font(AppFont.systemScaled(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(heroSubtitle)
                .font(AppFont.body())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Paywall_Header")
    }

    private var heroTitle: String {
        switch viewModel.trigger {
        case .resubscribe:
            return NSLocalizedString("paywall.premium.hero.resubscribe.title", comment: "")
        case .changePlan:
            return NSLocalizedString("paywall.premium.hero.change.title", comment: "")
        default:
            return NSLocalizedString("paywall.premium.hero.default.title", comment: "")
        }
    }

    private var heroSubtitle: String {
        switch viewModel.trigger {
        case .resubscribe:
            return NSLocalizedString("paywall.premium.hero.resubscribe.subtitle", comment: "")
        case .changePlan:
            return NSLocalizedString("paywall.premium.hero.change.subtitle", comment: "")
        default:
            return NSLocalizedString("paywall.premium.hero.default.subtitle", comment: "")
        }
    }

    // MARK: - Features comparison table (free vs premium)

    private let freeColWidth: CGFloat = 48
    private let premiumColWidth: CGFloat = 72

    private var featuresSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(maxWidth: .infinity)
                Text(NSLocalizedString("paywall.comparison.header.free", comment: "Free"))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: freeColWidth, alignment: .center)
                Text("Premium")
                    .font(AppFont.caption())
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .frame(width: premiumColWidth, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
            comparisonRow(NSLocalizedString("paywall.comparison.feature.run_tracking", comment: ""), free: true)
            Divider().padding(.leading, 14)
            comparisonRow(NSLocalizedString("paywall.comparison.feature.training_metrics", comment: ""), free: true)
            Divider().padding(.leading, 14)
            comparisonRow(NSLocalizedString("paywall.comparison.feature.ai_plan", comment: ""), free: false)
            Divider().padding(.leading, 14)
            comparisonRow(NSLocalizedString("paywall.comparison.feature.ai_advice", comment: ""), free: false)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("Paywall_FeaturesSection")
    }

    private func comparisonRow(_ name: String, free: Bool) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(AppFont.caption())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: free ? "checkmark" : "minus")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(.tertiaryLabel))
                .frame(width: freeColWidth, alignment: .center)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: premiumColWidth, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Offerings (S05: Default + Early-bird — AC-12..17)

    @ViewBuilder
    private var offeringsSection: some View {
        switch viewModel.offerings {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 48)

        case .loaded(let offerings):
            VStack(spacing: 24) {
                // Early-bird section — shown first when eligible (AC-15)
                if viewModel.shouldShowEarlyBirdSection {
                    earlyBirdSection(offerings: offerings)
                        .accessibilityIdentifier("Paywall_EarlyBirdSection")
                }

                // Default section — always shown (AC-12)
                defaultSection()
                    .accessibilityIdentifier("Paywall_DefaultSection")
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

    // MARK: - Default Section (AC-12/13/14)

    @ViewBuilder
    private func defaultSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("paywall.premium.section.default.title", comment: ""))
                    .font(AppFont.systemScaled(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("Paywall_DefaultSectionTitle")

                Text(NSLocalizedString("paywall.premium.section.default.subtitle", comment: ""))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            let defaultPackages = viewModel.defaultPackages
            let defaultYearly = defaultPackages.first(where: { $0.package.period == .yearly })
            let defaultMonthly = defaultPackages.first(where: { $0.package.period == .monthly })

            VStack(spacing: 12) {
                if let defaultYearly {
                    YearlyCard(
                        displayPackage: defaultYearly,
                        cardSubtitle: String(
                            format: NSLocalizedString("paywall.premium.plan.trial_format", comment: ""),
                            "30"
                        ),
                        actionTitle: NSLocalizedString("paywall.premium.cta.start_trial", comment: ""),
                        isFocused: focusedCard == .defaultYearly,
                        purchaseState: viewModel.purchaseState,
                        onTap: {
                            focusedCard = .defaultYearly
                            Task {
                                await viewModel.purchase(
                                    request: SubscriptionPurchaseRequest(
                                        offeringId: Constants.IAP.defaultOfferingIdentifier,
                                        packageId: defaultYearly.package.id,
                                        offerType: nil,
                                        offerIdentifier: nil
                                    )
                                )
                            }
                        }
                    )
                }
                if let defaultMonthly {
                    MonthlyCard(
                        displayPackage: defaultMonthly,
                        cardSubtitle: NSLocalizedString("paywall.premium.plan.no_trial_format", comment: ""),
                        actionTitle: NSLocalizedString("paywall.premium.cta.subscribe_now", comment: ""),
                        isFocused: focusedCard == .defaultMonthly,
                        purchaseState: viewModel.purchaseState,
                        onTap: {
                            focusedCard = .defaultMonthly
                            Task {
                                await viewModel.purchase(
                                    request: SubscriptionPurchaseRequest(
                                        offeringId: Constants.IAP.defaultOfferingIdentifier,
                                        packageId: defaultMonthly.package.id,
                                        offerType: nil,
                                        offerIdentifier: nil
                                    )
                                )
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Early-Bird Section (AC-15/16/17)

    @ViewBuilder
    private func earlyBirdSection(offerings: [SubscriptionOfferingEntity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(NSLocalizedString("paywall.premium.section.earlybird.title", comment: ""))
                        .font(AppFont.systemScaled(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(NSLocalizedString("paywall.section.early_bird.badge_limited_time", comment: "Limited Time"))
                        .font(AppFont.caption2())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("Paywall_LimitedTimeBadge")
                }

                Text(NSLocalizedString("paywall.premium.section.earlybird.subtitle", comment: ""))
                    .font(AppFont.caption())
                    .foregroundColor(.secondary)
            }

            let allPackages = viewModel.displayPackages
            let yearly = allPackages.first(where: { $0.package.period == .yearly })
            let monthly = allPackages.first(where: { $0.package.period == .monthly })
            let currentOfferingId = viewModel.currentOfferingId(from: offerings)

            VStack(spacing: 12) {
                if let yearly {
                    YearlyCard(
                        displayPackage: yearly,
                        cardSubtitle: String(
                            format: NSLocalizedString("paywall.premium.plan.trial_format", comment: ""),
                            "30"
                        ),
                        actionTitle: NSLocalizedString("paywall.premium.cta.start_trial", comment: ""),
                        isFocused: focusedCard == .earlyBirdYearly,
                        purchaseState: viewModel.purchaseState,
                        onTap: {
                            focusedCard = .earlyBirdYearly
                            Task {
                                await viewModel.purchase(
                                    request: SubscriptionPurchaseRequest(
                                        offeringId: currentOfferingId,
                                        packageId: yearly.package.id,
                                        offerType: yearly.package.officialOffer?.type,
                                        offerIdentifier: yearly.package.officialOffer?.offerIdentifier
                                    )
                                )
                            }
                        }
                    )
                }
                if let monthly {
                    MonthlyCard(
                        displayPackage: monthly,
                        cardSubtitle: NSLocalizedString("paywall.premium.plan.no_trial_format", comment: ""),
                        actionTitle: NSLocalizedString("paywall.premium.cta.subscribe_now", comment: ""),
                        isFocused: focusedCard == .earlyBirdMonthly,
                        purchaseState: viewModel.purchaseState,
                        onTap: {
                            focusedCard = .earlyBirdMonthly
                            Task {
                                await viewModel.purchase(
                                    request: SubscriptionPurchaseRequest(
                                        offeringId: currentOfferingId,
                                        packageId: monthly.package.id,
                                        offerType: monthly.package.officialOffer?.type,
                                        offerIdentifier: monthly.package.officialOffer?.offerIdentifier
                                    )
                                )
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Disclosure (S05: switches by focused card — AC-20/21)

    private var disclosureSection: some View {
        let key = focusedCard.isYearly
            ? "paywall.premium.disclosure.trial"
            : "paywall.premium.disclosure.standard"
        return Text(NSLocalizedString(key, comment: ""))
            .font(AppFont.caption2())
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("Paywall_Disclosure")
    }

    // MARK: - Helpers (kept for early-bird section)

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

    private func localizedBillingCycle(for package: SubscriptionPackageEntity) -> String {
        let unitKey: String
        switch package.billingPeriodUnit {
        case .day:   unitKey = "paywall.disclosure.cycle.day"
        case .week:  unitKey = "paywall.disclosure.cycle.week"
        case .month: unitKey = "paywall.disclosure.cycle.month"
        case .year:  unitKey = "paywall.disclosure.cycle.year"
        }
        let unitText = NSLocalizedString(unitKey, comment: "billing cycle unit")
        let value = max(1, package.billingPeriodValue)
        if value == 1 { return unitText }
        return String(
            format: NSLocalizedString("paywall.disclosure.cycle.multiple", comment: "%d %@"),
            value,
            unitText
        )
    }
}

// MARK: - YearlyCard

private struct YearlyCard: View {
    let displayPackage: PaywallDisplayPackage
    let cardSubtitle: String
    let actionTitle: String
    let isFocused: Bool
    let purchaseState: PurchaseState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Early-bird top banner
                if displayPackage.isEarlyBird {
                    HStack {
                        Spacer()
                        Text("⚡  \(NSLocalizedString("paywall.badge.early_bird", comment: "早鳥限定"))  ⚡")
                            .font(AppFont.systemScaled(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .kerning(0.5)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .background(Color(red: 0.82, green: 0.32, blue: 0.0))
                } else {
                    // Recommended badge for default yearly
                    HStack {
                        Spacer()
                        Text(NSLocalizedString("paywall.premium.plan.annual.badge_recommended", comment: "RECOMMENDED"))
                            .font(AppFont.systemScaled(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .kerning(0.5)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .background(Color(red: 0.82, green: 0.32, blue: 0.0))
                }

                // Card body
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("paywall.premium.plan.annual.label", comment: ""))
                            .font(AppFont.systemScaled(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))

                        // Early-bird line-through original price
                        if displayPackage.isEarlyBird, let originalPrice = displayPackage.originalPriceLineThrough {
                            Text(originalPrice)
                                .font(AppFont.caption())
                                .foregroundColor(.white.opacity(0.72))
                                .strikethrough(true, color: .white.opacity(0.72))
                                .accessibilityLabel(
                                    String(
                                        format: NSLocalizedString("paywall.accessibility.original_price", comment: "Original price %@"),
                                        originalPrice
                                    )
                                )
                        }

                        Text(displayPackage.displayPrice)
                            .font(AppFont.systemScaled(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .accessibilityIdentifier("Paywall_YearlyPrice")

                        Text(cardSubtitle)
                            .font(AppFont.caption())
                            .foregroundColor(.white.opacity(0.85))

                        if displayPackage.isEarlyBird {
                            Text(NSLocalizedString("paywall.section.early_bird.lock_forever_subtitle", comment: ""))
                                .font(AppFont.caption())
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    if case .purchasing = purchaseState, isFocused {
                        ProgressView().tint(.white)
                    } else {
                        Text(actionTitle)
                            .font(AppFont.caption2())
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.95, green: 0.42, blue: 0.0))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
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
        .shadow(
            color: Color.orange.opacity(isFocused ? 0.5 : 0.2),
            radius: isFocused ? 12 : 6,
            x: 0,
            y: 4
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isFocused ? 0.6 : 0.0), lineWidth: 2)
        )
    }
}

// MARK: - MonthlyCard

private struct MonthlyCard: View {
    let displayPackage: PaywallDisplayPackage
    let cardSubtitle: String
    let actionTitle: String
    let isFocused: Bool
    let purchaseState: PurchaseState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(NSLocalizedString("paywall.premium.plan.monthly.label", comment: ""))
                            .font(AppFont.systemScaled(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        if displayPackage.isEarlyBird {
                            Text(NSLocalizedString("paywall.offer.badge_early_bird", comment: "早鳥方案"))
                                .font(AppFont.caption2())
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                                .accessibilityIdentifier("Paywall_EarlyBirdBadge_Monthly")
                        }
                    }

                    // Early-bird line-through original price
                    if displayPackage.isEarlyBird, let originalPrice = displayPackage.originalPriceLineThrough {
                        Text(originalPrice)
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                            .strikethrough(true, color: .secondary)
                            .accessibilityLabel(
                                String(
                                    format: NSLocalizedString("paywall.accessibility.original_price", comment: "Original price %@"),
                                    originalPrice
                                )
                            )
                    }

                    Text(displayPackage.displayPrice)
                        .font(AppFont.systemScaled(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("Paywall_MonthlyPrice")

                    Text(cardSubtitle)
                        .font(AppFont.caption())
                        .foregroundColor(.secondary)
                }
                Spacer()
                if case .purchasing = purchaseState, isFocused {
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
                    .stroke(isFocused ? Color.orange : Color(.separator), lineWidth: isFocused ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Paywall_MonthlyOption")
        .opacity(isFocused ? 1.0 : 0.85)
    }
}
