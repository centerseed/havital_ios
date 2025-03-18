import Foundation

struct VDOTCalculator {
    // Function to calculate VDOT based on distance (meters) and time (seconds)
    func calculateVDOT(distance: Int, time: Int) -> Double {
        let velocity = Double(distance) / (Double(time) / 60) // meters per minute
        let vo2 = -4.6 + 0.182258 * velocity + 0.000104 * pow(velocity, 2)
        let pct = 0.8 + 0.1894393 * exp(-0.012778 * Double(time) / 60) + 0.2989558 * exp(-0.1932605 * Double(time) / 60)
        return vo2 / pct
    }

    // Function to estimate paces for different race distances based on VDOT
    func paces(forVDOT vdot: Double) -> [String: String] {
        let distances: [String: Double] = [
            "5K": 5000,
            "10K": 10000,
            "Half Marathon": 21097.5,
            "Marathon": 42195
        ]

        var result: [String: String] = [:]

        for (name, distance) in distances {
            let root = bisect(lower: 1, upper: 600, vdot: vdot, distance: distance)
            let paceString = formatPace(seconds: root * 60)
            result[name] = paceString
        }

        return result
    }

    // Function to calculate training paces based on VDOT
    func trainingPaces(forVDOT vdot: Double) -> [String: String] {
        let paces: [String: (Double, Double)] = [
            "Easy": (0.59, 0.74),
            "Marathon": (0.75, 0.84),
            "Threshold": (0.83, 0.88),
            "Interval": (0.95, 1),
            "Repetition": (1.05, 1.2)
        ]

        var result: [String: String] = [:]

        for (name, pctRange) in paces {
            let slowerVelocity = calculateVelocity(vdot: vdot, pct: pctRange.0)
            let fasterVelocity = calculateVelocity(vdot: vdot, pct: pctRange.1)

            let slowerPace = formatPace(seconds: 1000 / slowerVelocity * 60)
            let fasterPace = formatPace(seconds: 1000 / fasterVelocity * 60)

            result[name] = "\(fasterPace) ~ \(slowerPace)"
        }

        return result
    }

    func calculateDifficultyIndex(vdot1: Double, vdot2: Double, week: Int, age: Int) -> Double {
        var difficultyIndex = pow(vdot2 / 40, 2.4) - pow(vdot1 / 40, 2.4)
        difficultyIndex *= 100

        // Week factor adjustment (12 - 24 weeks: 1 -> 0.75)
        let minWeek = 12
        let maxWeek = 24
        var weekFactor = 1.0
        if week >= minWeek && week <= maxWeek {
            weekFactor = 1.0 - (Double(week - minWeek) / Double(minWeek)) * 0.25
        }

        // Age factor adjustment (40 - 80 years: 1 -> 3)
        var ageFactor = 1.0
        if age > 40 {
            ageFactor = 1.0 + Double(age - 40) / 20.0
        }

        return difficultyIndex * weekFactor * ageFactor
    }

    // Function to calculate VDOT2 based on VDOT1 and target difficulty
    func calculateProposedVDOT(currentVDOT vdot1: Double, targetDifficulty: Double, week: Int, age: Int) -> Double {
        func difficultyFunction(vdot2: Double) -> Double {
            return calculateDifficultyIndex(vdot1: vdot1, vdot2: vdot2, week: week, age: age) - targetDifficulty
        }

        // Initial bounds for bisection method
        var lowerBound = vdot1
        var upperBound = vdot1 + 50 // Assume maximum progress range
        let tolerance = 1e-5

        while upperBound - lowerBound > tolerance {
            let midPoint = (lowerBound + upperBound) / 2
            if difficultyFunction(vdot2: midPoint) > 0 {
                upperBound = midPoint
            } else {
                lowerBound = midPoint
            }
        }

        return (lowerBound + upperBound) / 2
    }

    // 計算指定週數的 VDOT 值
    func calculateWeeklyVDOT(currentVDOT: Double, targetVDOT: Double, currentWeek: Int, totalWeeks: Int) -> Double {
        // 確保輸入的週數有效
        guard currentWeek > 0 && currentWeek <= totalWeeks else {
            return currentVDOT
        }
        
        // 計算達到目標 VDOT 的週數（總週數減去最後兩週）
        let targetWeek = totalWeeks - 2
        
        // 如果當前週數超過目標週數，返回目標 VDOT
        if currentWeek >= targetWeek {
            return targetVDOT
        }
        
        // 計算每週需要增加的 VDOT 值
        let totalVDOTIncrease = targetVDOT - currentVDOT
        let weeklyIncrease = totalVDOTIncrease / Double(targetWeek)
        
        // 計算當前週數應該達到的 VDOT 值
        let progressedVDOT = currentVDOT + (weeklyIncrease * Double(currentWeek))
        
        return progressedVDOT
    }

    // 計算當前週數應該達到的 VDOT 值
    func calculateProgressiveVDOT(currentVDOT: Double, targetVDOT: Double, totalWeeks: Int, currentWeek: Int) -> Double {
        // 確保輸入的週數有效
        guard totalWeeks > 7, currentWeek > 0, currentWeek <= totalWeeks else {
            return currentVDOT
        }
        
        // 定義進展區間：從第3週開始到倒數第4週結束
        let startWeek = 3
        let endWeek = totalWeeks - 4
        
        // 如果在進展區間之前，返回初始 VDOT
        if currentWeek < startWeek {
            return currentVDOT
        }
        
        // 如果在進展區間之後，返回目標 VDOT
        if currentWeek > endWeek {
            return targetVDOT
        }
        
        // 計算進展區間內的線性增長
        let progressWeeks = endWeek - startWeek + 1 // 總進展週數
        let currentProgressWeek = currentWeek - startWeek + 1 // 當前進展週數
        let vdotDifference = targetVDOT - currentVDOT
        
        // 使用線性插值計算當前應該達到的 VDOT
        let progressRatio = Double(currentProgressWeek) / Double(progressWeeks)
        let progressiveVDOT = currentVDOT + (vdotDifference * progressRatio)
        
        return progressiveVDOT
    }

    // Helper function: Bisection method to find time (minutes)
    private func bisect(lower: Double, upper: Double, vdot: Double, distance: Double) -> Double {
        let tolerance = 1e-5
        var low = lower
        var high = upper

        while high - low > tolerance {
            let mid = (low + high) / 2
            if f(x: mid, vdot: vdot, distance: distance) * f(x: low, vdot: vdot, distance: distance) < 0 {
                high = mid
            } else {
                low = mid
            }
        }

        return (low + high) / 2
    }

    private func f(x: Double, vdot: Double, distance: Double) -> Double {
        return (-4.6 + 0.182258 * distance * pow(x, -1) + 0.000104 * pow(distance, 2) * pow(x, -2)) /
               (0.8 + 0.1894393 * exp(-0.012778 * x) + 0.2989558 * exp(-0.1932605 * x)) - vdot
    }

    // Helper function: Calculate velocity
    private func calculateVelocity(vdot: Double, pct: Double) -> Double {
        return (-0.182258 + sqrt(0.033218 - 0.000416 * (-4.6 - (vdot * pct)))) / 0.000208
    }

    // Helper function: Format pace as mm:ss
    private func formatPace(seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    func calculateHRRRatio(hr: Double, maxHR: Double, restingHR: Double) -> Double {
            // 確保心率在有效範圍內
            let validHR = min(max(hr, restingHR), maxHR)
            
            // HRR 比率 = (當前心率 - 靜息心率) / (最大心率 - 靜息心率)
            let hrrRatio = (validHR - restingHR) / (maxHR - restingHR)
            return hrrRatio
        }
        
        /// 計算動態 VDOT 值，考慮心率因素
        /// - Parameters:
        ///   - distance: 距離（公里）
        ///   - time: 時間（秒）
        ///   - hr: 平均心率
        ///   - maxHR: 最大心率
        ///   - restingHR: 靜息心率
        ///   - a: 指數模型參數 A
        ///   - b: 指數模型參數 B
        /// - Returns: 動態 VDOT 值
        func calculateDynamicVDOT(distance: Double, time: Int, hr: Double, maxHR: Double = 180, restingHR: Double = 60, a: Double = 33.0, b: Double = 1.2) -> Double {
            // 將公里轉換為米
            let distanceInMeters = Int(distance * 1000)
            
            // 計算基本 VDOT
            let vdot = calculateVDOT(distance: distanceInMeters, time: time)
            
            // 計算 HRR 比率
            let hrrRatio = calculateHRRRatio(hr: hr, maxHR: maxHR, restingHR: restingHR)
            
            // 使用指數模型計算動態 VDOT
            // dynamic_vdot = vdot + A * ((1 - hrr_ratio) ** B)
            let dynamicVDOT = vdot + a * pow(1 - hrrRatio, b)
            
            return dynamicVDOT
        }
        
        /// 根據配速字串計算動態 VDOT
        /// - Parameters:
        ///   - distanceKm: 距離（公里）
        ///   - paceStr: 配速字串（格式如 "4:30"，表示每公里 4 分 30 秒）
        ///   - hr: 平均心率
        ///   - maxHR: 最大心率
        ///   - restingHR: 靜息心率
        /// - Returns: 動態 VDOT 值
        func calculateDynamicVDOTFromPace(distanceKm: Double, paceStr: String, hr: Double, maxHR: Double = 180, restingHR: Double = 60) -> Double {
            // 解析配速字串
            let components = paceStr.split(separator: ":")
            guard components.count == 2,
                  let minutes = Int(components[0]),
                  let seconds = Int(components[1]) else {
                return 0 // 無效的配速格式
            }
            
            // 計算總秒數
            let paceSeconds = minutes * 60 + seconds
            
            // 計算總時間（秒）
            let totalTimeSeconds = Int(distanceKm * Double(paceSeconds))
            
            // 使用總時間計算動態 VDOT
            return calculateDynamicVDOT(distance: distanceKm, time: totalTimeSeconds, hr: hr, maxHR: maxHR, restingHR: restingHR)
        }
}

// Example usage:
/*
let calculator = VDOTCalculator()

let vdot = calculator.calculateVDOT(distance: 10000, time: 4500)
print("VDOT: \(vdot)")

let racePaces = calculator.paces(forVDOT: vdot)
print("Race Paces: \(racePaces)")

let trainingPaces = calculator.trainingPaces(forVDOT: vdot)
print("Training Paces: \(trainingPaces)")
*/
