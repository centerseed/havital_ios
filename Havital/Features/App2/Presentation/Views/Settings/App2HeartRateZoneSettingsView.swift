import SwiftUI

// MARK: - App2HeartRateZoneSettingsView
/// 2.0「心率區間」（設計 frame-26）：最大／靜息心率輸入 ＋ HRR 換算的 Z1–Z5 色條。
///
/// - 區間換算沿用 `App2OnboardingProjection.heartRateBands`（frame-33 同一支），
///   它底下是既有的 `HeartRateZone.calculateZones`。
/// - 儲存走 `App2SettingsViewModel.saveHeartRate` → 既有的 `UpdateHeartRateZonesUseCase`
///   （repository 會寫 `max_heart_rate`／`resting_heart_rate` 並重算快取區間）。
struct App2HeartRateZoneSettingsView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    @State private var maxHR: Int = 190
    @State private var restingHR: Int = 60
    @State private var isSaving = false
    @State private var didLoadInitial = false
    @State private var errorMessage: String?

    /// 設計 frame-26／33 的五條色帶。
    private static let bandColors: [Color] = [
        Color(hex: "#5AA9F0"), Color(hex: "#4FC47E"), Color(hex: "#E0B23A"),
        Color(hex: "#EC8A4C"), Color(hex: "#E5546C")
    ]

    private var bands: [App2OnboardingProjection.HeartRateBand] {
        App2OnboardingProjection.heartRateBands(maxHR: maxHR, restingHR: restingHR)
    }

    private var isValid: Bool { maxHR > restingHR }

    var body: some View {
        App2SettingsPageScaffold(
            title: NSLocalizedString("training.heart_rate_zone", comment: "HR Zone"),
            onBack: onClose,
            backIdentifier: "App2_HeartRateZoneClose",
            titleIdentifier: "App2_HeartRateZoneView",
            ctaTitle: NSLocalizedString("common.save", comment: "Save"),
            ctaEnabled: isValid,
            ctaBusy: isSaving,
            ctaIdentifier: "App2_HeartRateZoneSave",
            ctaAction: { save() }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.App2.Onboarding.hrSubtitle.localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                stepperCard(
                    title: L10n.App2.Onboarding.hrMax.localized,
                    value: $maxHR,
                    range: 120...220,
                    identifier: "App2_HeartRateZoneMax"
                )
                stepperCard(
                    title: L10n.App2.Onboarding.hrResting.localized,
                    value: $restingHR,
                    range: 30...120,
                    identifier: "App2_HeartRateZoneResting"
                )

                bandsSection
            }
        }
        .onAppear(perform: loadInitialIfNeeded)
        .alert(
            NSLocalizedString("error.unknown", comment: ""),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common.ok", comment: "OK")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 數值卡（設計是左值右 −／＋）

    private func stepperCard(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        identifier: String
    ) -> some View {
        App2Card(spacing: 4) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(App2Theme.inkTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(value.wrappedValue)")
                            .font(.app2Numeric(32, weight: .black))
                            .foregroundStyle(App2Theme.inkPrimary)
                        Text(L10n.App2.Onboarding.hrBpm.localized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(App2Theme.inkMuted)
                    }
                }
                Spacer(minLength: 8)
                stepperButton(systemImage: "minus", filled: false, identifier: "\(identifier)Minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                }
                stepperButton(systemImage: "plus", filled: true, identifier: "\(identifier)Plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func stepperButton(
        systemImage: String,
        filled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(filled ? App2Theme.accentBlue : App2Theme.insetBackground)
                .frame(width: 52, height: 46)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(filled ? Color.white : App2Theme.inkSubtle)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 區間色條

    private var bandsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.App2.Onboarding.hrBandsTitle.localized)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)

            HStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.element.id) { index, band in
                    VStack(spacing: 2) {
                        Text("Z\(band.index)")
                            .font(.system(size: 14, weight: .black))
                        Text(band.nameKey.localized)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .background(Self.bandColors[min(index, Self.bandColors.count - 1)].opacity(0.95))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
            .accessibilityIdentifier("App2_HeartRateZoneBands")

            HStack(spacing: 0) {
                ForEach(bands) { band in
                    Text("\(band.upperBpm)")
                        .font(.app2Mono(13, weight: .bold))
                        .foregroundStyle(App2Theme.inkSubtle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Text(L10n.App2.Onboarding.hrBandsFooter.localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 狀態

    private func loadInitialIfNeeded() {
        guard !didLoadInitial else { return }
        didLoadInitial = true
        if let value = viewModel.maxHeartRate, value > 0 { maxHR = value }
        if let value = viewModel.restingHeartRate, value > 0 { restingHR = value }
    }

    private func save() {
        guard !isSaving, isValid else { return }
        isSaving = true
        Task {
            let ok = await viewModel.saveHeartRate(maxHR: maxHR, restingHR: restingHR)
            isSaving = false
            if ok {
                onClose()
            } else {
                errorMessage = NSLocalizedString("error.unknown", comment: "")
            }
        }
    }
}
