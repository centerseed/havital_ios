import SwiftUI

// MARK: - App2RootView
/// 2.0 的主 tab 結構：狀態 · 課表 · 紀錄 · 設定。
///
/// 對照 1.x 的四個 tab（訓練計畫／訓練紀錄／表現數據／成就），2.0 把「表現數據」
/// 收進首頁的訓練狀況卡（§3.1a 指標網格），把「成就」暫時移出主導航，換進「設定」
/// （§3.9a）。這是資訊架構的重建，不是換圖示。
///
/// **這支只在 2.0 分支取代 `ContentView.mainAppContent()` 的 TabView。**
/// 1.x 發版線（`main`）不受影響 —— 本票不合回 main。
struct App2RootView: View {

    var body: some View {
        TabView {
            App2HomeView()
                .tabItem {
                    Image(systemName: "waveform.path.ecg")
                    Text(L10n.App2.Tab.state.localized)
                }
                .accessibilityIdentifier("App2_Tab_State")

            App2PlanView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text(L10n.App2.Tab.plan.localized)
                }
                .accessibilityIdentifier("App2_Tab_Plan")

            App2RecordsView()
                .tabItem {
                    Image(systemName: "list.clipboard")
                    Text(L10n.App2.Tab.records.localized)
                }
                .accessibilityIdentifier("App2_Tab_Records")

            App2SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(L10n.App2.Tab.settings.localized)
                }
                .accessibilityIdentifier("App2_Tab_Settings")
        }
        .tint(App2Theme.accentBlue)
        .toolbarBackground(App2Theme.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .accessibilityIdentifier("App2_RootView")
    }
}

#Preview {
    App2RootView()
}
