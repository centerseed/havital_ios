import SwiftUI

// MARK: - App2PaceZoneSettingsView
/// 2.0「配速區間」（設計 frame-27）：VDOT 值 ＋ E／M／T／I／R 各訓練配速。
///
/// 資料全部沿用既有：VDOT 來自 `VDOTManager`（`App2SettingsViewModel.currentVDOT`），
/// 配速換算來自 `PaceCalculator.getPaceRange(for:vdot:)`，區間名稱來自
/// `PaceCalculator.PaceZone.displayName` —— 與 1.4 設定頁的 `paceZoneSection` 同一組值。
///
/// **與設計的差距（不硬造）**：設計 frame-27 有 `−／＋` 手動調 VDOT 與「儲存」。
/// app 端目前沒有任何 VDOT 寫入口（全庫唯一的 VDOT 寫入是單筆紀錄的
/// `vdot_override`，語意是「這筆納不納入估算」，不是覆寫數值），所以這一頁是唯讀，
/// 不放假的調整鈕。缺口列在票面。
struct App2PaceZoneSettingsView: View {

    let onClose: () -> Void
    @ObservedObject var viewModel: App2SettingsViewModel

    /// 五列配速，鍵與名稱都取自既有詞彙（`PaceCalculator` 的課型鍵 ＋ `training.type.*`）。
    ///
    /// **與設計的一個字面差異**：frame-27 的 R 是「反覆跑」（比間歇更快）。
    /// 這個 app 的配速表沒有那一級 —— `PaceCalculator.PaceZone` 裡的 `[R]` 是**恢復跑**
    /// （最慢的一級）。不為了對上設計字面而發明一個不存在的配速，所以這裡照本 app 的
    /// 語意由慢到快排：恢復 → 輕鬆 → 馬拉松 → 閾值 → 間歇。
    private static let rows: [(letter: String, nameKey: String, type: String, tint: Color)] = [
        ("R", "training.type.recovery", "recovery", App2Theme.trackAhead),
        ("E", "training.type.easy", "easy", App2Theme.trackOnTrack),
        ("M", "training.type.tempo", "marathon", App2Theme.bandAmber),
        ("T", "training.type.threshold", "threshold", App2Theme.bandOrange),
        ("I", "training.type.interval", "interval", App2Theme.bandRed)
    ]

    private var vdot: Double { viewModel.currentVDOT }

    var body: some View {
        App2SettingsPageScaffold(
            title: NSLocalizedString("profile.pace_zones", comment: "Pace Zones"),
            onBack: onClose,
            backIdentifier: "App2_PaceZoneClose",
            titleIdentifier: "App2_PaceZoneView"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                vdotCard
                if vdot > 0 {
                    paceList
                }
            }
        }
    }

    private var vdotCard: some View {
        App2AccentCard(strength: 0.1, padding: 18, spacing: 8) {
            Text(L10n.App2.Settings.vdotValue.localized)
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(App2Theme.inkTertiary)

            // 沒有 VDOT 就整個大數字不出現（一個 40pt 的破折號在畫面上是一條橘色橫槓）。
            if vdot > 0 {
                Text(String(format: "%.1f", vdot))
                    .font(.app2Numeric(40, weight: .black))
                    .foregroundStyle(App2Theme.accentOrange)
                    .accessibilityIdentifier("App2_PaceZoneVdotValue")
            }

            Text(vdot > 0
                 ? L10n.App2.Settings.vdotNote.localized
                 : L10n.App2.Settings.vdotUnavailable.localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("App2_PaceZoneVdotCard")
    }

    private var paceList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.App2.Settings.paceListTitle.localized)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(App2Theme.inkPrimary)

            App2GroupedList {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                    paceRow(row, showsDivider: index < Self.rows.count - 1)
                }
            }
        }
    }

    private func paceRow(
        _ row: (letter: String, nameKey: String, type: String, tint: Color),
        showsDivider: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(row.tint.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(row.letter)
                            .font(.app2Mono(14, weight: .black))
                            .foregroundStyle(row.tint)
                    )
                Text(NSLocalizedString(row.nameKey, comment: ""))
                    .font(.app2RowTitle)
                    .foregroundStyle(App2Theme.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text(paceText(for: row.type))
                    .font(.app2Mono(15, weight: .bold))
                    .foregroundStyle(App2Theme.inkPrimary)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 14)

            if showsDivider {
                Rectangle()
                    .fill(App2Theme.insetBorder)
                    .frame(height: 1)
                    .padding(.leading, 59)
            }
        }
    }

    /// 兩端相同就印一個值（設計 frame-27 的 M／T／I／R 就是單值）。
    private func paceText(for type: String) -> String {
        guard let range = PaceCalculator.getPaceRange(for: type, vdot: vdot) else { return "—" }
        return range.min == range.max ? range.min : "\(range.min)–\(range.max)"
    }
}
