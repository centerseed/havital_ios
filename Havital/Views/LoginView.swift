import SwiftUI

struct LoginView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Title and Subtitle
            VStack(spacing: 16) {
                Text("Havital")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(AppTheme.shared.primaryColor)
                
                Text("Make daily exercise more easily")
                    .font(.title2)
                    .foregroundColor(AppTheme.TextColors.secondary)
            }
            
            // Welcome Image
            Image("welcome") // Make sure to add this image to assets
                .resizable()
                .scaledToFit()
                .frame(height: 250)
                .padding(.horizontal)
            
            Spacer()
            
            // Login/Signup Buttons
            VStack(spacing: 16) {
                Button {
                    isLoggedIn = true
                } label: {
                    Text("登入")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.shared.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    isLoggedIn = true
                } label: {
                    Text("註冊")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.shared.cardBackgroundColor)
                        .foregroundColor(AppTheme.shared.primaryColor)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.shared.primaryColor, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(AppTheme.shared.backgroundColor)
    }
}

#Preview {
    LoginView()
}
