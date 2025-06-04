import SwiftUI
import Charts

// 用於解析 JSON 的資料結構
private struct SpeedPoint: Codable {
    let value: Double
    let time: TimeInterval
}


struct PaceChartPreviewView: View {
    @State private var paces: [DataPoint] = []
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var selectedFileIndex = 0
    
    private let jsonFiles = [
        "workout_sample_1",
        "workout_sample_2",
        "workout_sample_3"// 添加更多檔案名稱
    ]
    
    var body: some View {
        VStack {
            Picker("選擇測試數據", selection: $selectedFileIndex) {
                ForEach(0..<jsonFiles.count, id: \.self) { index in
                    Text(jsonFiles[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedFileIndex) { _ in
                loadWorkoutData()
            }
            
            Text("數據點數量: \(paces.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let error = error {
                Text("錯誤: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            if !paces.isEmpty {
                Text("第一個數據點: \(paces[0].value, specifier: "%.2f") m/s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            PaceChartView(
                paces: paces,
                isLoading: isLoading,
                error: error
            )
        }
        .onAppear {
            loadWorkoutData()
        }
    }
    
    private func loadWorkoutData() {
        let selectedFile = jsonFiles[selectedFileIndex]
        print("正在載入檔案: \(selectedFile).json")
        
        // 先重置狀態
        DispatchQueue.main.async {
            self.paces = []
            self.isLoading = true
            self.error = nil
        }
        
        // 非同步載入實際數據
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 嘗試從 Bundle 的根目錄載入
            if let bundlePath = Bundle.main.path(forResource: selectedFile, ofType: "json") {
                let url = URL(fileURLWithPath: bundlePath)
                print("找到檔案: \(url.path)")
                self.loadData(from: url)
                return
            }
            
            // 2. 嘗試從 WorkoutFixtures 資料夾載入
            if let bundlePath = Bundle.main.path(forResource: selectedFile, ofType: "json", inDirectory: "WorkoutFixtures") {
                let url = URL(fileURLWithPath: bundlePath)
                print("找到檔案: \(url.path)")
                self.loadData(from: url)
                return
            }
            
            // 3. 嘗試從模擬器應用程式包中載入
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsPath.appendingPathComponent("\(selectedFile).json")
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    print("從文件目錄找到檔案: \(fileURL.path)")
                    self.loadData(from: fileURL)
                    return
                }
            }
            
            // 4. 嘗試從測試 Bundle 載入
            if let testBundle = Bundle(identifier: "com.yourcompany.HavitalTests"),
               let url = testBundle.url(forResource: selectedFile, withExtension: "json", subdirectory: "WorkoutFixtures") {
                print("在測試 Bundle 中找到檔案: \(url.path)")
                self.loadData(from: url)
                return
            }
            
            // 5. 如果都找不到，顯示錯誤並載入測試數據
            let errorMessage = "找不到 \(selectedFile).json 檔案。請確保檔案已添加到專案的 Bundle 中，並且 Target Membership 已正確設置。"
            print(errorMessage)
            
            // 載入測試數據
            let testPaces: [DataPoint] = [
                DataPoint(time: Date().addingTimeInterval(-300), value: 2.5),
                DataPoint(time: Date().addingTimeInterval(-240), value: 2.8),
                DataPoint(time: Date().addingTimeInterval(-180), value: 3.0),
                DataPoint(time: Date().addingTimeInterval(-120), value: 2.7),
                DataPoint(time: Date().addingTimeInterval(-60), value: 3.2)
            ]
            
            DispatchQueue.main.async {
                self.error = errorMessage
                self.paces = testPaces
                self.error = "找不到測試數據檔案 \(selectedFile).json。請確認：\n1. 檔案已添加到目標的 Copy Bundle Resources 中\n2. 檔案位於應用程式的根目錄或 WorkoutFixtures 資料夾內"
                self.isLoading = false
            }
        }
    }
    
    private func loadData(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let workoutData = try decoder.decode(WorkoutData.self, from: data)
            
            // 直接轉換所有數據點，不進行過濾或處理
            let newPaces = workoutData.speeds.map { speedPoint in
                return DataPoint(time: Date(timeIntervalSince1970: speedPoint.time), value: speedPoint.value)
            }
            
            DispatchQueue.main.async {
                self.paces = newPaces
                self.isLoading = false
                print("成功載入 \(newPaces.count) 個數據點")
                if let first = newPaces.first, let last = newPaces.last {
                    print("時間範圍: \(first.time) 到 \(last.time)")
                    print("速度範圍: \(newPaces.map { $0.value }.min() ?? 0) 到 \(newPaces.map { $0.value }.max() ?? 0) m/s")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = "解析數據時出錯: \(error.localizedDescription)"
                self.isLoading = false
                print("載入數據時出錯: \(error)")
            }
        }
    }
    
    // 用於在 Preview 中尋找測試 bundle 的輔助類別
    private class TestBundleFinder {}
}


// MARK: - 預覽
struct PaceChartPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PaceChartPreviewView()
            .previewDisplayName("配速圖表預覽")
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

// MARK: - 資料模型
// 使用專案中已定義的 DataPoint 模型

