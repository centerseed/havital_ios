import SwiftUI

// MARK: - App2Revalidating
/// 「載一次、之後靜默重驗」的載入策略（stale-while-revalidate）。
///
/// 沒有這條策略時，切 tab 會重建 view → 重建 `@StateObject` → 重打 API →
/// 每次切換都閃 loading（2026-08-25 用戶在模擬器上點名）。
/// 兩件事一起才治得好：**ViewModel 常駐在殼層**（下面 `App2RootView` 持有），
/// 以及**重驗時不清空既有資料、不進 loading 態**（各 ViewModel 的 `hasLoaded`）。
/// 重驗鎖的卡死門檻（T-0355）：一輪 revalidate 超過這個秒數沒歸還鎖，
/// 下一次（含下拉刷新）不再被 `isRevalidating` 吞掉，直接開新輪。
enum App2RevalidatePolicy {
    static let stuckThreshold: TimeInterval = 30

    /// true ＝ 這一輪讓路（防重入）；false ＝ 執行——沒有 in-flight，或前一輪
    /// 開始已超過門檻（視為卡死，讓位開新輪）。抽成純函式鎖進單元測試。
    static func shouldBlock(isRevalidating: Bool, began: Date?, now: Date = Date()) -> Bool {
        guard isRevalidating else { return false }
        guard let began else { return true }
        return now.timeIntervalSince(began) <= stuckThreshold
    }
}

/// 重驗輪的 task-local 代號（`async let` 子任務會繼承）。0 ＝ 不在任何輪內。
/// 被接管的舊輪代號 ≠ 現任 generation，其共用狀態寫入以此被丟棄（T-0359 D04）。
enum App2RevalidateRound {
    @TaskLocal static var id: Int = 0
}

@MainActor
protocol App2Revalidating: AnyObject {
    var hasLoaded: Bool { get }
    var lastLoadedAt: Date? { get }
    /// 向後端重取一次。已經有資料時**不清畫面、不進 loading**。
    func revalidate() async
}

extension App2Revalidating {
    /// 第一次進頁 → 正常載入（會出 loading）。
    /// 之後再進來 → 只有超過 `staleAfter` 才在背景重驗，畫面保留舊資料。
    func loadIfNeeded(staleAfter: TimeInterval = 60) async {
        guard hasLoaded else {
            await revalidate()
            return
        }
        guard let lastLoadedAt, Date().timeIntervalSince(lastLoadedAt) > staleAfter else { return }
        await revalidate()
    }

    /// 下拉刷新：跳過 60 秒門檻直接重驗。語意與 `loadIfNeeded` 同一條
    /// （同一份資料、同一個 ViewModel 狀態），不是第二套快取。
    func forceRefresh() async {
        await revalidate()
    }
}

// MARK: - PersonalAchievementsViewModel + App2Revalidating
/// 成就頁在 2.0 只是**第二個版面**，ViewModel／Repository／端點都沿用 1.x
/// （`GET /v2/achievements/summary`）。這裡把既有的載入路徑接上同一條 SWR 語意，
/// 四個 tab 的「進頁重驗」與「下拉刷新」才是同一套：兩者都落到既有的 `refresh()`
/// → `performLoad(forceRefresh: true)`（繞過 repository 快取重取，但 `summary`
/// 不清空、`state` 不退回 `.loading`，畫面不閃）。**沒有第二份快取。**
extension PersonalAchievementsViewModel: App2Revalidating {
    func revalidate() async {
        await refresh()
    }
}

// MARK: - App2RootView
/// 2.0 的主 tab 結構：狀態 · 課表 · 紀錄 · **成就**。
///
/// 對照 1.x 的四個 tab（訓練計畫／訓練紀錄／表現數據／成就），2.0 把「表現數據」
/// 收進首頁的訓練狀況卡（§3.1a 指標網格），第四格留給成就（設計 frame-11）。
/// **設定不是 tab** —— 入口是首頁右上角的 LV 六角徽章（2026-08-25 設計更新：
/// 課表頁 header 只剩標題＋週次切換器，頭像鈕拿掉），開成一張全螢幕頁
/// （設計 frame-21 的左上有返回鍵，是被推出來的頁而不是 tab）。
///
/// **底部導航是系統原生 `TabView`**（2026-08-26 使用者裁決）：高度、safe-area 貼底、
/// 選中態都交給系統，不再自繪懸浮膠囊。頁面內容的底部留白因此縮到
/// `App2Theme.tabBarClearance` 的小值 —— 系統 tab bar 已經自己 inset 了 scroll view。
///
/// **四個 ViewModel 由這一層持有**：`TabView` 換頁在某些情境會重建子 view 連同它的
/// `@StateObject`，切回來就重打 API。把 ViewModel 提到殼層之後，切換不重建、
/// 不重新 fetch、捲動位置也保留。
///
/// **這支只在 2.0 分支取代 `ContentView.mainAppContent()` 的 TabView。**
/// 1.x 發版線（`main`）不受影響 —— 本票不合回 main。
struct App2RootView: View {

    @ObservedObject private var appearanceStore = App2AppearanceStore.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: App2Tab = .state
    @State private var isShowingSettings = false

    @StateObject private var homeViewModel = App2HomeViewModel()
    @StateObject private var planViewModel = App2PlanViewModel()
    @StateObject private var recordsViewModel = App2RecordsViewModel()
    @StateObject private var settingsViewModel = App2SettingsViewModel()
    /// 成就頁直接用既有 feature 的 ViewModel（`GET /v2/achievements/summary`），
    /// 不另寫平行實作。
    @StateObject private var achievementsViewModel = PersonalAchievementsViewModel()

    var body: some View {
        TabView(selection: $selection) {
            App2HomeView(
                onOpenSettings: { isShowingSettings = true },
                viewModel: homeViewModel,
                // 訓練狀況卡的徽章＝成就頁那一顆，所以共用同一個 ViewModel。
                achievementsViewModel: achievementsViewModel
            )
            .tabItem { tabLabel(.state) }
            .tag(App2Tab.state)

            App2PlanView(viewModel: planViewModel)
                .tabItem { tabLabel(.plan) }
                .tag(App2Tab.plan)

            App2RecordsView(viewModel: recordsViewModel)
                .tabItem { tabLabel(.records) }
                .tag(App2Tab.records)

            App2AchievementsView(viewModel: achievementsViewModel)
                .tabItem { tabLabel(.achievements) }
                .tag(App2Tab.achievements)
        }
        .tint(App2Theme.accentBlue)
        .task {
            // **Garmin 連結狀態要在殼層恢復一次。**
            // `GarminManager.isConnected` 開機時是從 UserDefaults(`garmin_connected`)
            // 讀回來的，登出會把它清掉；1.4 靠 `AuthenticationService` 在載完 user 之後
            // 補打一次 `/connect/garmin/status`，而 2.0 的殼沒有那條路徑 —— 結果是
            // 重新登入後 Garmin 明明還連著，訓練詳情的「傳到 Garmin」鈕卻不出現
            //（2026-08-26 QA）。這裡不是第二份狀態，打的是既有的同一支。
            await GarminManager.shared.checkConnectionStatusIfNeeded()
        }
        .fullScreenCover(isPresented: $isShowingSettings) {
            App2SettingsView(
                onClose: { isShowingSettings = false },
                viewModel: settingsViewModel
            )
        }
        // 背景回前景要重驗。ViewModel 常駐殼層＋重驗只掛 `.task`（進頁才觸發）的組合，
        // 意味著隔天從背景打開 app、停在同一個 tab 時**沒有任何東西會重打 API**——
        // 昨天的跑步紀錄要殺掉 app 重開才進來（2026-08-29 使用者回報）。
        // 走同一條 SWR（60 秒門檻、不清畫面不閃 loading），不是第二套載入路徑。
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await homeViewModel.loadIfNeeded() }
            Task { await planViewModel.loadIfNeeded() }
            Task { await recordsViewModel.loadIfNeeded() }
            Task { await achievementsViewModel.loadIfNeeded() }
        }
        .accessibilityIdentifier("App2_RootView")
        .preferredColorScheme(appearanceStore.preference.colorScheme)
    }

    /// tab item 的圖與字。identifier 掛在 `Label` 上 —— 系統 tab bar 會把它帶到
    /// `UITabBarItem`，maestro 才點得到（用文字選 tab 不行：首頁今日課表卡裡就有
    /// 「課表」兩個字，會先被選中）。
    private func tabLabel(_ tab: App2Tab) -> some View {
        Label(tab.titleKey.localized, systemImage: tab.symbolName)
            .accessibilityIdentifier("App2_Tab_\(tab.rawValue.capitalized)")
    }
}

#Preview {
    App2RootView()
}
