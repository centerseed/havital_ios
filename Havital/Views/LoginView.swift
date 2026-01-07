import SwiftUI
import FirebaseAuth

struct LoginView: View {
    // Clean Architecture: Transition - Keep using AuthenticationService but from environment
    // TODO: Migrate to LoginViewModel in future refactor (requires Apple Sign In UI handling)
    @EnvironmentObject private var authService: AuthenticationService
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            VStack(spacing: 60) {
                Spacer()

                // Title and Subtitle
                VStack(spacing: 16) {
                    Image("paceriz_light")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(AppTheme.shared.primaryColor)
                        .frame(height: 60)

                    Text(NSLocalizedString("login.tagline", comment: "Login tagline"))
                        .font(.title2)
                        .foregroundColor(AppTheme.TextColors.secondary)
                        .multilineTextAlignment(.center)
                }



                Spacer()

                // Login Buttons
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await authService.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text(NSLocalizedString("login.google_signin", comment: "Sign in with Google"))
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

                    Button {
                        Task {
                            await authService.signInWithApple()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.title2)
                            Text(NSLocalizedString("login.apple_signin", comment: "Sign in with Apple"))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(authService.isLoading ? Color.gray : Color.black) // Apple's branding is typically black or white
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
                .padding(.bottom, 48) // 增加底部間距，讓按鈕不會太靠近底部

                Spacer()

                // Demo Mode 按鈕 (放在最下方)
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

                    Button {
                        Task {
                            await authService.demoLogin()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("login.demo_mode", comment: ""))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(NSLocalizedString("login.for_apple_review", comment: ""))
                                    .font(.caption)
                                    .opacity(0.7)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                    .disabled(authService.isLoading)
                    .accessibilityIdentifier("Login_DemoButton")
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.backgroundColor) : UIColor(AppTheme.shared.backgroundColor)
        }))
        .onReceive(authService.$loginError) { newError in
            if let error = newError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert(NSLocalizedString("login.failed", comment: "Login Failed"), isPresented: $showError) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {
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
