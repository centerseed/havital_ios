import SwiftUI
import FirebaseAuth
import HealthKit

struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @StateObject private var garminManager = GarminManager.shared
    @StateObject private var userPreferenceManager = UserPreferenceManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @EnvironmentObject private var featureFlagManager: FeatureFlagManager
    @Environment(\.dismiss) private var dismiss
    @State private var showZoneEditor = false
    @State private var showWeeklyDistanceEditor = false  // 新增週跑量編輯器狀態
    @State private var currentWeekDistance: Int = 0  // 新增當前週跑量
    @State private var weeklyDistance: Int = 0
    @State private var showTrainingDaysEditor = false
    @State private var showOnboardingConfirmation = false  // 重新 OnBoarding 確認對話框狀態
    @State private var showDeleteAccountConfirmation = false  // 刪除帳戶確認對話框狀態
    @State private var isDeletingAccount = false  // 刪除帳戶加載狀態
    @State private var showDataSourceSwitchConfirmation = false  // 數據源切換確認對話框
    @State private var pendingDataSourceType: DataSourceType?  // 待切換的數據源類型
    // 保留 DataSyncView 相關狀態變量供未來使用
    @State private var showDataSyncView = false  // 顯示數據同步畫面（已停用）
    @State private var syncDataSource: DataSourceType?  // 需要同步的數據源（已停用）
    @State private var showGarminAlreadyBoundAlert = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
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
            
            // 數據來源設定區塊
            dataSourceSection
            
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
                    // 編輯訓練日按鈕 (與編輯週跑量一致)
                    Button(action: { showTrainingDaysEditor = true }) {
                        HStack {
                            Text("編輯訓練日")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // Logout Section
            Section {
                // 在登出按鈕上方加入重新 OnBoarding 按鈕
                Button(action: {
                    showOnboardingConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重新 OnBoarding")
                    }
                }
                
                Button(role: .destructive) {
                    Task {
                        do {
                            try await AuthenticationService.shared.signOut()
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
            
            // App Version Section
            Section {
                HStack {
                    Spacer()
                    Text("版本號 \(appVersion)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // 刪除帳戶按鈕
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("刪除帳戶")
                        if isDeletingAccount {
                            Spacer()
                            ProgressView()
                                .padding(.leading, 8)
                        }
                    }
                }
                .disabled(isDeletingAccount)
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
        // 保留 DataSyncView sheet 供未來使用（目前已停用）
        .sheet(isPresented: $showDataSyncView) {
            if let syncDataSource = syncDataSource {
                NavigationStack {
                    DataSyncView(dataSource: syncDataSource)
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
        // 編輯訓練日編輯器
        .alert("確認刪除帳戶", isPresented: $showDeleteAccountConfirmation) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    do {
                        try await viewModel.deleteAccount()
                        // 刪除成功後會自動登出並導航到登入畫面
                    } catch {
                        print("刪除帳戶失敗: \(error.localizedDescription)")
                        isDeletingAccount = false
                    }
                }
            }
        } message: {
            Text("此操作無法復原，所有資料將被永久刪除。確定要繼續嗎？")
        }
        .sheet(isPresented: $showTrainingDaysEditor) {
            if let ud = viewModel.userData {
                EditTrainingDaysView(
                    initialWeekdays: Set(ud.preferWeekDays ?? []),
                    initialLongRunDay: ud.preferWeekDaysLongrun?.first ?? 6
                ) {
                    viewModel.fetchUserProfile()
                }
            } else {
                EmptyView()
            }
        }
        // 重新 OnBoarding 確認對話框
        .confirmationDialog(
            "確定要重新開始 OnBoarding 流程嗎？",
            isPresented: $showOnboardingConfirmation,
            titleVisibility: .visible
        ) {
            Button("確定", role: .destructive) {
                AuthenticationService.shared.startReonboarding() // 改為呼叫新的方法
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這將會重置您的所有訓練設置，需要重新設定您的訓練偏好。目前的訓練計畫將會被清除，且無法復原。")
        }
        .onReceive(garminManager.$garminAlreadyBoundMessage) { msg in
            showGarminAlreadyBoundAlert = (msg != nil)
        }
        .alert("Garmin Connect™ 帳號已被綁定", isPresented: $showGarminAlreadyBoundAlert) {
            Button("我知道了", role: .cancel) {
                garminManager.garminAlreadyBoundMessage = nil
            }
        } message: {
            Text(garminManager.garminAlreadyBoundMessage ?? "該 Garmin Connect™ 帳號已經綁定至另一個 Paceriz 帳號。請先使用原本綁定的 Paceriz 帳號登入，並在個人資料頁解除 Garmin Connect™ 綁定後，再用本帳號進行連接。")
        }
    }
    
    // 使用者頭像與名稱標頭
    @ViewBuilder
    private func profileHeader(_ userData: User) -> some View {
        HStack(alignment: .center, spacing: 16) {
            if let urlString = userData.photoUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFill().opacity(0.3)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFill()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(userData.displayName ?? "用戶")
                    .font(.title2).bold()
                
                // 檢查是否為 Apple 登入且 email 為空或匿名
                if let providerData = Auth.auth().currentUser?.providerData.first,
                   providerData.providerID == "apple.com" && 
                   (userData.email?.isEmpty == true || userData.email?.contains("privaterelay.appleid.com") == true) {
                    Text("Apple 用戶")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(userData.email ?? Auth.auth().currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical)
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
    
    private func trainingDaysView(_ userData: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Regular training days
            HStack {
                Text("一般訓練日:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                ForEach(userData.preferWeekDays?.filter { !(userData.preferWeekDaysLongrun?.contains($0) ?? false) }.sorted() ?? [], id: \.self) { day in
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
            if !(userData.preferWeekDaysLongrun?.isEmpty ?? false) {
                HStack {
                    Text("長跑日:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    ForEach(userData.preferWeekDaysLongrun?.sorted() ?? [], id: \.self) { day in
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
    
    private var dataSourceSection: some View {
        Section(header: Text("數據來源")) {
            VStack(spacing: 12) {
                // 當沒有選擇數據源時顯示提示
                if userPreferenceManager.dataSourcePreference == .unbound {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("尚未選擇數據來源")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("請選擇一個主要數據源來同步您的訓練記錄")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Apple Health 選項
                dataSourceRow(
                    type: .appleHealth,
                    icon: "heart.fill",
                    title: "Apple Health",
                    subtitle: "使用 iPhone 和 Apple Watch 的健康資料"
                )
                .id("apple-health-row")
                
                // 只有當 Garmin 功能啟用時才顯示
                if featureFlagManager.isGarminIntegrationAvailable {
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Garmin 選項
                    dataSourceRow(
                        type: .garmin,
                        icon: "clock.arrow.circlepath",
                        title: "Garmin Connect™",
                        subtitle: "同步您的 Garmin 帳號活動"
                    )
                    .id("garmin-row")
                }
                
                // 已隱藏 Garmin 連接錯誤訊息（使用者需求）
            }
            .padding(.vertical, 4)
        }
        .alert("切換數據來源", isPresented: $showDataSourceSwitchConfirmation) {
            Button("取消", role: .cancel) {
                pendingDataSourceType = nil
            }
            Button("確認切換") {
                if let newDataSource = pendingDataSourceType {
                    switchDataSource(to: newDataSource)
                    pendingDataSourceType = nil
                }
            }
        } message: {
            if let pendingType = pendingDataSourceType {
                let currentDataSource = userPreferenceManager.dataSourcePreference
                
                switch (currentDataSource, pendingType) {
                case (.unbound, .garmin):
                    Text("選擇 Garmin Connect™ 需要進行授權流程。您將被重定向到 Garmin 網站進行登入和授權。授權成功後，您的訓練紀錄將從 Garmin Connect™ 載入。")
                case (.unbound, .appleHealth):
                    Text("選擇 Apple Health 作為您的數據源。您的訓練紀錄將從 Apple Health 載入，包括來自 iPhone 和 Apple Watch 的健康資料。")
                case (.garmin, .appleHealth):
                    Text("切換到 Apple Health 將會解除您的 Garmin Connect™ 綁定，確保後台不再接收 Garmin 數據。您的訓練紀錄將從 Apple Health 載入，目前顯示的紀錄會被新數據源的內容取代，請確認是否要繼續？")
                case (.appleHealth, .garmin):
                    Text("切換到 Garmin Connect™ 需要進行授權流程。您將被重定向到 Garmin 網站進行登入和授權。授權成功後，您的訓練紀錄將從 Garmin Connect™ 載入，目前顯示的紀錄會被新數據源的內容取代。")
                case (_, .unbound):
                    Text("切換到尚未綁定狀態將會清除所有本地運動數據。您稍後可以在個人資料頁面中重新選擇和連接數據來源。")
                default:
                    Text("確認要進行此操作嗎？")
                }
            }
        }
    }
    
    @ViewBuilder
    private func dataSourceRow(
        type: DataSourceType,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        let isCurrentSource = userPreferenceManager.dataSourcePreference == type
        let isGarminConnecting = type == .garmin && garminManager.isConnecting
        let isUnbound = userPreferenceManager.dataSourcePreference == .unbound
        
        Button(action: {
            // 防止重複觸發
            guard !showDataSourceSwitchConfirmation else {
                return
            }
            
            // 如果已經是當前數據源，不需要切換
            if isCurrentSource {
                return
            }
            
            // 如果Garmin正在連接中，不允許切換
            if isGarminConnecting {
                return
            }
            
            // 顯示確認對話框
            pendingDataSourceType = type
            showDataSourceSwitchConfirmation = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // 圖示
                    if type == .garmin {
                        Image("Garmin Tag-black-high-res")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .frame(width: 24)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(isCurrentSource ? .blue : .secondary)
                            .frame(width: 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 狀態指示
                    if isCurrentSource {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("使用中")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else if isUnbound {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.orange)
                    }
                    
                    // Garmin連接狀態
                    if type == .garmin && isGarminConnecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    }
                }
                
                // 操作提示
                HStack {
                    if isCurrentSource {
                        Text("目前使用的數據源")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text(isUnbound ? "選擇此數據源" : "切換到此數據源")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.leading, 32)
            }
            .padding(.vertical, 8)
        }
        .disabled(isCurrentSource || isGarminConnecting)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .id("\(type.rawValue)-row")
    }
    
    // 處理數據源切換邏輯
    private func switchDataSource(to newDataSource: DataSourceType) {
        Task {
            switch newDataSource {
            case .unbound:
                // 切換到尚未綁定狀態
                userPreferenceManager.dataSourcePreference = .unbound
                
                // 同步到後端
                do {
                    try await UserService.shared.updateDataSource(newDataSource.rawValue)
                    print("數據源設定已同步到後端: \(newDataSource.displayName)")
                } catch {
                    print("同步數據源設定到後端失敗: \(error.localizedDescription)")
                }
                
            case .appleHealth:
                // 切換到Apple Health時，先解除Garmin綁定
                if garminManager.isConnected {
                    do {
                        // 調用後端API解除Garmin綁定
                        let disconnectResult = try await GarminDisconnectService.shared.disconnectGarmin()
                        print("Garmin解除綁定成功: \(disconnectResult.message)")
                        
                        // 本地斷開Garmin連接
                        await garminManager.disconnect()
                        
                    } catch {
                        print("Garmin解除綁定失敗: \(error.localizedDescription)")
                        // 即使解除綁定失敗，也繼續本地斷開連接
                        await garminManager.disconnect()
                    }
                }
                
                // 請求 HealthKit 權限
                do {
                    try await healthKitManager.requestAuthorization()
                    print("Apple Health 權限請求成功")
                } catch {
                    print("Apple Health 權限請求失敗: \(error.localizedDescription)")
                    // 即使權限請求失敗，也繼續切換數據源
                }
                
                userPreferenceManager.dataSourcePreference = .appleHealth
                
                // 同步到後端
                do {
                    try await UserService.shared.updateDataSource(newDataSource.rawValue)
                    print("數據源設定已同步到後端: \(newDataSource.displayName)")
                    
                    // 切換完成，不再顯示同步畫面
                    print("Apple Health 數據源切換完成")
                } catch {
                    print("同步數據源設定到後端失敗: \(error.localizedDescription)")
                }
                
            case .garmin:
                // 切換到Garmin時，總是啟動OAuth流程
                // 這樣可以確保連接狀態是最新的，並且處理token過期的情況
                await garminManager.startConnection()
                
                // 等待 OAuth 流程完成
                // 監聽連接狀態變化，最多等待 30 秒
                let maxWaitTime = 30.0 // 30 秒
                let startTime = Date()
                
                while garminManager.isConnecting && Date().timeIntervalSince(startTime) < maxWaitTime {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                }
                
                if garminManager.isConnected {
                    // OAuth 成功，切換完成
                    print("Garmin 數據源切換完成")
                } else if !garminManager.isConnecting {
                    // OAuth 流程已結束但未成功連接
                    print("Garmin OAuth 失敗或用戶取消")
                } else {
                    // 超時
                    print("Garmin OAuth 超時")
                }
                // 注意：數據源的更新會在OAuth成功後在GarminManager中處理
            }
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView()
    }
}
