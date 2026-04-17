# 遷移路線圖

## 總覽

| 週 | 目標 | 交付物 |
|----|------|--------|
| 1-2 | 基礎設施 | DI Container, ViewState, 目錄結構 |
| 3-4 | TrainingPlan 模組 | 完整 Clean Architecture 遷移 |
| 5-6 | User + Auth 模組 | 拆分 God Objects |
| 7-8 | Workout + Onboarding | 完成遷移，清理舊代碼 |

---

## 第 1-2 週：基礎設施

### Week 1：核心元件

**任務：**
1. 建立 `Features/` 目錄結構
2. 實作 `ViewState<T>` enum
3. 實作 `DomainError` enum
4. 實作 `DependencyContainer`
5. 建立共用 UI 元件 (`ErrorView`, `EmptyStateView`)

**驗收標準：**
- [ ] ViewState 編譯通過
- [ ] DependencyContainer 可註冊/解析依賴
- [ ] ErrorView 可處理 DomainError

### Week 2：TrainingPlan 基礎

**任務：**
1. 建立 `Features/TrainingPlan/` 結構
2. 定義 `TrainingPlanRepository` Protocol
3. 實作 `TrainingPlanRemoteDataSource`
4. 實作 `TrainingPlanLocalDataSource` (遷移現有緩存邏輯)
5. 實作 `TrainingPlanMapper`

**驗收標準：**
- [ ] Repository Protocol 定義完整
- [ ] DataSource 可正常獲取/緩存數據
- [ ] 單元測試覆蓋 >80%

---

## 第 3-4 週：TrainingPlan 模組

### Week 3：Repository + ViewModel

**任務：**
1. 實作 `TrainingPlanRepositoryImpl` (含雙軌緩存)
2. 重構 `WeeklyPlanViewModel` (從 TrainingPlanViewModel 提取)
3. 更新 `TrainingPlanView` 使用 ViewState
4. 在 DependencyContainer 註冊依賴

**驗收標準：**
- [ ] 雙軌緩存正常運作
- [ ] WeeklyPlanView 使用 ViewState 正確顯示各狀態
- [ ] 取消錯誤不顯示 ErrorView

### Week 4：完成 TrainingPlan 遷移

**任務：**
1. 提取 `TrainingOverviewViewModel`
2. 提取 `WeeklySummaryViewModel`
3. 提取 `EditScheduleViewModel`
4. 遷移所有 TrainingPlan 相關 View
5. 標記舊 `TrainingPlanViewModel` 為 deprecated

**驗收標準：**
- [ ] TrainingPlan 功能全部正常
- [ ] 無 View 直接呼叫 Service
- [ ] 整合測試通過

---

## 第 5-6 週：User + Auth 模組

### Week 5：User 模組

**任務：**
1. 建立 `Features/User/` 結構
2. 拆分 `UserManager` 為:
   - `UserRepository` (Profile CRUD)
   - `HeartRateZonesRepository`
   - `UserTargetsRepository`
3. 實作對應的 DataSources
4. 更新 `UserProfileViewModel`

**驗收標準：**
- [ ] UserManager 職責清晰
- [ ] 循環依賴消除
- [ ] 單元測試覆蓋 >80%

### Week 6：Authentication 模組

**任務：**
1. 建立 `Features/Authentication/` 結構
2. 拆分 `AuthenticationService` 為:
   - `AuthRepository` (Protocol)
   - `FirebaseAuthDataSource`
   - `BackendAuthDataSource`
3. 更新所有登入相關 ViewModel
4. 測試 Google、Apple、Email 登入流程

**驗收標準：**
- [ ] 所有登入方式正常
- [ ] Token 刷新機制正常
- [ ] 登出/刪除帳號正常

---

## 第 7-8 週：Workout + Onboarding + 清理

### Week 7：Workout 模組 + Onboarding

**任務：**
1. 建立 `Features/Workout/` 結構
2. 實作 `WorkoutRepository`
3. 遷移 `UnifiedWorkoutManager` 邏輯
4. 重構 Onboarding Views (提取 ViewModel 到獨立檔案)
5. 移除 View 直接呼叫 Service

**驗收標準：**
- [ ] Workout 功能正常
- [ ] HealthKit 同步正常
- [ ] Onboarding 流程正常

### Week 8：清理 + 收尾

**任務：**
1. 移除所有已 deprecated 的舊 Managers
2. 移除舊 `APIClient` (統一用 HTTPClient)
3. 更新 CLAUDE.md
4. 完整回歸測試
5. 效能測試

**驗收標準：**
- [ ] 無 Legacy 代碼
- [ ] 所有功能正常
- [ ] App 啟動時間無退化
- [ ] 測試覆蓋率 >85%

---

## 遷移策略

### Facade 模式 (向後兼容)

遷移期間，保留 `.shared` 介面：

```swift
// 舊介面繼續工作
extension UserManager {
    static var shared: UserManager {
        // 內部使用 DI Container
        DependencyContainer.shared.resolve()
    }
}
```

### 漸進式 View 遷移

1. 先更新 ViewModel
2. 一次遷移一個 View
3. 驗證後再遷移下一個

### 回滾計畫

每週結束時：
- 建立 Git tag
- 確保可快速回滾到穩定版本

---

## 風險評估

| 風險 | 機率 | 影響 | 緩解措施 |
|------|------|------|----------|
| 雙軌緩存失效 | 中 | 高 | 遷移時 1:1 複製現有邏輯，充分測試 |
| 初始化 race condition | 中 | 高 | 保留 AppStateManager 順序，加入測試 |
| UI 狀態錯亂 | 低 | 中 | ViewState 強制所有狀態互斥 |
| DI 註冊遺漏 | 低 | 低 | 編譯時 Protocol 檢查 |

---

## 成功指標

| 指標 | 當前 | 目標 |
|------|------|------|
| God Object 數量 | 3 (>1000 行) | 0 |
| Singleton 使用 | 108 處 | <10 處 (Core only) |
| 測試覆蓋率 | ~40% | >85% |
| View→Service 直接呼叫 | 13+ | 0 |
| ViewModel→Service 直接呼叫 | 15+ | 0 |
| 循環依賴 | 有 | 無 |
