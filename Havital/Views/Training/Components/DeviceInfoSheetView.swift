import SwiftUI

// MARK: - 裝置資料說明 Sheet
struct DeviceInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("裝置資料說明")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)
                    Text("Paceriz 原生支援 Garminc和Apple Watch。其他如Coros等裝置，您只需使用原廠軟體，將訓練數據同步到 Apple 健康（HealthKit），Paceriz 便會自動讀取您的訓練紀錄。")
                    Text("請注意，許多第三方裝置在整合 Apple 健康時，僅會寫入部分且有限的資訊。因此，Paceriz 呈現的數據與原廠應用可能會有所不同，這屬於正常現象。")
                    Text("我們會陸續支援更多不同廠牌的裝置，帶給您更完整、精確的運動體驗。")
                }
                .padding()
            }
            .navigationTitle("說明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
}
