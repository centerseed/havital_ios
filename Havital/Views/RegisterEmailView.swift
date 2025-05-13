import SwiftUI

struct RegisterEmailView: View {
    @StateObject private var viewModel = RegisterEmailViewModel()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var navigateToVerify = false

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
                        showAlert = true
                    } else {
                        // 註冊成功，前往輸入驗證碼畫面
                        navigateToVerify = true
                    }
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
            // navigation link to verification
            NavigationLink(destination: VerifyEmailView(), isActive: $navigateToVerify) {
                EmptyView()
            }
        }
        .padding()
        .navigationTitle("註冊帳號")
        .alert(alertTitle, isPresented: $showAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    NavigationStack { RegisterEmailView() }
}
