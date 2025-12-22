# 背景任務調度器 Error 3 問題分析與修復

## 問題描述

GA 收到的錯誤信息：
```
背景同步任務註冊失敗：無法完成作業
(BGTASKSCHEDULER ERROR DOMAIN 錯誤 3)
```

**錯誤代碼**: `BGTaskSchedulerErrorCodeNotPermitted` (error 3)

這個錯誤表示**系統不允許註冊或排程背景任務**。

---

## 根本原因分析

### 1️⃣ 雙重任務衝突
應用程式中有**兩個獨立的背景任務排程系統**使用相同的 task identifier：

| 位置 | 函數 | Task ID | 說明 |
|------|------|---------|------|
| `HavitalApp.swift:444` | `scheduleBackgroundWorkoutSync()` | `com.havital.workout-sync` | 全局函數，排程任務 |
| `WorkoutBackgroundManager.swift:615` | `scheduleBackgroundTask()` | `com.havital.workout-sync` | 局部函數，也排程同一任務 |

### 2️⃣ 全局清除導致衝突
在 `HavitalApp.swift:315`，代碼執行：
```swift
BGTaskScheduler.shared.cancelAllTaskRequests()  // 清除所有任務
```

這會在初始化時清除所有已排程的任務，造成競態條件。

### 3️⃣ 重複註冊失敗
當兩個地方同時嘗試排程同一個 task identifier 時，系統會拒絕（error 3 = NotPermitted）。

---

## 時序圖：問題流程

```
應用啟動
  ↓
registerBackgroundTasks() 在 init() 中執行
  ↓
BGTaskScheduler.shared.cancelAllTaskRequests()  ← ⚠️ 清除所有任務
  ↓
註冊 "com.havital.workout-sync" 任務
  ↓
setupWorkoutBackgroundProcessing() 執行
  ↓
scheduleBackgroundWorkoutSync() 執行  ← 嘗試排程 "com.havital.workout-sync"
  ↓
HKObserverQuery 回調執行
  ↓
checkAndUploadPendingWorkouts() 執行
  ↓
scheduleBackgroundTask() 執行  ← ❌ 再次嘗試排程同一任務
  ↓
💥 Error 3: 已註冊的任務無法再次排程
```

---

## 修復方案

### 修復 1：移除全局 cancelAllTaskRequests()

**文件**: `Havital/HavitalApp.swift:310-357`

**舊代碼**:
```swift
private func registerBackgroundTasks() {
    let taskIdentifier = "com.havital.workout-sync"

    // ❌ 全局清除所有任務 - 導致競態條件
    BGTaskScheduler.shared.cancelAllTaskRequests()

    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
        // ...
    }
}
```

**新代碼** ✅:
```swift
private func registerBackgroundTasks() {
    let taskIdentifier = "com.havital.workout-sync"

    // ✅ 不要全局清除所有任務，只檢查任務是否已註冊
    // 後台註冊只需要執行一次
    do {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            // 背景同步任務
            print("背景任務開始執行")
            // ... (保持原有邏輯)
        }
        print("已註冊背景任務: \(taskIdentifier)")
    } catch {
        print("❌ 背景任務註冊失敗: \(error.localizedDescription)")
    }
}
```

### 修復 2：統一任務排程邏輯

**文件**: `Havital/Managers/WorkoutBackgroundManager.swift:615-631`

**舊代碼**:
```swift
private func scheduleBackgroundTask() {
    let taskIdentifier = "com.havital.workout-sync"

    let request = BGProcessingTaskRequest(identifier: taskIdentifier)
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

    do {
        try BGTaskScheduler.shared.submit(request)  // ❌ 重複排程
        print("已安排背景健身記錄同步任務")
    } catch {
        print("無法安排背景同步任務: \(error.localizedDescription)")
    }
}
```

**新代碼** ✅:
```swift
private func scheduleBackgroundTask() {
    // ✅ 修復：不再在這裡獨立排程任務，而是委派給全局的 scheduleBackgroundWorkoutSync()
    // 這樣避免重複任務競爭和 error 3（NotPermitted）
    scheduleBackgroundWorkoutSync()
}
```

---

## 修復原理

### ✅ 單一責任原則
- **`HavitalApp.swift`** 中的 `registerBackgroundTasks()` - 負責**註冊**背景任務（只執行一次）
- **全局函數** `scheduleBackgroundWorkoutSync()` - 負責**排程**背景任務（可多次調用）
- **`WorkoutBackgroundManager.scheduleBackgroundTask()`** - 委派給全局排程函數

### ✅ 避免重複訪問
- 移除 `cancelAllTaskRequests()` 防止競態條件
- 任務註冊在 App init 時執行一次，不再重複
- 任務排程可以多次調用，但都委派給同一個全局函數

### ✅ 減少權限衝突
- Info.plist 已正確配置 `BGTaskSchedulerPermittedIdentifiers`
- 單一的任務標識符管理流程
- 避免同時註冊和排程同一任務

---

## 修復後的流程

```
應用啟動
  ↓
registerBackgroundTasks() - 註冊一次
  ↓
✅ BGTaskScheduler 接受註冊
  ↓
setupWorkoutBackgroundProcessing() 執行
  ↓
scheduleBackgroundWorkoutSync() 排程任務
  ✓ 成功排程
  ↓
HKObserverQuery 回調執行
  ↓
checkAndUploadPendingWorkouts() 執行
  ↓
scheduleBackgroundTask() 執行
  ↓
✅ 委派到 scheduleBackgroundWorkoutSync()
  ✓ 成功排程（可重複調用）
  ↓
💚 無衝突，無 Error 3
```

---

## 驗證清單

- [x] 移除 `BGTaskScheduler.shared.cancelAllTaskRequests()`
- [x] 使用 `do-catch` 封裝任務註冊
- [x] WorkoutBackgroundManager 委派任務排程
- [x] 保持 Info.plist 配置不變
- [x] 代碼編譯通過，無新錯誤

---

## 預期改進

| 指標 | 修復前 | 修復後 |
|------|--------|--------|
| BGTaskScheduler Error 3 率 | 50% | ~0% |
| 後台任務成功率 | 部分失敗 | 穩定成功 |
| 任務重複衝突 | 頻繁 | 消除 |
| GA 錯誤上報 | 4 (50%) | ~0 |

---

## 相關代碼文件

- [HavitalApp.swift:310-357](../../Havital/HavitalApp.swift#L310-L357) - 背景任務註冊
- [WorkoutBackgroundManager.swift:614-619](../../Managers/WorkoutBackgroundManager.swift#L614-L619) - 任務排程委派
- [Info.plist:5-10](../../Info.plist#L5-L10) - 背景任務識別符配置

---

## 測試建議

### 1. 本地測試
```bash
# 在真機上測試後台任務
# 1. 運行應用並完成登入
# 2. 進入背景
# 3. 監控 Xcode console 日誌
# 期望看到: "已註冊背景任務: com.havital.workout-sync"
# 不期望看到: "❌ 背景任務註冊失敗"
```

### 2. GA 監控
- 監視 `BGTASKSCHEDULER ERROR DOMAIN` 錯誤比率
- 應在下一個版本發布後下降到 < 5%

### 3. 背景任務驗證
```bash
# 真機開發者模式
Settings → Developer → Background App Refresh → Havital
# 應該能看到任務成功執行
```

---

## 相關 Apple 文檔

- [BGTaskScheduler Documentation](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Error Code Reference](https://developer.apple.com/documentation/backgroundtasks/bgtaskschedulererrorcode)
- [Background Tasks Guide](https://developer.apple.com/documentation/backgroundtasks)

---

**修復日期**: 2025-11-14
**相關分支**: dev_heart_rate
**影響範圍**: iOS 應用的後台任務系統
