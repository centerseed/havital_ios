import SwiftUI

struct EmailLoginView: View {
    @StateObject private var viewModel = EmailLoginViewModel()
    @State private var showAlert = false
    @State private var showResendSuccess = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss

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
                    Text("登入")
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
        .navigationTitle("Email 登入")
        .alert("登入失敗", isPresented: $showAlert) {
            // 僅 email 未驗證時顯示重新發送按鈕
            if viewModel.canResendVerification {
                Button("重新發送驗證信") {
                    Task {
                        await viewModel.resendVerification()
                        showResendSuccess = true
                    }
                }
            }
            Button("確定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("提示", isPresented: $showResendSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(viewModel.resendSuccessMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack { EmailLoginView() }
}
