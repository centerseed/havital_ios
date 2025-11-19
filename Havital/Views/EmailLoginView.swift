import SwiftUI

struct EmailLoginView: View {
    @StateObject private var viewModel = EmailLoginViewModel()
    @State private var showAlert = false
    @State private var showResendSuccess = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            TextField(L10n.Auth.emailPlaceholder.localized, text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            SecureField(L10n.Auth.passwordPlaceholder.localized, text: $viewModel.password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Button(action: {
                Task {
                    await viewModel.login()
                    if let error = viewModel.errorMessage {
                        alertMessage = error
                        showAlert = true
                    } else {
                        dismiss()
                    }
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(NSLocalizedString("common.login", comment: "Log In"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.shared.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(viewModel.isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle(NSLocalizedString("login.email_title", comment: "Email Login"))
        .alert(NSLocalizedString("login.failed", comment: "Login Failed"), isPresented: $showAlert) {
            // 僅 email 未驗證時顯示重新發送按鈕
            if viewModel.canResendVerification {
                Button(NSLocalizedString("login.email_not_verified_resend", comment: "Resend Verification Email")) {
                    Task {
                        await viewModel.resendVerification()
                        showResendSuccess = true
                    }
                }
            }
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert(NSLocalizedString("login.resend_success_title", comment: "Notice"), isPresented: $showResendSuccess) {
            Button(NSLocalizedString("common.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(viewModel.resendSuccessMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack { EmailLoginView() }
}
