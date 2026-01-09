# Phase 9: ViewModels 整合與優化 - 分析報告

**分析日期**: 2026-01-07 17:45
**當前狀態**: 分析完成，待執行優化

---

## 📊 ViewModel 統計

### 總覽

| 類別 | 數量 | 百分比 |
|------|------|--------|
| Core ViewModels | 3 | 10% |
| Feature ViewModels | 27 | 90% |
| **總計** | **30** | **100%** |

### 按 Feature 分類

| Feature | ViewModel 數量 | 檔案 |
|---------|---------------|------|
| **Authentication** | 6 | AuthenticationViewModel, LoginViewModel, AuthCoordinatorViewModel, EmailLoginViewModel, RegisterEmailViewModel, VerifyEmailViewModel |
| **Onboarding** | 1 | OnboardingFeatureViewModel |
| **Target** | 4 | TargetFeatureViewModel, BaseSupportingTargetViewModel, AddSupportingTargetViewModel, EditSupportingTargetViewModel |
| **TrainingPlan** | 7 | TrainingPlanViewModel, WeeklyPlanViewModel, WeeklySummaryViewModel, EditScheduleViewModel, TrainingReadinessViewModel, TrainingRecordViewModel, VDOTChartViewModel (⚠️ 命名錯誤) |
| **Workout** | 5 | WorkoutListViewModel, WorkoutDetailViewModel, WorkoutDetailViewModelV2, WorkoutShareCardViewModel, BackfillPromptViewModel |
| **UserProfile** | 4 | UserProfileFeatureViewModel, HRVChartViewModel, HRVChartViewModelV2 (⚠️ 未使用), SleepHeartRateViewModel |
| **Core** | 3 | AppViewModel, BaseChartViewModel, BaseDataViewModel |

---

## 🔍 發現的問題

### 問題 1: 嚴重命名錯誤 ⚠️

**檔案**: `Features/TrainingPlan/Presentation/ViewModels/VDOTViewMode.swift`

**問題**:
- 檔案名稱: `VDOTViewMode.swift` (錯誤)
- 實際類別: `class VDOTChartViewModel`
- 使用情況: 被 `Views/Components/VDOTChartView.swift` 使用

**影響**:
- 檔案名與內容不符，嚴重違反命名規範
- 導致維護困難，無法通過檔案名找到對應類別

**修復方案**:
```bash
# 重命名檔案
mv Features/TrainingPlan/Presentation/ViewModels/VDOTViewMode.swift \
   Features/TrainingPlan/Presentation/ViewModels/VDOTChartViewModel.swift
```

---

### 問題 2: 冗餘 V2 版本 - HRVChartViewModelV2

**檔案**: `Features/UserProfile/Presentation/ViewModels/HRVChartViewModelV2.swift`

**問題**:
- V2 版本存在但**完全未被使用**
- 舊版 `HRVChartViewModel` 仍在使用中 (`Views/Health/HRVTrendChartView.swift`)
- V2 是死代碼 (Dead Code)

**分析**:
```
HRVChartViewModel ✅ (使用中)
  └── Views/Health/HRVTrendChartView.swift

HRVChartViewModelV2 ❌ (未使用)
  └── 無任何 View 引用
```

**修復方案**:
```bash
# 刪除未使用的 V2 版本
rm Features/UserProfile/Presentation/ViewModels/HRVChartViewModelV2.swift
```

---

### 問題 3: 冗餘 V2 版本 - VDOTChartViewModelV2

**檔案**: `Features/TrainingPlan/Presentation/ViewModels/VDOTChartViewModelV2.swift`

**問題**:
- V2 版本存在但**完全未被使用**
- 舊版 `VDOTChartViewModel` (在錯誤命名的 VDOTViewMode.swift 中) 仍在使用
- V2 是死代碼 (Dead Code)

**分析**:
```
VDOTChartViewModel ✅ (使用中)
  └── Views/Components/VDOTChartView.swift
  └── 定義在 VDOTViewMode.swift (⚠️ 檔案命名錯誤)

VDOTChartViewModelV2 ❌ (未使用)
  └── 無任何 View 引用
```

**修復方案**:
```bash
# 刪除未使用的 V2 版本
rm Features/TrainingPlan/Presentation/ViewModels/VDOTChartViewModelV2.swift
```

---

### 問題 4: WorkoutDetailViewModel 雙版本並存

**檔案**:
- `Features/Workout/Presentation/ViewModels/WorkoutDetailViewModel.swift`
- `Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift`

**使用情況**:
- `WorkoutDetailViewModelV2` ✅ 被 `Views/Training/WorkoutDetailViewV2.swift` 使用
- `WorkoutDetailViewModel` ⚠️ 需要檢查使用情況

**分析待執行**:
```bash
# 檢查 WorkoutDetailViewModel 是否還在使用
grep -r "WorkoutDetailViewModel[^V]" Havital/Views
```

**可能結果**:
1. 如果未使用 → 刪除 WorkoutDetailViewModel.swift
2. 如果使用中 → 保留雙版本，但需文檔說明差異

---

## 📋 命名規範分析

### 當前命名模式

**Feature 主 ViewModel (FeatureViewModel)**:
- ✅ `TargetFeatureViewModel` - Target Feature 主 VM
- ✅ `UserProfileFeatureViewModel` - UserProfile Feature 主 VM
- ✅ `OnboardingFeatureViewModel` - Onboarding Feature 主 VM

**功能 ViewModel (FunctionalViewModel)**:
- ✅ `TrainingPlanViewModel` - 訓練計畫主 VM
- ✅ `WorkoutListViewModel` - 訓練記錄列表 VM
- ✅ `WeeklyPlanViewModel` - 週計畫 VM
- ✅ `EditScheduleViewModel` - 編輯排程 VM

**不一致問題**:
- `TrainingPlanViewModel` 應該是 Feature 主 VM，但未使用 `FeatureViewModel` 後綴
- `WorkoutListViewModel` 也是 Feature 主 VM，但未使用 `FeatureViewModel` 後綴

### 建議命名規範

| ViewModel 類型 | 命名規範 | 範例 |
|---------------|----------|------|
| **Feature 主 ViewModel** | `{Feature}FeatureViewModel` | `TrainingPlanFeatureViewModel`, `WorkoutFeatureViewModel` |
| **子功能 ViewModel** | `{Function}ViewModel` | `WeeklyPlanViewModel`, `EditScheduleViewModel` |
| **圖表 ViewModel** | `{Chart}ViewModel` | `VDOTChartViewModel`, `HRVChartViewModel` |
| **協調器 ViewModel** | `{Feature}CoordinatorViewModel` | `AuthCoordinatorViewModel` |

---

## 🎯 優化建議

### 第一優先級：修復嚴重錯誤

1. ✅ **重命名 VDOTViewMode.swift**
   - 影響: 高 (命名錯誤)
   - 難度: 低
   - 時間: 5 分鐘

2. ✅ **刪除 HRVChartViewModelV2.swift**
   - 影響: 中 (死代碼)
   - 難度: 低
   - 時間: 2 分鐘

3. ✅ **刪除 VDOTChartViewModelV2.swift**
   - 影響: 中 (死代碼)
   - 難度: 低
   - 時間: 2 分鐘

### 第二優先級：清理冗餘

4. ⏳ **檢查並處理 WorkoutDetailViewModel**
   - 影響: 中
   - 難度: 低
   - 時間: 10 分鐘

### 第三優先級：統一命名規範 (可選)

5. ⏳ **重命名 TrainingPlanViewModel → TrainingPlanFeatureViewModel**
   - 影響: 低 (重構)
   - 難度: 中 (需更新所有引用)
   - 時間: 30 分鐘

6. ⏳ **重命名 WorkoutListViewModel → WorkoutFeatureViewModel**
   - 影響: 低 (重構)
   - 難度: 中
   - 時間: 30 分鐘

---

## 📈 優化效益預估

| 指標 | Before Phase 9 | After Phase 9 (目標) | 改善 |
|------|----------------|---------------------|------|
| ViewModel 總數 | 30 | 27-28 | -7% to -10% |
| 命名錯誤檔案 | 1 | 0 | -100% |
| 未使用 ViewModels | 2-3 | 0 | -100% |
| 命名規範合規率 | ~70% | 90%+ | +20% |
| 死代碼 (Dead Code) | 2 個檔案 | 0 | -100% |

---

## 🚀 Phase 9 執行計劃

### Phase 9A: 修復嚴重錯誤 (立即執行)

**預計時間**: 15 分鐘

1. 重命名 VDOTViewMode.swift → VDOTChartViewModel.swift
2. 更新 Xcode project.pbxproj 引用
3. 刪除 HRVChartViewModelV2.swift
4. 刪除 VDOTChartViewModelV2.swift
5. Build 驗證

### Phase 9B: 清理冗餘代碼 (立即執行)

**預計時間**: 10 分鐘

1. 檢查 WorkoutDetailViewModel 使用情況
2. 如果未使用，刪除 WorkoutDetailViewModel.swift
3. Build 驗證

### Phase 9C: 統一命名規範 (可選，延後執行)

**預計時間**: 1-2 小時

1. 重命名 Feature 主 ViewModels
2. 更新所有 View 引用
3. 更新文檔
4. 全面 Build 驗證

---

## 🔍 檔案清單

### 需要修復的檔案

```
⚠️ 命名錯誤:
Features/TrainingPlan/Presentation/ViewModels/VDOTViewMode.swift
  → 應改名為: VDOTChartViewModel.swift

❌ 未使用 (待刪除):
Features/UserProfile/Presentation/ViewModels/HRVChartViewModelV2.swift
Features/TrainingPlan/Presentation/ViewModels/VDOTChartViewModelV2.swift

⏳ 待檢查:
Features/Workout/Presentation/ViewModels/WorkoutDetailViewModel.swift
```

### 使用中的檔案 (保留)

```
✅ Core ViewModels (3):
Core/Presentation/ViewModels/AppViewModel.swift
Core/Presentation/ViewModels/BaseChartViewModel.swift
Core/Presentation/ViewModels/BaseDataViewModel.swift

✅ Authentication ViewModels (6):
Features/Authentication/Presentation/ViewModels/AuthenticationViewModel.swift
Features/Authentication/Presentation/ViewModels/LoginViewModel.swift
Features/Authentication/Presentation/ViewModels/AuthCoordinatorViewModel.swift
Features/Authentication/Presentation/ViewModels/EmailLoginViewModel.swift
Features/Authentication/Presentation/ViewModels/RegisterEmailViewModel.swift
Features/Authentication/Presentation/ViewModels/VerifyEmailViewModel.swift

✅ Target ViewModels (4):
Features/Target/Presentation/ViewModels/TargetFeatureViewModel.swift
Features/Target/Presentation/ViewModels/BaseSupportingTargetViewModel.swift
Features/Target/Presentation/ViewModels/AddSupportingTargetViewModel.swift
Features/Target/Presentation/ViewModels/EditSupportingTargetViewModel.swift

✅ TrainingPlan ViewModels (6 after cleanup):
Features/TrainingPlan/Presentation/ViewModels/TrainingPlanViewModel.swift
Features/TrainingPlan/Presentation/ViewModels/WeeklyPlanViewModel.swift
Features/TrainingPlan/Presentation/ViewModels/WeeklySummaryViewModel.swift
Features/TrainingPlan/Presentation/ViewModels/EditScheduleViewModel.swift
Features/TrainingPlan/Presentation/ViewModels/TrainingReadinessViewModel.swift
Features/TrainingPlan/Presentation/ViewModels/TrainingRecordViewModel.swift
Features/TrainingPlan/Presentation/ViewModels/VDOTChartViewModel.swift (重命名後)

✅ Workout ViewModels (4 or 5):
Features/Workout/Presentation/ViewModels/WorkoutListViewModel.swift
Features/Workout/Presentation/ViewModels/WorkoutDetailViewModelV2.swift
Features/Workout/Presentation/ViewModels/WorkoutShareCardViewModel.swift
Features/Workout/Presentation/ViewModels/BackfillPromptViewModel.swift
Features/Workout/Presentation/ViewModels/WorkoutDetailViewModel.swift (待確認)

✅ UserProfile ViewModels (3 after cleanup):
Features/UserProfile/Presentation/ViewModels/UserProfileFeatureViewModel.swift
Features/UserProfile/Presentation/ViewModels/HRVChartViewModel.swift
Features/UserProfile/Presentation/ViewModels/SleepHeartRateViewModel.swift

✅ Onboarding ViewModels (1):
Features/Onboarding/Presentation/ViewModels/OnboardingFeatureViewModel.swift
```

---

## 📝 執行檢查清單

### Phase 9A: 修復嚴重錯誤
- [ ] 重命名 VDOTViewMode.swift → VDOTChartViewModel.swift
- [ ] 刪除 HRVChartViewModelV2.swift
- [ ] 刪除 VDOTChartViewModelV2.swift
- [ ] Build 驗證

### Phase 9B: 清理冗餘代碼
- [ ] 檢查 WorkoutDetailViewModel 使用情況
- [ ] 刪除未使用的 ViewModels
- [ ] Build 驗證

### Phase 9C: 文檔更新
- [ ] 更新 PHASE-6-7-8-PROGRESS-SUMMARY.md
- [ ] 創建 PHASE-9-COMPLETION-REPORT.md
- [ ] 更新 ViewModel 計數

---

**分析狀態**: ✅ 完成
**下一步**: 執行 Phase 9A - 修復嚴重錯誤
**預計完成時間**: 25 分鐘

**維護人**: Clean Architecture Migration Team
**最後更新**: 2026-01-07 17:45
