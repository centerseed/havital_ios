# FRD: Training V2 架構整合計劃

**文件版本**: 1.0
**建立日期**: 2025-01-17
**狀態**: Draft

---

## 1. 概述

### 1.1 背景

Training V2 API 引入了全新的訓練計畫架構，支援多種目標類型（race_run, beginner, maintenance）和方法論（paceriz, complete_10k 等）。V1 和 V2 架構不相容，需要實現新舊並存策略。

### 1.2 目標

- 在 Clean Architecture 下組織 V2 程式碼
- 實現 V1/V2 並存，確保現有用戶不受影響
- 建立可靠的版本識別機制
- 新用戶 Onboarding 時自動使用 V2

---

## 2. V2 程式碼檔案結構

### 2.1 目錄結構設計

```
Havital/Features/
├── TrainingPlan/                    # V1 架構（保持現有）
│   ├── Domain/
│   ├── Data/
│   ├── Infrastructure/
│   └── Presentation/
│
└── TrainingPlanV2/                  # V2 架構（全新）
    ├── Domain/
    │   ├── Entities/
    │   │   ├── PlanOverviewV2.swift
    │   │   ├── WeeklyPlanV2.swift
    │   │   ├── WeeklySummaryV2.swift
    │   │   ├── TrainingStageV2.swift
    │   │   ├── MilestoneV2.swift
    │   │   └── MethodologyOverview.swift
    │   ├── Repositories/
    │   │   ├── TrainingPlanV2Repository.swift
    │   │   └── WeeklySummaryV2Repository.swift
    │   ├── UseCases/
    │   │   ├── CreateOverviewV2UseCase.swift
    │   │   ├── GenerateWeeklyPlanV2UseCase.swift
    │   │   ├── CreateWeeklySummaryV2UseCase.swift
    │   │   └── ApplyRecommendationsUseCase.swift
    │   └── Errors/
    │       └── TrainingPlanV2Error.swift
    │
    ├── Data/
    │   ├── DTOs/
    │   │   ├── PlanOverviewV2DTO.swift
    │   │   ├── WeeklyPlanV2DTO.swift
    │   │   ├── WeeklySummaryV2DTO.swift
    │   │   ├── ReadinessSummaryDTO.swift
    │   │   └── CustomizationRecommendationDTO.swift
    │   ├── DataSources/
    │   │   ├── TrainingPlanV2RemoteDataSource.swift
    │   │   └── TrainingPlanV2LocalDataSource.swift
    │   ├── Mappers/
    │   │   ├── PlanOverviewV2Mapper.swift
    │   │   ├── WeeklyPlanV2Mapper.swift
    │   │   └── WeeklySummaryV2Mapper.swift
    │   └── Repositories/
    │       ├── TrainingPlanV2RepositoryImpl.swift
    │       └── WeeklySummaryV2RepositoryImpl.swift
    │
    └── Presentation/
        ├── ViewModels/
        │   ├── TrainingPlanV2ViewModel.swift
        │   ├── WeeklyPlanV2ViewModel.swift
        │   ├── WeeklySummaryV2ViewModel.swift
        │   └── CustomizationViewModel.swift
        └── ViewStates/
            └── TrainingPlanV2ViewState.swift
```

### 2.2 核心模組說明

| 模組 | 職責 |
|------|------|
| **PlanOverviewV2** | 計畫概覽實體，包含 target_type、methodology_id、訓練階段等 |
| **WeeklyPlanV2** | 週課表實體，完整的 LLM 生成課表數據 |
| **WeeklySummaryV2** | 週摘要實體，包含 Readiness、Capability Progression、建議等 |
| **CustomizationRecommendation** | 客製化建議實體，支援 5 種調整類型 |

### 2.3 與現有架構的隔離原則

- V1 和 V2 模組完全獨立，無相互依賴
- 共用 Core Layer（HTTPClient、Logger、CacheEventBus）
- 共用部分 Infrastructure（WeekDateService）
- 快取 Key 使用不同前綴區分

---

## 3. V1/V2 並存策略

### 3.1 架構分層

```
┌─────────────────────────────────────────────────┐
│              Presentation Layer                  │
│  ┌─────────────────┐   ┌─────────────────────┐  │
│  │ TrainingPlanView │   │ TrainingPlanV2View │  │
│  │     (V1)        │   │       (V2)          │  │
│  └─────────────────┘   └─────────────────────┘  │
└─────────────────────────────────────────────────┘
                        ▲
                        │ 依賴 TrainingVersionRouter
                        │
┌─────────────────────────────────────────────────┐
│           TrainingVersionRouter                  │
│   - 判斷用戶訓練架構版本                          │
│   - 路由到正確的 ViewModel/Repository             │
└─────────────────────────────────────────────────┘
                        ▲
            ┌───────────┴───────────┐
            ▼                       ▼
┌───────────────────┐   ┌───────────────────────┐
│  TrainingPlanRepo │   │  TrainingPlanV2Repo   │
│      (V1)         │   │        (V2)           │
└───────────────────┘   └───────────────────────┘
```

### 3.2 Router 設計

**TrainingVersionRouter** 負責：
1. 讀取用戶的訓練架構版本
2. 提供正確的 Repository 和 ViewModel 工廠
3. 在 View 層路由到正確的 UI 組件

### 3.3 共存原則

| 面向 | V1 | V2 |
|------|----|----|
| API 端點前綴 | `/plan/race_run/` | `/v2/plan/` |
| 快取 Key 前綴 | `training_plan_v1_` | `training_plan_v2_` |
| Firestore 路徑 | `users/{uid}/training_plans/` | `users/{uid}/plan_overviews_v2/` |
| 事件名稱 | `dataChanged.trainingPlan` | `dataChanged.trainingPlanV2` |

---

## 4. 用戶版本識別機制

### 4.1 版本識別策略

**核心原則**: 利用現有 User 資料同步機制，無需額外 API

```
用戶登入 → 現有 User Sync API → User 資料包含 training_version → 本地判斷
```

### 4.2 User 資料擴充（後端）

在現有 User 文件中新增 `training_version` 欄位：

**Firestore 路徑**: `users/{uid}`

**新增欄位**:
```json
{
  "training_version": "v2",    // "v1" | "v2" | null
  "active_overview_id": "overview_xyz_20250101"  // V2 專用（可選）
}
```

**欄位更新時機（後端邏輯）**:
- 當 `POST /v2/plan/overview` 成功建立時 → 設定 `training_version = "v2"`
- 現有 V1 用戶保持 `training_version = "v1"` 或 `null`

### 4.3 App 端判斷邏輯

```
User Sync 回傳的 training_version 值：
├── "v2"  → V2 用戶，使用 V2 架構
├── "v1"  → V1 用戶，使用 V1 架構
└── null  → 判斷是否有 V1 計畫
            ├── 有 → V1 用戶
            └── 無 → 新用戶，待 Onboarding
```

### 4.4 登出登入後的版本保持

**流程**:
```
用戶登出 → 清除本地快取
用戶登入 → User Sync API 回傳包含 training_version → 自動恢復正確版本
```

**優點**:
- 無額外 API 調用
- 無額外 Firestore 讀取（版本資訊已在 User 文件中）
- 與現有 User Sync 流程整合

### 4.5 Fallback 機制（舊用戶相容）

若 `training_version` 為 `null`（舊用戶尚未有此欄位）：
1. 嘗試呼叫 `GET /plan/race_run/overview`
2. 若成功 → V1 用戶（後端可順便補上 `training_version = "v1"`）
3. 若 404 → 新用戶，進入 Onboarding

---

## 5. Onboarding 與版本升級

### 5.1 新用戶 Onboarding（直接 V2）

**流程**:
```
新用戶註冊 → Onboarding 流程 →
呼叫 POST /v2/plan/overview →
呼叫 POST /v2/plan/weekly →
設定 training_version = "v2" →
進入主畫面
```

### 5.2 現有 V1 用戶（保持 V1）

**流程**:
```
V1 用戶登入 →
GET /user/training-version 回傳 "v1" →
使用 V1 相關 Repository/ViewModel →
顯示 V1 TrainingPlanView
```

### 5.3 重新 Onboarding（升級至 V2）

**流程**:
```
V1 用戶點擊「重新設定目標」 →
進入 Onboarding 流程 →
呼叫 POST /v2/plan/overview →
呼叫 POST /v2/plan/weekly →
設定 training_version = "v2" →
返回主畫面（使用 V2）
```

**關鍵決策**: 重新 Onboarding = 升級至 V2（不可逆）

### 5.4 CompleteOnboardingV2UseCase

```swift
// Domain Layer
final class CompleteOnboardingV2UseCase {
    func execute(input: Input) async throws -> Output {
        // 1. 建立 V2 Overview
        let overview = try await trainingPlanV2Repository.createOverview(input)

        // 2. 產生第一週課表
        let weeklyPlan = try await trainingPlanV2Repository.createWeeklyPlan(
            weekOfTraining: 1
        )

        // 3. 更新版本標記
        await updateTrainingVersion(to: .v2)

        // 4. 發布完成事件
        CacheEventBus.shared.publish(.onboardingCompletedV2)

        return Output(overview: overview, weeklyPlan: weeklyPlan)
    }
}
```

---

## 6. 遷移考量

### 6.1 不提供自動遷移

**原因**:
- V1/V2 資料結構差異大
- 用戶訓練階段、里程碑無法直接對應
- 強制遷移可能導致用戶體驗混亂

**策略**: 用戶在完成當前訓練計畫後，下次設定新目標時自動使用 V2

### 6.2 V1 維護策略

- V1 程式碼保持運作但不新增功能
- Bug 修復仍會進行
- 預計在 80% 用戶遷移至 V2 後考慮 V1 棄用計畫

---

## 7. 實作優先順序

### Phase 1: 基礎架構
1. 建立 `TrainingPlanV2/` 目錄結構
2. 實作 V2 Domain Entities
3. 實作 V2 DTOs 和 Mappers
4. 實作 `TrainingVersionRouter`

### Phase 2: 資料層
1. 實作 `TrainingPlanV2RemoteDataSource`
2. 實作 `TrainingPlanV2LocalDataSource`
3. 實作 `TrainingPlanV2RepositoryImpl`

### Phase 3: 表現層
1. 實作 V2 ViewModels
2. 修改 Onboarding 流程支援 V2
3. 建立 V2 Views（或複用現有 Views）

### Phase 4: 整合與測試
1. 整合 TrainingVersionRouter 到主流程
2. 端對端測試 V1/V2 切換
3. 測試登出登入後版本保持

---

## 8. 風險與緩解措施

| 風險 | 影響 | 緩解措施 |
|------|------|----------|
| 後端 V2 API 不穩定 | 新用戶無法完成 Onboarding | 建立 Fallback 機制，暫時使用 V1 |
| 版本判斷錯誤 | 用戶看到錯誤的訓練資料 | 多重驗證機制 + 強制刷新選項 |
| V1/V2 快取衝突 | 資料顯示異常 | 完全隔離的快取 Key 前綴 |
| 重新 Onboarding 資料丟失 | 用戶訓練歷史消失 | 明確提示 + 歷史資料保留（只是不再用於計畫生成）|

---

## 9. 成功指標

- [ ] 新用戶 100% 使用 V2 架構
- [ ] V1 用戶登入後正確顯示 V1 內容
- [ ] 登出登入後版本正確保持
- [ ] 重新 Onboarding 成功升級至 V2
- [ ] 無 V1/V2 快取衝突錯誤

---

**文件維護者**: iOS Team
**下次審核日期**: TBD
