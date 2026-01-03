# REFACTOR-001: 總體重構路線圖

**版本**: 1.0
**最後更新**: 2026-01-03
**狀態**: 🔄 進行中

---

## 概述

本文檔提供 Paceriz iOS App Clean Architecture 重構的完整路線圖，包括所有 Features 的優先級排序、依賴關係、時間規劃和資源分配。

---

## Feature 依賴關係圖

### 依賴層級結構

```
Level 0: Core Infrastructure (已完成 ✅)
├── DependencyContainer
├── UnifiedCacheManager
├── HTTPClient
└── 基礎 Utils

Level 1: 認證與用戶 (Week 3-4)
├── Authentication Feature (Week 3) ⚠️
│   └── 所有需要用戶認證的功能依賴此
└── UserProfile Feature (Week 4) 🔥
    └── 用戶基本資料管理

Level 2: 訓練數據核心 (Week 3-5)
├── Workout Feature (Week 3) 🔥 [並行]
│   ├── UnifiedWorkoutManager → WorkoutRepository
│   ├── WorkoutV2Service → RemoteDataSource
│   └── 本地緩存 → LocalDataSource
│
└── VDOT Feature (Week 5) ⚠️
    └── 依賴 Workout 數據計算 VDOT

Level 3: 訓練計劃 (已完成 ✅)
└── TrainingPlan Feature ✅
    ├── 依賴 Workout 數據
    ├── 依賴 UserProfile 數據
    └── 參考實現 (ARCH-005)

Level 4: 健康分析 (Week 6)
└── TrainingReadiness Feature (Week 6) ⚠️
    ├── 依賴 Workout 數據
    ├── 依賴 HealthKit 數據
    └── 依賴 VDOT 計算

Level 5: 第三方整合 (Week 7-8)
├── Garmin Integration (Week 7) ℹ️
│   └── 依賴 Workout 數據同步
└── Strava Integration (Week 8) ℹ️
    └── 依賴 Workout 數據同步
```

---

## 重構優先級矩陣

### 優先級評分標準

| 因素 | 權重 | 評分範圍 |
|-----|------|---------|
| **業務價值** | 30% | 1-5 分 |
| **技術債務** | 25% | 1-5 分 |
| **依賴影響** | 20% | 1-5 分 |
| **重構複雜度** (反向) | 15% | 1-5 分 |
| **使用頻率** | 10% | 1-5 分 |

### Features 優先級評分

| Feature | 業務價值 | 技術債務 | 依賴影響 | 複雜度 | 使用頻率 | **總分** | **優先級** |
|---------|---------|---------|---------|-------|---------|---------|-----------|
| **Workout** | 5 | 5 | 5 | 4 | 5 | **4.65** | 🔥 最高 |
| **UserProfile** | 5 | 4 | 4 | 2 | 5 | **4.25** | 🔥 高 |
| **TrainingPlan** | 5 | 5 | 3 | 4 | 4 | **4.30** | ✅ 已完成 |
| **VDOT** | 3 | 3 | 2 | 2 | 3 | **2.75** | ⚠️ 中 |
| **TrainingReadiness** | 4 | 3 | 2 | 3 | 3 | **3.10** | ⚠️ 中 |
| **Authentication** | 4 | 2 | 5 | 2 | 5 | **3.75** | ⚠️ 中 |
| **Garmin Integration** | 2 | 2 | 1 | 2 | 2 | **1.90** | ℹ️ 低 |
| **Strava Integration** | 2 | 2 | 1 | 2 | 2 | **1.90** | ℹ️ 低 |

---

## 詳細時間規劃

### Phase 1: 基礎設施 (已完成 ✅)

**時間**: Week 1-2 (已完成)
**狀態**: ✅ 100% 完成

#### Week 1: 架構分析與設計
- [x] Day 1-2: 現狀分析 (ARCH-001)
- [x] Day 3-4: 目標架構設計 (ARCH-002)
- [x] Day 5: 遷移路線圖 (ARCH-003)

#### Week 2: 參考實現
- [x] Day 1-2: 資料流設計 (ARCH-004)
- [x] Day 3-5: TrainingPlan 參考實現 (ARCH-005)
  - [x] Repository Pattern 實作
  - [x] Use Cases 實作
  - [x] ViewModel 重構
  - [x] DI 整合

---

### Phase 2: 核心 Features (進行中 🔄)

**時間**: Week 3-6 (預計 4 週)
**狀態**: 🔄 進行中

#### Week 3: Workout Feature 🔥

**預計時間**: 5 個工作日
**複雜度**: ⭐⭐⭐⭐ (高)

##### Day 1: Domain Layer
- [ ] 創建 `WorkoutRepository.swift` 協議
  - 定義 CRUD 操作
  - 定義查詢方法（按日期範圍、類型篩選）
  - 定義同步方法（HealthKit, Garmin, Strava）
- [ ] 創建 `WorkoutError.swift` 錯誤類型
- [ ] 創建基礎 Use Cases:
  - `GetWorkoutsInRangeUseCase`
  - `SyncWorkoutFromHealthKitUseCase`

##### Day 2: Data Layer (Repository Implementation)
- [ ] 創建 `WorkoutRepositoryImpl.swift`
  - 實現雙軌緩存策略
  - 整合 `UnifiedWorkoutManager`
- [ ] 創建 `WorkoutRemoteDataSource.swift`
  - 封裝 `WorkoutV2Service` API 調用
- [ ] 創建 `WorkoutLocalDataSource.swift`
  - 整合現有緩存機制

##### Day 3: Use Cases Implementation
- [ ] 實現 `GetWorkoutsInRangeUseCase`
  - 業務邏輯：過濾、排序、分組
- [ ] 實現 `SyncWorkoutFromHealthKitUseCase`
  - 整合 HealthKit 同步邏輯
- [ ] 實現 `CalculateWorkoutStatsUseCase`
  - 距離、配速、心率計算

##### Day 4: ViewModel 重構
- [ ] 重構 `WorkoutDetailViewModel`
  - 注入 Use Cases
  - 移除對 Service 的直接依賴
- [ ] 更新 DI 註冊
  - `registerWorkoutModule()`
  - Use Case 工廠方法

##### Day 5: 測試與驗證
- [ ] 單元測試 (Use Cases)
- [ ] 整合測試 (Repository)
- [ ] 回歸測試 (UI 功能)
- [ ] 更新文檔

#### Week 4: UserProfile Feature 🔥

**預計時間**: 3 個工作日
**複雜度**: ⭐⭐ (中)

##### Day 1: Domain & Data Layer
- [ ] 創建 `UserProfileRepository.swift` 協議
- [ ] 創建 `UserProfileRepositoryImpl.swift`
  - 整合 `UserManager` 和 `UserService`
- [ ] 創建 DataSources
  - `UserProfileRemoteDataSource`
  - `UserProfileLocalDataSource`

##### Day 2: Use Cases & ViewModel
- [ ] 創建 Use Cases:
  - `GetUserProfileUseCase`
  - `UpdateUserProfileUseCase`
  - `SyncUserPreferencesUseCase`
- [ ] 重構 `UserProfileViewModel`
  - 注入 Use Cases
  - 統一狀態管理

##### Day 3: 測試與驗證
- [ ] 單元測試
- [ ] 整合測試
- [ ] 更新文檔

#### Week 5: VDOT Feature ⚠️

**預計時間**: 3 個工作日
**複雜度**: ⭐⭐⭐ (中高)

##### Day 1: Domain & Data Layer
- [ ] 創建 `VDOTRepository.swift` 協議
- [ ] 創建 `VDOTRepositoryImpl.swift`
  - 整合 `VDOTManager` 和 `VDOTService`
- [ ] 創建 DataSources

##### Day 2: Use Cases & ViewModel
- [ ] 創建 Use Cases:
  - `CalculateVDOTUseCase`
  - `GetVDOTHistoryUseCase`
  - `PredictRaceTimeUseCase`
- [ ] 重構 ViewModel

##### Day 3: 測試與驗證
- [ ] 單元測試
- [ ] 整合測試
- [ ] 更新文檔

#### Week 6: TrainingReadiness Feature ⚠️

**預計時間**: 4 個工作日
**複雜度**: ⭐⭐⭐⭐ (高)

##### Day 1-2: Domain & Data Layer
- [ ] 創建 `TrainingReadinessRepository.swift` 協議
- [ ] 創建 `TrainingReadinessRepositoryImpl.swift`
  - 整合多個數據源（HRV, Sleep, Workout）
- [ ] 創建 DataSources
  - `HealthDataRemoteDataSource`
  - `HealthDataLocalDataSource`

##### Day 3: Use Cases
- [ ] 創建 Use Cases:
  - `CalculateReadinessScoreUseCase`
  - `GetHRVTrendUseCase`
  - `GetSleepQualityUseCase`

##### Day 4: ViewModel & 測試
- [ ] 重構 `TrainingReadinessViewModel`
- [ ] 測試與驗證
- [ ] 更新文檔

---

### Phase 3: 認證與整合 (規劃中 📋)

**時間**: Week 7-8 (預計 2 週)
**狀態**: 📋 規劃中

#### Week 7: Authentication Feature ⚠️

**預計時間**: 3 個工作日
**複雜度**: ⭐⭐ (中)

##### Day 1: Domain & Data Layer
- [ ] 創建 `AuthenticationRepository.swift` 協議
- [ ] 創建 `AuthenticationRepositoryImpl.swift`
  - 整合 `AuthenticationService`
  - 安全性考量（Token 管理）

##### Day 2: Use Cases & ViewModel
- [ ] 創建 Use Cases:
  - `LoginWithEmailUseCase`
  - `RegisterUserUseCase`
  - `RefreshTokenUseCase`
- [ ] 重構 ViewModels:
  - `EmailLoginViewModel`
  - `RegisterEmailViewModel`

##### Day 3: 測試與驗證
- [ ] 單元測試
- [ ] 安全性測試
- [ ] 更新文檔

#### Week 8: Integration Features ℹ️

**預計時間**: 4 個工作日
**複雜度**: ⭐⭐⭐ (中高)

##### Day 1-2: Garmin Integration
- [ ] 創建 `GarminRepository.swift`
- [ ] 實現 Garmin 同步 Use Cases
- [ ] 重構相關 ViewModels

##### Day 3-4: Strava Integration
- [ ] 創建 `StravaRepository.swift`
- [ ] 實現 Strava 同步 Use Cases
- [ ] 重構相關 ViewModels

---

### Phase 4: 優化與完善 (規劃中 📋)

**時間**: Week 9-10 (預計 2 週)
**狀態**: 📋 規劃中

#### Week 9: 錯誤處理與性能優化

##### Day 1-2: 統一錯誤處理
- [ ] 創建 `DomainError` 統一錯誤類型
- [ ] 所有 Repository 返回 `Result<T, DomainError>`
- [ ] 統一錯誤 UI 顯示

##### Day 3-4: 性能優化
- [ ] 緩存策略優化
- [ ] 並發處理優化
- [ ] 記憶體使用優化

##### Day 5: 代碼品質
- [ ] 移除所有編譯警告
- [ ] 循環依賴檢查與修正
- [ ] 代碼風格統一

#### Week 10: 測試與文檔

##### Day 1-3: 完整回歸測試
- [ ] 所有 Features 功能測試
- [ ] 端到端測試
- [ ] 性能測試

##### Day 4-5: 文檔與審查
- [ ] 更新所有架構文檔
- [ ] 創建遷移指南
- [ ] 最終代碼審查

---

## 里程碑與交付物

### Milestone 1: 核心數據層重構完成 (Week 6 結束)
**交付物**:
- [x] TrainingPlan Feature (已完成)
- [ ] Workout Feature
- [ ] UserProfile Feature
- [ ] VDOT Feature
- [ ] TrainingReadiness Feature
- [ ] 測試覆蓋率 > 80%

**驗收標準**:
- 所有核心 Features 遵循 Clean Architecture
- Repository Pattern 覆蓋率 100%
- Use Case 封裝率 > 70%
- 無功能回歸

### Milestone 2: 認證與整合完成 (Week 8 結束)
**交付物**:
- [ ] Authentication Feature
- [ ] Garmin Integration
- [ ] Strava Integration
- [ ] 安全性審查報告

**驗收標準**:
- 所有第三方整合正常工作
- 認證流程安全可靠
- Token 管理符合最佳實踐

### Milestone 3: 重構完成 (Week 10 結束)
**交付物**:
- [ ] 100% Clean Architecture 符合度
- [ ] 完整測試套件 (覆蓋率 > 85%)
- [ ] 架構文檔集
- [ ] 遷移指南

**驗收標準**:
- 編譯警告 = 0
- 循環依賴 = 0
- 所有測試通過
- 性能無退化

---

## 風險與緩解措施

### 高風險項目

#### 1. Workout Feature 重構複雜度高 ⚠️
**風險**:
- 數據同步邏輯複雜（HealthKit, Garmin, Strava）
- 使用頻率高，回歸風險大

**緩解措施**:
- 增加測試時間至 1 整天
- 分階段遷移（先本地數據，後同步邏輯）
- 使用 Feature Flag 控制新代碼啟用

#### 2. 認證重構安全風險 ⚠️
**風險**:
- Token 管理不當可能導致安全漏洞
- 影響所有需要認證的功能

**緩解措施**:
- 專門安全性審查
- 保留舊實現作為回滾選項
- 小範圍用戶測試

#### 3. 時間超支風險 ⚠️
**風險**:
- 實際重構時間可能超過估算

**緩解措施**:
- 每個 Phase 預留 20% 緩衝時間
- 優先完成高優先級 Features
- 低優先級 Features 可推遲

---

## 資源分配

### 人力分配建議

| 階段 | 主要開發者 | 測試人員 | Code Reviewer |
|-----|-----------|---------|---------------|
| Phase 2 (Week 3-6) | 2 人 | 0.5 人 | 1 人 |
| Phase 3 (Week 7-8) | 1-2 人 | 0.5 人 | 1 人 |
| Phase 4 (Week 9-10) | 1 人 | 1 人 | 1 人 |

### 工作量估算

| Feature | 開發時間 | 測試時間 | 總計 | 人天 |
|---------|---------|---------|------|------|
| Workout | 4 天 | 1 天 | 5 天 | 5 |
| UserProfile | 2 天 | 1 天 | 3 天 | 3 |
| VDOT | 2 天 | 1 天 | 3 天 | 3 |
| TrainingReadiness | 3 天 | 1 天 | 4 天 | 4 |
| Authentication | 2 天 | 1 天 | 3 天 | 3 |
| Integrations | 3 天 | 1 天 | 4 天 | 4 |
| 優化與完善 | 5 天 | 5 天 | 10 天 | 10 |
| **總計** | **21 天** | **11 天** | **32 天** | **32** |

**注意**: 以上為單人工作量估算，實際可多人並行加速

---

## 成功標準

### 必須達成 (Must Have)
- ✅ 所有核心 Features 遵循 Clean Architecture
- ✅ Repository Pattern 覆蓋率 100%
- ✅ Use Case 封裝率 > 70%
- ✅ 測試覆蓋率 > 85%
- ✅ 零功能回歸
- ✅ 編譯無警告

### 期望達成 (Should Have)
- ✅ Use Case 封裝率 > 90%
- ✅ 測試覆蓋率 > 90%
- ✅ 性能優化 10%+
- ✅ 代碼行數減少 15%+

### 可選達成 (Nice to Have)
- ✅ 完整的架構文檔集
- ✅ 自動化測試 CI/CD
- ✅ 代碼品質報告儀表板

---

## 下一步

1. **閱讀**: [REFACTOR-002-Feature-Plans.md](./REFACTOR-002-Feature-Plans.md) 了解各 Feature 詳細計劃
2. **準備**: 建立測試基礎設施（參考 REFACTOR-004）
3. **開始**: Workout Feature 重構（Week 3）

---

**文檔版本**: 1.0
**撰寫日期**: 2026-01-03
**維護者**: Paceriz iOS Team
