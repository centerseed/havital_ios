import SwiftUI

struct VerifyEmailView: View {
    @StateObject private var viewModel = VerifyEmailViewModel()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField(L10n.Auth.verifyCodePlaceholder.localized, text: $viewModel.code)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Button(action: {
                Task {
                    await viewModel.verify()
                    if let error = viewModel.errorMessage {
                        alertTitle = L10n.Auth.verifyFailed.localized
                        alertMessage = error
                    } else if let success = viewModel.successMessage {
                        alertTitle = L10n.Auth.verifySuccess.localized
                        alertMessage = success
                    }
                    showAlert = true
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(L10n.Auth.verifyEmail.localized)
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
        .navigationTitle(L10n.Auth.verifyEmailTitle.localized)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    NavigationStack { VerifyEmailView() }
}
