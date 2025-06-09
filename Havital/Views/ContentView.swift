// Havital/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var appViewModel: AppViewModel // 新增對 AppViewModel 的環境物件引用
    // 假設 AppState 用於管理主 App 的其他狀態，例如選中的 Tab
    // @StateObject private var appState = AppState() // 如果你有 AppState 並且需要它
    // 移除 fullScreenCover 相關邏輯

    var body: some View {
        Group {
            if !authService.isAuthenticated {
                LoginView()
                    .environmentObject(authService)
            } else if !authService.hasCompletedOnboarding {
                OnboardingIntroView()
                    .environmentObject(authService)
            } else {
                mainAppContent()
            }
        }
        .onChange(of: authService.hasCompletedOnboarding) { _ in
            // 完成或重置 onboarding 時自動關閉 modal
            // 移除 fullScreenCover 相關邏輯
        }
        .onChange(of: authService.isReonboardingMode) { _ in
            // 移除 fullScreenCover 相關邏輯
        }
    }

    // 抽取主應用內容，方便管理
    @ViewBuilder
    private func mainAppContent() -> some View {
        // 從 HavitalApp.swift 遷移過來的 TabView
        TabView {
            TrainingPlanView()
                // .environmentObject(healthKitManager) // healthKitManager 已在 ContentView 層級注入
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("訓練計劃")
                }
            
            TrainingRecordView()
                // .environmentObject(healthKitManager) // healthKitManager 已在 ContentView 層級注入
                .tabItem {
                    Image(systemName: "chart.line.text.clipboard")
                    Text("訓練紀錄")
                }
            
            MyAchievementView()
                // .environmentObject(healthKitManager) // healthKitManager 已在 ContentView 層級注入
                .tabItem {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    Text("表現數據")
                }
        }
        .onAppear {
            // 當主畫面出現時，一次性請求所有必要權限並設置背景處理
            // 這裡需要能夠呼叫 HavitalApp 中的 setupAllPermissionsAndBackgroundProcessing()
            // 或者將該方法的邏輯移到一個 AppViewModel 或類似的地方，ContentView 可以存取
            // 暫時，我們假設 AppViewModel 中有這個方法或可以觸發這個邏輯
            // 如果 AppViewModel 是 @EnvironmentObject，則可以直接呼叫
            // appViewModel.setupAllPermissionsAndBackgroundProcessing()
            // 實際情況下，你可能需要將 HavitalApp 中的私有方法重構到 AppViewModel
            // 為了演示，我們先註解掉，你需要在你的 AppViewModel 中實現類似功能並從這裡呼叫
            // print("Main TabView appeared. Triggering permission setup.")
            // appViewModel.requestPermissionsAndSetupBackgroundTasks() // 假設 AppViewModel 有此方法
        }
        .alert("需要健康資料權限", isPresented: $appViewModel.showHealthKitAlert) {
            Button("前往設定", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(appViewModel.healthKitAlertMessage)
        }
    }


    
    // 輔助屬性，用於避免在 SwiftUI Previews 中自動彈出 Onboarding
    private var isInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // 建立一個模擬的 AuthenticationService 供預覽使用
        let authService = AuthenticationService.shared
        let appViewModel = AppViewModel() // 建立一個 AppViewModel 實例供預覽
        // 你可以根據需要設定 authService 和 appViewModel 的狀態來預覽不同場景
        // authService.isAuthenticated = true
        // authService.hasCompletedOnboarding = false
        // appViewModel.showHealthKitAlert = true // 範例
        
        return ContentView()
            .environmentObject(authService)
            .environmentObject(appViewModel) // 注入 AppViewModel
    }
}
