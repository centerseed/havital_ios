import SwiftUI

// MARK: - App2Tab
/// 2.0 的四個主 tab（設計 frame-00／01／10／11 的底部導航）。
///
/// 第四格是**成就**，不是設定 —— 設定的入口在各頁右上角的頭像（`App2Avatar`）。
enum App2Tab: String, CaseIterable, Identifiable {
    case state, plan, records, achievements

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .state:        return L10n.App2.Tab.state
        case .plan:         return L10n.App2.Tab.plan
        case .records:      return L10n.App2.Tab.records
        case .achievements: return L10n.App2.Tab.achievements
        }
    }

    var symbolName: String {
        switch self {
        case .state:        return "waveform.path.ecg"
        case .plan:         return "figure.run"
        case .records:      return "list.clipboard.fill"
        case .achievements: return "flag.fill"
        }
    }
}

// MARK: - App2TabBar
/// 懸浮膠囊式 tab bar。
///
/// 設計 markup：`position:absolute;bottom:20px;left:16px;right:16px;height:66px;`
/// `border-radius:27px;background:rgba(255,255,255,0.55);backdrop-filter:blur(22px) saturate(180%)`。
///
/// **為什麼不用 `TabView` 的 `tabItem`**（2026-08-25 查過，repo 內沒有第二支自訂
/// 底部導航，`App2RootView` 原本就是唯一一處）：`tabItem` 產出的是系統 tab bar
/// ——滿版、貼底、不透明、圓角不可調，做不出浮在內容上方的膠囊。所以 tab 切換
/// 自己管，頁面在 `ZStack` 裡疊。
struct App2TabBar: View {
    @Binding var selection: App2Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(App2Tab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 19, weight: .semibold))
                        Text(tab.titleKey.localized)
                            .font(.system(size: 13, weight: isSelected ? .heavy : .bold))
                            // identifier 掛在 Text 這個葉節點上：掛在 Button 或外層容器
                            // 都不會出現在 accessibility tree（2026-08-25 用 maestro 的
                            // hierarchy dump 確認）。用文字選 tab 也不行 —— 首頁今日課表卡
                            // 裡就有「課表」兩個字，會先被選中。
                            .accessibilityIdentifier("App2_Tab_\(tab.rawValue.capitalized)")
                    }
                    .foregroundStyle(isSelected ? App2Theme.accentBlue : App2Theme.inkSecondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 6)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(App2Theme.accentBlue.opacity(0.14))
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 66)
        .background {
            RoundedRectangle(cornerRadius: App2Theme.tabBarCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: App2Theme.tabBarCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.45))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: App2Theme.tabBarCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: App2Theme.shadowInk.opacity(0.22), radius: 17, x: 0, y: 14)
        .shadow(color: App2Theme.shadowInk.opacity(0.06), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("App2_TabBar")
    }
}

// MARK: - App2PageHeader
/// 各頁頂部的一列：大標題（或字標）＋ 右側動作。
///
/// 設計 markup：`font-size:24px;font-weight:900;color:#10151c;letter-spacing:0.5px`。
/// repo 內既有的 header（`TrainingModeHeaderV2`／`RaceHeaderViewV2`／`WeekProgressHeader`）
/// 都綁死各自的內容與 1.x 版面，沒有可重用的純標題列。
/// **被推出來的頁**（設定 frame-21、訓練計畫 frame-20、賽事管理 frame-12）第一列多一顆
/// 34×34 的白底返回鍵，其餘構造完全一樣 —— 所以是同一個型別多一個選填的 `onBack`，
/// 不是第二個 header。
struct App2PageHeader<Trailing: View>: View {
    let title: String
    /// 設計 frame-20 的標題是 19px，tab 頁與賽事管理是 24px。
    var titleSize: CGFloat = 24
    /// nil = tab 頁（沒有返回鍵）。
    var onBack: (() -> Void)?
    /// 返回鍵的 accessibility identifier —— 每一頁各自命名，UI 測試才點得到正確那一顆。
    var backIdentifier: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let onBack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(App2Theme.cardBackground)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(App2Theme.shadowInk.opacity(0.08), lineWidth: 1)
                    )
                    .overlay {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(App2Theme.inkSubtle)
                    }
                    .shadow(color: App2Theme.shadowInk.opacity(0.12), radius: 3, x: 0, y: 3)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onBack)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(backIdentifier ?? "App2_PageBack")
            }

            Text(title)
                .font(.system(size: titleSize, weight: .black))
                .tracking(0.5)
                .foregroundStyle(App2Theme.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 4)
    }
}
