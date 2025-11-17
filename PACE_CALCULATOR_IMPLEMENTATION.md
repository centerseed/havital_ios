# 配速計算器功能實現總結

## 概述
成功實現了基於 VDOT 的配速計算器功能，當用戶編輯課表時自動提供訓練配速建議，並可查看完整配速表。

## 實現的功能

### 1. 配速計算工具類 (`PaceCalculator.swift`)
**位置**: `Havital/Utils/PaceCalculator.swift`

**核心功能**:
- ✅ 實現丹尼爾跑步公式的配速計算
- ✅ 支持 6 個訓練配速區間：
  - 恢復跑配速 [R] (0.52-0.59)
  - 輕鬆跑配速 [Easy] (0.59-0.74)
  - 節奏跑配速 [T] (0.75-0.84)
  - 全程馬拉松配速 [M] (0.78-0.82)
  - 閾值跑配速 [TH] (0.83-0.88)
  - 間歇跑配速 [I] (0.95-1.0)
- ✅ 配速格式化為 mm:ss，秒數四捨五入到 0 或 5
- ✅ 訓練類型自動映射到對應配速區間
- ✅ 提供配速區間範圍查詢（最快/最慢配速）

**核心算法**:
```swift
// 丹尼爾速度公式
v = (-0.182258 + √(0.033218 - 0.000416 × (-4.6 - vdot × pct))) / 0.000208

// 配速轉換
pace (min/km) = 1000 / v (m/min)
```

### 2. ViewModel 擴展
**文件**: `TrainingPlanViewModel.swift`

**新增屬性**:
```swift
@Published var currentVDOT: Double?
@Published var calculatedPaces: [PaceCalculator.PaceZone: String] = [:]
@Published var isLoadingPaces = false
```

**新增方法**:
- `loadVDOTAndCalculatePaces()` - 從 VDOTManager 獲取 weight_vdot 並計算配速表
- `getSuggestedPace(for:)` - 根據訓練類型返回建議配速
- `getPaceRange(for:)` - 返回訓練類型的配速區間範圍
- `recalculatePaces()` - 重新計算配速（VDOT 更新時使用）

**初始化流程**:
在 `performUnifiedInitialization()` 中添加了步驟 5：載入 VDOT 並計算配速

### 3. 配速表展示界面 (`PaceTableView.swift`)
**位置**: `Havital/Views/Training/EditSchedule/PaceTableView.swift`

**功能**:
- ✅ 顯示當前用戶的 VDOT 值
- ✅ 列出所有 6 個訓練配速區間及對應配速
- ✅ 每個配速區間有顏色標識和說明
- ✅ 提供配速使用指南
- ✅ 支持 Sheet 彈窗展示

**UI 設計**:
- VDOT 值顯著展示在頂部
- 配速表使用卡片式設計，易於閱讀
- 顏色編碼：綠色（恢復/輕鬆）、橙色（節奏/馬拉松/閾值）、紅色（間歇）

### 4. 編輯器界面更新

#### TrainingDetailEditor
**修改**: 添加配速表按鈕到導航欄
```swift
// 導航欄新增配速表圖標按鈕
ToolbarItem(placement: .navigationBarTrailing) {
    HStack {
        if let vdot = viewModel.currentVDOT {
            Button {
                showingPaceTable = true
            } label: {
                Image(systemName: "speedometer")
            }
        }
        Button("儲存") { ... }
    }
}

// Sheet 展示配速表
.sheet(isPresented: $showingPaceTable) {
    PaceTableView(vdot: vdot, calculatedPaces: calculatedPaces)
}
```

#### EasyRunDetailEditor
**新增功能**: 建議配速提示卡
- 自動顯示「輕鬆跑配速」建議
- 一鍵套用按鈕，點擊自動填充配速欄位
- 黃色燈泡圖標提示

#### TempoRunDetailEditor
**新增功能**: 節奏跑配速建議
- 顯示「節奏跑配速」或「閾值跑配速」建議
- 支持一鍵套用

#### IntervalDetailEditor
**新增功能**: 間歇訓練配速建議
- 顯示「間歇跑配速」建議（用於衝刺段）
- 一鍵套用到衝刺段配速

#### LongRunDetailEditor & SimpleTrainingDetailEditor
**更新**: 接受 viewModel 參數，為未來擴展建議配速做準備

### 5. 數據流架構

```
用戶認證
   ↓
VDOTManager 初始化
   ↓
獲取 weight_vdot (最新加權 VDOT)
   ↓
TrainingPlanViewModel.loadVDOTAndCalculatePaces()
   ↓
PaceCalculator.calculateTrainingPaces(vdot)
   ↓
計算所有 6 個訓練區間配速
   ↓
儲存到 calculatedPaces 字典
   ↓
編輯器界面使用配速建議
```

## 使用體驗

### 用戶編輯課表時：
1. **查看配速表**: 點擊導航欄的速度計圖標 (speedometer)，彈出完整配速表
2. **獲取建議配速**: 各訓練類型編輯器自動顯示建議配速提示卡
3. **一鍵套用**: 點擊「套用」按鈕，建議配速自動填入對應欄位
4. **手動調整**: 用戶仍可根據實際情況手動調整配速

### 配速映射關係：
| 訓練類型 | 配速區間 |
|---------|---------|
| 恢復跑 | 恢復跑配速 [R] |
| 輕鬆跑、LSD | 輕鬆跑配速 [Easy] |
| 節奏跑 | 節奏跑配速 [T] |
| 閾值跑 | 閾值跑配速 [TH] |
| 長距離跑 | 馬拉松配速 [M] |
| 間歇跑 | 間歇跑配速 [I] |

## 技術特點

### 1. 遵循現有架構原則
- ✅ 符合 CLAUDE.md 規範
- ✅ 使用 TaskManageable 模式
- ✅ 從 VDOTManager 獲取數據
- ✅ 雙軌緩存策略（立即顯示緩存，背景更新）
- ✅ 正確的錯誤處理和取消任務處理

### 2. 配速計算精確度
- 使用標準丹尼爾跑步公式
- 秒數四捨五入到 5 的倍數，符合實際使用習慣
- 支持 VDOT 驗證（20-85 範圍）
- 無效 VDOT 時使用預設值 45.0

### 3. UI/UX 優化
- 建議配速以黃色提示卡顯示，不干擾主流程
- 一鍵套用功能簡化操作
- 配速表使用 Sheet 展示，查看方便
- 顏色編碼直觀易懂

## 測試建議

### 功能測試：
1. **VDOT 載入測試**
   - 驗證從 VDOTManager 正確獲取 weight_vdot
   - 測試無 VDOT 數據時使用預設值

2. **配速計算測試**
   - 使用已知 VDOT 值驗證計算結果
   - 例：VDOT = 45.5 時，輕鬆跑配速應為 5:35 左右

3. **UI 互動測試**
   - 點擊配速表按鈕顯示完整配速表
   - 各訓練類型顯示正確的建議配速
   - 一鍵套用功能正常工作

4. **邊緣情況測試**
   - VDOT 為 0 或 null
   - VDOT 超出合理範圍（< 20 或 > 85）
   - 未知訓練類型

### 性能測試：
- 配速計算應在毫秒級完成
- 不應阻塞主線程
- 內存使用正常

## 未來擴展建議

1. **配速範圍顯示**: 在建議配速旁顯示「最快-最慢」區間
2. **心率區間**: 根據 VDOT 計算對應的心率區間
3. **單位切換**: 支持英哩配速顯示
4. **配速歷史**: 記錄用戶常用配速
5. **自定義調整**: 允許用戶微調 VDOT 計算係數

## 文件清單

### 新增文件：
1. `Havital/Utils/PaceCalculator.swift` - 配速計算工具類
2. `Havital/Views/Training/EditSchedule/PaceTableView.swift` - 配速表展示界面
3. `PACE_CALCULATOR_IMPLEMENTATION.md` - 本文件

### 修改文件：
1. `Havital/ViewModels/TrainingPlanViewModel.swift`
   - 新增 VDOT 和配速相關屬性
   - 新增配速計算方法
   - 更新初始化流程

2. `Havital/Views/Training/EditSchedule/TrainingDetailEditor.swift`
   - 添加配速表按鈕
   - 更新所有編輯器組件接受 viewModel 參數
   - 添加建議配速提示卡到各訓練類型編輯器

3. `Havital/Views/Training/EditSchedule/EditableDailyCard.swift`
   - 更新 TrainingEditSheet 傳遞 viewModel

## 驗證清單

- [x] 配速計算公式實現正確
- [x] 從 VDOTManager 獲取 weight_vdot
- [x] 配速表界面完整美觀
- [x] 建議配速自動顯示
- [x] 一鍵套用功能實現
- [x] 導航欄配速表按鈕
- [x] 所有訓練類型編輯器更新
- [x] 符合現有架構規範
- [x] 無編譯錯誤

## 總結

成功實現了完整的配速計算器功能，大幅提升了用戶編輯課表時選擇配速的便利性。基於用戶當前的 VDOT 值（weight_vdot），系統能自動計算並建議各訓練類型的合適配速，減少用戶的決策負擔。配速表功能讓用戶隨時查看完整的配速參考，有助於更好地理解和執行訓練計劃。

實現完全遵循 CLAUDE.md 規範，使用現有的架構模式，與 VDOTManager 無縫集成，確保數據一致性和可靠性。
