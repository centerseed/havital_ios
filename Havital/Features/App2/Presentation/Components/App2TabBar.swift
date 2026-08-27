import SwiftUI

// MARK: - App2Tab
/// 2.0 的四個主 tab（設計 frame-00／01／10／11 的底部導航）。
///
/// 第四格是**成就**，不是設定 —— 設定的入口在首頁右上角的「…」menu。
///
/// **底部導航是系統原生 `TabView`**（2026-08-26 使用者裁決：自繪的懸浮膠囊位置
/// 太高、不是 iOS 預設）。高度、safe-area 貼底、選中態全部交給系統，這裡只提供
/// tab 的身分（標題與 icon）。自繪的 `App2TabBar` 已刪除，沒有第二條底部導航。
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

// MARK: - App2PageHeader
/// 各頁頂部的一列：大標題（或字標）＋ 右側動作。
///
/// 設計 markup：`font-size:24px;font-weight:900;color:#10151c;letter-spacing:0.5px`。
/// repo 內既有的 header（`TrainingModeHeaderV2`／`RaceHeaderViewV2`／`WeekProgressHeader`）
/// 都綁死各自的內容與 1.x 版面，沒有可重用的純標題列。
/// **被推出來的頁**（設定 frame-21、訓練計畫 frame-20、賽事管理 frame-12）第一列多一顆
/// 34×34 的白底返回鍵，其餘構造完全一樣 —— 所以是同一個型別多一個選填的 `onBack`，
/// 不是第二個 header。
///
/// `centre` 是選填的**置中**內容（課表頁的週次切換器，2026-08-27 走查裁決（q））。
/// 它是 overlay 而不是 HStack 的第三格 —— 標題與右側動作的寬度不對稱，排進 HStack
/// 只會「看起來像置中」。沒給 `centre` 的頁面（14 個呼叫點裡的其他 13 個）走
/// `Centre == EmptyView` 那支 init，簽名與原本一模一樣。
struct App2PageHeader<Centre: View, Trailing: View>: View {
    let title: String
    /// 設計 frame-20 的標題是 19px，tab 頁與賽事管理是 24px。
    var titleSize: CGFloat = 24
    /// nil = tab 頁（沒有返回鍵）。
    var onBack: (() -> Void)?
    /// 返回鍵的 accessibility identifier —— 每一頁各自命名，UI 測試才點得到正確那一顆。
    var backIdentifier: String?
    /// 頁面標記掛在標題這顆葉節點上。
    ///
    /// **不要掛在頁面最外層的容器**：SwiftUI 會把容器的 identifier 蓋到每一個
    /// 子節點上，整頁的按鈕在 a11y tree 裡就全部叫同一個名字
    /// （2026-08-25 maestro 實測：訓練計畫總覽的返回鍵與「調整」都變成
    /// `App2_PlanOverviewView`，於是一顆都點不到）。
    var titleIdentifier: String?
    /// 置中內容（選填）。
    @ViewBuilder let centre: () -> Centre
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        titleSize: CGFloat = 24,
        onBack: (() -> Void)? = nil,
        backIdentifier: String? = nil,
        titleIdentifier: String? = nil,
        @ViewBuilder centre: @escaping () -> Centre,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.titleSize = titleSize
        self.onBack = onBack
        self.backIdentifier = backIdentifier
        self.titleIdentifier = titleIdentifier
        self.centre = centre
        self.trailing = trailing
    }

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
                .accessibilityIdentifier(titleIdentifier ?? "")
            Spacer(minLength: 8)
            trailing()
        }
        .overlay(alignment: .center) { centre() }
        .padding(.horizontal, 4)
    }
}

extension App2PageHeader where Centre == EmptyView {
    /// 沒有置中內容的頁面用這一支 —— 簽名與加 `centre` 之前完全相同。
    init(
        title: String,
        titleSize: CGFloat = 24,
        onBack: (() -> Void)? = nil,
        backIdentifier: String? = nil,
        titleIdentifier: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(
            title: title,
            titleSize: titleSize,
            onBack: onBack,
            backIdentifier: backIdentifier,
            titleIdentifier: titleIdentifier,
            centre: { EmptyView() },
            trailing: trailing
        )
    }
}
