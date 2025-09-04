import SwiftUI

struct RegisterEmailView: View {
    @StateObject private var viewModel = RegisterEmailViewModel()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Button(action: {
                Task {
                    await viewModel.register()
                    if let error = viewModel.errorMessage {
                        alertTitle = L10n.Auth.registerFailed.localized
                        alertMessage = error
                    } else {
                        alertTitle = L10n.Auth.registerSuccess.localized
                        alertMessage = L10n.Auth.registerSuccessMessage.localized
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
                    Text(L10n.Auth.register.localized)
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
        .navigationTitle(L10n.Auth.registerTitle.localized)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("確定", role: .cancel) { presentationMode.wrappedValue.dismiss() }
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    NavigationStack { RegisterEmailView() }
}
