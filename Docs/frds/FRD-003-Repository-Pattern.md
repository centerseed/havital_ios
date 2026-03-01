# FRD-003: Repository Pattern 實作

**版本**: 1.0
**最後更新**: 2025-12-30
**狀態**: 🔄 規劃中
**優先級**: 🔥 High
**預估工作量**: 3-5 天

---

## 功能概述

引入 Repository Pattern 和依賴反轉原則，將資料訪問邏輯從 ViewModel 和 Manager 中解耦，建立清晰的架構分層。

---

## 業務目標

### 核心目標
- 解決 ViewModel 直接依賴具體 Service 實作的問題
- 建立統一的資料訪問介面，提高代碼可測試性
- 為後續 Clean Architecture 遷移奠定基礎

### 成功指標
- TrainingPlan 模組完全遷移到 Repository Pattern
- 單元測試覆蓋率達到 80% 以上
- 雙軌緩存策略保持正常運作
- 現有功能無退化

---

## 功能需求

### 1. Domain Layer 建立

#### 1.1 Repository Protocol 定義
- **功能描述**: 定義訓練計畫資料訪問的標準介面
- **核心介面**:
  - 獲取訓練計畫概覽
  - 獲取週計畫（支援緩存優先）
  - 刷新週計畫（強制從 API）
  - 生成新週計畫
  - 獲取當前週數
- **設計原則**: Protocol 不依賴具體實作，僅定義行為契約

#### 1.2 Domain Entities
- **功能描述**: 定義業務實體模型
- **核心實體**:
  - TrainingPlanOverview（訓練計畫概覽）
  - WeeklyPlan（週計畫）
  - DailyWorkout（每日訓練）
- **特性**: 不包含持久化邏輯，僅包含業務邏輯方法

#### 1.3 Domain Errors
- **功能描述**: 定義領域層級的錯誤類型
- **錯誤類型**:
  - 無效週數錯誤
  - 計畫內容無效錯誤
  - 計畫未找到錯誤

### 2. Data Layer 實作

#### 2.1 Data Transfer Objects (DTOs)
- **功能描述**: 定義 API 響應的資料模型
- **用途**: 與後端 API JSON 結構對應，處理序列化與反序列化
- **命名規範**: 使用 DTO 後綴（如 WeeklyPlanDTO）

#### 2.2 Remote DataSource
- **功能描述**: 封裝所有 API 調用邏輯
- **職責**:
  - 發送 HTTP 請求到後端 API
  - 將 JSON 響應解析為 DTO
  - 處理網路錯誤
- **依賴**: HTTPClient

#### 2.3 Local DataSource
- **功能描述**: 封裝所有本地緩存邏輯
- **職責**:
  - 使用 UnifiedCacheManager 管理緩存
  - 提供緩存讀寫介面
  - 檢查緩存是否過期
- **TTL 策略**: 訓練計畫使用 permanent 策略

#### 2.4 DTO Mapper
- **功能描述**: 負責 DTO → Entity 轉換
- **職責**:
  - 將 API 響應的 DTO 轉換為 Domain Entity
  - 處理數據格式轉換（如時間戳 → Date）
  - 保證轉換邏輯集中管理

#### 2.5 Repository Implementation
- **功能描述**: 實作 Repository Protocol
- **核心邏輯**:
  - **雙軌緩存策略**:
    - Track A: 優先從 Local DataSource 讀取緩存，立即返回
    - Track B: 背景從 Remote DataSource 刷新數據
  - 協調 Remote 和 Local DataSource
  - 使用 Mapper 進行 DTO → Entity 轉換

### 3. Dependency Injection Container

#### 3.1 DI Container 建立
- **功能描述**: 管理所有依賴關係的註冊與解析
- **註冊類型**:
  - Singleton: HTTPClient、Logger 等基礎設施
  - Factory: ViewModel（每次創建新實例）
  - Protocol 註冊: Repository 註冊為 Protocol 類型

#### 3.2 服務註冊
- **註冊順序**:
  1. Core Layer（HTTPClient、Logger）
  2. Data Layer（DataSource、Mapper、Repository）
  3. Presentation Layer（ViewModel）

### 4. ViewModel 重構

#### 4.1 依賴反轉
- **變更**: 從依賴具體 Manager 改為依賴 Repository Protocol
- **注入方式**: 通過建構子注入 Repository
- **優勢**: 易於測試，可替換實作

#### 4.2 方法調整
- **變更**: 調用 Repository Protocol 方法而非 Manager 方法
- **保持**: UI 狀態管理邏輯不變（後續 Week 4 處理）

### 5. View 層更新

#### 5.1 ViewModel 獲取
- **變更**: 從 DI Container 解析 ViewModel
- **方式**: 使用 StateObject + DI Container.resolve()
- **影響**: UI 層代碼改動最小

---

## 非功能需求

### 性能要求
- 雙軌緩存響應時間 < 150ms（Track A）
- API 請求超時時間保持 30 秒
- 背景刷新不阻塞 UI 線程

### 可測試性
- Repository 可使用 Mock DataSource 進行單元測試
- ViewModel 可使用 Mock Repository 進行單元測試
- 測試覆蓋率 > 80%

### 可維護性
- 新增資料來源不需修改 Repository Protocol
- 新增實體類型僅需添加對應 Mapper
- DI Container 提供清晰的依賴圖

---

## 驗收標準

### 功能驗收
- [ ] TrainingPlan 模組的 Repository Protocol 已定義
- [ ] Remote DataSource 和 Local DataSource 已實作
- [ ] DTO Mapper 已實作並通過測試
- [ ] Repository Implementation 實作雙軌緩存邏輯
- [ ] DI Container 能正確解析所有依賴
- [ ] TrainingPlanViewModel 通過 Protocol 依賴 Repository
- [ ] TrainingPlanView 從 DI Container 獲取 ViewModel

### 測試驗收
- [ ] Repository 單元測試覆蓋率 > 80%
- [ ] DataSource 單元測試覆蓋率 > 80%
- [ ] Mapper 單元測試覆蓋率 > 90%
- [ ] ViewModel 單元測試使用 Mock Repository

### 性能驗收
- [ ] 有緩存時，數據顯示時間 < 150ms
- [ ] 背景刷新不影響已顯示的緩存內容
- [ ] API 調用追蹤系統正常運作

### 兼容性驗收
- [ ] 現有功能無退化
- [ ] 雙軌緩存策略保持運作
- [ ] API 調用來源追蹤正常

---

## 依賴關係

### 前置依賴
- ✅ Week 2 完成：UnifiedCacheManager 已標準化
- ✅ HTTPClient 已實作並穩定運作
- ✅ API 調用追蹤系統已就緒

### 後續依賴
- Week 4 依賴本週完成的 Repository Pattern
- Week 5 依賴本週完成的錯誤處理基礎

---

## 風險與緩解措施

### 高風險

#### 風險 1: 雙軌緩存邏輯遷移可能破壞現有機制
**影響**: 用戶體驗下降，數據刷新異常
**緩解措施**:
- 在 Repository 層保持與現有 Manager 相同的雙軌邏輯
- 完整的單元測試驗證緩存行為
- 逐步遷移，新舊架構並存

#### 風險 2: Singleton 依賴替換可能導致崩潰
**影響**: App 啟動失敗或運行時崩潰
**緩解措施**:
- 漸進式遷移，優先遷移獨立模組
- 保留 Singleton 作為臨時適配器
- 充分的整合測試

### 中風險

#### 風險 3: DI Container 註冊錯誤
**影響**: 運行時找不到依賴導致崩潰
**緩解措施**:
- 使用 Protocol + 泛型減少註冊錯誤
- 單元測試驗證 DI Container 解析邏輯
- 提供清晰的註冊文檔

---

## 實作計劃

### Phase 1: 目錄結構建立 (0.5 天)
- 創建 features/training_plan 目錄結構
- 創建 domain/data/presentation 子目錄
- 創建 core/di 目錄

### Phase 2: Domain Layer 實作 (1 天)
- 定義 Repository Protocol
- 移動並整理 Entities
- 定義 Domain Errors

### Phase 3: Data Layer 實作 (1.5 天)
- 創建 DTOs
- 實作 Remote DataSource
- 實作 Local DataSource
- 實作 Mapper
- 實作 Repository Implementation

### Phase 4: DI Container 實作 (0.5 天)
- 實作 DependencyContainer
- 註冊所有依賴
- 測試依賴解析

### Phase 5: ViewModel 和 View 重構 (0.5 天)
- 重構 TrainingPlanViewModel 使用 Repository
- 更新 TrainingPlanView 使用 DI Container

### Phase 6: 測試與驗證 (0.5 天)
- 編寫單元測試
- 執行整合測試
- 驗證功能無退化

---

## 參考文檔

- [ARCH-002: Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [ARCH-003: 遷移路線圖](../01-architecture/ARCH-003-Migration-Roadmap.md)
- [ARCH-004: 資料流設計](../01-architecture/ARCH-004-Data-Flow.md)

---

**文檔版本**: 1.0
**撰寫日期**: 2025-12-30
**負責人**: iOS Team
**審核人**: Tech Lead
