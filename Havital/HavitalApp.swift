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
    
    var body: some Scene {
        WindowGroup {
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
                .environmentObject(healthKitManager)
            }
        }
    }
}
