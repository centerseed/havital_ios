import SwiftUI

// MARK: - App2SessionDetailView
/// 2.0 訓練詳情 —— 設計 **frame-02「課表詳細 · 勻速轉間歇」** 與
/// dc.html「課表詳細 · 輕鬆跑／節奏跑／長距離」三張非間歇版式。
///
/// 兩種版式差在 hero 的顏色與是否有橘柱，其餘（預計配速圖、本次訓練目標、訓練結構、
/// 熱適應）**共用同一組區塊** —— 2026-08-25 裁決：配速結構示意圖每種課型都要有。
/// 所以這裡不做兩支 view，只讓 hero 的強調色跟著 `DayType` 走。
///
/// **這一頁不打端點。** 投影在 `App2SessionDetailProjection`，資料是呼叫端手上那份
/// 週課表 payload 的同一天。唯一的網路動作是「傳到 Garmin」（既有的
/// `GarminPushViewModel` → `POST /v2/integrations/garmin/push-workout`，T-0044）。
struct App2SessionDetailView: View {

    let detail: App2SessionDetail
    let onClose: () -> Void

    /// 「傳到 Garmin」沿用既有的 1.4 實作，不另寫一份推送路徑。
    @StateObject private var garminViewModel: GarminPushViewModel
    /// 沒連 Garmin 就沒有這顆鈕（不做死鈕）。
    @ObservedObject private var garminManager = GarminManager.shared
    /// 課型說明的完整版（怎麼跑／為什麼／訓練邏輯／週課表角色）。
    @State private var isShowingTypeInfo = false

    init(detail: App2SessionDetail, onClose: @escaping () -> Void) {
        self.detail = detail
        self.onClose = onClose
        _garminViewModel = StateObject(
            wrappedValue: GarminPushViewModel(repository: DependencyContainer.shared.resolve())
        )
    }

    private var accent: Color { detail.dayType?.app2StripColor ?? App2Theme.accentBlue }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    if !detail.structureBars.isEmpty { paceCard }
                    if let info = trainingTypeInfo { purposeCard(info) }
                    if detail.goalText != nil || detail.reasonText != nil { goalCard }
                    if detail.showsFuelingNote { fuelingCard }
                    if !detail.segments.isEmpty { structureCard }
                    if let climate = detail.climate { climateCard(climate) }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 14)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        .sheet(isPresented: $isShowingTypeInfo) {
            if let info = trainingTypeInfo {
                // 完整說明沿用 1.4 既有的 `TrainingTypeInfoView`（四段式），
                // 不另做一份 2.0 版的說明頁。
                TrainingTypeInfoView(trainingTypeInfo: info)
            }
        }
        .alert(NSLocalizedString("garmin.push.alert_title", comment: "Garmin"), isPresented: $garminViewModel.showAlert) {
            if garminViewModel.offerReconnect {
                Button(NSLocalizedString("garmin.push.reconnect", comment: "")) {
                    Task { await GarminManager.shared.startConnection(force: true) }
                }
                Button(NSLocalizedString("garmin.push.later", comment: ""), role: .cancel) { }
            } else {
                Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
            }
        } message: {
            Text(garminViewModel.alertMessage ?? "")
        }
        .alert(NSLocalizedString("garmin.push.hint_title", comment: "Garmin"), isPresented: $garminViewModel.showPushHint) {
            Button(NSLocalizedString("common.ok", comment: "OK")) { }
            Button(NSLocalizedString("garmin.push.hint_dont_show_again", comment: "")) {
                garminViewModel.dismissPushHintForever()
            }
        } message: {
            Text(NSLocalizedString("garmin.push.hint_message", comment: ""))
        }
    }

    // MARK: - 頁首（返回 ＋ 日期 ＋ 標題）

    private var topBar: some View {
        // 頁首走共用的 `App2PageHeader`（賽事管理／訓練計畫總覽／設定同一個構造），
        // 不另做一顆返回鍵。設計把日期放在標題上方，這裡改放右側 —— 共用元件只有一列，
        // 為了一個副標另開一支 header 是分裂。
        App2PageHeader(
            title: L10n.App2.Detail.title.localized,
            titleSize: 19,
            onBack: onClose,
            backIdentifier: "App2_SessionDetailBack",
            titleIdentifier: "App2_SessionDetailView"
        ) {
            Text(detail.dateTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkTertiary)
        }
        .padding(.horizontal, App2Theme.pagePadding)
        .padding(.vertical, 10)
    }

    // MARK: - Hero（課型色卡：kicker ＋ 標題 ＋ 傳到 Garmin ＋ 三格數字）

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let kicker = detail.kicker {
                        Text(kicker)
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(accent.app2Darkened.opacity(0.85))
                    }
                    Text(detail.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 4)
                garminButton
            }

            HStack(alignment: .bottom, spacing: 0) {
                if let km = detail.distanceKm {
                    heroStat(
                        label: L10n.App2.Detail.distance.localized,
                        value: App2NumberFormat.grouped(km, maximumFractionDigits: 1),
                        unit: "km"
                    )
                    heroDivider
                }
                if let duration = detail.durationLabel {
                    heroStat(label: L10n.App2.Detail.duration.localized, value: duration, unit: nil)
                    heroDivider
                }
                heroStat(
                    label: L10n.App2.Detail.phases.localized,
                    value: String(format: L10n.App2.Detail.phaseCount.localized, detail.phaseCount),
                    unit: nil
                )
                Spacer(minLength: 0)
            }
        }
        .padding(App2Theme.heroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: accent.opacity(0.16), location: 0),
                            .init(color: accent.opacity(0.03), location: 0.6),
                            .init(color: .white, location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        )
        .accessibilityIdentifier("App2_SessionDetailHero")
    }

    private func heroStat(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(App2Theme.inkFaint)
                }
            }
            Text(value)
                .font(.app2Mono(21))
                .foregroundStyle(App2Theme.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(App2Theme.insetBorder)
            .frame(width: 1, height: 30)
            .padding(.horizontal, 4)
    }

    /// 「傳到 Garmin」只在**真的推得動**時出現：跑步課 ＋ Garmin 已連結 ＋ 推得出日期。
    /// 缺任何一項就不擺這顆鈕（不做按下去必定失敗的死鈕）。
    @ViewBuilder
    private var garminButton: some View {
        if detail.isRunSession, garminManager.isConnected, let date = detail.dateString {
            VStack(spacing: 3) {
                Image(systemName: garminViewModel.uiState == .working ? "arrow.triangle.2.circlepath" : "figure.run")
                    .font(.system(size: 17, weight: .bold))
                Text(NSLocalizedString("training.detail.push_to_garmin", comment: ""))
                    .font(.system(size: 11, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(accent.app2Darkened)
            .frame(width: 62, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(App2Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.28), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard garminViewModel.uiState != .working else { return }
                garminViewModel.push(dayIndex: detail.dayIndex, date: date)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(NSLocalizedString("training.detail.push_to_garmin", comment: ""))
            .accessibilityIdentifier("App2_SessionDetailGarminPush")
        }
    }

    // MARK: - 預計配速（設計 frame-02 的長條圖，每種課型都有）

    private var paceCard: some View {
        App2Card(padding: 15, spacing: 11) {
            Text(L10n.App2.Detail.pacePreview.localized)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)
            App2SessionStructureChart(bars: detail.structureBars, showsNotes: true)
        }
        .accessibilityIdentifier("App2_SessionDetailPaceCard")
    }

    // MARK: - 本次訓練目標

    // MARK: - 這堂課練什麼（課型的設計目的）

    /// 課型說明的來源是既有的 `TrainingTypeInfo`（`Havital/Models/TrainingTypeInfo.swift`
    /// ＋ `training_type_info.*` 三語字串），**不在 App2 再寫一份文案**。
    ///
    /// 課型判定走 `detail.dayType` —— 它是 `App2SessionDetailProjection` 依 payload
    /// 的 `training_type`（V2）或 `category` ＋ `primary.run_type` / `interval.variant`
    /// （V3）解出來的結構化 `DayType`，不是對顯示字做詞表比對。變體對不上已知集合時
    /// 會退成 `.interval`，那時顯示的就是「間歇跑」的通用說明。
    private var trainingTypeInfo: TrainingTypeInfo? {
        guard let dayType = detail.dayType else { return nil }
        return TrainingTypeInfo.info(for: dayType)
    }

    /// 「本次訓練目標」上方那張卡：課型的設計目的一句話 ＋ 進完整說明。
    private func purposeCard(_ info: TrainingTypeInfo) -> some View {
        App2Card(padding: 15, spacing: 8) {
            HStack(spacing: 7) {
                Text(info.icon)
                    .font(.system(size: 15))
                Text(L10n.App2.Detail.purposeSection.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
                Text(info.title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(App2Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(info.whyRun)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                Text(L10n.App2.Detail.purposeMore.localized)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(accent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isShowingTypeInfo = true }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("App2_SessionPurposeCard")
    }

    private var goalCard: some View {
        App2Card(padding: 15, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Text(L10n.App2.Detail.goal.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
            }
            if let goal = detail.goalText {
                Text(goal)
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = detail.reasonText {
                Text(reason)
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("App2_SessionDetailGoalCard")
    }

    // MARK: - 補給建議（長距離）

    private var fuelingCard: some View {
        App2NoteBox(symbol: "cup.and.saucer.fill") {
            Text(L10n.App2.Session.fuelingNote.localized)
                .font(.system(size: 13, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("App2_SessionDetailFueling")
    }

    // MARK: - 訓練結構

    private var structureCard: some View {
        App2Card(padding: 15, spacing: 10) {
            HStack {
                Text(L10n.App2.Detail.structure.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer()
                Text(String(format: L10n.App2.Detail.phaseCount.localized, detail.segments.count))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
            }
            ForEach(detail.segments) { segment in
                segmentRow(segment)
            }
        }
        .accessibilityIdentifier("App2_SessionDetailStructure")
    }

    private func segmentRow(_ segment: App2SessionDetailSegment) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(verbatim: "\(segment.index)")
                .font(.app2Mono(13))
                .foregroundStyle(segment.isWork ? .white : App2Theme.inkTertiary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(segment.isWork ? accent : App2Theme.insetBackground)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(segment.name)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(App2Theme.inkPrimary)
                    if let repeats = segment.repeatsLabel {
                        App2Chip(
                            text: repeats,
                            foreground: accent.app2Darkened,
                            background: accent.opacity(0.13),
                            monospaced: true
                        )
                    }
                }
                if let value = segment.detail {
                    Text(value)
                        .font(.app2Mono(14, weight: .bold))
                        .foregroundStyle(App2Theme.inkSecondary)
                }
                if let note = segment.note {
                    Text(note)
                        .font(.system(size: 13, weight: .medium))
                        .lineSpacing(2)
                        .foregroundStyle(App2Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 10, leading: 11, bottom: 10, trailing: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
        .app2InsetSurface(cornerRadius: 12)
        .accessibilityIdentifier("App2_SessionDetailSegment_\(segment.id)")
    }

    // MARK: - 熱適應（`climate_meta`，真資料）

    private func climateCard(_ climate: App2SessionClimate) -> some View {
        App2NoteBox(symbol: "thermometer.sun.fill", accent: App2Theme.accentOrangeBright) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(NSLocalizedString("climate.section_title", comment: ""))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Text(
                        [climate.shortLevel, climate.feelsLike]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(App2Theme.accentOrangeText)
                }
                Text(climate.reason)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("App2_SessionDetailClimate")
    }
}
