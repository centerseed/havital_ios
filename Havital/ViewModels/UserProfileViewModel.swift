import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var userData: User?
    @Published var heartRateZones: [HeartRateZonesManager.HeartRateZone] = []
    @Published var isLoadingZones = true
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchUserProfile() {
        Task {
            await TrackedTask("UserProfileViewModel: fetchUserProfile") { [self] in
                isLoading = true
                error = nil

                UserService.shared.getUserProfile()
                    .receive(on: DispatchQueue.main)
                    .sink { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.error = error
                            print("Error fetching user profile: \(error.localizedDescription)")
                        }
                    } receiveValue: { response in
                        // Now we correctly access the user data directly
                        self.userData = response
                        print("Successfully fetched user profile for: \(response.displayName)")
                    }
                    .store(in: &self.cancellables)
            }.value
        }
    }
    
    func loadHeartRateZones() async {
        isLoadingZones = true
        // Ensure zone data is calculated
        await HeartRateZonesBridge.shared.ensureHeartRateZonesAvailable()
        // Get heart rate zones
        heartRateZones = HeartRateZonesManager.shared.getHeartRateZones()
        isLoadingZones = false
    }
    
    func weekdayName(for index: Int) -> String {
        return ViewModelUtils.weekdayName(for: index)
    }
    
    func weekdayShortName(for index: Int) -> String {
        return ViewModelUtils.weekdayShortName(for: index)
    }
    
    func formatHeartRate(_ rate: Int) -> String {
        return "\(rate) bpm"
    }
    
    /// 支援可選 HeartRate 顯示
    func formatHeartRate(_ rate: Int?) -> String {
        guard let r = rate else { return "-- bpm" }
        return "\(r) bpm"
    }
    
    func zoneColor(for zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

extension UserProfileViewModel {
    // 更新週跑量的方法
    func updateWeeklyDistance(distance: Int) async {
        await TrackedTask("UserProfileViewModel: updateWeeklyDistance") { [self] in
            isLoading = true
            error = nil

            do {
                let userData = [
                    "current_week_distance": distance
                ] as [String: Any]

                try await UserService.shared.updateUserData(userData)
                print("週跑量數據更新成功")

                // 重新載入用戶資料
                await MainActor.run {
                    self.fetchUserProfile()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    print("更新週跑量失敗: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                isLoading = false
            }
        }.value
    }
    
    // 刪除帳戶
    func deleteAccount() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法獲取當前用戶ID"])
        }
        
        do {
            try await UserService.shared.deleteUser(userId: userId)
            // 登出並清除本地資料
            try await AuthenticationService.shared.signOut()
        } catch {
            print("刪除帳戶失敗: \(error.localizedDescription)")
            throw error
        }
    }
}
