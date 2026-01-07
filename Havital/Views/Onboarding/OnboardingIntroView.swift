// Havital/Views/Onboarding/OnboardingIntroView.swift
import SwiftUI

struct OnboardingIntroView: View {
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    var body: some View {
        // 移除 NavigationView - 由 OnboardingContainerView 的 NavigationStack 管理
        ScrollView {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        // 標題區塊
                        VStack(spacing: 16) {
                            Image("paceriz_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)

                            Text(NSLocalizedString("onboarding.welcome_to_paceriz", comment: "Welcome to Paceriz!"))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 20)
                        
                        // 主要內容區塊
                        VStack(alignment: .leading, spacing: 24) {
                            Text(NSLocalizedString("onboarding.ready_to_start", comment: "Ready to start your running journey?"))
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text(NSLocalizedString("onboarding.training_focus", comment: "Our training plans focus on:"))
                                .font(.headline)
                            
                            // 特色項目
                            VStack(alignment: .leading, spacing: 16) {
                                featureRow(icon: "target", 
                                         title: NSLocalizedString("onboarding.goal_oriented", comment: "Goal-Oriented"), 
                                         description: NSLocalizedString("onboarding.goal_oriented_desc", comment: "Goal oriented description"))
                                
                                featureRow(icon: "arrow.triangle.2.circlepath", 
                                         title: NSLocalizedString("onboarding.progressive", comment: "Progressive Training"), 
                                         description: NSLocalizedString("onboarding.progressive_desc", comment: "Progressive training description"))
                                
                                featureRow(icon: "heart.text.square", 
                                         title: NSLocalizedString("onboarding.heart_rate_guided", comment: "Heart Rate Guided"), 
                                         description: NSLocalizedString("onboarding.heart_rate_guided_desc", comment: "Heart rate guided description"))
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        Spacer()
                        
                        // 底部提示文字
                        Text(NSLocalizedString("onboarding.setup_guide", comment: "Setup guide text"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                        // 開始設定按鈕
                        Button(action: {
                            coordinator.navigate(to: .dataSource)
                        }) {
                            Text(NSLocalizedString("onboarding.start_setup", comment: "Start Setup"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        }
                        .accessibilityIdentifier("OnboardingStartButton")
                        .padding(.horizontal, 40)
                        .padding(.bottom, 30)
                        .padding(.top, 10)
                    }
                    .padding(.top, 8)
                }
        .navigationBarHidden(true)
        .navigationBarTitle("", displayMode: .inline)
    }

    // 輔助視圖：創建統一風格的特色項目行
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("**\(title)**")
                    .font(.subheadline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingIntroView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingIntroView()
    }
}
