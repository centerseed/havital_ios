import SwiftUI

struct CalendarSyncSetupView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Binding var isPresented: Bool
    let onComplete: (CalendarManager.SyncPreference) -> Void
    
    @State private var selectedPreference: CalendarManager.SyncPreference = .allDay
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(L10n.CalendarSyncSetup.description.localized)
                        .foregroundStyle(.secondary)
                        .padding()
                    
                    Picker(L10n.CalendarSyncSetup.syncMethod.localized, selection: $selectedPreference) {
                        Text(L10n.CalendarSyncSetup.allDay.localized)
                            .tag(CalendarManager.SyncPreference.allDay)
                        Text(L10n.CalendarSyncSetup.specificTime.localized)
                            .tag(CalendarManager.SyncPreference.specificTime)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if selectedPreference == .specificTime {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(L10n.CalendarSyncSetup.trainingTime.localized)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                HStack {
                                    Text(L10n.CalendarSyncSetup.startTime.localized)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    DatePicker("",
                                             selection: $calendarManager.preferredStartTime,
                                             displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.wheel)
                                        .environment(\.locale, Locale(identifier: "zh_TW"))
                                        .environment(\.timeZone, TimeZone.current)
                                        .onChange(of: calendarManager.preferredStartTime) { newValue in
                                            let calendar = Calendar.current
                                            let components = calendar.dateComponents([.hour, .minute], from: newValue)
                                            if let hour = components.hour {
                                                print("Selected start time: \(hour):\(components.minute ?? 0)")
                                                UserDefaults.standard.set(hour, forKey: "PreferredStartHour")
                                                UserDefaults.standard.set(components.minute ?? 0, forKey: "PreferredStartMinute")
                                                UserDefaults.standard.synchronize()
                                            }
                                        }
                                        .frame(width: 150)
                                        .labelsHidden()
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text(L10n.CalendarSyncSetup.endTime.localized)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    DatePicker("",
                                             selection: $calendarManager.preferredEndTime,
                                             displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.wheel)
                                        .environment(\.locale, Locale(identifier: "zh_TW"))
                                        .environment(\.timeZone, TimeZone.current)
                                        .onChange(of: calendarManager.preferredEndTime) { newValue in
                                            let calendar = Calendar.current
                                            let components = calendar.dateComponents([.hour, .minute], from: newValue)
                                            if let hour = components.hour {
                                                print("Selected end time: \(hour):\(components.minute ?? 0)")
                                                UserDefaults.standard.set(hour, forKey: "PreferredEndHour")
                                                UserDefaults.standard.set(components.minute ?? 0, forKey: "PreferredEndMinute")
                                                UserDefaults.standard.synchronize()
                                            }
                                        }
                                        .frame(width: 150)
                                        .labelsHidden()
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            
                            Text(L10n.CalendarSyncSetup.adjustNote.localized)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle(L10n.CalendarSyncSetup.title.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.CalendarSyncSetup.startSync.localized) {
                        startSync()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("錯誤", isPresented: .constant(error != nil)) {
                Button("確定") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func startSync() {
        isLoading = true
        
        Task {
            do {
                let granted = await calendarManager.requestCalendarAccess()
                if granted {
                    await MainActor.run {
                        onComplete(selectedPreference)
                        isPresented = false
                    }
                } else {
                    await MainActor.run {
                        error = L10n.CalendarSyncSetup.accessError.localized
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
