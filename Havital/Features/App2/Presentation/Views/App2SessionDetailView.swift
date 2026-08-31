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
    /// 單位制切換要當場重畫（同 `App2WorkoutDetailView` 的接法）。
    @ObservedObject private var unitManager = UnitManager.shared
    /// 課型說明的完整版（怎麼跑／為什麼／訓練邏輯／週課表角色）。
    @State private var isShowingTypeInfo = false
    /// 傳到 Garmin 的二次確認。
    @State private var isConfirmingGarminPush = false

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
                    // 配速是跑步課的語意：肌力／交叉訓練的 payload 沒有配速
                    // （cross DTO 只有 cross_type/duration/intensity），畫「預計配速」
                    // 就是替瑜伽編一個配速（2026-08-26 使用者回報）。
                    // 沒有配速值就整張卡不出現（2026-08-27 晚走查裁決（j））：
                    // 輕鬆跑／恢復跑常常整天沒有 `pace`，那時這張卡是一張沒有
                    // 任何數字的圖。不畫「—」，也不在 app 端推算一個配速。
                    if detail.isRunSession, !detail.structureBars.isEmpty, detail.hasPaceData {
                        paceCard
                    }
                    // 「本次訓練目標」與「這堂課練什麼」曾經是兩張卡，內容重疊。
                    // 收成一張：課型目的（既有 `TrainingTypeInfo`）為主體，
                    // 逐日敘述只在證明得出它仍對應現在這一天時附加（見投影層）。
                    // 設計 frame-02c：長距離的補給提示卡夾在「預計配速」與
                    // 「本次訓練目標」之間。
                    if detail.showsFuelingNote { fuelingCard }
                    if trainingTypeInfo != nil || detail.goalText != nil || detail.reasonText != nil {
                        goalCard
                    }
                    if !detail.segments.isEmpty { structureCard }
                    // 主課結構之後接「力量訓練」（2026-08-27 晚走查裁決（d））。
                    if let strength = detail.strength { strengthCard(strength) }
                    // 設計 frame-02d 的下半部順序：訓練結構 → 目標區間 → 熱適應。
                    if targetZoneEffort != nil || estimatedRangeLabel != nil { targetZoneSection }
                    if let climate = detail.climate { climateCard(climate) }
                }
                .padding(.horizontal, App2Theme.pagePadding)
                .padding(.vertical, 14)
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
        // **`fullScreenCover` 不是 `sheet`。** 這一頁自己就開在 fullScreenCover 裡，
        // 巢狀 sheet 在這個 repo 不會進 accessibility tree，實測是「看完整說明」點下去
        // 沒反應（2026-08-26 QA）。同 `App2SettingsView` 子頁的既有處置。
        .fullScreenCover(isPresented: $isShowingTypeInfo) {
            if let info = trainingTypeInfo {
                // 完整說明沿用 1.4 既有的 `TrainingTypeInfoView`（四段式），
                // 不另做一份 2.0 版的說明頁。
                TrainingTypeInfoView(trainingTypeInfo: info)
                    .accessibilityIdentifier("App2_TrainingTypeInfoView")
            }
        }
        // 傳到 Garmin 前先確認（標題 ＋ 課表摘要 ＋ 確認／取消）。Android 側同步在加，
        // 兩平台一致 —— 這顆鈕會真的把課表寫進使用者的 Garmin Connect 帳號。
        .alert(
            NSLocalizedString("garmin.push.confirm_title", comment: "Send to Garmin"),
            isPresented: $isConfirmingGarminPush
        ) {
            Button(NSLocalizedString("garmin.push.confirm_action", comment: "Send")) {
                guard let date = detail.dateString else { return }
                garminViewModel.push(dayIndex: detail.dayIndex, date: date)
            }
            .accessibilityIdentifier("App2_SessionDetailGarminPushConfirm")
            Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
                .accessibilityIdentifier("App2_SessionDetailGarminPushCancel")
        } message: {
            Text(String(
                format: NSLocalizedString("garmin.push.confirm_message", comment: ""),
                garminPushSummary
            ))
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

    /// Hero（設計 frame-02）：課型色實心漸層 ＋ 白字，**三行**——
    /// ① kicker 膠囊 ＋ 正方形「傳到 Garmin」白鈕；② 課型大標；
    /// ③ 三格數據（總距離／預計時間／段數），等寬並以半透明白直線分隔。
    /// 右上角另有一層溢出畫布的半透明大圓 blob。
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                // **這一行不得消失**：`kicker` 在 payload 缺 `pace_zone`／
                // `target_intensity` 時退成課型的結構詞（見 `App2SessionDetailProjection`）。
                if let kicker = detail.kicker {
                    Text(kicker)
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.22)))
                }
                Spacer(minLength: 4)
                garminButton
            }

            Text(detail.title)
                .font(.system(size: 30, weight: .black))
                .tracking(0.5)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            HStack(alignment: .bottom, spacing: 0) {
                if let km = detail.distanceKm {
                    heroStat(
                        label: L10n.App2.Detail.distance.localized,
                        value: App2NumberFormat.grouped(
                            unitManager.currentUnitSystem.convertedDistance(km),
                            maximumFractionDigits: 1
                        ),
                        unit: unitManager.currentUnitSystem.distanceSuffix
                    )
                    heroDivider
                }
                if let duration = detail.durationLabel {
                    heroStat(label: L10n.App2.Detail.duration.localized, value: duration, unit: nil)
                    if showsPhasesStat { heroDivider }
                }
                // 「配速變化 N 段」是配速格：整天沒有配速值時它講不出任何東西，
                // 整格不出現（2026-08-27 晚走查裁決（j））。
                if showsPhasesStat {
                    heroStat(
                        label: L10n.App2.Detail.phases.localized,
                        value: String(format: L10n.App2.Detail.phaseCount.localized, detail.phaseCount),
                        unit: nil
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(App2Theme.heroPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                stops: [
                    .init(color: accent.app2Lightened, location: 0),
                    .init(color: accent, location: 0.6),
                    .init(color: accent.app2Darkened, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        // 右上角溢出的半透明大圓（設計 `right:-40 top:-40 170×170 rgba(255,255,255,0.1)`）。
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 170, height: 170)
                .offset(x: 40, y: -40)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: App2Theme.cardCornerRadius, style: .continuous))
        .shadow(color: accent.opacity(0.42), radius: 16, x: 0, y: 12)
        .accessibilityIdentifier("App2_SessionDetailHero")
    }

    /// hero 第三格（配速變化段數）只在跑步課且真的有配速值時出現。
    private var showsPhasesStat: Bool { detail.isRunSession && detail.hasPaceData }

    private func heroStat(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(value)
                .font(.app2Mono(24))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 確認框裡那一行課表摘要 —— 課型 ＋ 日期 ＋ 拿得到的距離／時間。
    /// **只組拿得到的欄位**，缺的不編。
    private var garminPushSummary: String {
        var parts: [String] = [detail.title, detail.dateTitle]
        if let km = detail.distanceKm {
            let unit = unitManager.currentUnitSystem
            parts.append(
                App2NumberFormat.grouped(unit.convertedDistance(km), maximumFractionDigits: 1)
                    + " " + unit.distanceSuffix
            )
        }
        if let duration = detail.durationLabel {
            parts.append(duration)
        }
        return parts.joined(separator: " · ")
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.28))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 6)
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
            // 設計 frame-02：**白底、圓角 16 的近正方形方塊**，圖示在上、
            // 兩行文字在下，icon 與文字同色＝該課型主色。不是圓形、不是純文字鈕。
            .foregroundStyle(accent.app2Darkened)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: App2Theme.shadowInk.opacity(0.28), radius: 9, x: 0, y: 8)
            .contentShape(Rectangle())
            .onTapGesture {
                guard garminViewModel.uiState != .working else { return }
                isConfirmingGarminPush = true
            }
            .id(date)
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
            // **單段勻速課畫配速帶，不畫長條圖**（設計 frame-02c，2026-08-26 裁決）：
            // 一根柱的長條圖看不出任何配速變化，圖裡沒有資訊。多段課維持長條圖。
            if let band = detail.paceBand {
                App2SessionPaceBandChart(band: band, accent: accent)
            } else {
                App2SessionStructureChart(bars: detail.structureBars, showsNotes: true)
            }
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

    /// 「本次訓練目標」。
    ///
    /// **主體是課型目的**（既有的 `TrainingTypeInfo.whyRun`，`training_type_info.*`
    /// 三語已齊）——它跟著當日課型走，改了課型就跟著換。
    ///
    /// `day_target`／`reason` 是**逐日生成**的敘述，用戶在編輯器改過課型之後
    /// 後端不重生，會與當日課表矛盾（2026-08-26 使用者截圖）。所以它們只在
    /// 投影層證明得出「仍對應現在這一天」時才附在下面（見
    /// `App2SessionDetailProjection.isDayNarrativeConsistent`）。
    private var goalCard: some View {
        App2Card(padding: 15, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Text(L10n.App2.Detail.goal.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Spacer(minLength: 6)
                if let info = trainingTypeInfo {
                    Text("\(info.icon) \(info.title)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(App2Theme.inkTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            if let info = trainingTypeInfo {
                Text(info.whyRun)
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(4)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let goal = detail.goalText {
                Text(goal)
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = detail.reasonText {
                Text(reason)
                    .font(.system(size: 13, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if trainingTypeInfo != nil {
                HStack(spacing: 5) {
                    Text(L10n.App2.Detail.purposeMore.localized)
                        .font(.system(size: 13, weight: .heavy))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundStyle(accent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if trainingTypeInfo != nil { isShowingTypeInfo = true } }
        .accessibilityElement(children: .contain)
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

    /// 設計 frame-02d：訓練結構**不是一張大卡**，是「區塊小標 ＋ 每段各自一張圓角卡」。
    private var structureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.App2.Detail.structure.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                // 設計 frame-02c：header 是「N 段 · M 分鐘」。推不出分鐘就只留段數。
                Text(structureMetaLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                Spacer(minLength: 0)
            }
            ForEach(detail.segments) { segment in
                segmentRow(segment)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("App2_SessionDetailStructure")
    }

    // MARK: - 力量訓練

    /// 動作清單（名稱 ＋ `3 組 × 45 秒`）。版式沿用訓練結構那一組小標＋卡片，
    /// 顏色用肌力的紫（`App2Theme.accentViolet`，與課表頁的肌力列同一顆）。
    private func strengthCard(_ strength: App2SessionStrength) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L10n.App2.Detail.strengthSection.localized)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(App2Theme.inkPrimary)
                Text(String(
                    format: L10n.App2.Home.strengthRow.localized,
                    strength.exerciseCount
                ))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(App2Theme.inkMuted)
                Spacer(minLength: 0)
            }

            ForEach(strength.groups) { group in
                App2Card(padding: 14, spacing: 9) {
                    if group.typeLabel != nil || group.durationLabel != nil {
                        HStack(spacing: 8) {
                            if let typeLabel = group.typeLabel {
                                Text(typeLabel)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(App2Theme.accentViolet)
                            }
                            Spacer(minLength: 0)
                            if let durationLabel = group.durationLabel {
                                Text(durationLabel)
                                    .font(.app2Mono(12))
                                    .foregroundStyle(App2Theme.inkTertiary)
                            }
                        }
                    }

                    if let note = group.note {
                        Text(note)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(App2Theme.inkSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(group.exercises) { exercise in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(App2Theme.accentViolet)
                                .frame(width: 5, height: 5)
                            Text(exercise.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(App2Theme.inkPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            if let detailText = exercise.detail {
                                Text(detailText)
                                    .font(.app2Mono(12))
                                    .foregroundStyle(App2Theme.inkSubtle)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("App2_SessionDetailStrength")
    }

    /// `1 段 · 55 分鐘`。分鐘從 hero 的「預計時間」推（同一個值，不另算一份）；
    /// 推不出來就只印段數。
    private var structureMetaLabel: String {
        let count = detail.segments.count
        guard let minutes = detail.durationMinutes else {
            return String(format: L10n.App2.Detail.phaseCount.localized, count)
        }
        return String(format: L10n.App2.Detail.structureMeta.localized, count, minutes)
    }

    /// 段附註句。payload 自己帶了描述就用它的；沒有就用課型的確定性文案
    /// （設計 frame-02d：「連續不中斷，維持穩定閾值配速」「全程勻速，最後幾公里
    /// 才是重點」）。逐日生成的敘述不進這裡 —— 理由見投影層。
    private func segmentNote(_ segment: App2SessionDetailSegment) -> String? {
        if let note = segment.note { return note }
        guard segment.isWork else { return nil }
        return App2SessionDetailProjection.workSegmentNoteKey(detail.dayType)?.localized
    }

    /// 單段課的首卡帶課型 icon 圓章，多段課是序號色圈（設計 frame-02d）。
    private var showsSegmentTypeIcon: Bool { detail.segments.count == 1 }

    /// 序號色圈：主段＝實心課型色白字；暖身／緩和＝白底色描邊（設計 frame-02d 的綠圈）。
    private func segmentColor(_ segment: App2SessionDetailSegment) -> Color {
        segment.isWork ? accent : App2Theme.accentGreenBright
    }

    @ViewBuilder
    private func segmentBadge(_ segment: App2SessionDetailSegment) -> some View {
        let color = segmentColor(segment)
        if showsSegmentTypeIcon, let dayType = detail.dayType {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: dayType.app2SymbolName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
        } else if segment.isWork {
            Text(verbatim: "\(segment.index)")
                .font(.app2Mono(13))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color))
        } else {
            Text(verbatim: "\(segment.index)")
                .font(.app2Mono(13))
                .foregroundStyle(color.app2Darkened)
                .frame(width: 28, height: 28)
                .background(Circle().fill(App2Theme.cardBackground))
                .overlay(Circle().strokeBorder(color.opacity(0.55), lineWidth: 1.5))
        }
    }

    private func segmentRow(_ segment: App2SessionDetailSegment) -> some View {
        HStack(alignment: .top, spacing: 11) {
            segmentBadge(segment)

            VStack(alignment: .leading, spacing: 3) {
                Text(segment.name)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(App2Theme.inkPrimary)
                if let value = App2SessionDetailProjection.segmentDetail(
                    segment, unitSystem: unitManager.currentUnitSystem
                ) {
                    Text(value)
                        .font(.app2Mono(14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(App2Theme.inkSecondary)
                }
                if let note = segmentNote(segment) {
                    Text(note)
                        .font(.system(size: 13, weight: .medium))
                        .lineSpacing(2)
                        .foregroundStyle(App2Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            // 間歇主段的趟數 chip 靠右上（設計 frame-02d 的「× 10」）。
            if let repeats = segment.repeatsLabel {
                App2Chip(
                    text: repeats,
                    foreground: .white,
                    background: accent,
                    monospaced: true
                )
            }
        }
        .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
        // **主段卡淡底高亮**（設計 frame-02d：間歇橘、節奏藍、耐力紫＝課型色）；
        // 暖身／緩和維持白底圓角卡。
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(segment.isWork ? accent.opacity(0.09) : App2Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    segment.isWork ? accent.opacity(0.28) : App2Theme.insetBorder,
                    lineWidth: 1
                )
        )
        .accessibilityIdentifier("App2_SessionDetailSegment_\(segment.id)")
    }

    // MARK: - 目標區間（設計 frame-02d 的兩張並排卡）

    /// 體感級距走既有的 `TrainingEffortScale`（課型對照，1.4 訓練詳情同一張表），
    /// **不在這裡再寫一份**。跑步課以外（休息／肌力／交叉）沒有這個語意 → nil。
    private var targetZoneEffort: TrainingEffortScale.Value? {
        TrainingEffortScale.value(for: detail.dayType)
    }

    private var estimatedRangeLabel: String? {
        App2SessionDetailProjection.estimatedRangeLabel(durationMinutes: detail.durationMinutes)
    }

    private var targetZoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            App2SectionCaption(text: L10n.App2.Detail.targetZone.localized)
            HStack(spacing: 11) {
                if let effort = targetZoneEffort {
                    targetZoneCard(
                        label: L10n.App2.Detail.effortLabel.localized,
                        unit: nil,
                        value: effort.rpeText,
                        suffix: "/10",
                        identifier: "App2_SessionDetailEffort"
                    )
                }
                if let range = estimatedRangeLabel {
                    targetZoneCard(
                        label: L10n.App2.Detail.estimatedTime.localized,
                        unit: App2SessionDetailProjection.estimatedRangeUnit(
                            durationMinutes: detail.durationMinutes
                        ),
                        value: range,
                        suffix: nil,
                        identifier: "App2_SessionDetailEstimatedTime"
                    )
                }
            }
        }
        .accessibilityIdentifier("App2_SessionDetailTargetZone")
    }

    private func targetZoneCard(
        label: String,
        unit: String?,
        value: String,
        suffix: String?,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(App2Theme.inkMuted)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.app2Mono(26))
                    .foregroundStyle(accent.app2Darkened)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(App2Theme.inkMuted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .app2CardSurface(cornerRadius: 16)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 熱適應（`climate_meta`，真資料）

    /// 熱壓力等級的顏色。`danger` 是紅（設計 frame-02d 的危險級示例），
    /// 其餘留在橘色階 —— 等級本身是後端給的 `heat_pressure_level`，不是這裡判的。
    private func climateTint(_ level: String) -> Color {
        level == "danger" ? App2Theme.accentRed : App2Theme.accentOrangeBright
    }

    private func climateCard(_ climate: App2SessionClimate) -> some View {
        let tint = climateTint(climate.level)
        return App2NoteBox(symbol: "thermometer.sun.fill", accent: tint) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(NSLocalizedString("climate.section_title", comment: ""))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(App2Theme.inkPrimary)
                    Spacer(minLength: 6)
                    // 設計 frame-02d：等級 ＋ 體感溫度是右側一顆 chip，不是標題後的散字。
                    App2Chip(
                        text: [climate.shortLevel, climate.feelsLike]
                            .compactMap { $0 }
                            .joined(separator: " · "),
                        foreground: tint.app2Darkened,
                        background: tint.opacity(0.13)
                    )
                }
                Text(climate.reason)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // 「調整後配速」那一行（設計 frame-02d（c），8/28 盤點 D3：Android 早有）。
                // **調整後的值只出現在這張卡**（2026-05 裁決）；沒有 `climate_adjusted_pace`
                // 就整行不出現。
                if let adjusted = climate.adjustedSummary {
                    Text(String(
                        format: NSLocalizedString("app2.session.heat_adjusted", comment: ""),
                        adjusted
                    ))
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(App2Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("App2_SessionDetailClimateAdjusted")
                }
            }
        }
        .accessibilityIdentifier("App2_SessionDetailClimate")
    }
}
