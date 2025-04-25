import SwiftUI
import Combine

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var userData: UserProfileData?
    @Published var heartRateZones: [HeartRateZonesManager.HeartRateZone] = []
    @Published var isLoadingZones = true
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchUserProfile() {
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
                // Now we correctly access the nested data property
                self.userData = response.data
                print("Successfully fetched user profile for: \(response.data.displayName)")
            }
            .store(in: &cancellables)
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
        // Using a system where 1=Monday, 2=Tuesday, ... 7=Sunday
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        let adjustedIndex = (index - 1) % 7
        return "星期" + weekdays[adjustedIndex]
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
    }
}
