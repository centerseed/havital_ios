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
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                            
                            Text(L10n.AppLoadingView.initializationFailed.localized)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(L10n.AppLoadingView.checkConnection.localized)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            Task {
                                await appStateManager.reinitialize()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text(L10n.AppLoadingView.restart.localized)
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .frame(width: 200)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
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