import SwiftUI

/// App 載入畫面 - 顯示初始化進度
struct AppLoadingView: View {
    @ObservedObject var appStateManager = AppStateManager.shared
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 應用圖示或 Logo
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(appStateManager.initializationProgress > 0 ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                              value: appStateManager.initializationProgress)
                
                // 載入狀態文字
                Text(appStateManager.currentState.description)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // 進度条
                ProgressView(value: appStateManager.initializationProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
                
                // 進度百分比
                Text("\(Int(appStateManager.initializationProgress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // 錯誤狀態的重試按鈕
                if case .error(let errorMessage) = appStateManager.currentState {
                    VStack(spacing: 12) {
                        Text("錯誤: \(errorMessage)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("重試") {
                            Task {
                                await appStateManager.reinitialize()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.top, 16)
                }
            }
            .padding(32)
        }
    }
}

#Preview {
    AppLoadingView()
}