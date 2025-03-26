import SwiftUI
import Combine

class UserProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var userData: UserProfileData?
    
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
    
    func weekdayName(for index: Int) -> String {
        // Using a system where 1=Monday, 2=Tuesday, ... 7=Sunday
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        let adjustedIndex = (index - 1) % 7
        return "星期" + weekdays[adjustedIndex]
    }
    
    // Format heart rate to ensure proper display
    func formatHeartRate(_ value: Int) -> String {
        return "\(value) bpm"
    }
}
