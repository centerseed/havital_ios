import SwiftUI

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("載入中...")
                        Spacer()
                    }
                } else if let userData = viewModel.userData {
                    // User Profile Header
                    HStack(spacing: 16) {
                        if let photoURL = userData.photoUrl,
                           let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .foregroundColor(.blue.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(userData.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text(userData.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                
                        }
                    }
                    .padding(.vertical, 8)
                } else if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text("載入失敗: \(error.localizedDescription)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                }
            }
            
            if let userData = viewModel.userData {
                // Heart Rate Section
                Section(header: Text("心率資訊")) {
                    HStack {
                        Label("最大心率", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text(viewModel.formatHeartRate(userData.maxHr ?? 0))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Label("靜息心率", systemImage: "heart")
                            .foregroundColor(.blue)
                        Spacer()
                        Text(viewModel.formatHeartRate(userData.relaxingHr ?? 0))
                            .fontWeight(.medium)
                    }
                }
                
                // Training Days Section
                Section(header: Text("訓練日")) {
                    // Days of the week in order (Monday to Sunday)
                    ForEach(1...7, id: \.self) { dayIndex in
                        if userData.preferWeekDays.contains(dayIndex) {
                            HStack {
                                Text(viewModel.weekdayName(for: dayIndex))
                                    .fontWeight(.medium)
                                
                                if userData.preferWeekDaysLongrun.contains(dayIndex) {
                                    Spacer()
                                    Text("長跑日")
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .foregroundColor(Color.blue)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                } else {
                                    Spacer()
                                    Text("一般訓練")
                                        .font(.subheadline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .foregroundColor(Color.green)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
            }
            
            Section {
                Button(role: .destructive) {
                    Task {
                        do {
                            try AuthenticationService.shared.signOut()
                            dismiss()
                        } catch {
                            print("登出失敗: \(error)")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("登出")
                    }
                }
            }
        }
        .navigationTitle("個人資料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
        }
        .refreshable {
            viewModel.fetchUserProfile()
        }
        .task {
            viewModel.fetchUserProfile()
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView()
    }
}
