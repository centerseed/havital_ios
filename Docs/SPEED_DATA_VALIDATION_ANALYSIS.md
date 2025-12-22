# Apple Health 運動資料驗證分析

## 🎯 核心問題

當前上傳邏輯強制要求「速度樣本 (`speeds` array)」，但實際上有多種資料來源可以驗證運動的合法性。

## 📊 可用的資料來源

### 1. **速度樣本資料** (`speeds: [(Date, Double)]`)
- **來源**：GPS 實時記錄
- **特徵**：連續的時間序列資料
- **有無指示**：有此資料 = 有 GPS 訊號
- **無此資料原因**：
  - 室內運動（跑步機、動感單車）
  - GPS 信號弱（地下室、隧道）
  - Apple Watch 未啟用 GPS

### 2. **分圈資料** (`laps: [LapData]`)
- **來源**：Apple Health 記錄的運動分段
- **包含欄位**：
  - `totalDistanceM`: 分圈總距離
  - `avgSpeedMPerS`: 分圈平均速度（計算值 = 距離/時間）
  - `avgHeartRateBpm`: 分圈平均心率
  - `totalTimeS`: 分圈時長
- **有無指示**：有分圈資料 = 運動被正確記錄
- **特徵**：即使無 GPS 也會有分圈資料

### 3. **心率樣本資料** (`heartRates: [(Date, Double)]`)
- **來源**：心率感應器（Apple Watch 或配戴設備）
- **特徵**：連續時間序列，採樣頻率約 5-10 秒
- **有無指示**：有心率 = 運動有效

### 4. **步頻資料** (`cadences: [(Date, Double)]`)
- **來源**：加速度計計算或第三方設備
- **特徵**：連續時間序列，採樣頻率約 15 秒
- **有無指示**：有步頻 = 跑步相關運動有效

### 5. **總距離** (`distance: Double`)
- **來源**：
  - GPS 軌跡（若有 GPS）
  - 加速度計推算（若無 GPS）
- **特徵**：單一聚合值
- **限制**：無法判斷資料品質

---

## 🔍 驗證邏輯優化方案

### 目前邏輯（有缺陷）

```
跑步類型 + 無速度樣本
  → 標記失敗（缺少必要資料）
  → 進入重試機制
```

**問題**：
- 室內運動（跑步機）無法上傳
- 即使有分圈資料和心率資料也被拒絕

### 改進邏輯（推薦）

```
跑步類型的運動驗證
  ├─ 速度樣本 > 0？
  │  └─ 是 → ✅ 有 GPS，繼續驗證
  │
  ├─ 速度樣本 = 0 但有分圈資料且分圈有 totalDistanceM？
  │  └─ 是 → ✅ 無 GPS 但運動完整，允許上傳
  │
  ├─ 速度樣本 = 0 但無分圈資料，有心率 + 步頻？
  │  └─ 是 → ⚠️ 基礎資料完整，允許上傳
  │
  └─ 都沒有？
     └─ ❌ 真的沒有運動資料，標記失敗
```

---

## 📋 改進後的驗證優先級

| 優先級 | 資料來源 | 驗證條件 | 說明 |
|--------|---------|---------|------|
| **1** | 速度樣本 | `speeds.count >= 2` | 最可靠，有 GPS 實測 |
| **2** | 分圈距離 | `laps.count > 0 && laps.exists(totalDistanceM > 0)` | 次優，運動完整記錄 |
| **3** | 計算速度 | `distance > 0 && duration > 0` | 可接受，基礎驗證 |
| **4** | 心率 + 步頻 | `heartRates.count >= 2 && cadences.count >= 2` | 基本驗證，無距離資訊 |

---

## 💡 具體實現建議

### 新增驗證函數

```swift
/// 判斷是否有可靠的速度資訊
private func hasReliableSpeedData(requiredData: WorkoutRequiredData) -> Bool {
    // 優先級 1: GPS 速度樣本
    if requiredData.speedData.count >= 2 {
        print("✅ 有 GPS 速度樣本 (\(requiredData.speedData.count) 筆)")
        return true
    }

    // 優先級 2: 分圈中有距離資訊
    if let laps = requiredData.lapData, !laps.isEmpty {
        let hasDistanceInLaps = laps.contains { ($0.totalDistanceM ?? 0) > 0 }
        if hasDistanceInLaps {
            let lapDistances = laps.compactMap { $0.totalDistanceM }.reduce(0, +)
            print("✅ 有分圈距離資訊 (總計: \(lapDistances) m，\(laps.count) 圈)")
            return true
        }
    }

    // 優先級 3: 總距離 > 0
    if let distance = requiredData.workout.totalDistance?.doubleValue(for: .meter()),
       distance > 0 {
        print("✅ 有計算距離 (\(distance) m)")
        return true
    }

    // 優先級 4: 至少有心率和步頻
    if requiredData.heartRateData.count >= 2 && requiredData.cadenceData.count >= 2 {
        print("⚠️ 有心率和步頻，但無距離資訊")
        return true
    }

    // 都沒有可靠資訊
    print("❌ 無可靠速度或距離資訊")
    return false
}

/// 判斷是否需要重試速度資料
private func shouldRetrySpeedData(workout: HKWorkout, speedData: [(Date, Double)]) -> Bool {
    // 只有同時滿足以下條件才重試：
    // 1. 運動類型是跑步相關
    // 2. 目前無速度樣本
    // 3. 有分圈資料並且分圈裡有距離（表示 Watch 在記錄）

    let isRunning = isRunningRelatedWorkout(workout)
    let noSpeedData = speedData.count < 2

    // 檢查分圈中是否有距離
    if isRunning && noSpeedData,
       let laps = try? await healthKitManager.fetchLapData(for: workout),
       !laps.isEmpty,
       laps.contains(where: { ($0.totalDistanceM ?? 0) > 0 }) {
        print("⚠️ 有分圈距離但無 GPS 速度，可能是 GPS 延遲同步，進行重試...")
        return true
    }

    // 無分圈距離也無速度，可能是室內運動，不重試
    if isRunning && noSpeedData {
        print("⚠️ 無分圈距離也無 GPS 速度，判定為室內運動，跳過重試")
        return false
    }

    return false
}
```

### 修改驗證邏輯

```swift
/// 修改後的必要資料驗證
private func validateAndFetchRequiredWorkoutData(
    for workout: HKWorkout,
    retryHeartRate: Bool = false
) async -> WorkoutRequiredData {
    let isRunning = isRunningRelatedWorkout(workout)

    // 1. 獲取心率數據（所有運動都需要）
    var heartRateData: [(Date, Double)] = []
    // ... 現有邏輯保持不變

    // 2. 獲取分圈資料（先於速度數據）
    var lapData: [LapData]?
    do {
        lapData = try await healthKitManager.fetchLapData(for: workout)
        if let laps = lapData {
            let hasDistance = laps.contains { ($0.totalDistanceM ?? 0) > 0 }
            print("📍 [驗證] 分圈資料: \(laps.count) 圈，有距離: \(hasDistance)")
        }
    } catch {
        print("⚠️ [驗證] 無法獲取分圈資料")
    }

    // 3. 獲取速度數據（基於分圈決定是否重試）
    var speedData: [(Date, Double)] = []
    do {
        speedData = try await healthKitManager.fetchSpeedData(for: workout)
        print("📊 [驗證] 初次速度數據: \(speedData.count) 筆")

        // 只在滿足特定條件下重試速度
        if shouldRetrySpeedData(workout: workout, speedData: speedData) {
            speedData = await retryFetchingData(
                name: "速度",
                currentData: speedData,
                fetchOperation: { _ in
                    try await self.healthKitManager.fetchSpeedData(for: workout)
                }
            )
        }
    } catch {
        print("❌ [驗證] 無法獲取速度數據")
    }

    // 4. 其他資料...（保持現有邏輯）

    let requiredData = WorkoutRequiredData(
        workout: workout,
        heartRateData: heartRateData,
        speedData: speedData,
        cadenceData: cadenceData,
        strideLengthData: strideLengthData,
        groundContactTimeData: groundContactTimeData,
        verticalOscillationData: verticalOscillationData,
        totalCalories: totalCalories,
        lapData: lapData
    )

    return requiredData
}
```

### 修改驗證條件

```swift
/// 改進 WorkoutRequiredData 的驗證邏輯
var isAllRequiredDataAvailable: Bool {
    if isRunningRelated {
        // 跑步運動：優先級驗證
        // 1. 有有效的心率
        guard heartRateData.count >= 2 else {
            print("❌ 缺少心率資料")
            return false
        }

        // 2. 有可靠的速度來源
        guard hasReliableSpeedData(self) else {
            print("❌ 缺少可靠的速度或距離資訊")
            return false
        }

        // 3. 有步頻或分圈資料
        let hasCadence = cadenceData.count >= 2
        let hasLaps = (lapData?.count ?? 0) > 0
        guard hasCadence || hasLaps else {
            print("❌ 缺少步頻或分圈資料")
            return false
        }

        return true
    } else {
        // 其他運動：只需要心率
        return heartRateData.count >= 2
    }
}
```

---

## 📍 資料來源優先級圖表

```
運動驗證決策樹
│
├─ 心率 >= 2？
│  └─ 否 → ❌ 失敗（必需）
│
└─ 是 → 檢查是否為跑步相關
   │
   ├─ 否 → ✅ 通過（其他運動只需心率）
   │
   └─ 是 → 檢查速度/距離來源
      │
      ├─ GPS 速度 >= 2？
      │  └─ 是 → ✅ 優先級 1 通過
      │
      ├─ 分圈有距離且分圈 > 0？
      │  └─ 是 → ✅ 優先級 2 通過
      │
      ├─ 總距離 > 0？
      │  └─ 是 → ✅ 優先級 3 通過
      │
      └─ 都無？
         ├─ 有步頻？
         │  └─ 是 → ⚠️ 優先級 4 通過（後端可推算速度）
         │
         └─ 都無 → ❌ 失敗（無速度或距離資訊）
```

---

## 🔄 重試策略調整

| 情況 | 當前行為 | 改進後 | 理由 |
|------|---------|--------|------|
| **有 GPS 速度** | 重試 5 次（若不足 2 筆） | 重試 3 次 | Apple Health 通常快速同步 |
| **無 GPS 但有分圈距離** | 標記失敗 | **不重試，直接上傳** | 運動完整記錄，分圈有速度 |
| **無 GPS 無分圈距離** | 標記失敗 | **不重試，判斷為室內運動** | 可能是跑步機，無 GPS 正常 |
| **只有心率和步頻** | 標記失敗 | **允許上傳** | 基本資訊完整，後端可推算 |

---

## 📝 預期改進成果

### 目前問題
- ❌ 跑步機運動無法上傳
- ❌ Apple Watch 無 GPS 運動被拒絕
- ❌ 分圈資料完整但因缺速度樣本被拒

### 改進後
- ✅ 跑步機運動正常上傳（有分圈 + 心率 + 步頻）
- ✅ 無 GPS 運動基於分圈資料上傳
- ✅ 保持資料品質標準（心率必需）
- ✅ 更精確的運動有效性判斷

---

## 🎯 實現優先級

1. **立即修改**：停止強制要求 `speeds` 陣列非空
2. **添加驗證**：實現 `hasReliableSpeedData()` 函數
3. **優化重試**：基於分圈決定是否重試速度
4. **日誌改進**：清楚記錄驗證決策過程

