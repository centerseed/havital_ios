import SwiftUI

// MARK: - Login View (Clean Architecture)
/// Uses LoginViewModel for authentication operations
/// All authentication flows are handled via Repository pattern
struct LoginView: View {
    // Clean Architecture: Use LoginViewModel instead of AuthenticationService
    @StateObject private var viewModel = LoginViewModel()
    @State private var showError = false
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
                        .font(AppFont.title2())
                        .foregroundColor(AppTheme.TextColors.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Login Buttons
                VStack(spacing: 16) {
                    // Google Sign-In Button
                    Button {
                        Task {
                            await viewModel.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(AppFont.title2())
                            Text(NSLocalizedString("login.google_signin", comment: "Sign in with Google"))
                                .font(AppFont.title3())
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isLoading ? Color.gray : AppTheme.shared.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .overlay(
                        Group {
                            if viewModel.isGoogleSignInLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    )

                    // Apple Sign-In Button
                    Button {
                        Task {
                            await viewModel.signInWithApple()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(AppFont.title2())
                            Text(NSLocalizedString("login.apple_signin", comment: "Sign in with Apple"))
                                .font(AppFont.title3())
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isLoading ? Color.gray : Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .overlay(
                        Group {
                            if viewModel.isAppleSignInLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

                Spacer()

                // Demo Mode Button
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

                    Button {
                        Task {
                            await viewModel.demoLogin()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(AppFont.title2())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("login.demo_mode", comment: ""))
                                    .font(AppFont.title3())
                                    .fontWeight(.semibold)
                                Text(NSLocalizedString("login.for_apple_review", comment: ""))
                                    .font(AppFont.caption())
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
                    .disabled(viewModel.isLoading)
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
        .onChange(of: viewModel.hasError) { hasError in
            showError = hasError
        }
        .alert(NSLocalizedString("login.failed", comment: "Login Failed"), isPresented: $showError) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) {
                // Reset error state
            }
        } message: {
            Text(viewModel.getErrorMessage() ?? "Unknown error")
        }
    }
}

#Preview {
    LoginView()
}
