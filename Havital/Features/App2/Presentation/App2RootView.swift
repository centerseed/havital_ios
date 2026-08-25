import SwiftUI

// MARK: - App2Revalidating
/// 「載一次、之後靜默重驗」的載入策略（stale-while-revalidate）。
///
/// 沒有這條策略時，切 tab 會重建 view → 重建 `@StateObject` → 重打 API →
/// 每次切換都閃 loading（2026-08-25 用戶在模擬器上點名）。
/// 兩件事一起才治得好：**ViewModel 常駐在殼層**（下面 `App2RootView` 持有），
/// 以及**重驗時不清空既有資料、不進 loading 態**（各 ViewModel 的 `hasLoaded`）。
@MainActor
protocol App2Revalidating: AnyObject {
    var hasLoaded: Bool { get }
    var lastLoadedAt: Date? { get }
    func load() async
}

extension App2Revalidating {
    /// 第一次進頁 → 正常載入（會出 loading）。
    /// 之後再進來 → 只有超過 `staleAfter` 才在背景重驗，畫面保留舊資料。
    func loadIfNeeded(staleAfter: TimeInterval = 60) async {
        guard hasLoaded else {
            await load()
            return
        }
        guard let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) > staleAfter else { return }
        await load()
    }
}

// MARK: - App2RootView
/// 2.0 的主 tab 結構：狀態 · 課表 · 紀錄 · **成就**。
///
/// 對照 1.x 的四個 tab（訓練計畫／訓練紀錄／表現數據／成就），2.0 把「表現數據」
/// 收進首頁的訓練狀況卡（§3.1a 指標網格），第四格留給成就（設計 frame-11）。
/// **設定不是 tab** —— 入口是課表頁右上角的頭像（設計 frame-01），開成一張全螢幕頁
/// （設計 frame-21 的左上有返回鍵，是被推出來的頁而不是 tab）。
///
/// tab bar 是懸浮膠囊（`App2TabBar`），所以頁面在 `ZStack` 裡疊而不是走 `TabView`；
/// 每一頁自己留 `App2Theme.tabBarClearance` 的底部空間。
///
/// **四個 ViewModel 由這一層持有**：`switch` 換頁會把子 view 連同它的
/// `@StateObject` 一起丟掉，切回來就重打 API。把 ViewModel 提到殼層 ＋ 已造訪的頁
/// 留在 `ZStack` 裡（用 opacity 切換），切換就不重建、不重新 fetch、捲動位置也保留。
///
/// **這支只在 2.0 分支取代 `ContentView.mainAppContent()` 的 TabView。**
/// 1.x 發版線（`main`）不受影響 —— 本票不合回 main。
struct App2RootView: View {

    @State private var selection: App2Tab = .state
    /// 已造訪過的 tab —— 沒進過的頁不預先建立（省掉冷啟時四頁一起打 API）。
    @State private var visited: Set<App2Tab> = [.state]
    @State private var isShowingSettings = false

    @StateObject private var homeViewModel = App2HomeViewModel()
    @StateObject private var planViewModel = App2PlanViewModel()
    @StateObject private var recordsViewModel = App2RecordsViewModel()
    @StateObject private var settingsViewModel = App2SettingsViewModel()
    /// 成就頁直接用既有 feature 的 ViewModel（`GET /v2/achievements/summary`），
    /// 不另寫平行實作。
    @StateObject private var achievementsViewModel = PersonalAchievementsViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            App2Theme.pageGradient.ignoresSafeArea()

            ZStack {
                page(.state) { App2HomeView(viewModel: homeViewModel) }
                page(.plan) {
                    App2PlanView(
                        onOpenSettings: { isShowingSettings = true },
                        avatarInitial: settingsViewModel.avatarInitial,
                        viewModel: planViewModel
                    )
                }
                page(.records) { App2RecordsView(viewModel: recordsViewModel) }
                page(.achievements) { App2AchievementsView(viewModel: achievementsViewModel) }
            }

            App2TabBar(selection: $selection)
                .padding(.bottom, 4)
        }
        .onChange(of: selection) { _, newValue in
            visited.insert(newValue)
        }
        .fullScreenCover(isPresented: $isShowingSettings) {
            App2SettingsView(
                onClose: { isShowingSettings = false },
                viewModel: settingsViewModel
            )
        }
        .accessibilityIdentifier("App2_RootView")
    }

    /// 已造訪的頁一律留在階層裡（保留 ViewModel 與捲動位置），只切可見度。
    /// 隱藏的頁同時退出 accessibility tree，否則 UI 測試會抓到背景頁的元素。
    @ViewBuilder
    private func page<Content: View>(
        _ tab: App2Tab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if visited.contains(tab) {
            content()
                .opacity(selection == tab ? 1 : 0)
                .allowsHitTesting(selection == tab)
                .accessibilityHidden(selection != tab)
        }
    }
}

#Preview {
    App2RootView()
}
