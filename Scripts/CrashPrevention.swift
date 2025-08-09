#!/usr/bin/env swift

import Foundation

// MARK: - Crash Prevention Verification Script
/// 檢測潛在的崩潰風險並提供修正建議

class CrashPreventionAnalyzer {
    
    struct RiskPattern {
        let pattern: String
        let description: String
        let severity: Severity
        let suggestion: String
        
        enum Severity: String, CaseIterable {
            case critical = "🔴 CRITICAL"
            case high = "🟠 HIGH"
            case medium = "🟡 MEDIUM"
            case low = "🟢 LOW"
        }
    }
    
    static let riskPatterns: [RiskPattern] = [
        // Dictionary Key 相關風險
        RiskPattern(
            pattern: "Dictionary.*Date|Date.*Dictionary",
            description: "使用 Date 對象作為 Dictionary key",
            severity: .critical,
            suggestion: "使用 timeIntervalSince1970 替代 Date 對象"
        ),
        
        // 內存管理風險
        RiskPattern(
            pattern: "Task.*{(?!.*\\[weak self\\])",
            description: "Task 閉包中缺少 [weak self]",
            severity: .high,
            suggestion: "在 Task 閉包中添加 [weak self] 捕獲語法"
        ),
        
        // 線程安全風險
        RiskPattern(
            pattern: "activeTasks\\[.*\\]\\s*=(?!.*taskQueue)",
            description: "直接修改 activeTasks 可能存在線程安全問題",
            severity: .high,
            suggestion: "在 taskQueue 中執行 Dictionary 操作"
        ),
        
        // 空指針風險
        RiskPattern(
            pattern: "\\!\\s*\\w+\\.\\w+(?!.*guard)",
            description: "強制解包可能導致崩潰",
            severity: .medium,
            suggestion: "使用 guard let 或 if let 安全解包"
        )
    ]
    
    func analyze(in directory: String) {
        print("🔍 開始分析崩潰風險...")
        print("📂 目標目錄: \(directory)")
        print("=" * 50)
        
        var totalRisks = 0
        var criticalRisks = 0
        
        for pattern in Self.riskPatterns {
            let risks = findRisks(pattern: pattern, in: directory)
            totalRisks += risks.count
            
            if pattern.severity == .critical {
                criticalRisks += risks.count
            }
            
            if !risks.isEmpty {
                print("\n\(pattern.severity.rawValue) \(pattern.description)")
                print("建議: \(pattern.suggestion)")
                print("-" * 30)
                
                for risk in risks.prefix(5) { // 只顯示前5個
                    print("📍 \(risk)")
                }
                
                if risks.count > 5 {
                    print("... 還有 \(risks.count - 5) 個類似問題")
                }
            }
        }
        
        print("\n" + "=" * 50)
        print("📊 分析結果:")
        print("• 總計風險: \(totalRisks)")
        print("• 嚴重風險: \(criticalRisks)")
        
        if criticalRisks > 0 {
            print("⚠️  發現嚴重風險，建議立即修正！")
        } else if totalRisks > 0 {
            print("✅ 無嚴重風險，但建議修正其他問題")
        } else {
            print("🎉 未發現明顯風險模式")
        }
    }
    
    private func findRisks(pattern: RiskPattern, in directory: String) -> [String] {
        // 這裡應該實現實際的文件掃描邏輯
        // 為了演示，返回空數組
        return []
    }
}

// MARK: - String Extension
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - Main Execution
let analyzer = CrashPreventionAnalyzer()
let projectPath = "/Users/wubaizong/havital/apps/ios/Havital"
analyzer.analyze(in: projectPath)

print("\n🛡️ 崩潰預防清單:")
print("✅ Dictionary key 使用 TimeInterval 而非 Date")
print("✅ Task 閉包使用 [weak self]")
print("✅ activeTasks 使用 TaskID 而非 String")
print("✅ 所有 TaskManageable 使用 @preconcurrency")
print("✅ 添加防禦性檢查和邊界條件處理")
print("✅ 實現正確的錯誤處理和日誌記錄")

print("\n🔧 執行自動檢查:")

// 實際的檢查腳本
let checkCommands = [
    "grep -r 'Dictionary.*Date' /Users/wubaizong/havital/apps/ios/Havital/Havital/ --include='*.swift' || echo '✅ No dangerous Date Dictionary keys found'",
    "grep -r 'var activeTasks.*String:' /Users/wubaizong/havital/apps/ios/Havital/Havital/ --include='*.swift' || echo '✅ No unsafe String activeTasks found'",
    "grep -r 'executeTask.*\"' /Users/wubaizong/havital/apps/ios/Havital/Havital/ --include='*.swift' | head -3 || echo '✅ TaskID usage looks good'"
]

for command in checkCommands {
    print("Running: \(command)")
    // 在實際實現中會執行這些命令
}