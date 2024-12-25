//
//  HavitalApp.swift
//  Havital
//
//  Created by 吳柏宗 on 2024/12/9.
//

import SwiftUI
import HealthKit

@main
struct HavitalApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !isLoggedIn {
                    LoginView().environmentObject(healthKitManager)
                } else if !hasCompletedOnboarding {
                    OnboardingView().environmentObject(healthKitManager)
                } else {
                    TabView {
                        TrainingPlanView()
                            .tabItem {
                                Image(systemName: "list.bullet")
                                Text("訓練計劃")
                            }
                        TrainingRecordView()
                            .tabItem {
                                Image(systemName: "chart.bar.fill")
                                Text("訓練紀錄")
                            }
                        MyAchievementView()
                            .tabItem {
                                Image(systemName: "star")
                                Text("我的成就")
                            }
                    }
                }
            }
            .environmentObject(healthKitManager)
            .onAppear {
                Task {
                    await requestHealthKitAuthorization()
                }
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
    }
    
    private func requestHealthKitAuthorization() async {
        await withCheckedContinuation { continuation in
            healthKitManager.requestAuthorization { success in
                if !success {
                    appViewModel.healthKitAlertMessage = "請在設定中允許 Havital 存取健康資料，以獲得完整的訓練追蹤功能"
                    appViewModel.showHealthKitAlert = true
                }
                continuation.resume()
            }
        }
    }
}
