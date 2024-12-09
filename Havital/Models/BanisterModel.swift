import Foundation

class BanisterModel {
    private let baselinePerformance: Double = 100 // 基準表現值
    private let tauFitness: Double = 42 // 體能適應時間常數
    private let tauFatigue: Double = 10 // 疲勞效應時間常數
    private let k1: Double = 1.0 // 體能效應權重係數
    private let k2: Double = 2.0 // 疲勞效應權重係數

    private var lastUpdateDate: Date?
    private var fitness: Double = 0
    private var fatigue: Double = 0

    func calculateTrimp(duration: TimeInterval, avgHR: Double, restingHR: Double, maxHR: Double) -> Double {
        let hrRatio = (avgHR - restingHR) / (maxHR - restingHR)
        let y: Double = 0.64 * exp(1.92 * hrRatio) // 使用單一公式
        return (duration / 60.0) * hrRatio * y // 將 duration 轉換為分鐘
    }

    func update(date: Date, trimp: Double = 0) {
        let calendar = Calendar.current

        guard let lastUpdate = lastUpdateDate else {
            // 第一次更新
            fitness = trimp
            fatigue = trimp
            lastUpdateDate = date
            return
        }

        let days = calendar.dateComponents([.day], from: lastUpdate, to: date).day ?? 0

        if days > 0 {
            let decayFactorFitness = exp(-Double(days) / tauFitness)
            let decayFactorFatigue = exp(-Double(days) / tauFatigue)

            if trimp > 0 { // 當天有訓練
                fitness = fitness * decayFactorFitness + trimp
                fatigue = fatigue * decayFactorFatigue + trimp
                lastUpdateDate = date
            } else { // 當天沒有訓練
                fitness *= decayFactorFitness
                fatigue *= decayFactorFatigue
            }
        } else if trimp > 0 { // 同一天內多次更新
            fitness += trimp
            fatigue += trimp
            lastUpdateDate = date
        }
    }

    func performance() -> Double {
        return baselinePerformance + k1 * fitness - k2 * fatigue
    }

    func getPerformanceForDate(_ date: Date) -> Double {
        guard let lastUpdate = lastUpdateDate else {
            return baselinePerformance
        }

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastUpdate, to: date).day ?? 0

        let decayedFitness = fitness * exp(-Double(days) / tauFitness)
        let decayedFatigue = fatigue * exp(-Double(days) / tauFatigue)

        return baselinePerformance + k1 * decayedFitness - k2 * decayedFatigue
    }

    func reset() {
        fitness = 0
        fatigue = 0
        lastUpdateDate = nil
    }
}

struct PerformancePoint: Identifiable {
    let id = UUID()
    let date: Date
    let performance: Double
    let hasWorkout: Bool
    let workoutName: String?
}
