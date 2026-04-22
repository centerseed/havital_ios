//
//  RaceEventListView.swift
//  Havital
//
//  賽事列表頁面（可重用於 Onboarding 和目標編輯流程）
//  支援搜尋、地區切換、距離篩選、skeleton loading、預選高亮
//
//  DataSource is a generic @ObservedObject conforming to RacePickerDataSource,
//  removing the hard coupling to OnboardingFeatureViewModel.
//

import SwiftUI

// MARK: - Distance Filter

private enum DistanceFilter: String, CaseIterable {
    case all = "全部"
    case fullMarathon = "全馬"
    case halfMarathon = "半馬"
    case tenK = "10K"
    case fiveK = "5K"
    case other = "其他"

    var localizedTitle: String {
        switch self {
        case .all:          return NSLocalizedString("race_filter.all", comment: "全部")
        case .fullMarathon: return NSLocalizedString("race_filter.full_marathon", comment: "全馬")
        case .halfMarathon: return NSLocalizedString("race_filter.half_marathon", comment: "半馬")
        case .tenK:         return NSLocalizedString("race_filter.10k", comment: "10K")
        case .fiveK:        return NSLocalizedString("race_filter.5k", comment: "5K")
        case .other:        return NSLocalizedString("race_filter.other", comment: "其他")
        }
    }

    func matches(_ distanceKm: Double) -> Bool {
        switch self {
        case .all:          return true
        case .fullMarathon: return abs(distanceKm - 42.195) < 0.1
        case .halfMarathon: return abs(distanceKm - 21.0975) < 0.1
        case .tenK:         return abs(distanceKm - 10.0) < 0.1
        case .fiveK:        return abs(distanceKm - 5.0) < 0.1
        case .other:
            let knownDistances: [Double] = [5.0, 10.0, 21.0975, 42.195]
            return !knownDistances.contains(where: { abs(distanceKm - $0) < 0.1 })
        }
    }

    var accessibilityId: String {
        switch self {
        case .all: return "RaceEventList_Filter_all"
        case .fullMarathon: return "RaceEventList_Filter_full_marathon"
        case .halfMarathon: return "RaceEventList_Filter_half_marathon"
        case .tenK: return "RaceEventList_Filter_10k"
        case .fiveK: return "RaceEventList_Filter_5k"
        case .other: return "RaceEventList_Filter_other"
        }
    }
}

// MARK: - RaceEventListView

struct RaceEventListView<DataSource: RacePickerDataSource>: View {

    @ObservedObject var dataSource: DataSource
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var selectedDistanceFilter: DistanceFilter = .all
    @State private var raceForDistanceSelection: RaceEvent? = nil

    // MARK: - Filtered Races

    private var filteredRaces: [RaceEvent] {
        let today = Date()
        let regionFiltered = dataSource.raceEvents.filter { race in
            // 只隱藏過期賽事（eventDate < today），報名截止的仍顯示
            race.eventDate >= Calendar.current.startOfDay(for: today) &&
            race.region == dataSource.selectedRegion
        }

        let distanceFiltered = selectedDistanceFilter == .all
            ? regionFiltered
            : regionFiltered.filter { race in
                race.distances.contains(where: { selectedDistanceFilter.matches($0.distanceKm) })
            }

        guard !debouncedSearchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return distanceFiltered.sorted(by: { $0.eventDate < $1.eventDate })
        }

        let query = debouncedSearchText.lowercased()
        return distanceFiltered.filter { race in
            race.name.lowercased().contains(query) ||
            race.city.lowercased().contains(query)
        }
        .sorted(by: { $0.eventDate < $1.eventDate })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 地區切換器
            regionPicker
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // 距離篩選 chips
            distanceFilterChips
                .padding(.bottom, 8)

            Divider()

            // 賽事列表
            if dataSource.isLoadingRaces {
                skeletonList
            } else if !dataSource.isRaceAPIAvailable {
                apiFailureView
            } else if filteredRaces.isEmpty {
                emptyStateView
            } else {
                raceList
            }
        }
        .navigationTitle(NSLocalizedString("onboarding.race_event_list_nav_title", comment: "選擇賽事"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: NSLocalizedString("onboarding.race_search_prompt", comment: "搜尋賽事名稱或城市")
        )
        .sheet(item: $raceForDistanceSelection) { race in
            RaceDistanceSelectionSheet(race: race) { distance in
                dataSource.selectRaceEvent(race, distance: distance)
                dismiss()
            }
        }
        .task {
            // 首次進入時，若賽事清單為空則載入
            if dataSource.raceEvents.isEmpty {
                await dataSource.loadCuratedRaces()
            }
        }
        .onChange(of: dataSource.selectedRegion) { _ in
            Task {
                await dataSource.loadCuratedRaces()
            }
        }
        .onChange(of: searchText) { newValue in
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                // 若 sleep 結束時 searchText 已再次變更，則放棄此次更新
                guard searchText == newValue else { return }
                debouncedSearchText = newValue
            }
        }
    }

    // MARK: - Subviews

    private var regionPicker: some View {
        Picker(NSLocalizedString("onboarding.select_region", comment: "地區"), selection: $dataSource.selectedRegion) {
            Text(NSLocalizedString("region.taiwan", comment: "台灣")).tag("tw")
            Text(NSLocalizedString("region.japan", comment: "日本")).tag("jp")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("RaceEventList_RegionPicker")
    }

    private var distanceFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DistanceFilter.allCases, id: \.self) { filter in
                    DistanceFilterChip(
                        title: filter.localizedTitle,
                        isSelected: selectedDistanceFilter == filter,
                        accessibilityId: filter.accessibilityId
                    ) {
                        selectedDistanceFilter = filter
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
    }

    private var raceList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredRaces.enumerated()), id: \.element.id) { index, race in
                    let isSelected = dataSource.preselectedRaceId != nil &&
                                     dataSource.preselectedRaceId == race.raceId
                    RaceEventCard(
                        race: race,
                        isSelected: isSelected,
                        accessibilityId: "RaceEventCard_\(index)"
                    ) {
                        handleRaceSelection(race)
                    }

                    if race.id != filteredRaces.last?.id {
                        Divider()
                            .padding(.leading, 24)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var skeletonList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    RaceEventCardSkeleton()

                    Divider()
                        .padding(.leading, 24)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(AppFont.systemScaled(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            Text(NSLocalizedString("onboarding.race_list_empty", comment: "找不到符合條件的賽事"))
                .font(AppFont.headline())
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var apiFailureView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(AppFont.systemScaled(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            Text(NSLocalizedString("race_picker.api_failure_title", comment: "無法載入賽事資料庫"))
                .font(AppFont.headline())
                .foregroundColor(.secondary)

            Text(NSLocalizedString("race_picker.api_failure_hint", comment: "請使用手動輸入，或稍後再試"))
                .font(AppFont.bodySmall())
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(NSLocalizedString("race_picker.retry", comment: "重試")) {
                Task {
                    await dataSource.loadCuratedRaces()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("RaceEventList_RetryButton")

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func handleRaceSelection(_ race: RaceEvent) {
        if race.distances.count == 1, let onlyDistance = race.distances.first {
            // 單一距離：直接選中，dismiss 返回上層
            dataSource.selectRaceEvent(race, distance: onlyDistance)
            dismiss()
        } else {
            // 多距離：彈出距離選擇 Sheet
            raceForDistanceSelection = race
        }
    }
}

// MARK: - DistanceFilterChip

private struct DistanceFilterChip: View {
    let title: String
    let isSelected: Bool
    let accessibilityId: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.caption())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }
}

// MARK: - RaceEventCard

private struct RaceEventCard: View {
    let race: RaceEvent
    let isSelected: Bool
    let accessibilityId: String
    let onTap: () -> Void

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: race.eventDate)
    }

    private var daysUntilString: String {
        let days = race.daysUntilEvent
        if days == 0 {
            return NSLocalizedString("race_card.today", comment: "今天")
        } else if days == 1 {
            return NSLocalizedString("race_card.tomorrow", comment: "明天")
        } else {
            return String(format: NSLocalizedString("race_card.days_until", comment: "還有 %d 天"), days)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    // 賽事名稱 + 預選標記
                    HStack(spacing: 6) {
                        Text(race.name)
                            .font(AppFont.headline())
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                                .accessibilityIdentifier("RaceEventCard_Selected_\(race.raceId)")
                        }

                        if race.entryStatus == "closed" {
                            Text(NSLocalizedString("race_card.entry_closed", comment: "報名截止"))
                                .font(AppFont.captionSmall())
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.12))
                                )
                        }
                    }

                    // 城市
                    Label(race.city, systemImage: "mappin.circle.fill")
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)

                    // 日期
                    Label(dateString, systemImage: "calendar")
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)

                    // 距離 badges
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(race.distances.sorted(by: { $0.distanceKm < $1.distanceKm })) { distance in
                                Text(distance.name)
                                    .font(AppFont.captionSmall())
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                // 倒數天數
                VStack(spacing: 2) {
                    Text(daysUntilString)
                        .font(AppFont.captionSmall())
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .multilineTextAlignment(.center)

                    Image(systemName: "chevron.right")
                        .font(AppFont.systemScaled(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.06)
                : Color.clear
        )
        .overlay(
            isSelected
                ? RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                : nil
        )
        .accessibilityIdentifier(accessibilityId)
    }
}

// MARK: - RaceEventCardSkeleton

private struct RaceEventCardSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 180, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 12)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 12)

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 22)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 22)
                }
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 16)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = OnboardingFeatureViewModel()
    NavigationStack {
        RaceEventListView(dataSource: viewModel)
    }
}
