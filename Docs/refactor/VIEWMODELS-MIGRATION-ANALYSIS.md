# ViewModels 遷移分析

**分析日期**: 2026-01-07
**目標**: 將 Havital/ViewModels/ 中的 ViewModels 遷移至對應的 Feature Modules

---

## 當前狀態

### Havital/ViewModels/ 清單 (19 個 ViewModels)

| ViewModel | 大小 | 所屬 Feature | 遷移目標 | 優先級 |
|-----------|------|-------------|---------|--------|
| AppViewModel.swift | 6.4 KB | Core | Core/Presentation/ (保留) | N/A |
| EmailLoginViewModel.swift | 1.9 KB | Authentication | Features/Authentication/Presentation/ | High |
| RegisterEmailViewModel.swift | 790 B | Authentication | Features/Authentication/Presentation/ | High |
| VerifyEmailViewModel.swift | 701 B | Authentication | Features/Authentication/Presentation/ | High |
| AddSupportingTargetViewModel.swift | 1.3 KB | Target | Features/Target/Presentation/ | High |
| EditSupportingTargetViewModel.swift | 3.1 KB | Target | Features/Target/Presentation/ | High |
| TrainingReadinessViewModel.swift | 6.9 KB | TrainingPlan | Features/TrainingPlan/Presentation/ | Medium |
| TrainingRecordViewModel.swift | 16.6 KB | TrainingPlan | Features/TrainingPlan/Presentation/ | Medium |
| WorkoutDetailViewModel.swift | 9.5 KB | Workout | Features/Workout/Presentation/ | Medium |
| WorkoutDetailViewModelV2.swift | 38.7 KB | Workout | Features/Workout/Presentation/ | High |
| WorkoutShareCardViewModel.swift | 5.8 KB | Workout | Features/Workout/Presentation/ | Low |
| BackfillPromptViewModel.swift | 2.8 KB | Workout | Features/Workout/Presentation/ | Low |
| HRVChartViewModel.swift | 10.1 KB | UserProfile/Health | Features/UserProfile/Presentation/ | Low |
| HRVChartViewModelV2.swift | 8.8 KB | UserProfile/Health | Features/UserProfile/Presentation/ | Low |
| SleepHeartRateViewModel.swift | 10.2 KB | UserProfile/Health | Features/UserProfile/Presentation/ | Low |
| VDOTChartViewModelV2.swift | 9.8 KB | TrainingPlan | Features/TrainingPlan/Presentation/ | Low |
| VDOTViewMode.swift | 8.4 KB | TrainingPlan | Features/TrainingPlan/Presentation/ | Low |
| BaseChartViewModel.swift | 1.4 KB | Core/Shared | Core/Presentation/ (保留) | N/A |
| BaseDataViewModel.swift | 4.5 KB | Core/Shared | Core/Presentation/ (保留) | N/A |

---

## 按 Feature 分類

### Features/Authentication/Presentation/ (3 個)

**高優先級** - 這些 ViewModels 應該立即遷移

| ViewModel | 用途 | 依賴 |
|-----------|------|------|
| EmailLoginViewModel | Email 登入 | AuthenticationService |
| RegisterEmailViewModel | Email 註冊 | AuthenticationService |
| VerifyEmailViewModel | Email 驗證 | AuthenticationService |

**遷移策略**:
- 創建統一的 `AuthenticationViewModel` 替代這 3 個小 ViewModels
- 使用 AuthRepository + AuthSessionRepository
- 提供 @Published 屬性給 Views 綁定

---

### Features/Target/Presentation/ (2 個)

**高優先級** - Target Feature 已有完整架構

| ViewModel | 用途 | 依賴 |
|-----------|------|------|
| AddSupportingTargetViewModel | 新增輔助目標 | TargetService (已廢棄) |
| EditSupportingTargetViewModel | 編輯輔助目標 | TargetService (已廢棄) |

**遷移策略**:
- 合併為 `TargetManagementViewModel`
- 使用 TargetRepository (已存在)
- 移除對 TargetService 的依賴

---

### Features/TrainingPlan/Presentation/ (4 個)

**中優先級** - 訓練計畫相關

| ViewModel | 用途 | 依賴 | 備註 |
|-----------|------|------|------|
| TrainingReadinessViewModel | 訓練準備度 | VDOTService, UserService | 健康數據分析 |
| TrainingRecordViewModel | 訓練記錄 | WorkoutV2Service | 歷史記錄查詢 |
| VDOTChartViewModelV2 | VDOT 圖表 | VDOTService | 數據可視化 |
| VDOTViewMode | VDOT 視圖模式 | VDOTService | 數據可視化 |

**遷移策略**:
- 使用 TrainingPlanRepository
- 使用 Infrastructure 層的 VDOTService
- 合併重複的 VDOT ViewModels

---

### Features/Workout/Presentation/ (4 個)

**高優先級** (V2) + 低優先級 (舊版)

| ViewModel | 用途 | 依賴 | 優先級 | 備註 |
|-----------|------|------|--------|------|
| WorkoutDetailViewModelV2 | 訓練詳情 V2 | WorkoutV2Service | High | 38.7 KB - 主要使用 |
| WorkoutDetailViewModel | 訓練詳情舊版 | WorkoutV2Service | Low | 9.5 KB - 待刪除 |
| WorkoutShareCardViewModel | 分享卡片 | WorkoutV2Service | Low | 社交功能 |
| BackfillPromptViewModel | 回填提示 | BackfillService | Low | 數據同步提示 |

**遷移策略**:
- **WorkoutDetailViewModelV2** 優先遷移（主要使用）
- 使用 WorkoutRepository
- 刪除舊版 WorkoutDetailViewModel
- BackfillPromptViewModel 使用 Infrastructure 層 BackfillService

---

### Features/UserProfile/Presentation/ (3 個)

**低優先級** - 健康數據可視化

| ViewModel | 用途 | 依賴 |
|-----------|------|------|
| HRVChartViewModel | HRV 圖表 | HealthDataService |
| HRVChartViewModelV2 | HRV 圖表 V2 | HealthDataService |
| SleepHeartRateViewModel | 睡眠心率 | HealthDataService |

**遷移策略**:
- 合併 HRVChartViewModel 和 V2
- 使用 UserProfileRepository
- 低優先級（可選功能）

---

### Core/Presentation/ (3 個 - 保留)

**不遷移** - 核心共用組件

| ViewModel | 用途 | 保留原因 |
|-----------|------|---------|
| AppViewModel | App 生命週期 | 全局狀態管理 |
| BaseChartViewModel | 圖表基類 | 共用基類 |
| BaseDataViewModel | 數據基類 | 共用基類 |

**策略**: 保留在 Havital/ViewModels/ 或移至 Core/Presentation/

---

## 遷移優先級

### Phase 7A: Authentication ViewModels (High Priority)

**目標**: 完成 Authentication Feature 的 Presentation 層

1. ✅ 創建 `AuthenticationViewModel` (統一 VM)
2. ✅ 整合 3 個小 ViewModels (Email Login/Register/Verify)
3. ✅ 使用 AuthRepository + AuthSessionRepository

**預計工作量**: 2-3 小時

---

### Phase 7B: Target ViewModels (High Priority)

**目標**: 完成 Target Feature 的 ViewModel 遷移

1. ✅ 創建 `TargetManagementViewModel`
2. ✅ 整合 AddSupportingTargetViewModel + EditSupportingTargetViewModel
3. ✅ 使用 TargetRepository

**預計工作量**: 1-2 小時

---

### Phase 7C: Workout ViewModels (High Priority for V2)

**目標**: 遷移主要使用的 WorkoutDetailViewModelV2

1. ✅ 遷移 `WorkoutDetailViewModelV2` 到 Features/Workout/Presentation/
2. ✅ 使用 WorkoutRepository
3. ❌ 刪除舊版 WorkoutDetailViewModel

**預計工作量**: 2-3 小時

---

### Phase 7D: TrainingPlan ViewModels (Medium Priority)

**目標**: 遷移訓練計畫相關 ViewModels

1. ⏳ 遷移 TrainingReadinessViewModel
2. ⏳ 遷移 TrainingRecordViewModel
3. ⏳ 合併 VDOTChartViewModelV2 + VDOTViewMode

**預計工作量**: 3-4 小時

---

### Phase 7E: UserProfile ViewModels (Low Priority)

**目標**: 遷移健康數據可視化 ViewModels

1. ⏳ 合併 HRVChartViewModel + HRVChartViewModelV2
2. ⏳ 遷移 SleepHeartRateViewModel
3. ⏳ 使用 UserProfileRepository

**預計工作量**: 2-3 小時

---

## 遷移策略總結

### 高優先級 (立即執行)

| Phase | ViewModels | Feature | 工作量 |
|-------|-----------|---------|--------|
| 7A | 3 個 | Authentication | 2-3 小時 |
| 7B | 2 個 | Target | 1-2 小時 |
| 7C | 1 個 (V2) | Workout | 2-3 小時 |

**總計**: 6 個 ViewModels, 5-8 小時

---

### 中優先級 (Phase 8)

| Phase | ViewModels | Feature | 工作量 |
|-------|-----------|---------|--------|
| 7D | 4 個 | TrainingPlan | 3-4 小時 |

---

### 低優先級 (Phase 9)

| Phase | ViewModels | Feature | 工作量 |
|-------|-----------|---------|--------|
| 7E | 3 個 | UserProfile | 2-3 小時 |
| 清理 | 3 個舊版 | 刪除 | 1 小時 |

---

## 預期成果

### 遷移前 (當前)

```
Havital/ViewModels/  (19 個 ViewModels)
├── Authentication (3)
├── Target (2)
├── TrainingPlan (4)
├── Workout (4)
├── UserProfile (3)
└── Core (3)

Features/
├── Authentication/Presentation/ (0 ViewModels)
├── Target/Presentation/ (1 ViewModel - TargetFeatureViewModel)
├── TrainingPlan/Presentation/ (已有部分 ViewModels)
├── Workout/Presentation/ (1 ViewModel - WorkoutListViewModel)
└── UserProfile/Presentation/ (1 ViewModel - UserProfileFeatureViewModel)
```

### 遷移後 (目標)

```
Havital/ViewModels/  (3 個共用 ViewModels)
├── AppViewModel.swift
├── BaseChartViewModel.swift
└── BaseDataViewModel.swift

Features/
├── Authentication/Presentation/
│   └── ViewModels/
│       └── AuthenticationViewModel.swift  ← 新增 (整合 3 個)
├── Target/Presentation/
│   └── ViewModels/
│       ├── TargetFeatureViewModel.swift (已有)
│       └── TargetManagementViewModel.swift  ← 新增 (整合 2 個)
├── TrainingPlan/Presentation/
│   └── ViewModels/
│       ├── TrainingPlanViewModel.swift (已有)
│       ├── TrainingReadinessViewModel.swift  ← 遷移
│       ├── TrainingRecordViewModel.swift  ← 遷移
│       └── VDOTChartViewModel.swift  ← 整合 2 個
├── Workout/Presentation/
│   └── ViewModels/
│       ├── WorkoutListViewModel.swift (已有)
│       ├── WorkoutDetailViewModel.swift  ← 遷移 V2
│       ├── WorkoutShareCardViewModel.swift  ← 遷移
│       └── BackfillPromptViewModel.swift  ← 遷移
└── UserProfile/Presentation/
    └── ViewModels/
        ├── UserProfileFeatureViewModel.swift (已有)
        ├── HRVChartViewModel.swift  ← 整合 2 個
        └── SleepHeartRateViewModel.swift  ← 遷移
```

---

## 風險評估

| 風險項目 | 等級 | 緩解措施 |
|---------|------|---------|
| Views 依賴舊 ViewModels | High | 逐步遷移，保留舊 VM 作為 deprecated bridge |
| Build 失敗 | Medium | 每個 Phase 後執行 build 驗證 |
| 功能破壞 | Medium | 保持 VM 介面一致，只改變實作 |
| 工作量過大 | Low | 分階段執行，高優先級先行 |

---

## 下一步

### 立即執行 (Phase 7A)

1. 創建 `AuthenticationViewModel` 在 Features/Authentication/Presentation/ViewModels/
2. 整合 EmailLoginViewModel, RegisterEmailViewModel, VerifyEmailViewModel
3. 使用 AuthRepository + AuthSessionRepository + OnboardingRepository
4. 提供 @Published 屬性給 Views 綁定
5. 標記舊 ViewModels 為 @deprecated

---

**維護人**: Clean Architecture Migration Team
**最後更新**: 2026-01-07 14:30
