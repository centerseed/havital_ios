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
                        alertTitle = "註冊失敗"
                        alertMessage = error
                    } else {
                        alertTitle = "註冊成功"
                        alertMessage = "請至您的電子信箱點擊確認連結，完成驗證後返回此處登入。"
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
                    Text("註冊")
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
        .navigationTitle("註冊帳號")
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
