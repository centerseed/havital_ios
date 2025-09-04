import SwiftUI

struct GarminReconnectionAlert: View {
    @ObservedObject var garminManager = GarminManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // 圖示
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            // 標題
            Text(L10n.GarminReconnectionAlert.title.localized)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // 訊息
            Text(garminManager.reconnectionMessage ?? L10n.GarminReconnectionAlert.defaultMessage.localized)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // 按鈕
            VStack(spacing: 12) {
                // 重新綁定按鈕
                Button {
                    Task {
                        await garminManager.startConnection()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text(L10n.GarminReconnectionAlert.reconnectButton.localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // 稍後提醒按鈕
                Button {
                    garminManager.clearReconnectionMessage()
                    dismiss()
                } label: {
                    Text(L10n.GarminReconnectionAlert.remindLaterButton.localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
    }
}

struct GarminReconnectionAlertModifier: ViewModifier {
    @ObservedObject var garminManager = GarminManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // 半透明背景
                Group {
                    if garminManager.needsReconnection {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .overlay(
                                GarminReconnectionAlert()
                                    .onAppear {
                                        print("🚨 GarminReconnectionAlert 顯示")
                                        print("  - needsReconnection: \(garminManager.needsReconnection)")
                                        print("  - isConnected: \(garminManager.isConnected)")
                                        print("  - reconnectionMessage: \(garminManager.reconnectionMessage ?? "nil")")
                                    }
                            )
                            .transition(.opacity)
                    }
                }
            )
    }
}

extension View {
    func garminReconnectionAlert() -> some View {
        modifier(GarminReconnectionAlertModifier())
    }
}

#Preview {
    VStack {
        Text("主要內容")
            .padding()
        Spacer()
    }
    .garminReconnectionAlert()
    .onAppear {
        // 預覽時顯示警告
        GarminManager.shared.needsReconnection = true
        GarminManager.shared.reconnectionMessage = "您的 Garmin Connect™ 連線狀態已過期，請重新綁定以確保數據正常同步。"
    }
}