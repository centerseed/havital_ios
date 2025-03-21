//
//  HavitalApp.swift
//  Havital
//
//  Created by 吳柏宗 on 2024/12/9.
//

import SwiftUI
import HealthKit
import FirebaseCore
import FirebaseAppCheck

@main
struct HavitalApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isHealthKitAuthorized") private var isHealthKitAuthorized = false
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var authService = AuthenticationService.shared
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            if !authService.isAuthenticated {
                LoginView()
                    .environmentObject(appViewModel)
            } else if !hasCompletedOnboarding {
                OnboardingView()
                   .environmentObject(appViewModel)
            } else {
                TabView {
                    TrainingPlanView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "figure.run")
                            Text("訓練計劃")
                        }
                    
                    TrainingRecordView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "chart.line.text.clipboard")
                            Text("訓練紀錄")
                        }
                    
                    MyAchievementView()
                        .environmentObject(healthKitManager)
                        .tabItem {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            Text("表現數據")
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
