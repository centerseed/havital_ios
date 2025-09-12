import SwiftUI

struct NetworkErrorToast: View {
    let message: String
    let onDismiss: () -> Void
    
    @State private var show = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.orange)
                .font(.system(size: 16, weight: .medium))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 16)
        .offset(y: show ? 0 : -100)
        .opacity(show ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: show)
        .onAppear {
            show = true
            
            // 3秒後自動消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        show = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Toast Container Modifier
extension View {
    func networkErrorToast(
        isPresented: Binding<Bool>,
        message: String
    ) -> some View {
        ZStack(alignment: .top) {
            self
            
            if isPresented.wrappedValue {
                VStack {
                    NetworkErrorToast(
                        message: message,
                        onDismiss: {
                            isPresented.wrappedValue = false
                        }
                    )
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .zIndex(999)
            }
        }
    }
}