import Foundation

class WeeklySummaryStorage {
    static let shared = WeeklySummaryStorage()
    private init() {}
    
    private var baseURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("WeeklySummaries")
    }
    
    private func createDirectoryIfNeeded(at url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func getYearDirectory(date: Date) -> URL {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        return baseURL.appendingPathComponent(String(year))
    }
    
    private func getSummaryURL(for date: Date) -> URL {
        let yearDirectory = getYearDirectory(date: date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = dateFormatter.string(from: date) + ".json"
        return yearDirectory.appendingPathComponent(fileName)
    }
    
    func saveSummary(_ summary: WeeklySummary, date: Date) {
        let yearDirectory = getYearDirectory(date: date)
        createDirectoryIfNeeded(at: baseURL)
        createDirectoryIfNeeded(at: yearDirectory)
        
        let summaryURL = getSummaryURL(for: date)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(summary)
            try data.write(to: summaryURL)
        } catch {
            print("Error saving summary: \(error)")
        }
    }
    
    func loadSummaries(from startDate: Date, to endDate: Date) -> [WeeklySummary] {
        var summaries: [WeeklySummary] = []
        let calendar = Calendar.current
        
        // 獲取開始和結束年份
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)
        
        // 遍歷每一年
        for year in startYear...endYear {
            let yearDirectory = baseURL.appendingPathComponent(String(year))
            guard let files = try? FileManager.default.contentsOfDirectory(at: yearDirectory,
                                                                         includingPropertiesForKeys: nil) else {
                continue
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // 遍歷該年份目錄下的所有文件
            for file in files {
                guard file.pathExtension == "json",
                      let fileName = file.deletingPathExtension().lastPathComponent.components(separatedBy: "/").last,
                      let fileDate = dateFormatter.date(from: fileName) else {
                    continue
                }
                
                // 檢查日期是否在範圍內
                if fileDate >= startDate && fileDate <= endDate {
                    if let data = try? Data(contentsOf: file),
                       let summary = try? JSONDecoder().decode(WeeklySummary.self, from: data) {
                        summaries.append(summary)
                    }
                }
            }
        }
        
        return summaries.sorted { $0.startDate < $1.startDate }
    }
}
