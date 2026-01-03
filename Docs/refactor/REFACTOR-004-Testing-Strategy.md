# REFACTOR-004: 測試策略

**版本**: 1.0
**最後更新**: 2026-01-03
**狀態**: 📋 規劃中

---

## 概述

本文檔定義 Clean Architecture 重構過程中的完整測試策略，確保代碼質量、功能正確性和性能穩定性。

---

## 測試金字塔

### 測試層級分布

```
           ▲
          /E2E\          10% - 端到端測試 (UI Tests)
         /─────\
        /Integ  \        20% - 整合測試 (Integration Tests)
       /─────────\
      /   Unit    \      70% - 單元測試 (Unit Tests)
     /─────────────\
```

### 各層級測試目標

| 測試層級 | 覆蓋範圍 | 目標覆蓋率 | 運行頻率 |
|---------|---------|-----------|---------|
| **單元測試** | Use Cases, Repositories, ViewModels | > 85% | 每次提交 |
| **整合測試** | 多層級交互、API 調用 | > 60% | 每次 PR |
| **端到端測試** | 完整用戶流程 | 主要流程 | 每日 |

---

## 單元測試策略

### Domain Layer 測試

#### 測試重點: Use Cases

**測試原則**:
- 每個 Use Case 至少 5 個測試案例
- 覆蓋正常流程、邊界條件、錯誤處理
- 使用 Mock Repository，不依賴真實數據源

#### 測試模板範例

**Use Case: GetWorkoutsInRangeUseCase**

測試案例設計:
1. ✅ 正常流程: 返回指定日期範圍的訓練記錄
2. ✅ 空結果: 日期範圍內無訓練記錄
3. ✅ 過濾邏輯: 僅返回指定活動類型
4. ✅ 排序驗證: 按日期降序排列
5. ✅ 錯誤處理: Repository 拋出錯誤時正確處理

**測試結構**:
```
測試文件: GetWorkoutsInRangeUseCaseTests.swift

測試案例:
- testExecute_WithValidDateRange_ReturnsWorkouts()
- testExecute_WithEmptyResult_ReturnsEmptyArray()
- testExecute_WithActivityTypeFilter_ReturnsFilteredWorkouts()
- testExecute_WithMultipleWorkouts_ReturnsSortedByDate()
- testExecute_WithRepositoryError_ThrowsError()
```

#### Mock 策略

**Mock Repository 實現**:
```
特點:
- 實現 Repository Protocol
- 內部使用陣列存儲測試數據
- 可控制返回結果和錯誤

範例:
MockWorkoutRepository:
- stubbedWorkouts: [WorkoutV2] = []
- stubbedError: Error? = nil
- getWorkouts(...) -> 返回 stubbedWorkouts 或拋出 stubbedError
```

#### 覆蓋率目標

| Use Case 類型 | 目標覆蓋率 | 必須測試 |
|--------------|-----------|---------|
| 數據查詢 | > 90% | 正常流程、空結果、錯誤處理 |
| 數據計算 | > 95% | 各種輸入組合、邊界條件 |
| 數據同步 | > 90% | 成功、失敗、部分成功 |

---

### Data Layer 測試

#### 測試重點: Repository Implementation

**測試原則**:
- 驗證雙軌緩存策略正確性
- 驗證 Remote 和 Local DataSource 協調
- 驗證錯誤傳播

#### 測試案例設計

**Repository: WorkoutRepositoryImpl**

測試案例:
1. ✅ 有緩存: 立即返回緩存，背景刷新
2. ✅ 無緩存: 從 API 獲取並緩存
3. ✅ API 失敗: 返回緩存（如有）或拋出錯誤
4. ✅ 緩存失效: 強制刷新
5. ✅ 並發請求: 防止重複 API 調用

**測試結構**:
```
測試文件: WorkoutRepositoryImplTests.swift

測試案例:
- testGetWorkouts_WithCache_ReturnsImmediately()
- testGetWorkouts_NoCache_FetchesFromAPI()
- testGetWorkouts_APIFailure_ReturnsCacheOrThrows()
- testRefreshWorkouts_BypassesCache()
- testConcurrentRequests_NoDuplicateAPICalls()
```

#### 覆蓋率目標

| Repository 類型 | 目標覆蓋率 | 必須測試 |
|----------------|-----------|---------|
| 讀取操作 | > 85% | 緩存命中、緩存未命中、錯誤 |
| 寫入操作 | > 85% | 成功、失敗、衝突 |
| 同步操作 | > 80% | 完整流程、錯誤處理 |

---

### Presentation Layer 測試

#### 測試重點: ViewModels

**測試原則**:
- 驗證 UI 狀態轉換
- 驗證 Use Case 調用正確性
- 驗證錯誤處理和用戶提示

#### 測試案例設計

**ViewModel: WorkoutDetailViewModel**

測試案例:
1. ✅ 初始狀態: loading
2. ✅ 載入成功: 狀態轉為 loaded，數據正確
3. ✅ 載入失敗: 狀態轉為 error，顯示錯誤訊息
4. ✅ 刷新操作: 重新載入數據
5. ✅ 用戶交互: 按鈕點擊觸發正確操作

**測試結構**:
```
測試文件: WorkoutDetailViewModelTests.swift

測試案例:
- testInitialState_IsLoading()
- testLoadWorkout_Success_UpdatesState()
- testLoadWorkout_Failure_ShowsError()
- testRefresh_ReloadsData()
- testDeleteWorkout_CallsRepository()
```

#### 覆蓋率目標

| ViewModel 類型 | 目標覆蓋率 | 必須測試 |
|---------------|-----------|---------|
| 數據展示 | > 80% | 載入、成功、失敗狀態 |
| 用戶交互 | > 85% | 所有用戶操作 |
| 狀態管理 | > 90% | 狀態轉換邏輯 |

---

## 整合測試策略

### 測試重點

整合測試驗證多個層級的協同工作，重點測試：
1. **API 整合**: Repository → DataSource → 真實 API
2. **數據流完整性**: View → ViewModel → Use Case → Repository
3. **緩存策略**: 雙軌緩存的實際運作

### 測試環境

#### 測試 API 環境
```
使用測試環境 API:
- Base URL: https://test-api.paceriz.com
- 測試用戶帳號
- Mock API Server (可選)

優點:
- 不影響生產數據
- 可控制測試數據
- 可模擬各種場景（成功、失敗、延遲）
```

### 整合測試案例

#### Workout Feature 整合測試

**測試場景 1: 完整數據載入流程**
```
步驟:
1. 清除本地緩存
2. 調用 ViewModel.loadWorkouts()
3. 驗證 API 被調用
4. 驗證數據正確存入緩存
5. 驗證 UI 狀態更新為 loaded

預期結果:
- API 調用成功
- 緩存已更新
- UI 顯示正確數據
```

**測試場景 2: 雙軌緩存策略**
```
步驟:
1. 預先緩存舊數據
2. 調用 ViewModel.loadWorkouts()
3. 驗證立即返回緩存數據
4. 等待背景刷新完成
5. 驗證 UI 更新為最新數據

預期結果:
- UI 立即顯示緩存（< 100ms）
- 背景刷新成功
- UI 自動更新為最新數據
```

**測試場景 3: 網路錯誤處理**
```
步驟:
1. 模擬網路斷開
2. 調用 ViewModel.loadWorkouts()
3. 驗證返回緩存（如有）
4. 驗證 UI 顯示錯誤提示（如無緩存）

預期結果:
- 優雅降級（有緩存時）
- 錯誤提示清晰（無緩存時）
```

### 整合測試覆蓋率目標

| Feature | 整合測試數量 | 覆蓋率目標 |
|---------|------------|-----------|
| Workout | 10+ | > 60% |
| UserProfile | 8+ | > 60% |
| TrainingPlan | 12+ | > 65% |
| VDOT | 6+ | > 55% |

---

## 端到端測試策略

### 測試重點

端到端測試模擬真實用戶操作，驗證完整用戶流程。

### 關鍵用戶流程

#### 流程 1: 首次啟動與登入
```
步驟:
1. 啟動應用
2. 點擊「登入」按鈕
3. 輸入測試帳號密碼
4. 點擊「登入」
5. 等待主畫面載入

驗證:
- 登入成功
- 主畫面顯示正確
- 用戶資料載入
```

#### 流程 2: 查看訓練記錄
```
步驟:
1. 導航至「訓練記錄」頁面
2. 等待數據載入
3. 點擊某條訓練記錄
4. 查看訓練詳情

驗證:
- 訓練列表顯示正確
- 詳情頁顯示完整資訊
- 地圖、圖表正常顯示
```

#### 流程 3: 同步 HealthKit 數據
```
步驟:
1. 導航至「設定」
2. 點擊「同步 HealthKit」
3. 等待同步完成
4. 返回訓練記錄頁面

驗證:
- 同步成功提示
- 新數據出現在列表
- 統計數據更新
```

### 端到端測試覆蓋率目標

| 流程類型 | 測試案例數 | 自動化比例 |
|---------|-----------|-----------|
| 認證流程 | 3 | 100% |
| 訓練記錄 | 5 | 80% |
| 訓練計劃 | 4 | 80% |
| 設定 | 3 | 60% |

---

## 性能測試策略

### 測試指標

| 指標類別 | 指標名稱 | 目標值 | 測試方法 |
|---------|---------|-------|---------|
| **啟動** | 冷啟動時間 | < 2s | XCTest Performance |
| **啟動** | 熱啟動時間 | < 0.5s | XCTest Performance |
| **載入** | 訓練記錄列表載入 | < 1s | 手動計時 |
| **載入** | 訓練詳情頁載入 | < 0.5s | 手動計時 |
| **記憶體** | 峰值記憶體使用 | < 200MB | Instruments |
| **記憶體** | 平均記憶體使用 | < 100MB | Instruments |
| **網路** | API 響應時間 | < 500ms | Network Profiler |

### 性能測試場景

#### 場景 1: 大量數據載入
```
測試條件:
- 1000+ 條訓練記錄
- 複雜的過濾條件
- 多種活動類型

測試步驟:
1. 清除緩存
2. 載入訓練記錄列表
3. 測量載入時間和記憶體使用

目標:
- 載入時間 < 1s
- 記憶體使用 < 150MB
- UI 流暢（60fps）
```

#### 場景 2: 快速切換頁面
```
測試步驟:
1. 快速切換 Tab（訓練、計劃、統計）
2. 重複 20 次
3. 監控記憶體洩漏

目標:
- 無記憶體洩漏
- 頁面切換流暢
- 記憶體使用穩定
```

---

## 回歸測試策略

### 回歸測試範圍

每次重構完成後，必須執行完整回歸測試，確保無功能退化。

### 回歸測試檢查清單

#### Workout Feature 回歸測試
- [ ] 訓練記錄列表正確顯示
- [ ] 訓練詳情頁資訊完整
- [ ] HealthKit 同步功能正常
- [ ] Garmin 同步功能正常
- [ ] Strava 同步功能正常
- [ ] 訓練記錄編輯功能正常
- [ ] 訓練記錄刪除功能正常
- [ ] 統計數據計算正確
- [ ] 地圖顯示正確
- [ ] 圖表顯示正確

#### UserProfile Feature 回歸測試
- [ ] 用戶資料顯示正確
- [ ] 用戶資料編輯功能正常
- [ ] 頭像上傳功能正常
- [ ] 偏好設定保存正常
- [ ] 語言切換功能正常
- [ ] 單位切換功能正常

#### TrainingPlan Feature 回歸測試
- [ ] 訓練計劃列表顯示正確
- [ ] 週計畫詳情正確
- [ ] 訓練建議準確
- [ ] 計劃生成功能正常
- [ ] 計劃修改功能正常
- [ ] 完成狀態統計正確

---

## 測試自動化

### CI/CD 整合

#### GitHub Actions 配置

**Pull Request 觸發**:
```
觸發條件:
- 所有 PR 到 main 分支

執行內容:
1. 編譯檢查（無警告）
2. 單元測試（覆蓋率 > 85%）
3. 整合測試
4. 代碼品質檢查（SwiftLint）

阻止合併條件:
- 編譯失敗
- 測試失敗
- 覆蓋率不達標
- 代碼品質不合格
```

**Daily Build**:
```
觸發條件:
- 每日凌晨 2:00

執行內容:
1. 完整編譯
2. 所有單元測試
3. 所有整合測試
4. 端到端測試
5. 性能測試

產出:
- 測試報告
- 覆蓋率報告
- 性能報告
- 通知結果至 Slack/Email
```

### 測試報告

#### 覆蓋率報告格式

**總覽**:
```
整體覆蓋率: 87%
- Domain Layer: 92%
- Data Layer: 85%
- Presentation Layer: 83%

趨勢:
- 上週: 85%
- 本週: 87% (+2%)
```

**詳細報告**:
```
檔案級別覆蓋率:
- GetWorkoutsInRangeUseCase.swift: 95%
- WorkoutRepositoryImpl.swift: 88%
- WorkoutDetailViewModel.swift: 82%

未覆蓋程式碼:
- WorkoutDetailViewModel.swift:145-150 (錯誤處理)
- WorkoutRepositoryImpl.swift:78-82 (邊界條件)
```

---

## 測試工具與框架

### 推薦工具

| 工具 | 用途 | 必要性 |
|-----|------|-------|
| **XCTest** | 單元測試、整合測試 | 必須 |
| **XCUITest** | 端到端測試 | 必須 |
| **Quick/Nimble** | BDD 風格測試（可選） | 可選 |
| **SwiftLint** | 代碼品質檢查 | 必須 |
| **Instruments** | 性能分析 | 必須 |
| **Firebase Crashlytics** | 崩潰監控 | 必須 |
| **SonarQube** | 代碼品質平台（可選） | 可選 |

---

## 測試最佳實踐

### 編寫可測試代碼

#### 原則 1: 依賴注入
```
好處:
- 易於替換為 Mock
- 測試獨立性高
- 解耦合

範例:
- ViewModel 通過初始化注入 Use Cases
- Use Case 通過初始化注入 Repository
```

#### 原則 2: 純函數優先
```
好處:
- 無副作用
- 結果可預測
- 易於測試

範例:
- 計算邏輯封裝為純函數
- 避免全局狀態
```

#### 原則 3: 小而專注
```
好處:
- 每個類職責單一
- 測試案例簡單
- 易於維護

範例:
- Use Case 只做一件事
- 避免 God Class
```

### 測試代碼品質

#### 原則 1: 測試命名清晰
```
命名格式:
test{方法名}_{測試條件}_{預期結果}()

範例:
- testExecute_WithValidDateRange_ReturnsWorkouts()
- testGetWorkouts_WithCache_ReturnsImmediately()
```

#### 原則 2: AAA 模式
```
結構:
1. Arrange (準備): 設置測試數據和條件
2. Act (執行): 調用被測試的方法
3. Assert (驗證): 驗證結果

好處:
- 結構清晰
- 易於閱讀
- 易於維護
```

#### 原則 3: 獨立性
```
要求:
- 每個測試案例獨立運行
- 不依賴其他測試的執行順序
- setUp 和 tearDown 正確實現

驗證:
- 隨機順序運行測試
- 所有測試都通過
```

---

## 測試覆蓋率目標總結

### 最終目標

| 層級 | 目標覆蓋率 | 當前狀態 | 完成時間 |
|-----|-----------|---------|---------|
| **Domain Layer** | > 90% | 待開始 | Week 10 |
| **Data Layer** | > 85% | 待開始 | Week 10 |
| **Presentation Layer** | > 80% | 待開始 | Week 10 |
| **整體** | > 85% | 25% | Week 10 |

### 階段性目標

| Phase | 完成時間 | 覆蓋率目標 |
|-------|---------|-----------|
| Phase 2 (核心 Features) | Week 6 | > 70% |
| Phase 3 (認證與整合) | Week 8 | > 80% |
| Phase 4 (優化完善) | Week 10 | > 85% |

---

**文檔版本**: 1.0
**撰寫日期**: 2026-01-03
**維護者**: Paceriz iOS Team
**參考**: ARCH-005 TrainingPlan Reference Implementation
