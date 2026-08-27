import SwiftUI

// MARK: - App2RecordsView
/// 2.0 紀錄頁 —— 設計 **frame-10「紀錄」**（語意／端點見
/// `DESIGN-app2-decision-chain-api.md` §3.6）。
///
/// 版面：標題「訓練紀錄」＋ 右上日曆鈕 → hero 藍卡（近 30 天／今年累積雙欄 ＋
/// 近 8 週趨勢柱）→ 課型篩選 chip 列 → 依日期分組的紀錄（組標題帶「N 次跑步 ·
/// 共 X km」小計）→ 每筆紀錄白卡（左緣課型色、課型徽章 ＋ VDOT 徽章、距離／配速／
/// 時間三欄大 mono 數字）。
struct App2RecordsView: View {

    @ObservedObject var viewModel: App2RecordsViewModel

    /// 右上日曆鈕開的是 1.x 既有的 `TrainingCalendarView`（`WeekOverviewCardV2`
    /// 也是以 sheet + NavigationView 開它）—— 不另做一份月曆。
    @State private var showTrainingCalendar = false
    /// 點某一列開的訓練詳情（設計 frame-15）。nil = 沒開。
    @State private var detailWorkout: WorkoutV2?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                App2PageHeader(title: L10n.App2.Records.title.localized) {
                    calendarButton
                }
                .padding(.bottom, 14)

                if let sourced = viewModel.records {
                    heroCard(sourced).padding(.bottom, 20)
                    filterChips
                    HStack {
                        Spacer()
                        App2StubBadge(origin: sourced.origin)
                    }
                    .frame(height: sourced.origin.isStub ? nil : 0)
                    .padding(.horizontal, 4)

                    ForEach(viewModel.visibleGroups) { group in
                        groupHeader(group)
                        ForEach(group.items) { item in
                            workoutCard(item).padding(.bottom, 11)
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text(L10n.App2.Common.noData.localized)
                        .font(.app2Body)
                        .foregroundStyle(App2Theme.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, App2Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, App2Theme.tabBarClearance)
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .accessibilityIdentifier("App2_RecordsView")
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.forceRefresh() }
        .sheet(isPresented: $showTrainingCalendar) {
            NavigationView {
                TrainingCalendarView()
            }
        }
        .fullScreenCover(item: $detailWorkout) { workout in
            App2WorkoutDetailView(
                workout: workout,
                onClose: { detailWorkout = nil },
                // 刪掉的那一筆不能還留在清單上。
                onDeleted: { Task { await viewModel.forceRefresh() } }
            )
        }
    }

    // MARK: - 右上日曆鈕（設計 `openCal`）

    /// `Button` 會吃掉 label 上的 identifier，所以可點元素用
    /// 容器 ＋ `contentShape` ＋ `onTapGesture` ＋ `.isButton` trait。
    private var calendarButton: some View {
        Image(systemName: "calendar")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(App2Theme.accentBlueDeep)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(App2Theme.cardBackground)
                    .overlay(Circle().stroke(App2Theme.cardBorder, lineWidth: 1))
            )
            .contentShape(Circle())
            .onTapGesture { showTrainingCalendar = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_RecordsCalendarButton")
    }

    // MARK: - 課型篩選 chip 列（設計 `recTabs`）

    @ViewBuilder
    private var filterChips: some View {
        if viewModel.filters.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.filters) { filter in
                        filterChip(filter, isSelected: filter.id == viewModel.selectedFilterID)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 18)
            .accessibilityIdentifier("App2_RecordsFilterChips")
        }
    }

    private func filterChip(_ filter: App2RecordFilter, isSelected: Bool) -> some View {
        Text(filter.label)
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(isSelected ? Color.white : App2Theme.inkSecondary)
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? App2Theme.accentBlue : App2Theme.cardBackground)
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : App2Theme.cardBorder,
                    lineWidth: 1
                )
            )
            .contentShape(Capsule())
            .onTapGesture { viewModel.select(filterID: filter.id) }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("App2_RecordsFilterChip_\(filter.id)")
    }

    // MARK: - 分組標題 ＋ 小計（設計 `g.group` / `g.count` / `g.sum`）

    private func groupHeader(_ group: App2RecordGroup) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(group.title)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
            Text(L10n.Record.Group.runCountFormat.localized(with: group.count))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(App2Theme.inkTertiary)
            Spacer(minLength: 8)
            if group.totalKm > 0 {
                Text(L10n.Record.Group.totalKmFormat.localized(with: group.totalKm))
                    .font(.app2Mono(11.5, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
        .accessibilityIdentifier("App2_RecordsGroupHeader")
    }

    // MARK: - hero（雙欄總量 ＋ 近 8 週趨勢）

    private func heroCard(_ sourced: App2Sourced<App2Records>) -> some View {
        let records = sourced.value
        return App2AccentCard(strength: 0.14, padding: 18, spacing: 0) {
            HStack {
                Spacer()
                App2StubBadge(origin: sourced.origin)
            }
            .frame(height: sourced.origin.isStub ? nil : 0)

            HStack(alignment: .top, spacing: 14) {
                totalsColumn(
                    title: L10n.App2.Records.monthSection.localized,
                    titleColor: App2Theme.accentBlueDeep,
                    value: Self.grouped(records.monthDistanceKm),
                    unit: "km",
                    footnote: Self.monthComparison(records.monthDeltaKm)
                        ?? String(format: L10n.App2.Records.runsCount.localized, records.monthWorkouts),
                    footnoteColor: records.monthDeltaKm.map(Self.deltaColor)
                )
                Rectangle()
                    .fill(App2Theme.shadowInk.opacity(0.1))
                    .frame(width: 1)
                totalsColumn(
                    title: L10n.App2.Records.ytdSection.localized,
                    titleColor: App2Theme.inkMuted,
                    value: records.ytdDistanceKm.map { Self.grouped($0) } ?? "—",
                    unit: "km",
                    footnote: records.ytdWorkouts.map {
                        String(format: L10n.App2.Records.runsCount.localized, $0)
                    } ?? "—"
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.App2.Records.trendTitle.localized)
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(App2Theme.inkSecondary)
                    Spacer()
                    Text(L10n.App2.Records.trendUnit.localized)
                        .font(.app2Mono(11, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                App2WeeklyVolumeChart(bars: records.weeklySeries)
            }
            .padding(.top, 16)
            .accessibilityIdentifier("App2_RecordsWeeklyCard")
        }
        .accessibilityIdentifier("App2_RecordsTotalsCard")
    }

    private func totalsColumn(
        title: String,
        titleColor: Color,
        value: String,
        unit: String,
        footnote: String,
        footnoteColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .tracking(1)
                .foregroundStyle(titleColor)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.app2Mono(30))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(verbatim: " \(unit)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(App2Theme.inkTertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 6)
            Text(footnote)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(footnoteColor ?? App2Theme.inkTertiary)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 每筆紀錄卡

    private func workoutCard(_ item: App2RecordItem) -> some View {
        let row = item.row
        let type = row.dayType
        return App2LeftStripCard(
            strip: type?.app2StripColor ?? App2Theme.accentBlue,
            padding: EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15)
        ) {
            HStack {
                if let tag = row.tag {
                    App2Chip(
                        text: tag,
                        foreground: type?.app2ChipForeground ?? App2Theme.accentBlueDeep,
                        background: type?.app2ChipBackground ?? App2Theme.accentBlue.opacity(0.12)
                    )
                }
                // 設計 `r.when` 是相對時間（「今天 08:07」／「3 天前」），
                // 不是 `8/22`。走既有的 `DateFormatterHelper`（VM 已算好）。
                Text(item.whenLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(App2Theme.inkTertiary)
                Spacer(minLength: 6)
                if let vdot = row.vdot {
                    App2Chip(
                        text: "VDOT \(vdot)",
                        foreground: App2Theme.accentOrangeText,
                        background: App2Theme.accentOrange.opacity(0.09),
                        monospaced: true
                    )
                }
            }

            HStack(alignment: .bottom, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(row.distance.replacingOccurrences(of: " km", with: ""))
                        .font(.app2Mono(28))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(verbatim: "km")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
                if let pace = row.pace {
                    metricColumn(
                        value: pace.replacingOccurrences(of: "/km", with: ""),
                        suffix: "/km",
                        caption: L10n.App2.Records.pace.localized
                    )
                }
                metricColumn(
                    value: row.duration,
                    suffix: nil,
                    caption: L10n.App2.Records.time.localized
                )
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        // Garmin badge（2026-08-27 走查裁決（o））：**品牌合規要求，不是美觀選擇**。
        // 1.4 的紀錄列（`WorkoutV2RowView.sourceAttributionView`）早就有，App2 漏接。
        // 用 overlay 釘右下角而不是塞進數字那一列 —— 放進 HStack 會把配速／時間
        // 欄擠到換行（實機破版）。
        .overlay(alignment: .bottomTrailing) {
            garminBadge(item.workout)
                .padding(.trailing, 12)
                .padding(.bottom, 10)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 樣本資料沒有原始紀錄 → 不可點（不做點下去什麼都沒有的死列）。
            guard let workout = item.workout else { return }
            detailWorkout = workout
        }
        .accessibilityAddTraits(item.workout == nil ? [] : .isButton)
        .accessibilityIdentifier("App2_RecordRow")
    }

    /// Garmin 來源的紀錄在列的**右下角**掛官方 badge（裁決（o））。
    ///
    /// 判定與 1.4 `WorkoutV2RowView` 同一條：`provider == "garmin"`，或裝置名字看得出
    /// 是 Garmin（Apple Health 轉進來的那批 `provider` 是 `apple_health`，只有
    /// `device_name` 說得出來源）。asset 也是同一份（`GarminAttributionView` 的
    /// `Garmin Tag-*-high-res`），不另存一張圖。
    ///
    /// 這一頁**只放 Garmin**：裁決（o）講的是 Garmin 品牌規範的合規缺口，
    /// 不是把 1.4 那組三選一的來源標記整組搬過來。
    @ViewBuilder
    private func garminBadge(_ workout: WorkoutV2?) -> some View {
        if let workout, Self.isGarminSourced(workout) {
            GarminAttributionView(deviceModel: nil, displayStyle: .compact)
                .scaleEffect(0.82, anchor: .bottomTrailing)
                .accessibilityIdentifier("App2_RecordRowGarminBadge")
        }
    }

    static func isGarminSourced(_ workout: WorkoutV2) -> Bool {
        if workout.provider.lowercased() == "garmin" { return true }
        let device = workout.deviceName?.lowercased() ?? ""
        return device.contains("garmin") || device.contains("forerunner")
    }

    private func metricColumn(value: String, suffix: String?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.app2Mono(20))
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(App2Theme.inkTertiary)
                }
            }
            Text(caption)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
        }
    }

    /// 設計 hero 左欄的「↑ 較上月 +18」。上月資料不齊時 VM 給 nil，這一列就不出現。
    ///
    /// 精度跟上方的本月跑量同一條規則 —— 否則同一欄會出現 `77.9 km` 配 `+78`。
    static func monthComparison(_ deltaKm: Double?) -> String? {
        guard let deltaKm else { return nil }
        let arrow = deltaKm > 0 ? "↑" : (deltaKm < 0 ? "↓" : "→")
        let magnitude = grouped(abs(deltaKm))
        let signed = deltaKm > 0 ? "+\(magnitude)" : (deltaKm < 0 ? "-\(magnitude)" : magnitude)
        return "\(arrow) " + String(format: L10n.App2.Records.vsLastMonth.localized, signed)
    }

    private static func deltaColor(_ deltaKm: Double) -> Color {
        if deltaKm > 0 { return App2Theme.accentGreen }
        if deltaKm < 0 { return App2Theme.accentOrangeText }
        return App2Theme.inkTertiary
    }

    /// `1,284` 這種千分位（設計 hero 的今年累積）——走共用的 `App2NumberFormat`。
    ///
    /// **保留一位小數**：跑量的真值就是 `72.6`，四捨五入成 `73` 會跟同一份資料在
    /// Android 上顯示的數字對不上（2026-08-25 兩平台實走）。整數值不帶 `.0`。
    static func grouped(_ km: Double) -> String {
        App2NumberFormat.grouped(km, maximumFractionDigits: 1)
    }
}
