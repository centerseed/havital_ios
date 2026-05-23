import Foundation

// MARK: - WorkoutReflectionGate
//
// 純函式 gate：判斷 WorkoutDetailView 是否應自動彈出 WorkoutReflectionView。
// 無副作用，易於單元測試。

enum WorkoutReflectionGate {
    /// detail 載入後、無 RPE、且本次尚未自動彈過 → 自動彈一次。
    static func shouldAutoPrompt(hasRPE: Bool, detailLoaded: Bool, alreadyPrompted: Bool) -> Bool {
        detailLoaded && !hasRPE && !alreadyPrompted
    }
}
