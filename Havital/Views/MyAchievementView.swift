import SwiftUI
import Charts
import HealthKit

struct MyAchievementView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 訓練表現圖表
                    VStack(alignment: .leading) {
                        Text("訓練表現趨勢")
                            .font(.title2)
                            .padding(.horizontal)
                        
                        PerformanceChartView()
                            .environmentObject(healthKitManager)
                            .frame(height: 250)
                            .padding()
                            .onAppear {
                                print("PerformanceChartView appeared")
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                    
                    // HRV 趨勢圖
                    VStack(alignment: .leading) {
                        Text("心率變異性 (HRV) 趨勢")
                            .font(.title2)
                            .padding(.horizontal)
                        
                        HRVTrendChartView()
                            .environmentObject(healthKitManager)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                    
                    // 睡眠靜息心率圖
                    VStack(alignment: .leading) {
                        Text("睡眠靜息心率")
                            .font(.title2)
                            .padding(.horizontal)
                        
                        SleepHeartRateChartView()
                            .environmentObject(healthKitManager)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的成就")
            .onAppear {
                loadHRVData()
            }
        }
    }
    
    private func loadHRVData() {
        // 先請求授權
        healthKitManager.requestAuthorization { success in
            guard success else {
                print("HealthKit 授權失敗")
                return
            }
            
            // 授權成功後獲取數據
            Task {
                // 設定日期範圍為最近一個月
                let calendar = Calendar.current
                let now = Date()
                let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
                let startDate = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: endDate))!
                
                print("開始獲取 HRV 數據，時間範圍：\(startDate) 到 \(endDate)")
                let data = await healthKitManager.fetchHRVData(start: startDate, end: endDate)
                print("獲取到 \(data.count) 條 HRV 數據")
                
                // 按日期分組並計算每日平均值
                let groupedData = Dictionary(grouping: data) { item in
                    calendar.startOfDay(for: item.0)
                }
                
                let dailyAverages = groupedData.map { (date, values) in
                    let average = values.map { $0.1 }.reduce(0, +) / Double(values.count)
                    return (date, average)
                }.sorted { $0.0 < $1.0 }
                
                print("處理後得到 \(dailyAverages.count) 天的 HRV 平均值")
            }
        }
    }
}

#Preview {
    NavigationView {
        MyAchievementView()
    }
}
