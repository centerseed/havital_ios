import Foundation
import Combine

class VDOTChartViewModel: ObservableObject {
    @Published var vdotPoints: [VDOTDataPoint] = []
    @Published var averageVdot: Double = 0
    @Published var latestVdot: Double = 0
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var yAxisRange: ClosedRange<Double> = 30...40
    @Published var needUpdatedHrRange: Bool = false
    
    private let networkService = NetworkService.shared
    private let storage = VDOTStorage.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 初始化時嘗試從本地加載數據
    init() {
        loadLocalData()
    }
    
    private func loadLocalData() {
        let (localPoints, needUpdate) = storage.loadVDOTData()
        if !localPoints.isEmpty {
            self.vdotPoints = localPoints
            self.needUpdatedHrRange = needUpdate
            
            // 更新平均和最新VDOT
            updateVDOTStatistics()
            
            // 更新Y軸範圍
            updateYAxisRange()
        }
    }
    
    private func updateVDOTStatistics() {
        // 計算平均VDOT
        if !vdotPoints.isEmpty {
            averageVdot = vdotPoints.reduce(0.0) { $0 + $1.value } / Double(vdotPoints.count)
            
            // 獲取最新VDOT
            if let latestPoint = vdotPoints.max(by: { $0.date < $1.date }) {
                latestVdot = latestPoint.value
            }
        }
    }
    
    private func updateYAxisRange() {
        // 計算適當的Y軸範圍
        let values = vdotPoints.map { $0.value }
        if let minValue = values.min(), let maxValue = values.max() {
            // 添加5%的padding
            let padding = (maxValue - minValue) * 0.05
            let yMin = Swift.max(minValue - padding, 0) // 確保不低於0
            let yMax = maxValue + padding
            
            // 如果範圍太小，擴大它
            let minimumRange = 5.0 // 最小範圍5個單位
            let range = yMax - yMin
            if range < minimumRange {
                let additionalPadding = (minimumRange - range) / 2
                let newYMin = Swift.max(yMin - additionalPadding, 0)
                let newYMax = yMax + additionalPadding
                self.yAxisRange = newYMin...newYMax
            } else {
                self.yAxisRange = yMin...yMax
            }
        }
    }
    
    func fetchVDOTData(limit: Int = 30, forceFetch: Bool = false) async {
        // 如果本地有數據，延遲顯示loading狀態
        let shouldShowLoading = vdotPoints.isEmpty
        
        if shouldShowLoading {
            await MainActor.run {
                isLoading = true
                error = nil
            }
        }
        
        // 檢查是否需要從後端獲取數據
        // 如果10分鐘內已獲取過數據且不是強制刷新，則使用本地緩存
        if !needUpdatedHrRange && !forceFetch && !storage.shouldRefreshData(cacheTimeInMinutes: 10) && !vdotPoints.isEmpty {
            print("使用10分鐘內的本地緩存VDOT數據")
            
            if shouldShowLoading {
                await MainActor.run {
                    isLoading = false
                }
            }
            
            return
        }
        
        do {
            let endpoint = try Endpoint(
                path: "/workout/vdots",
                method: .get,
                requiresAuth: true,
                queryItems: [URLQueryItem(name: "limit", value: String(limit))]
            )
            
            print("從後端獲取VDOT數據...")
            let response: VDOTResponse = try await networkService.request(endpoint)
            
            let vdotEntries = response.data.vdots
            let points = vdotEntries.map { entry in
                VDOTDataPoint(
                    date: Date(timeIntervalSince1970: entry.datetime),
                    value: entry.dynamicVdot
                )
            }.sorted { $0.date < $1.date }
            
            // 計算平均VDOT
            let calculatedAverage = vdotEntries.isEmpty ? 0 : vdotEntries.reduce(0.0) { $0 + $1.dynamicVdot } / Double(vdotEntries.count)
            
            // 獲取最新VDOT
            let latestEntry = vdotEntries.max(by: { $0.datetime < $1.datetime })
            let calculatedLatest = latestEntry?.dynamicVdot ?? 0.0
            
            // 計算適當的Y軸範圍
            let values = points.map { $0.value }
            var yMin: Double = 0
            var yMax: Double = 40
            
            if let minValue = values.min(), let maxValue = values.max() {
                // 添加5%的padding
                let padding = (maxValue - minValue) * 0.05
                yMin = Swift.max(minValue - padding, 0) // 確保不低於0
                yMax = maxValue + padding
                
                // 如果範圍太小，擴大它
                let minimumRange = 5.0 // 最小範圍5個單位
                let range = yMax - yMin
                if range < minimumRange {
                    let additionalPadding = (minimumRange - range) / 2
                    yMin = Swift.max(yMin - additionalPadding, 0)
                    yMax = yMax + additionalPadding
                }
            }
            
            await MainActor.run {
                self.vdotPoints = points
                self.averageVdot = calculatedAverage
                self.latestVdot = calculatedLatest
                self.needUpdatedHrRange = response.data.needUpdatedHrRange
                self.yAxisRange = yMin...yMax
                self.isLoading = false
                
                // 保存到本地
                self.storage.saveVDOTData(points: points, needUpdatedHrRange: response.data.needUpdatedHrRange)
            }
            
            print("VDOT數據獲取完成，已更新本地緩存")
        } catch {
            await MainActor.run {
                // 如果API請求失敗但有本地數據，不顯示錯誤
                if !self.vdotPoints.isEmpty {
                    self.error = nil
                    print("從後端獲取VDOT數據失敗，但使用本地數據: \(error.localizedDescription)")
                } else {
                    self.error = "無法載入跑力數據: \(error.localizedDescription)"
                    print("無法載入跑力數據: \(error.localizedDescription)")
                }
                self.isLoading = false
            }
        }
    }
    
    // 強制刷新數據（清除本地緩存並重新獲取）
    func refreshVDOTData() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        // 清除本地緩存
        storage.clearVDOTData()
        
        // 重新獲取數據（強制從後端獲取）
        await fetchVDOTData(forceFetch: true)
    }
    
    // 通過提供的日期獲取VDOT
    func getVDOTForDate(_ date: Date) -> Double? {
        // 尋找距離提供日期最近且不晚於該日期的點
        let sortedPoints = vdotPoints.sorted(by: { $0.date > $1.date }) // 按日期降序排序
        
        // 找出不晚於給定日期的最近點
        for point in sortedPoints {
            if point.date <= date {
                return point.value
            }
        }
        
        // 如果沒有早於給定日期的點，返回最早的點的值
        return sortedPoints.last?.value
    }
    
    // 獲取當前（最新）VDOT值
    func getCurrentVDOT() -> Double {
        return latestVdot
    }
    
    // 檢查是否有足夠的數據
    var hasData: Bool {
        return !vdotPoints.isEmpty
    }
}
