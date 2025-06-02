import Foundation

// MARK: - Models
struct WorkoutData: Codable {
    let id: String
    let name: String
    let type: String
    let startDate: TimeInterval
    let endDate: TimeInterval
    let duration: TimeInterval
    let distance: Double
    let heartRates: [HeartRateData]
    let speeds: [SpeedData]
    let strideLengths: [StrideData]?
    let cadences: [CadenceData]?
    let groundContactTimes: [GroundContactTimeData]?
    let verticalOscillations: [VerticalOscillationData]?
}

struct HeartRateData: Codable {
    let time: TimeInterval
    let value: Double
}

struct SpeedData: Codable {
    let time: TimeInterval
    let value: Double
}

struct StrideData: Codable {
    let time: TimeInterval
    let value: Double
}

struct CadenceData: Codable {
    let time: TimeInterval
    let value: Double
}

struct GroundContactTimeData: Codable {
    let time: TimeInterval
    let value: Double
}

struct VerticalOscillationData: Codable {
    let time: TimeInterval
    let value: Double
}

struct APIResponse<T: Codable>: Codable {
    let data: T
}

// MARK: - Migration Service
class WorkoutMigrationService {
    private let devBaseURL = "https://api-service-364865009192.asia-east1.run.app"
    private let prodBaseURL = "https://api-service-163961347598.asia-east1.run.app"
    
    private let email: String
    private let devToken: String
    private let prodToken: String
    
    init(email: String, devToken: String, prodToken: String) {
        self.email = email
        self.devToken = devToken
        self.prodToken = prodToken
    }
    
    // MARK: - Main Migration Function
    func migrateWorkouts() async {
        print("🚀 開始遷移 workouts 從 dev 到 prod 環境...")
        
        do {
            // 1. 從 dev 環境取得使用者的 workouts
            print("🔍 正在從 dev 環境取得 workouts...")
            let workouts = try await fetchWorkouts(environment: .dev)
            print("✅ 成功取得 \(workouts.count) 筆 workouts")
            
            // 2. 將 workouts 上傳到 prod 環境
            print("\n🔄 正在將 workouts 上傳到 prod 環境...")
            let results = try await migrateWorkoutsToProd(workouts: workouts)
            
            // 3. 顯示遷移摘要
            print("\n📊 遷移摘要:")
            print("----------------------------------------")
            print("總共處理: \(results.total) 筆")
            print("成功: \(results.success) 筆")
            print("失敗: \(results.failed) 筆")
            
            if !results.failedWorkoutIds.isEmpty {
                print("\n❌ 失敗的 Workout IDs:")
                for id in results.failedWorkoutIds {
                    print("- \(id)")
                }
            }
            
            print("\n🎉 遷移完成！")
            
        } catch {
            print("❌ 遷移過程中發生錯誤: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private enum Environment {
        case dev, prod
        
        var baseURL: String {
            switch self {
            case .dev: return "https://api-service-364865009192.asia-east1.run.app"
            case .prod: return "https://api-service-163961347598.asia-east1.run.app"
            }
        }
    }
    
    private func fetchWorkouts(environment: Environment) async throws -> [WorkoutData] {
        let url = URL(string: "\(environment.baseURL)/workouts?email=\(email)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(environment == .dev ? devToken : prodToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "APIError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to fetch workouts"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([WorkoutData].self, from: data)
    }
    
    private func migrateWorkoutsToProd(workouts: [WorkoutData]) async throws -> (total: Int, success: Int, failed: Int, failedWorkoutIds: [String]) {
        var successCount = 0
        var failedCount = 0
        var failedWorkoutIds: [String] = []
        
        for (index, workout) in workouts.enumerated() {
            do {
                let url = URL(string: "\(prodBaseURL)/workout")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(prodToken)", forHTTPHeaderField: "Authorization")
                
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(workout)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    successCount += 1
                    print("✅ [\(index + 1)/\(workouts.count))] 已遷移 workout: \(workout.id.prefix(8))...")
                } else {
                    throw NSError(domain: "APIError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, 
                                  userInfo: [NSLocalizedDescription: "Failed to upload workout"])
                }
                
            } catch {
                failedCount += 1
                failedWorkoutIds.append(workout.id)
                print("❌ [\(index + 1)/\(workouts.count))] 遷移失敗 workout: \(workout.id.prefix(8))... - \(error.localizedDescription)")
            }
        }
        
        return (workouts.count, successCount, failedCount, failedWorkoutIds)
    }
}

// MARK: - Extensions
extension String {
    func prefix(_ length: Int) -> String {
        return String(prefix(Swift.min(length, count)))
    }
}

// MARK: - Main Execution
@main
struct WorkoutMigration {
    static func main() async {
        print("🏃‍♂️ Workout 遷移工具 🏃‍♀️")
        print("=============================")
        
        // 1. 獲取使用者輸入
        print("請輸入要遷移的使用者 email:")
        guard let email = readLine(), !email.isEmpty else {
            print("❌ 請輸入有效的 email")
            return
        }
        
        print("\n請輸入 dev 環境的 token:")
        guard let devToken = readLine(), !devToken.isEmpty else {
            print("❌ 請輸入有效的 dev token")
            return
        }
        
        print("\n請輸入 prod 環境的 token:")
        guard let prodToken = readLine(), !prodToken.isEmpty else {
            print("❌ 請輸入有效的 prod token")
            return
        }
        
        print("\n準備開始遷移...")
        
        // 2. 執行遷移
        let migrationService = WorkoutMigrationService(
            email: email,
            devToken: devToken,
            prodToken: prodToken
        )
        
        await migrationService.migrateWorkouts()
    }
}
