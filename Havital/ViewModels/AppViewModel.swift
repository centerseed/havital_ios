import SwiftUI

class AppViewModel: ObservableObject {
    @Published var showHealthKitAlert = false
    @Published var healthKitAlertMessage = ""
    
    init() {
        // 監聽 HealthKit 權限提示通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowHealthKitPermissionAlert"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let message = notification.userInfo?["message"] as? String {
                self?.healthKitAlertMessage = message
                self?.showHealthKitAlert = true
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
