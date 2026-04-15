# FRD-005: 錯誤處理標準化

**版本**: 1.0
**最後更新**: 2025-12-30
**狀態**: 🔄 規劃中
**優先級**: ⚠️ Medium
**預估工作量**: 2-3 天

---

## 功能概述

統一錯誤處理機制，引入 DomainError 類型系統，替代當前的 try-catch + NSError 模式，提供明確的錯誤分類和用戶友好的錯誤訊息。

---

## 業務目標

### 核心目標
- 建立統一的錯誤類型系統
- 提供清晰的錯誤分類和訊息
- 正確處理取消錯誤（不應顯示給用戶）
- 提升錯誤處理的可測試性

### 成功指標
- 所有 Repository 統一拋出 DomainError
- 取消錯誤不再觸發 ErrorView 顯示
- 錯誤處理測試覆蓋率 > 80%
- 用戶報告的「莫名錯誤」減少 70%

---

## 功能需求

### 1. DomainError 類型系統

#### 1.1 錯誤類型定義
- **功能描述**: 定義領域層級的錯誤枚舉
- **錯誤類型**:
  - **networkFailure(Error)**: 網路連線失敗
  - **serverFailure(statusCode: Int, message: String)**: 伺服器錯誤
  - **cacheFailure**: 本地緩存讀取失敗
  - **cancellationFailure**: 操作被取消
  - **authFailure**: 認證失敗
  - **validationFailure(String)**: 資料驗證失敗
  - **unknown(Error)**: 未知錯誤

#### 1.2 用戶友好錯誤訊息
- **功能描述**: 為每個錯誤類型提供本地化描述
- **訊息原則**:
  - 使用用戶易懂的語言
  - 提供可行的建議（如「請檢查網路設定」）
  - 避免技術術語
- **實作方式**: 實作 LocalizedError protocol

#### 1.3 錯誤轉換機制
- **功能描述**: 提供 Error → DomainError 的統一轉換
- **轉換規則**:
  - URLError.cancelled → cancellationFailure
  - URLError.notConnectedToInternet → networkFailure
  - HTTPURLResponse.statusCode ≥ 400 → serverFailure
  - 其他 → unknown(Error)

### 2. Repository Layer 錯誤處理

#### 2.1 統一錯誤拋出
- **功能描述**: Repository 統一拋出 DomainError
- **實作方式**: 在 catch 塊中轉換為 DomainError
- **範圍**: 所有 Repository 方法

#### 2.2 背景刷新錯誤處理
- **功能描述**: 背景刷新失敗不影響已顯示的緩存
- **處理策略**:
  - 背景刷新錯誤僅記錄日誌
  - 不拋出異常到上層
  - 保持已顯示的緩存內容

### 3. ViewModel 錯誤處理

#### 3.1 取消錯誤過濾
- **功能描述**: 取消錯誤不更新 UI 狀態
- **實作邏輯**:
  1. 捕獲錯誤
  2. 轉換為 DomainError
  3. 檢查是否為 cancellationFailure
  4. 如是取消錯誤，記錄日誌並返回
  5. 如非取消錯誤，更新狀態為 error

#### 3.2 錯誤狀態更新
- **功能描述**: 統一的錯誤狀態更新流程
- **流程**:
  1. 調用 Repository 方法
  2. 捕獲異常
  3. 轉換為 DomainError
  4. 過濾取消錯誤
  5. 更新 state = .error(domainError)
  6. 記錄錯誤日誌

### 4. HTTPClient 錯誤處理

#### 4.1 HTTP 狀態碼檢查
- **功能描述**: 檢查 HTTP 響應狀態碼
- **檢查規則**:
  - 200-299: 成功，返回數據
  - 400-499: 客戶端錯誤，拋出 serverFailure
  - 500-599: 伺服器錯誤，拋出 serverFailure
  - 其他: 拋出 unknown

#### 4.2 統一錯誤拋出
- **功能描述**: HTTPClient 統一拋出 DomainError
- **實作方式**: 在所有網路請求方法中轉換錯誤

---

## 非功能需求

### 可測試性
- 錯誤類型可枚舉，易於測試
- 錯誤轉換邏輯可獨立測試
- Mock 場景可精確控制錯誤類型

### 用戶體驗
- 錯誤訊息清晰易懂
- 取消操作不顯示錯誤
- 提供重試機制

### 可維護性
- 錯誤類型集中定義
- 錯誤轉換邏輯統一
- 新增錯誤類型易於擴展

---

## 驗收標準

### 功能驗收
- [ ] DomainError 枚舉已定義所有錯誤類型
- [ ] DomainError 實作 LocalizedError 提供用戶友好訊息
- [ ] Error → DomainError 轉換擴展已實作
- [ ] Repository 統一拋出 DomainError
- [ ] ViewModel 正確過濾取消錯誤
- [ ] HTTPClient 檢查 HTTP 狀態碼並拋出對應錯誤

### 測試驗收
- [ ] DomainError 轉換邏輯測試覆蓋率 100%
- [ ] Repository 錯誤處理測試覆蓋率 > 80%
- [ ] ViewModel 取消錯誤過濾測試通過
- [ ] HTTPClient 狀態碼檢查測試通過

### 用戶體驗驗收
- [ ] 網路錯誤顯示「請檢查網路設定」
- [ ] 伺服器錯誤顯示狀態碼和訊息
- [ ] 取消操作不顯示 ErrorView
- [ ] 背景刷新失敗不影響已顯示內容

### 兼容性驗收
- [ ] 現有錯誤處理邏輯平滑遷移
- [ ] 日誌記錄保持完整
- [ ] API 調用追蹤系統正常

---

## 依賴關係

### 前置依賴
- ✅ Week 3 完成：Repository Pattern 已實作
- ✅ Week 4 完成：ViewState 枚舉已定義

### 後續依賴
- Week 6 UseCase 層將使用 DomainError

---

## 風險與緩解措施

### 中風險

#### 風險 1: 錯誤轉換邏輯可能遺漏某些錯誤類型
**影響**: 某些錯誤被歸類為 unknown
**緩解措施**:
- 完整的錯誤類型列表
- 日誌記錄所有 unknown 錯誤
- 持續監控並補充錯誤類型

#### 風險 2: 背景刷新錯誤被吞噬可能隱藏問題
**影響**: 數據更新異常未被察覺
**緩解措施**:
- 背景刷新錯誤記錄詳細日誌
- 監控背景刷新失敗率
- 提供調試開關顯示背景錯誤

### 低風險

#### 風險 3: 用戶友好訊息可能不夠精確
**影響**: 用戶無法理解錯誤原因
**緩解措施**:
- UX 團隊審核錯誤訊息
- A/B 測試不同訊息版本
- 收集用戶反饋持續優化

---

## 實作計劃

### Phase 1: DomainError 定義 (0.5 天)
- 定義 DomainError 枚舉
- 實作 LocalizedError conformance
- 實作 Error → DomainError 轉換擴展

### Phase 2: Repository 錯誤處理更新 (1 天)
- 更新 Repository 統一拋出 DomainError
- 處理背景刷新錯誤邏輯
- 確保雙軌緩存邏輯正確

### Phase 3: ViewModel 錯誤處理更新 (0.5 天)
- 實作取消錯誤過濾邏輯
- 更新錯誤狀態更新流程
- 添加錯誤日誌記錄

### Phase 4: HTTPClient 錯誤處理更新 (0.5 天)
- 實作 HTTP 狀態碼檢查
- 統一錯誤拋出邏輯
- 處理網路異常

### Phase 5: 測試與驗證 (0.5 天)
- 編寫錯誤轉換測試
- 編寫 Repository 錯誤處理測試
- 編寫 ViewModel 取消錯誤過濾測試
- 執行用戶體驗測試

---

## 設計決策

### 決策 1: 使用枚舉而非繼承體系
**原因**:
- Swift 枚舉支援關聯值，更適合錯誤處理
- 編譯器可檢查 exhaustive switch
- 性能優於類型層級結構

### 決策 2: 取消錯誤不更新 UI 狀態
**原因**:
- 取消是用戶主動行為，不應視為錯誤
- 避免 UI 閃爍和誤導性錯誤提示
- 符合 iOS 系統慣例

### 決策 3: 背景刷新錯誤僅記錄日誌
**原因**:
- 背景刷新失敗不影響已顯示的緩存
- 避免干擾用戶體驗
- 通過監控和日誌追蹤問題

---

## 錯誤訊息規範

### 網路相關錯誤
- **networkFailure**: "網路連線失敗，請檢查網路設定"
- **cancellationFailure**: "操作已取消"（不顯示給用戶）

### 伺服器相關錯誤
- **serverFailure (4xx)**: "請求錯誤 (狀態碼): 錯誤訊息"
- **serverFailure (5xx)**: "伺服器錯誤 (狀態碼): 錯誤訊息"

### 認證相關錯誤
- **authFailure**: "認證失敗，請重新登入"

### 資料相關錯誤
- **cacheFailure**: "本地資料讀取失敗"
- **validationFailure**: "資料驗證失敗: 具體原因"

### 其他錯誤
- **unknown**: "未知錯誤: 錯誤描述"

---

## 參考文檔

- [ARCH-002: Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [ARCH-003: 遷移路線圖](../01-architecture/ARCH-003-Migration-Roadmap.md)
- Flutter 版本: ARCH-010 錯誤處理架構

---

**文檔版本**: 1.0
**撰寫日期**: 2025-12-30
**負責人**: iOS Team
**審核人**: Tech Lead
