import SwiftUI

@MainActor
class PersonalBestViewModel: ObservableObject {
    @Published var targetHours = 0
    @Published var targetMinutes = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var navigateToTrainingDays = false
    @Published var selectedDistance = "5" // 預設5公里
    @Published var hasPersonalBest = true // 是否有個人最佳成績
    
    let targetDistance: Double
    let availableDistances = [
        "3": "3公里",
        "5": "5公里",
        "10": "10公里",
        "21.0975": "半程馬拉松",
        "42.195": "全程馬拉松"
    ]
    
    init(targetDistance: Double) {
        self.targetDistance = targetDistance
    }
    
    var currentPace: String {
        guard hasPersonalBest else { return "" }
        let totalSeconds = (targetHours * 3600 + targetMinutes * 60)
        let distanceKm = Double(selectedDistance) ?? 5.0
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        let paceMinutes = paceSeconds / 60
        let paceRemainingSeconds = paceSeconds % 60
        return String(format: "%d:%02d", paceMinutes, paceRemainingSeconds)
    }
    
    func updatePersonalBest(hours: Int, minutes: Int) async {
        isLoading = true
        error = nil
        
        do {
            if hasPersonalBest {
                let userData = [
                    "distance_km": Double(selectedDistance) ?? 3.0,
                    "complete_time": hours * 3600 + minutes * 60
                ] as [String : Any]
                
                try await UserService.shared.updatePersonalBestData(userData)
            }
            navigateToTrainingDays = true
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct PersonalBestView: View {
    @StateObject private var viewModel: PersonalBestViewModel
    
    init(targetDistance: Double) {
        _viewModel = StateObject(wrappedValue: PersonalBestViewModel(targetDistance: targetDistance))
    }
    
    var body: some View {
        Form {
                Section(header: Text("目前最佳成績").padding(.top, 10)) {
                    Text("目標賽事距離：\(String(format: "%.1f", viewModel.targetDistance))公里")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Text("請選擇您已完成的最佳成績距離和時間")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Picker("選擇距離", selection: $viewModel.selectedDistance) {
                        ForEach(Array(viewModel.availableDistances.keys.sorted()), id: \.self) { key in
                            Text(viewModel.availableDistances[key] ?? key)
                                .tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Picker("時", selection: $viewModel.targetHours) {
                            ForEach(0...6, id: \.self) { hour in
                                Text("\(hour)")
                            }
                        }
                        .pickerStyle(.wheel)
                        Text("時")
                        
                        Picker("分", selection: $viewModel.targetMinutes) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute)")
                            }
                        }
                        .pickerStyle(.wheel)
                        Text("分")
                    }
                    
                    if !viewModel.currentPace.isEmpty {
                        HStack {
                            Text("平均配速")
                            Spacer()
                            Text("\(viewModel.currentPace) /公里")
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            
        }
                .navigationTitle("個人最佳成績")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                print("開始更新個人最佳成績")
                                await viewModel.updatePersonalBest(hours: viewModel.targetHours, minutes: viewModel.targetMinutes)
                            }
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                } else {
                                    Text("下一步")
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading || (viewModel.hasPersonalBest && viewModel.currentPace.isEmpty))
                        .padding(.vertical)
                    }
                }
                .background(
                    NavigationLink(destination: TrainingDaysSetupView(), isActive: $viewModel.navigateToTrainingDays) {
                        EmptyView()
                    }
                )
        }
        
    
}
