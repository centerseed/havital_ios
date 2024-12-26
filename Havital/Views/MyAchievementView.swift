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
            
        }
    }
    
}

#Preview {
    MyAchievementView()
        .environmentObject(HealthKitManager())
}
