import SwiftUI

/// 加載動畫視圖，支援預設的消息類型
struct LoadingAnimationView: View {
    /// 加載動畫的類型
    enum LoadingType {
        case generatePlan    // 產生週課表
        case generateReview  // 產生週回顧
        case custom([String]) // 自定義消息
        
        var messages: [String] {
            switch self {
            case .generatePlan:
                return [
                    "正在分析您的體能狀態...",
                    "正在規劃這週的訓練強度...",
                    "為您準備客製化課表，請稍後..."
                ]
            case .generateReview:
                return [
                    "正在分析本週訓練數據...",
                    "正在評估這週的訓練狀況...",
                    "太好了，訓練回顧即將準備好了！"
                ]
            case .custom(let messages):
                return messages
            }
        }
    }
    
    @State private var progress: CGFloat = 0.0
    @State private var shoeBounce = false
    @State private var messageIndex = 0
    private let messages: [String]
    private let totalDuration: Double
    
    /// 使用預設的加載類型初始化
    /// - Parameters:
    ///   - type: 加載類型，預設為產生週課表
    ///   - totalDuration: 總動畫持續時間，預設 25 秒
    init(type: LoadingType = .generatePlan, totalDuration: Double = 25) {
        self.messages = type.messages
        self.totalDuration = totalDuration
    }
    
    /// 使用自定義消息初始化
    /// - Parameters:
    ///   - messages: 自定義消息數組
    ///   - totalDuration: 總動畫持續時間，預設 25 秒
    init(messages: [String], totalDuration: Double = 25) {
        self.init(type: .custom(messages), totalDuration: totalDuration)
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .opacity(0.95)
            
            VStack(spacing: 30) {
                Spacer()
                
                // 鞋子圖示 + 動畫
                Image(systemName: "shoe.2")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .offset(y: shoeBounce ? -10 : 10)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: shoeBounce)
                
                // 輪播訊息
                Text(messages[messageIndex])
                    .font(.headline)
                    .foregroundColor(.primary)
                    .transition(.opacity)
                    .id(messageIndex)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // 進度條
                ZStack(alignment: .leading) {
                    Capsule()
                        .frame(height: 8)
                        .foregroundColor(Color(.systemGray5))
                    
                    Capsule()
                        .frame(width: progressBarWidth(), height: 8)
                        .foregroundColor(.blue)
                        .animation(.linear(duration: totalDuration), value: progress)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func progressBarWidth() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 80
        return screenWidth * progress
    }
    
    private func startAnimation() {
        shoeBounce = true
        
        // 開始進度動畫
        withAnimation(.linear(duration: totalDuration)) {
            progress = 1.0
        }
        
        // 平均分配每則訊息的顯示時間
        let messageCount = messages.count
        if messageCount > 1 {
            let interval = totalDuration / Double(messageCount)
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                withAnimation {
                    messageIndex = (messageIndex + 1) % messageCount
                    
                    // 如果動畫即將結束，停止計時器
                    if progress >= 0.95 {
                        timer.invalidate()
                    }
                }
            }
        }
    }
}

// MARK: - 預覽視圖
struct LoadingAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        // 產生週課表預覽
        LoadingAnimationView(type: .generatePlan)
            .previewDisplayName("產生週課表")
        
        // 產生週回顧預覽
        LoadingAnimationView(type: .generateReview)
            .previewDisplayName("產生週回顧")
            .previewLayout(.sizeThatFits)
        
        // 深色模式預覽
        LoadingAnimationView(type: .generatePlan)
            .preferredColorScheme(.dark)
            .previewDisplayName("深色模式")
        
        // 自定義消息預覽
        LoadingAnimationView(messages: ["正在處理中...", "請稍候..."])
            .previewDisplayName("自定義消息")
    }
}
