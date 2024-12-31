import Foundation
import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var isCalendarAuthorized = false
    @Published var syncPreference: SyncPreference?
    @Published var preferredStartTime: Date
    @Published var preferredEndTime: Date
    
    enum SyncPreference: String {
        case allDay
        case specificTime
    }
    
    init() {
        // 初始化存儲屬性
        let calendar = Calendar.current
        let now = Date()
        self.preferredStartTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        self.preferredEndTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        
        // 加載保存的設置
        loadSyncPreference()
        loadPreferredTimes()
        
        // 檢查日曆權限
        Task {
            await checkCalendarAuthorization()
        }
    }
    
    private func loadPreferredTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        if let startHour = UserDefaults.standard.object(forKey: "PreferredStartHour") as? Int,
           let startMinute = UserDefaults.standard.object(forKey: "PreferredStartMinute") as? Int {
            print("Loading saved start time: \(startHour):\(startMinute)")
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = startHour
            components.minute = startMinute
            components.second = 0
            
            if let date = calendar.date(from: components) {
                preferredStartTime = date
                print("Start time set to: \(startHour):\(startMinute)")
            }
        }
        
        if let endHour = UserDefaults.standard.object(forKey: "PreferredEndHour") as? Int,
           let endMinute = UserDefaults.standard.object(forKey: "PreferredEndMinute") as? Int {
            print("Loading saved end time: \(endHour):\(endMinute)")
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = endHour
            components.minute = endMinute
            components.second = 0
            
            if let date = calendar.date(from: components) {
                preferredEndTime = date
                print("End time set to: \(endHour):\(endMinute)")
            }
        }
    }
    
    private func loadSyncPreference() {
        if let preferenceString = UserDefaults.standard.string(forKey: "CalendarSyncPreference") {
            syncPreference = SyncPreference(rawValue: preferenceString)
        }
    }
    
    private func saveSyncPreference(_ preference: SyncPreference) {
        UserDefaults.standard.set(preference.rawValue, forKey: "CalendarSyncPreference")
        syncPreference = preference
    }
    
    private func savePreferredTimes() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: preferredStartTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: preferredEndTime)
        
        let startHour = startComponents.hour ?? 7
        let startMinute = startComponents.minute ?? 0
        let endHour = endComponents.hour ?? 8
        let endMinute = endComponents.minute ?? 0
        
        print("Saving times - Start: \(startHour):\(startMinute), End: \(endHour):\(endMinute)")
        
        UserDefaults.standard.set(startHour, forKey: "PreferredStartHour")
        UserDefaults.standard.set(startMinute, forKey: "PreferredStartMinute")
        UserDefaults.standard.set(endHour, forKey: "PreferredEndHour")
        UserDefaults.standard.set(endMinute, forKey: "PreferredEndMinute")
        UserDefaults.standard.synchronize()
    }
    
    private func checkCalendarAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        isCalendarAuthorized = status == .authorized
    }
    
    func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                isCalendarAuthorized = granted
            }
            return granted
        } catch {
            print("Error requesting calendar access: \(error)")
            return false
        }
    }
    
    func syncTrainingPlan(days: [(Date, Bool)], preference: SyncPreference? = nil) async throws {
        // 如果提供了新的偏好設置，保存它
        if let preference = preference {
            await MainActor.run {
                saveSyncPreference(preference)
            }
        }
        
        // 確保已經有同步偏好設置
        guard let syncPreference = preference ?? self.syncPreference else {
            throw NSError(domain: "CalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No sync preference set"])
        }
        
        // 確保有日曆權限
        if !isCalendarAuthorized {
            let granted = await requestCalendarAccess()
            if !granted {
                throw NSError(domain: "CalendarManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])
            }
        }
        
        // 刪除之前的訓練日事件
        try removeExistingEvents(between: days.first?.0 ?? Date(), and: days.last?.0 ?? Date())
        
        // 添加新的訓練日事件
        for (date, isTrainingDay) in days {
            if isTrainingDay {
                try addTrainingEvent(on: date, preference: syncPreference)
            }
        }
    }
    
    private func removeExistingEvents(between startDate: Date, and endDate: Date) throws {
        let calendar = Calendar.current
        let predicate = eventStore.predicateForEvents(withStart: startDate,
                                                    end: endDate,
                                                    calendars: [eventStore.defaultCalendarForNewEvents].compactMap { $0 })
        
        let existingEvents = eventStore.events(matching: predicate)
        let trainingEvents = existingEvents.filter { $0.title == "Havital 訓練日" }
        
        for event in trainingEvents {
            try eventStore.remove(event, span: .thisEvent)
        }
    }
    
    private func addTrainingEvent(on date: Date, preference: SyncPreference) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = "Havital 訓練日"
        event.notes = "今天是訓練日，記得按照計劃完成訓練！"
        
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        
        switch preference {
        case .allDay:
            event.isAllDay = true
            event.startDate = date
            event.endDate = date
            let alarm = EKAlarm(relativeOffset: -12 * 60 * 60)
            event.addAlarm(alarm)
            
        case .specificTime:
            // 從保存的設置中獲取時間
            let startHour = UserDefaults.standard.integer(forKey: "PreferredStartHour")
            let startMinute = UserDefaults.standard.integer(forKey: "PreferredStartMinute")
            let endHour = UserDefaults.standard.integer(forKey: "PreferredEndHour")
            let endMinute = UserDefaults.standard.integer(forKey: "PreferredEndMinute")
            
            print("Creating event with saved times - Start: \(startHour):\(startMinute), End: \(endHour):\(endMinute)")
            
            // 創建事件時間組件
            var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
            startComponents.hour = startHour
            startComponents.minute = startMinute
            startComponents.second = 0
            startComponents.timeZone = timeZone
            
            var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
            endComponents.hour = endHour
            endComponents.minute = endMinute
            endComponents.second = 0
            endComponents.timeZone = timeZone
            
            // 創建事件時間
            guard let startDate = calendar.date(from: startComponents),
                  let endDate = calendar.date(from: endComponents) else {
                throw NSError(domain: "CalendarManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "無法創建事件時間"])
            }
            
            event.timeZone = timeZone
            event.startDate = startDate
            event.endDate = endDate
            
            // 格式化輸出最終時間
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = timeZone
            print("Final event times - Start: \(formatter.string(from: startDate)), End: \(formatter.string(from: endDate))")
            
            let alarm = EKAlarm(relativeOffset: -30 * 60)
            event.addAlarm(alarm)
        }
        
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw NSError(domain: "CalendarManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No default calendar available"])
        }
        
        event.calendar = calendar
        
        try eventStore.save(event, span: .thisEvent)
        
        // 輸出最終保存的事件時間（本地時間）
        if let startDate = event.startDate, let endDate = event.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = timeZone
            print("Saved event (local time) - Start: \(formatter.string(from: startDate)), End: \(formatter.string(from: endDate))")
        }
    }
}
