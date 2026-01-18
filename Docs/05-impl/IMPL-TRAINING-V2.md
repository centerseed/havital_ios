# Training V2 實現計劃

**參考文件**: [FRD-TRAINING-V2-INTEGRATION.md](../04-frds/FRD-TRAINING-V2-INTEGRATION.md)
**建立日期**: 2025-01-17
**最後更新**: 2025-01-17

---

## 進度總覽

| 階段 | 名稱 | 狀態 | 完成項目 |
|------|------|------|----------|
| Phase 0 | 前置準備 | 🔲 未開始 | 0/3 |
| Phase 1 | Domain Layer | 🔲 未開始 | 0/5 |
| Phase 2 | Data Layer | 🔲 未開始 | 0/6 |
| Phase 3 | 版本路由 | 🔲 未開始 | 0/4 |
| Phase 4 | Presentation Layer | 🔲 未開始 | 0/5 |
| Phase 5 | Onboarding 整合 | 🔲 未開始 | 0/4 |
| Phase 6 | 整合測試 | 🔲 未開始 | 0/4 |

**狀態圖示**: 🔲 未開始 | 🔄 進行中 | ✅ 完成 | ⏸️ 暫停

---

## Phase 0: 前置準備

**目標**: 確認後端 API 就緒，建立目錄結構

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 0.1 | 確認後端 V2 API 可用 (`/v2/plan/overview`, `/v2/plan/weekly`, `/v2/summary/weekly`) | 🔲 | |
| 0.2 | 確認後端 User 資料新增 `training_version` 欄位 | 🔲 | |
| 0.3 | 建立 `Features/TrainingPlanV2/` 目錄結構 | 🔲 | |

---

## Phase 1: Domain Layer

**目標**: 定義 V2 業務實體和 Repository 介面

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 1.1 | 定義 `PlanOverviewV2` Entity（含 target_type, methodology_id, training_stages, milestones） | 🔲 | |
| 1.2 | 定義 `WeeklyPlanV2` Entity（含 workouts, metadata） | 🔲 | |
| 1.3 | 定義 `WeeklySummaryV2` Entity（含 readiness_summary, capability_progression, next_week_adjustments） | 🔲 | |
| 1.4 | 定義 `TrainingPlanV2Repository` Protocol | 🔲 | |
| 1.5 | 定義 `TrainingPlanV2Error` 錯誤類型 | 🔲 | |

---

## Phase 2: Data Layer

**目標**: 實作 API 通訊、快取、資料轉換

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 2.1 | 實作 V2 DTOs（`PlanOverviewV2DTO`, `WeeklyPlanV2DTO`, `WeeklySummaryV2DTO`） | 🔲 | |
| 2.2 | 實作 `TrainingPlanV2RemoteDataSource`（Overview API, Weekly Plan API） | 🔲 | |
| 2.3 | 實作 `WeeklySummaryV2RemoteDataSource`（Summary API, Recommendation API） | 🔲 | |
| 2.4 | 實作 `TrainingPlanV2LocalDataSource`（快取管理，Key 前綴 `training_plan_v2_`） | 🔲 | |
| 2.5 | 實作 V2 Mappers（DTO ↔ Entity 轉換） | 🔲 | |
| 2.6 | 實作 `TrainingPlanV2RepositoryImpl`（雙軌快取策略） | 🔲 | |

---

## Phase 3: 版本路由

**目標**: 實作版本識別與路由機制

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 3.1 | 擴充 User Model 支援 `training_version` 欄位 | 🔲 | |
| 3.2 | 實作 `TrainingVersionRouter`（讀取版本、提供依賴工廠） | 🔲 | |
| 3.3 | 整合 Router 到 `DependencyContainer` | 🔲 | |
| 3.4 | 實作 Fallback 機制（舊用戶 `training_version` 為 null 時的處理） | 🔲 | |

---

## Phase 4: Presentation Layer

**目標**: 實作 V2 ViewModels 和 Views

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 4.1 | 實作 `TrainingPlanV2ViewModel`（主協調器） | 🔲 | |
| 4.2 | 實作 `WeeklyPlanV2ViewModel`（週課表狀態管理） | 🔲 | |
| 4.3 | 實作 `WeeklySummaryV2ViewModel`（週摘要與建議） | 🔲 | |
| 4.4 | 建立 V2 Views 或修改現有 Views 支援 V2 資料結構 | 🔲 | |
| 4.5 | 修改 `ContentView` 根據版本路由到正確的 TrainingPlanView | 🔲 | |

---

## Phase 5: Onboarding 整合

**目標**: 新用戶直接使用 V2，重新 Onboarding 升級至 V2

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 5.1 | 實作 `CompleteOnboardingV2UseCase` | 🔲 | |
| 5.2 | 修改 `OnboardingCoordinator` 支援 V2 流程 | 🔲 | |
| 5.3 | Onboarding 完成後更新 User 的 `training_version` | 🔲 | |
| 5.4 | 發布 `CacheEvent.onboardingCompletedV2` 事件 | 🔲 | |

---

## Phase 6: 整合測試

**目標**: 驗證 V1/V2 並存運作正常

| # | 項目 | 狀態 | 備註 |
|---|------|------|------|
| 6.1 | 測試新用戶 Onboarding → V2 架構 | 🔲 | |
| 6.2 | 測試 V1 用戶登入 → 正確顯示 V1 內容 | 🔲 | |
| 6.3 | 測試登出登入後版本正確保持 | 🔲 | |
| 6.4 | 測試 V1 用戶重新 Onboarding → 升級至 V2 | 🔲 | |

---

## 依賴關係

```
Phase 0 (前置準備)
    ↓
Phase 1 (Domain) ──→ Phase 2 (Data)
                         ↓
                    Phase 3 (版本路由)
                         ↓
                    Phase 4 (Presentation)
                         ↓
                    Phase 5 (Onboarding)
                         ↓
                    Phase 6 (測試)
```

---

## 更新紀錄

| 日期 | 更新內容 | 更新者 |
|------|----------|--------|
| 2025-01-17 | 建立文件 | Claude |

---

## Agent 使用說明

完成項目後，請更新對應項目的狀態：
- `🔲` → `✅` 表示完成
- 在備註欄填寫相關資訊（如遇到的問題、決策變更等）
- 更新「進度總覽」表格的完成項目數
- 在「更新紀錄」新增一行記錄
