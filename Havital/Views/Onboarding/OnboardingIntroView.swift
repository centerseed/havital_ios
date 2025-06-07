// Havital/Views/Onboarding/OnboardingIntroView.swift
import SwiftUI

struct OnboardingIntroView: View {
    @State private var navigateToNextStep = false

    var body: some View {
        NavigationView { // 這個 NavigationView 將是 onboarding 流程的起點
            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                    
                    // 標題區塊
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.accentColor)
                        
                        Text("歡迎來到 Paceriz！")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 20)
                    
                    // 主要內容區塊
                    VStack(alignment: .leading, spacing: 24) {
                        Text("準備好開始您的跑步旅程了嗎？Paceriz 將根據您的個人目標和體能狀況，為您量身打造科學化的訓練計畫，幫助您跑得更遠、更快、更健康。")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("我們的訓練計畫融合了專業的跑步知識，注重：")
                            .font(.headline)
                        
                        // 特色項目
                        VStack(alignment: .leading, spacing: 16) {
                            featureRow(icon: "target", 
                                     title: "目標導向", 
                                     description: "無論您的目標是完成第一場5公里、挑戰馬拉松，還是提升個人紀錄，我們都會為您規劃清晰的路徑。")
                            
                            featureRow(icon: "arrow.triangle.2.circlepath", 
                                     title: "循序漸進", 
                                     description: "透過合理安排訓練強度與跑量，逐步提升您的體能，有效預防運動傷害。")
                            
                            featureRow(icon: "heart.text.square", 
                                     title: "心率引導", 
                                     description: "學習運用心率區間進行訓練，讓每次跑步更有效率，最大化您的訓練成果。")
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // 底部提示文字
                    Text("接下來，我們將引導您完成幾個簡單的設定，以便更了解您的需求。讓我們一起開始吧！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // 開始設定按鈕
                    Button(action: {
                        navigateToNextStep = true
                    }) {
                        Text("開始設定")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                    .padding(.top, 10)
                }
                .padding()
            }
            .navigationBarHidden(true) // 隱藏此頁的導航欄，因為它是流程的起點
            .navigationBarTitle("", displayMode: .inline)
            // 隱藏的 NavigationLink
            NavigationLink(destination: OnboardingView().navigationBarBackButtonHidden(true), isActive: $navigateToNextStep) {
                EmptyView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // 確保是堆疊式導航
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
