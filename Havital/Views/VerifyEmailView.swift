import SwiftUI

struct VerifyEmailView: View {
    @StateObject private var viewModel = VerifyEmailViewModel()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("驗證碼 (oobCode)", text: $viewModel.code)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            Button(action: {
                Task {
                    await viewModel.verify()
                    if let error = viewModel.errorMessage {
                        alertTitle = "驗證失敗"
                        alertMessage = error
                    } else if let success = viewModel.successMessage {
                        alertTitle = "驗證成功"
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
                    Text("驗證 Email")
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
        .navigationTitle("驗證 Email")
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
