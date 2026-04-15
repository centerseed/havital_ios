# Training V2 UI Native Component Migration Plan
# V2 原生 UI 組件遷移計劃

**目標**: 移除 V1 兼容層,創建原生支援 V2 資料結構的 UI 組件
**建立日期**: 2026-01-24
**最後更新**: 2026-01-24
**狀態**: 🔄 進行中

---

## 背景與問題

### 當前狀態 (2026-01-24)

✅ **已完成的工作**:
- V2 Data Layer 完整實作 (`DayDetail`, `TrainingSession`, DTOs, Mappers)
- V2 Domain Layer 完整實作 (新的 Entity 結構)
- V1 兼容層 (Compatibility Layer) 實作在 `TrainingSessionModels.swift`

❌ **存在的問題**:
- V2 UI 組件 (`WeekTimelineViewV2`, `TimelineItemViewV2`) 仍使用 V1 資料模型 (`TrainingDay`, `TrainingDetails`)
- 通過兼容層將 `DayDetail` → `TrainingDay` 轉換以適配 V1 UI
- 每次 V2 API 更新都需要維護兼容層的轉換邏輯
- 技術債務持續累積,長期維護成本高

### 遷移目標

**目標 A**: 完全移除兼容層依賴,創建原生 V2 UI 組件
**目標 B**: 確保 V1 和 V2 系統完全隔離,互不影響
**目標 C**: 為未來棄用 V1 做準備,降低遷移複雜度

---

## 進度總覽

| 階段 | 名稱 | 狀態 | 完成項目 |
|------|------|------|----------|
| Phase 1 | UI 組件分析 | ✅ 完成 | 3/3 |
| Phase 2 | 創建 V2 Native UI Components | 🔲 未開始 | 0/5 |
| Phase 3 | 更新 V2 Views 使用新組件 | 🔲 未開始 | 0/4 |
| Phase 4 | 移除兼容層 | 🔲 未開始 | 0/3 |
| Phase 5 | 測試與驗證 | 🔲 未開始 | 0/4 |

**狀態圖示**: 🔲 未開始 | 🔄 進行中 | ✅ 完成 | ⚠️ 有問題

---

## Phase 1: UI 組件分析

**目標**: 識別所有需要遷移的 UI 組件和依賴關係

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 1.1 | 識別使用 V1 資料模型的 V2 UI 組件 | ✅ | `TimelineItemViewV2`, `TrainingDetailsViewV2` |
| 1.2 | 分析兼容層的轉換邏輯 | ✅ | `DayDetail.type`, `DayDetail.trainingDetails` |
| 1.3 | 確認 V2 資料結構的完整性 | ✅ | 所有 V2 Entity 已實作 |

### 分析結果

**需要遷移的組件**:
1. `TimelineItemViewV2` - 當前期望接收 `TrainingDay`,需改為 `DayDetail`
2. `TrainingDetailsViewV2` - 當前期望接收 `TrainingDetails`,需改為 `TrainingSession`
3. `WeekTimelineViewV2` - 已部分支援 `DayDetail`,但子組件仍依賴 V1 模型

**兼容層依賴**:
- `DayDetail.type` → 推斷 `DayType` (從 `category` + `session.primary`)
- `DayDetail.trainingDetails` → 轉換 `TrainingSession` → `TrainingDetails`
- `DayDetail.dayIndexInt` → 直接返回 `dayIndex` (這個可保留,無副作用)

---

## Phase 2: 創建 V2 Native UI Components

**目標**: 創建完全使用 V2 資料結構的新 UI 組件

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 2.1 | 創建 `DayTimelineItemView` (原生支援 `DayDetail`) | 🔲 | 替代 `TimelineItemViewV2` |
| 2.2 | 創建 `SessionDetailsView` (原生支援 `TrainingSession`) | 🔲 | 替代 `TrainingDetailsViewV2` |
| 2.3 | 創建 `RunActivityView` (顯示 `RunActivity` 詳情) | 🔲 | 支援間歇、分段、一般跑步 |
| 2.4 | 創建 `StrengthActivityView` (顯示 `StrengthActivity` 詳情) | 🔲 | 顯示動作列表、組數、重量 |
| 2.5 | 創建 `CrossActivityView` (顯示 `CrossActivity` 詳情) | 🔲 | 顯示交叉訓練類型、強度 |

### 組件設計原則

**命名規則**:
- 使用明確的名稱,不加 "V2" 後綴
- 放置在 `Features/TrainingPlanV2/Presentation/Views/Components/` 目錄下
- 範例: `DayTimelineItemView`, `SessionDetailsView`

**資料依賴**:
- 只依賴 V2 Domain Entities (`DayDetail`, `TrainingSession`, `RunActivity` 等)
- 不依賴任何 V1 模型 (`TrainingDay`, `TrainingDetails`, `DayType`)
- 不使用兼容層的計算屬性

**UI 設計**:
- 複用現有的樣式邏輯 (顏色、字體、間距)
- 保持與 V1 一致的視覺呈現
- 支援所有訓練類型: run, strength, cross, rest

---

## Phase 3: 更新 V2 Views 使用新組件

**目標**: 將現有 V2 Views 切換到使用新的 Native Components

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 3.1 | 更新 `WeekTimelineViewV2` 使用 `DayTimelineItemView` | 🔲 | 移除對 `TimelineItemViewV2` 的依賴 |
| 3.2 | 更新 `DayTimelineItemView` 內部使用 `SessionDetailsView` | 🔲 | 移除對 `TrainingDetailsViewV2` 的依賴 |
| 3.3 | 確保所有 V2 Views 只依賴 V2 Entities | 🔲 | 檢查 imports,移除 V1 模型引用 |
| 3.4 | 更新 `TrainingPlanV2View` 確保完整的資料流 | 🔲 | ViewModel → View → Components |

### 資料流設計

**新的 V2 資料流**:
```
API Response
  → WeeklyPlanV2DTO
  → TrainingSessionMapper.toEntity()
  → WeeklyPlanV2 (days: [DayDetail])
  → TrainingPlanV2ViewModel
  → TrainingPlanV2View (passes weeklyPlan)
  → WeekTimelineViewV2 (accesses plan.days: [DayDetail])
  → DayTimelineItemView (receives DayDetail) ✅ 原生支援
  → SessionDetailsView (receives TrainingSession) ✅ 原生支援
```

**優點**:
- 資料流向清晰,無轉換損耗
- 類型安全,編譯期檢查
- 易於測試和維護

---

## Phase 4: 移除兼容層

**目標**: 安全地移除 V1 兼容層程式碼

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 4.1 | 確認所有 V2 UI 不再使用兼容層 | 🔲 | 全域搜尋 `DayDetail.type`, `DayDetail.trainingDetails` |
| 4.2 | 移除 `DayDetail` extension 中的兼容層方法 | 🔲 | 保留 `dayIndexInt`,移除其他轉換方法 |
| 4.3 | 清理不再使用的 Helper 函數 | 🔲 | `inferRunType`, `convertToTrainingDetails` 等 |

### 移除檢查清單

**兼容層程式碼位置**:
- 檔案: `Features/TrainingPlanV2/Domain/Entities/TrainingSessionModels.swift`
- 行數: Lines 225-479
- Extension: `extension DayDetail`

**需要移除的方法**:
- `var type: DayType` (Lines 235-254)
- `var trainingDetails: TrainingDetails?` (Lines 257-263)
- `inferRunType(from:)` (Lines 268-328)
- `inferCrossType(from:)` (Lines 331-344)
- `convertToTrainingDetails(from:)` (Lines 347-356)
- `convertRunActivityToDetails(_:)` (Lines 359-446)
- `convertStrengthActivityToDetails(_:)` (Lines 449-462)
- `convertCrossActivityToDetails(_:)` (Lines 465-478)

**保留的計算屬性**:
- `var dayIndexInt: Int` (Lines 230-232) - 無副作用,可保留方便使用

---

## Phase 5: 測試與驗證

**目標**: 確保 V2 UI 完整運作,不影響 V1

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 5.1 | 測試 V2 用戶的完整訓練流程 | 🔲 | Overview → Weekly Plan → Day Details |
| 5.2 | 測試所有訓練類型的顯示 | 🔲 | Run (easy, interval, progression), Strength, Cross, Rest |
| 5.3 | 確認 V1 用戶完全不受影響 | 🔲 | V1 路由、UI、資料流保持不變 |
| 5.4 | 驗證間歇訓練、分段訓練的細節顯示 | 🔲 | Work/Recovery, Segments, 心率區間 |

### 測試場景

**V2 用戶測試**:
1. **Easy Run Day** - 顯示距離、配速、心率區間
2. **Interval Training Day** - 顯示 Work/Recovery、重複次數、間歇細節
3. **Progression Run Day** - 顯示多個分段、漸速配速
4. **Strength Training Day** - 顯示動作列表、組數、次數、重量
5. **Cross Training Day** - 顯示交叉訓練類型、時長、強度
6. **Rest Day** - 顯示休息狀態

**V1 用戶測試**:
1. 確認 V1 路由正常 (ContentView 版本檢查)
2. 確認 V1 UI 顯示正常
3. 確認 V1 資料載入正常
4. 確認沒有編譯錯誤或 runtime crash

---

## 實施順序建議

### 第一階段 (1-2 天)
**重點**: 創建核心 UI 組件
- [ ] 完成 Phase 2.1: `DayTimelineItemView`
- [ ] 完成 Phase 2.2: `SessionDetailsView`

### 第二階段 (1 天)
**重點**: 創建活動類型專屬組件
- [ ] 完成 Phase 2.3: `RunActivityView`
- [ ] 完成 Phase 2.4: `StrengthActivityView`
- [ ] 完成 Phase 2.5: `CrossActivityView`

### 第三階段 (半天)
**重點**: 整合新組件到 V2 Views
- [ ] 完成 Phase 3.1-3.4: 更新所有 V2 Views

### 第四階段 (半天)
**重點**: 移除兼容層
- [ ] 完成 Phase 4.1-4.3: 移除兼容層程式碼

### 第五階段 (1 天)
**重點**: 測試驗證
- [ ] 完成 Phase 5.1-5.4: 全面測試

**預估總時長**: 4-5 天

---

## 依賴與風險

### 依賴項目

**完成的前置工作**:
- ✅ V2 Data Layer 完整實作
- ✅ V2 Domain Layer 完整實作
- ✅ V2 ViewModel 實作
- ✅ 兼容層實作 (作為參考)

**外部依賴**:
- 無,所有資料結構已完備

### 風險評估

| 風險 | 等級 | 緩解措施 |
|------|------|----------|
| 新 UI 組件遺漏某些訓練類型 | 中 | 參考兼容層的轉換邏輯,確保覆蓋所有 `runType` |
| V1 用戶受到影響 | 低 | 完全隔離,不修改 V1 相關程式碼 |
| UI 樣式與 V1 不一致 | 低 | 複用現有樣式邏輯,視覺對比測試 |
| 測試覆蓋不足 | 中 | 制定詳細測試場景,手動測試所有類型 |

---

## 成功指標

完成遷移後應達到:

1. **程式碼品質**
   - ✅ V2 UI 組件不依賴任何 V1 模型
   - ✅ 兼容層程式碼完全移除
   - ✅ 無編譯警告或錯誤

2. **功能完整性**
   - ✅ 所有訓練類型正常顯示
   - ✅ 間歇/分段訓練細節完整
   - ✅ V1 用戶完全不受影響

3. **架構優化**
   - ✅ V1 和 V2 系統完全隔離
   - ✅ 未來 API 更新只需修改 Mapper
   - ✅ 可獨立棄用 V1 而不影響 V2

4. **長期維護**
   - ✅ 技術債務清零
   - ✅ 程式碼易於理解和維護
   - ✅ 新功能開發不受歷史包袱限制

---

## 附錄

### 相關文件

- [TRAINING_V2_API_INTEGRATION_GUIDE.md](../02-apis/TRAINING_V2_API_INTEGRATION_GUIDE.md) - V2 API 規格
- [IMPL-TRAINING-V2.md](./IMPL-TRAINING-V2.md) - V2 整體實施計劃
- [ARCH-002-Clean-Architecture-Design.md](../01-architecture/ARCH-002-Clean-Architecture-Design.md) - Clean Architecture 設計原則

### 檔案位置

**V2 UI Components** (新增):
```
Features/TrainingPlanV2/Presentation/Views/Components/
├── DayTimelineItemView.swift           (新)
├── SessionDetailsView.swift            (新)
├── RunActivityView.swift               (新)
├── StrengthActivityView.swift          (新)
└── CrossActivityView.swift             (新)
```

**現有 V2 Views** (更新):
```
Features/TrainingPlanV2/Presentation/Views/
├── TrainingPlanV2View.swift            (檢查)
└── Components/
    ├── WeekTimelineViewV2.swift        (更新)
    ├── TimelineItemViewV2.swift        (標記為 deprecated,未來移除)
    └── TrainingDetailsViewV2.swift     (標記為 deprecated,未來移除)
```

**兼容層** (移除):
```
Features/TrainingPlanV2/Domain/Entities/
└── TrainingSessionModels.swift         (移除 extension DayDetail 中的兼容層)
```

---

**文件版本**: v1.0
**維護者**: Development Team
**審核狀態**: 待審核
