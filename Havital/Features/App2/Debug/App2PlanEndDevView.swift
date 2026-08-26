#if DEBUG
import SwiftUI

// MARK: - App2DevPlanEndOverride
/// 計畫結束態的**開發用強制狀態**。
///
/// 結束態的觸發是後端的 `next_action == "training_completed"`（`current_week >
/// total_weeks`），而 dev 帳號現在是第 1／6 週 —— 實機上走不到，等也等不到，
/// 後端也不接受用戶端指定週次。這個 override 只換**呈現的那一格**，
/// `App2PlanEndProjection.card` 的真實判斷路徑照跑不誤，關掉就恢復。
///
/// 卡片仍然由 `App2PlanEndProjection.makeCard` 組（同一段程式碼），只是變體由這裡
/// 指定 —— 走查看到的版式與真實結束態長得一樣，不是另畫一張像的卡。
enum App2DevPlanEndOverride: String, CaseIterable, Identifiable {
    /// 不覆寫，照真實 plan status。
    case off
    /// `plan_type = race`：深藍「備賽完成」。
    case race
    /// `plan_type = maintenance`：綠「訓練期完成」，不提賽事成績。
    case maintenance

    var id: String { rawValue }

    var isForcing: Bool { self != .off }

    /// 走查用的標籤。**刻意不進 `Localizable.strings`** —— DEBUG-only 開發工具不是
    /// 面向用戶的字串（同 `App2DevWeekReviewOverride.label` 的理由）。
    var label: String {
        switch self {
        case .off:         return "Off (real status)"
        case .race:        return "Forced: race (備賽完成)"
        case .maintenance: return "Forced: maintenance (訓練期完成)"
        }
    }

    var kind: App2PlanEndKind? {
        switch self {
        case .off:         return nil
        case .race:        return .race
        case .maintenance: return .maintenance
        }
    }

    /// 把 override 換成實際的結束態卡。
    ///
    /// 回傳 nil ＝「沒有覆寫，用真實判斷」。週數／賽名／目標成績仍然從真實資料取
    /// —— 走查的對象是版式與降級規則，不是內容。
    func resolve(
        planStatus: PlanStatusV2Response?,
        overview: PlanOverviewV2?,
        target: Target?,
        estimatedFinish: String?
    ) -> App2PlanEndCard? {
        guard let kind else { return nil }
        return App2PlanEndProjection.makeCard(
            kind: kind,
            planStatus: planStatus,
            overview: overview,
            target: target,
            estimatedFinish: estimatedFinish
        )
    }
}

// MARK: - App2PlanEndStoryFixture
/// 整期總結故事版（frame-00g2（a））的預覽資料。
///
/// **欄位形狀照 `SPEC-plan-period-summary.md` §5.2 的 `plan_period_summary`**
/// （`hero{line,subline}` ＋ `chapters[]{week_label,title,quote?,rizo_line?}`），
/// 內容是設計稿上那幾句。整份在 `#if DEBUG` 裡：
/// **production 路徑不得出現假造的敘事** —— 那條路上 `story` 恆為 nil，畫面走數字版。
enum App2PlanEndStoryFixture {

    /// 四個章節落在整期的哪幾週。
    ///
    /// 比例取自稿面那份 22 週的示範（1／9／18／22）：`ceil(22×0.4)=9`、
    /// `ceil(22×0.8)=18`，所以 N=22 時與稿面逐字相同，N 小的時候一起縮。
    /// **hero 句與章節標籤吃的是同一個 N** —— 先前 hero 寫死 22 而同屏的
    /// 章節標籤是真實週數，走查時兩個數字互相打臉（2026-08-27 補修，
    /// 與 Android `App2PlanEndFixture.narrative(totalWeeks)` 同一組比例）。
    /// 單調不遞減用 `max` 保住：N 很小時節點會擠在同幾週，但不會出現
    /// 「第 3 週」排在「第 5 週」前面。
    static func chapterWeeks(totalWeeks: Int) -> [Int] {
        let last = max(totalWeeks, 1)
        let mid1 = min(max(Int(ceil(Double(last) * 0.4)), 1), last)
        let mid2 = min(max(Int(ceil(Double(last) * 0.8)), mid1), last)
        return [1, mid1, mid2, last]
    }

    static func make(weeks: Int) -> App2PeriodStory {
        let chapters = chapterWeeks(totalWeeks: weeks)
        let last = chapters[3]
        return App2PeriodStory(
            heroLine: "\(last) 週，你把自己重新跑了一遍",
            heroSubline: "從報名時的「我是不是太衝動」，到站上 Hofu 起跑線的篤定"
                + "——這一段，你是一步一步跑出來的。",
            // **刻意留 nil。** `finish` 引用的是 race-result-binding 的讀口
            // （`SPEC-race-result-binding.md`，同樣未落地），所以就算敘事端點明天上線，
            // 這一格仍然是空的 —— 走查要看到的是**那個**狀態：完賽數字卡退成
            // 「目標＋當時預估」（2026-08-27 裁決：不得整塊省略），而不是一個
            // 我們現在還交不出來的成績。
            finish: nil,
            chapters: [
                App2PeriodStory.Chapter(
                    id: 0,
                    weekLabel: "第 \(chapters[0]) 週 · 起點",
                    title: "一切從「我是不是太衝動」開始",
                    quote: App2PeriodStory.Chapter.Quote(
                        text: "6:50 配速跑 8K 就喘到不行，開始懷疑報全馬是不是太衝動了。",
                        sessionSummary: "第 \(chapters[0]) 週 · 輕鬆跑 8.0 km"
                    ),
                    rizoLine: "第一週不用急，先讓身體記得規律就好。底子是慢慢疊出來的。"
                ),
                App2PeriodStory.Chapter(
                    id: 1,
                    weekLabel: "第 \(chapters[1]) 週 · 低谷",
                    title: "撞牆的那一週",
                    quote: App2PeriodStory.Chapter.Quote(
                        text: "長跑跑到 25K 整個垮掉，後面用走的回家。",
                        sessionSummary: "第 \(chapters[1]) 週 · 長距離 30 km"
                    ),
                    rizoLine: "掉速的那一段其實是熱與累積負荷疊在一起，不是能力退步。"
                ),
                App2PeriodStory.Chapter(
                    id: 2,
                    weekLabel: "第 \(chapters[2]) 週 · 突破",
                    title: "第一次把 32K 跑完還有餘力",
                    quote: App2PeriodStory.Chapter.Quote(
                        text: "鞋子換了新的，落地更穩，最後 5K 還能加速。",
                        sessionSummary: "第 \(chapters[2]) 週 · 長距離 32 km"
                    ),
                    rizoLine: "配速與心率整場守在耐力區間——這一趟就是賽事日的預演。"
                ),
                App2PeriodStory.Chapter(
                    id: 3,
                    weekLabel: "第 \(last) 週 · 賽事日",
                    title: "當初喘不過氣的配速，現在是你的恢復跑",
                    quote: nil,
                    rizoLine: "起跑到 30K 幾乎零波動，最後那段是你自己咬下來的。"
                )
            ]
        )
    }
}

// MARK: - App2PlanEndDevView
/// 計畫結束態開發者工具（2.0 設定頁 →「Plan End Dev Tools」，**只在 DEBUG build 出現**）。
///
/// 落點沿用既有的 `Features/<Feature>/Debug/` 慣例，dev flag 也沿用既有的
/// `App2DevSettings`（`App2WeeklyReviewDevView.swift`）—— **不另建第二種開發面板機制**。
///
/// 三件事：
/// 1. **結束態變體走查** —— 強制首頁與課表 tab 進 race／maintenance 兩種結束態。
/// 2. **故事版預覽** —— 整期總結頁改吃 fixture（欄位形狀照 `SPEC-plan-period-summary`
///    §5.2）。關掉就回到 production 走的數字版。
/// 3. 提醒：結束態一開，首頁的週回顧時機卡就該收掉（兩者互斥）。
struct App2PlanEndDevView: View {

    let onClose: () -> Void

    @ObservedObject private var dev = App2DevSettings.shared

    var body: some View {
        App2SettingsPageScaffold(
            title: "Plan End Dev Tools",
            onBack: onClose,
            backIdentifier: "App2_PlanEndDevBack",
            titleIdentifier: "App2_PlanEndDevView"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                variantSection
                storySection
            }
        }
        .background(App2Theme.pageGradient.ignoresSafeArea())
    }

    // MARK: - 結束態變體

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Plan end forced state")
            App2Card(padding: 15, spacing: 12) {
                ForEach(App2DevPlanEndOverride.allCases) { option in
                    radioRow(
                        isOn: dev.planEndOverride == option,
                        label: option.label,
                        identifier: "App2_DevPlanEndOverride_\(option.rawValue)"
                    ) {
                        dev.planEndOverride = option
                        // 結束態關掉時故事版預覽也一起關 —— 留著它會讓下一次走查
                        // 在「沒有結束態」的情況下還掛著一份敘事。
                        if option == .off { dev.planEndStoryPreview = false }
                    }
                }
                Text("Forces the home end state (goal card + today card replaced) and the "
                     + "plan tab end state. The weekly-review timing card is hidden while "
                     + "this is on — the two are mutually exclusive. Applies immediately, "
                     + "cleared on relaunch.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 故事版預覽

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            App2SectionCaption(text: "Period summary layout")
                .padding(.top, 20)
            App2Card(padding: 15, spacing: 12) {
                radioRow(
                    isOn: !dev.planEndStoryPreview,
                    label: "Numeric v1 (production path — narrative absent)",
                    identifier: "App2_DevPlanEndStory_off"
                ) { dev.planEndStoryPreview = false }

                radioRow(
                    isOn: dev.planEndStoryPreview,
                    label: "Story v2 (DEBUG fixture)",
                    identifier: "App2_DevPlanEndStory_on"
                ) { dev.planEndStoryPreview = true }

                Text("The narrative endpoint does not exist yet (SPEC-plan-period-summary is "
                     + "Draft), so production always renders the numeric version with the "
                     + "\"narrative not generated\" chip. The story fixture only ever lives in "
                     + "this DEBUG build — nothing is fabricated on the production path. Its "
                     + "week count follows the real total_weeks, so the hero line and the "
                     + "chapter labels always agree.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(App2Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    /// 單選列。與 `App2WeeklyReviewDevView.ctaSection` 同一組視覺；那一份是內嵌在
    /// `ForEach` 裡的，抽出來共用會讓兩支互相牽動，DEBUG 工具不值得那個耦合。
    private func radioRow(
        isOn: Bool,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOn ? App2Theme.accentBlue : App2Theme.chevron)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(App2Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}
#endif
