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
    @AppStorage("isHealthKitAuthorized") private var isHealthKitAuthorized = false
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                //LoginView()
                //    .environmentObject(appViewModel)
                OnboardingView()
                   .environmentObject(appViewModel)
            } else if !isLoggedIn {
                LoginView()
                    .environmentObject(appViewModel)
            } else {
                TabView {
                    TrainingPlanView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("訓練計劃")
                        }
                    
                    TrainingRecordView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "chart.bar.fill")
                            Text("訓練紀錄")
                        }
                    
                    MyAchievementView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "star")
                            Text("我的成就")
                        }
                }
                .onAppear {
                    requestHealthKitAuthorization()
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
    }
    
    private func requestHealthKitAuthorization() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await MainActor.run {
                    isHealthKitAuthorized = true
                }
            } catch {
                print("HealthKit authorization failed: \(error)")
                await MainActor.run {
                    isHealthKitAuthorized = false
                }
            }
        }
    }
}
