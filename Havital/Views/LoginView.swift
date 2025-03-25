import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var authService = AuthenticationService.shared
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Title and Subtitle
            VStack(spacing: 16) {
                Text("Paceriz")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(AppTheme.shared.primaryColor)
                
                Text("讓我們輕鬆踏上，運動健康之路")
                    .font(.title2)
                    .foregroundColor(AppTheme.TextColors.secondary)
            }
            
            // Welcome Image
            Image("welcome")
                .resizable()
                .scaledToFit()
                .frame(height: 250)
                .padding(.horizontal)
            
            Spacer()
            
            // Login Button
            VStack(spacing: 16) {
                Button {
                    Task {
                        await authService.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("使用 Google 登入")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(authService.isLoading ? Color.gray : AppTheme.shared.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(authService.isLoading)
                .overlay(
                    Group {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.backgroundColor) : UIColor(AppTheme.shared.backgroundColor)
        }))
        .onReceive(authService.$loginError) { newError in
            if let error = newError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("登入失敗", isPresented: $showError) {
            Button("確定", role: .cancel) {
                authService.loginError = nil
            }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    LoginView()
}
