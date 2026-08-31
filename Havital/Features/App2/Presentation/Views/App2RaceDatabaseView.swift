import SwiftUI

// MARK: - App2RaceDatabaseView
/// 2.0 賽事資料庫 —— 設計 **frame-14「賽事資料庫」**。
///
/// **資料就是 1.x 那一條**（`RaceRepository` → `GET /v2/races`，精選清單）；
/// 這裡只是 2.0 的版面：固定的搜尋列 ＋ 地區三段 ＋ 距離 chip，下面是結果清單。
struct App2RaceDatabaseView: View {

    let onPick: (RaceEvent, App2RaceDatabaseViewModel.DistanceFilter) -> Void
    let onClose: () -> Void

    @StateObject private var viewModel: App2RaceDatabaseViewModel

    /// 這一頁的距離字（非標準賽距的結果列）是 `UnitSystem.current` 現算的，而
    /// `UnitSystem.current` 只讀 UserDefaults、**不驅動重繪**。掛著的時候切換單位
    /// 就會停在舊單位（外審第七輪 D08）。沿用 `App2WorkoutDetailView`／
    /// `TrainingRecordView` 的同一種處置：觀察 `UnitManager`，並把當前單位**顯式**
    /// 傳進格式化函式，讓相依關係看得見。
    @ObservedObject private var unitManager = UnitManager.shared

    init(
        onPick: @escaping (RaceEvent, App2RaceDatabaseViewModel.DistanceFilter) -> Void,
        onClose: @escaping () -> Void,
        viewModel: App2RaceDatabaseViewModel? = nil
    ) {
        self.onPick = onPick
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: viewModel ?? App2RaceDatabaseViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            resultList
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    // MARK: - 固定在頂部的搜尋與篩選

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            App2PageHeader(
                title: L10n.App2.Races.databaseTitle.localized,
                titleSize: 22,
                onBack: onClose,
                backIdentifier: "App2_RaceDatabaseClose",
                titleIdentifier: "App2_RaceDatabaseView"
            ) { EmptyView() }
            .padding(.bottom, 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(App2Theme.inkMuted)
                TextField(L10n.App2.Races.searchPlaceholder.localized, text: $viewModel.query)
                    .font(.system(size: 15, weight: .semibold))
                    .submitLabel(.search)
                    .accessibilityIdentifier("App2_RaceDatabaseSearch")
                    .onChange(of: viewModel.query) { _, _ in viewModel.queryChanged() }
            }
            .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(App2Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
            )
            .padding(.bottom, 12)

            caption(L10n.App2.Races.regionLabel.localized)
            regionSegments.padding(.bottom, 12)

            caption(L10n.App2.Races.filterLabel.localized)
            distanceChips
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(App2Theme.pageTop.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle().fill(App2Theme.insetBorder).frame(height: 1)
        }
    }

    private var regionSegments: some View {
        HStack(spacing: 2) {
            ForEach(App2RaceDatabaseViewModel.Region.allCases) { region in
                let isSelected = viewModel.region == region
                Text(region.titleKey.localized)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(isSelected ? App2Theme.inkPrimary : App2Theme.inkSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSelected ? Color.white : Color.clear)
                            .shadow(
                                color: isSelected ? App2Theme.shadowInk.opacity(0.12) : .clear,
                                radius: 3, x: 0, y: 2
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.region = region
                        viewModel.filtersChanged()
                    }
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier("App2_RaceDatabaseRegion_\(region.rawValue)")
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(App2Theme.shadowInk.opacity(0.05))
        )
    }

    private var distanceChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(App2RaceDatabaseViewModel.DistanceFilter.allCases) { filter in
                    App2OnboardingChip(
                        title: filter.title(unitSystem: unitManager.currentUnitSystem),
                        isSelected: viewModel.distance == filter,
                        fillsWidth: false,
                        cornerRadius: 999,
                        identifier: "App2_RaceDatabaseFilter_\(filter.rawValue)"
                    ) {
                        viewModel.distance = filter
                        viewModel.filtersChanged()
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(App2Theme.inkMuted)
            .padding(EdgeInsets(top: 0, leading: 2, bottom: 6, trailing: 2))
    }

    // MARK: - 結果

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 11) {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                } else if viewModel.results.isEmpty {
                    emptyState
                } else {
                    Text(String(
                        format: L10n.App2.Races.resultCount.localized,
                        viewModel.results.count
                    ))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                    .padding(.horizontal, 2)

                    ForEach(viewModel.results) { event in
                        resultRow(event)
                    }
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    /// 讀不到與「沒有符合的賽事」是兩件事 —— 賽事庫掛掉時不能說「找不到符合的賽事」，
    /// 那會讓使用者一直改關鍵字。壞掉時的兩句話走既有的 `race_picker.api_failure_*`
    /// （1.x 賽事清單在用同一組，三語已齊），不新增同義字。
    private var emptyState: some View {
        VStack(spacing: 4) {
            Text(viewModel.isUnavailable
                 ? NSLocalizedString("race_picker.api_failure_title", comment: "")
                 : L10n.App2.Races.noResultTitle.localized)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(App2Theme.inkSubtle)
            Text(viewModel.isUnavailable
                 ? NSLocalizedString("race_picker.api_failure_hint", comment: "")
                 : L10n.App2.Races.noResultBody.localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(App2Theme.cardBorder, lineWidth: 1)
        )
        .accessibilityIdentifier("App2_RaceDatabaseEmpty")
    }

    private func resultRow(_ event: RaceEvent) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let distance = App2RaceDatabaseViewModel.pickedDistance(
                        event: event,
                        filter: viewModel.distance
                    ) {
                        App2Pill(
                            text: App2OnboardingFormat.distanceLabel(
                                km: distance.distanceKm,
                                unitSystem: unitManager.currentUnitSystem
                            ),
                            foreground: App2Theme.accentBlueDeep,
                            background: App2Theme.accentBlue.opacity(0.1),
                            border: App2Theme.accentBlue.opacity(0.2)
                        )
                    }
                    Text(event.city)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                        .lineLimit(1)
                    Text(App2OnboardingFormat.isoDate(event.eventDate))
                        .font(.app2Mono(13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }

                if event.daysUntilEvent >= 0 {
                    Text("\(L10n.App2.Races.countdown.localized) "
                         + String(
                            format: L10n.App2.Races.countdownDays.localized,
                            event.daysUntilEvent
                         ))
                        .font(.app2Mono(12))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                }
            }
            Spacer(minLength: 4)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(App2Theme.accentBlue.opacity(0.1))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(App2Theme.accentBlueDeep)
                }
        }
        .padding(EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15))
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2CardSurface(cornerRadius: 16)
        .contentShape(Rectangle())
        .onTapGesture { onPick(event, viewModel.distance) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_RaceDatabaseRow_\(event.raceId)")
    }
}
