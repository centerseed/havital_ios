import SwiftUI

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showZoneEditor = false
    @State private var showWeeklyDistanceEditor = false  // 新增週跑量編輯器狀態
    @State private var currentWeekDistance: Int = 0  // 新增當前週跑量
    @State private var weeklyDistance: Int = 0
    
    var body: some View {
        List {
            // Profile Section
            Section {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("載入中...")
                        Spacer()
                    }
                } else if let userData = viewModel.userData {
                    profileHeader(userData)
                } else if let error = viewModel.error {
                    errorView(error)
                }
            }
            
            // 新增週跑量區塊 - 放在最前面的重要位置
            if let userData = viewModel.userData {
                Section(header: Text("訓練資訊")) {
                    // 週跑量資訊與編輯按鈕
                    HStack {
                        Label("當前週跑量", systemImage: "figure.walk")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(userData.currentWeekDistance ?? 0) 公里")
                            .fontWeight(.medium)
                    }
                    
                    // 編輯週跑量按鈕
                    Button(action: {
                        // 將字串轉換為 Double
                        currentWeekDistance = Int(userData.currentWeekDistance ?? 0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            weeklyDistance = Int(userData.currentWeekDistance ?? 0)
                            showWeeklyDistanceEditor = true
                        }
                    }) {
                        HStack {
                            Text("編輯週跑量")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // Heart Rate Zones Section
            if let userData = viewModel.userData {
                Section(header: Text("心率資訊")) {
                    // Display basic heart rate info
                    HStack {
                        Label("最大心率", systemImage: "heart.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text(viewModel.formatHeartRate(userData.maxHr))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Label("靜息心率", systemImage: "heart")
                            .foregroundColor(.blue)
                        Spacer()
                        Text(viewModel.formatHeartRate(userData.relaxingHr))
                            .fontWeight(.medium)
                    }
                    
                    // Heart Rate Zone Info Button
                    Button(action: {
                        showZoneEditor = true
                    }) {
                        HStack {
                            Text("心率區間詳細資訊")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    // Heart Rate Zones
                    if viewModel.isLoadingZones {
                        HStack {
                            Spacer()
                            ProgressView("載入心率區間...")
                            Spacer()
                        }
                    } else {
                        heartRateZonesView
                    }
                }
                
                // Training Days Section - More Compact
                Section(header: Text("訓練日")) {
                    trainingDaysView(userData)
                }
            }
            
            // Logout Section
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
            Task {
                await viewModel.loadHeartRateZones()
            }
        }
        .task {
            viewModel.fetchUserProfile()
            await viewModel.loadHeartRateZones()
        }
        .sheet(isPresented: $showZoneEditor) {
            HeartRateZoneInfoView()
        }
        // 新增週跑量編輯器
        .sheet(isPresented: $showWeeklyDistanceEditor) {
            WeeklyDistanceEditorView(
                distance: $weeklyDistance,
                onSave: { newDistance in
                    Task {
                        await viewModel.updateWeeklyDistance(distance: newDistance)
                    }
                }
            )
            
        }
    }
    
    private var heartRateZonesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.heartRateZones, id: \.zone) { zone in
                HStack {
                    Circle()
                        .fill(viewModel.zoneColor(for: zone.zone))
                        .frame(width: 10, height: 10)
                    
                    Text("區間 \(zone.zone): \(zone.name)")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(zone.range.lowerBound))-\(Int(zone.range.upperBound))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func profileHeader(_ userData: UserProfileData) -> some View {
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
                
                Text(userData.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func trainingDaysView(_ userData: UserProfileData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Regular training days
            HStack {
                Text("一般訓練日:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                ForEach(userData.preferWeekDays.filter { !userData.preferWeekDaysLongrun.contains($0) }.sorted(), id: \.self) { day in
                    Text(viewModel.weekdayName(for: day).suffix(1))
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 24, height: 24)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Circle())
                }
            }
            
            // Long run days
            if !userData.preferWeekDaysLongrun.isEmpty {
                HStack {
                    Text("長跑日:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    ForEach(userData.preferWeekDaysLongrun.sorted(), id: \.self) { day in
                        Text(viewModel.weekdayName(for: day).suffix(1))
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
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

#Preview {
    NavigationStack {
        UserProfileView()
    }
}
