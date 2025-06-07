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
                    Text("Paceriz 支援 Garmin、Coros 等第三方裝置，您只需使用原廠軟體，將訓練數據同步到 Apple 健康（HealthKit），Paceriz 便會自動讀取您的訓練紀錄。")
                    Text("請注意，許多第三方裝置在整合 Apple 健康時，僅會寫入部分且有限的資訊。因此，Paceriz 呈現的數據與原廠應用可能會有所不同，這屬於正常現象。")
                    Text("我們正積極與 Garmin 等廠商洽談資料授權，期望未來能直接整合原廠數據，帶給您更完整、精確的運動體驗。")
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
