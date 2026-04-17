import SwiftUI
import UIKit

// MARK: - Login View (Clean Architecture)
/// Uses LoginViewModel for authentication operations
/// All authentication flows are handled via Repository pattern
struct LoginView: View {
    // Clean Architecture: Use LoginViewModel instead of AuthenticationService
    @StateObject private var viewModel = LoginViewModel()
    @State private var showError = false
    @State private var reviewerAccessProgress: CGFloat = 0
    @State private var reviewerAccessTriggered = false
    @State private var isReviewerAccessSheetPresented = false
    @State private var reviewerPasscode = ""
    @State private var reviewerProgressTask: Task<Void, Never>?
    @FocusState private var isReviewerPasscodeFocused: Bool
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
                        .accessibilityIdentifier("Login_ReviewerAccessTrigger")

                    ReviewerAccessProgressBar(progress: reviewerAccessProgress)
                        .frame(width: 160, height: 6)
                        .accessibilityIdentifier("Login_ReviewerAccessProgress")

                    Text(NSLocalizedString("login.tagline", comment: "Login tagline"))
                        .font(AppFont.title2())
                        .foregroundColor(AppTheme.TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .contentShape(Rectangle())
                .onLongPressGesture(
                    minimumDuration: ReviewerAccessConfig.minimumPressDuration,
                    maximumDistance: 24,
                    pressing: handleReviewerPressChange(_:),
                    perform: presentReviewerAccessSheet
                )

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
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(AppTheme.DarkMode.backgroundColor) : UIColor(AppTheme.shared.backgroundColor)
        }))
        .sheet(isPresented: $isReviewerAccessSheetPresented, onDismiss: resetReviewerAccessForm) {
            NavigationView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(NSLocalizedString("login.reviewer_access_title", comment: ""))
                        .font(AppFont.title2())
                        .fontWeight(.semibold)

                    Text(NSLocalizedString("login.reviewer_access_message", comment: ""))
                        .font(AppFont.body())
                        .foregroundColor(AppTheme.TextColors.secondary)

                    SecureField(NSLocalizedString("login.reviewer_passcode_placeholder", comment: ""), text: $reviewerPasscode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.asciiCapable)
                        .focused($isReviewerPasscodeFocused)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .accessibilityIdentifier("Login_ReviewerPasscodeField")
                        .onSubmit {
                            activateReviewerDemo()
                        }

                    Button(action: activateReviewerDemo) {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(NSLocalizedString("login.activate_demo_access", comment: ""))
                                    .font(AppFont.title3())
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(reviewerPasscode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : AppTheme.shared.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || reviewerPasscode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("Login_ReviewerActivateButton")

                    Button(NSLocalizedString("common.cancel", comment: "")) {
                        isReviewerAccessSheetPresented = false
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("Login_ReviewerCancelButton")

                    Spacer()
                }
                .padding(24)
                .navigationBarTitleDisplayMode(.inline)
            }
            .accessibilityIdentifier("Login_ReviewerAccessSheet")
            .onAppear {
                isReviewerPasscodeFocused = true
            }
        }
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
        .onDisappear {
            stopReviewerProgress(resetProgress: true)
        }
    }

    private func handleReviewerPressChange(_ isPressing: Bool) {
        if isPressing {
            startReviewerProgress()
        } else if !reviewerAccessTriggered {
            stopReviewerProgress(resetProgress: true)
        }
    }

    private func startReviewerProgress() {
        reviewerAccessTriggered = false
        reviewerProgressTask?.cancel()
        reviewerAccessProgress = 0

        reviewerProgressTask = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                reviewerAccessProgress = min(1, elapsed / ReviewerAccessConfig.minimumPressDuration)
                if reviewerAccessProgress >= 1 {
                    break
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func stopReviewerProgress(resetProgress: Bool) {
        reviewerProgressTask?.cancel()
        reviewerProgressTask = nil
        if resetProgress {
            reviewerAccessProgress = 0
        }
    }

    private func presentReviewerAccessSheet() {
        reviewerAccessTriggered = true
        stopReviewerProgress(resetProgress: false)
        reviewerAccessProgress = 1
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isReviewerAccessSheetPresented = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            reviewerAccessProgress = 0
            reviewerAccessTriggered = false
        }
    }

    private func activateReviewerDemo() {
        let trimmedPasscode = reviewerPasscode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPasscode.isEmpty else { return }

        Task {
            await viewModel.demoLogin(passcode: trimmedPasscode)
            if viewModel.authenticatedUser != nil {
                resetReviewerAccessForm()
                isReviewerAccessSheetPresented = false
            }
        }
    }

    private func resetReviewerAccessForm() {
        reviewerPasscode = ""
        isReviewerPasscodeFocused = false
    }
}

#Preview {
    LoginView()
}

private enum ReviewerAccessConfig {
    static var minimumPressDuration: TimeInterval {
        if let override = launchArgumentValue(for: "-reviewerAccessPressDuration"),
           let duration = TimeInterval(override) {
            return max(0.5, duration)
        }

        #if DEBUG
        return 1.0
        #else
        return 5.0
        #endif
    }

    private static func launchArgumentValue(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

private struct ReviewerAccessProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))

                Capsule()
                    .fill(AppTheme.shared.primaryColor)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .opacity(progress > 0 ? 1 : 0)
        .animation(.linear(duration: 0.05), value: progress)
    }
}
