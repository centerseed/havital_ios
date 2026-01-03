# FRD-004: 統一狀態管理

**版本**: 1.0
**最後更新**: 2025-12-30
**狀態**: 🔄 規劃中
**優先級**: 🔥 High
**預估工作量**: 2-3 天

---

## 功能概述

引入統一的 ViewState 枚舉，簡化 UI 狀態管理，解決當前多個 @Published 屬性分散的問題，提升代碼可維護性和可測試性。

---

## 業務目標

### 核心目標
- 統一 ViewModel 的狀態管理方式
- 簡化 View 層的 UI 渲染邏輯
- 減少狀態不一致的風險
- 提高 UI 狀態的可測試性

### 成功指標
- TrainingPlan 模組 ViewModel 完全遷移到單一狀態管理
- UI 狀態轉換邏輯簡化，代碼行數減少 30%
- ViewModel 測試覆蓋率 > 80%
- 狀態相關 Bug 減少 50%

---

## 功能需求

### 1. ViewState 枚舉設計

#### 1.1 核心狀態定義
- **功能描述**: 定義通用的 View 狀態枚舉
- **狀態類型**:
  - **loading**: 數據載入中
  - **loaded(T)**: 數據載入成功，包含資料
  - **error(DomainError)**: 載入失敗，包含錯誤信息
  - **empty**: 無數據狀態（可選）
- **泛型支援**: 支援任意數據類型 T

#### 1.2 便利方法
- **功能描述**: 提供狀態檢查的便利方法
- **方法列表**:
  - isLoading: 檢查是否為載入狀態
  - data: 獲取載入成功的數據（可選）
  - error: 獲取錯誤信息（可選）

#### 1.3 Equatable 支援
- **功能描述**: 支援狀態相等性比較（用於測試）
- **應用場景**: ViewModel 單元測試中驗證狀態轉換

### 2. ViewModel 重構

#### 2.1 移除分散的 @Published 屬性
- **變更前問題**:
  - 多個 @Published 屬性（isLoading, data, error）
  - 手動管理多個狀態變量
  - 容易出現狀態不一致
- **變更後**:
  - 單一 @Published 狀態源
  - 狀態轉換邏輯集中
  - 狀態一致性由編譯器保證

#### 2.2 引入單一狀態源
- **功能描述**: 每個數據流使用一個 ViewState
- **範例**:
  - weeklyPlanState: ViewState<WeeklyPlan>
  - overviewState: ViewState<TrainingPlanOverview>

#### 2.3 狀態轉換簡化
- **功能描述**: 統一的狀態賦值模式
- **轉換流程**:
  1. 開始載入 → state = .loading
  2. 載入成功 → state = .loaded(data)
  3. 載入失敗 → state = .error(domainError)

### 3. View 層更新

#### 3.1 狀態分支處理
- **功能描述**: 使用 switch 語句清晰處理各狀態
- **優勢**:
  - 編譯器確保所有狀態都被處理
  - 代碼結構清晰，易於維護
  - 減少遺漏狀態處理的風險

#### 3.2 狀態對應的 UI 組件
- **loading 狀態**: 顯示 ProgressView
- **loaded 狀態**: 顯示具體內容 View
- **error 狀態**: 顯示 ErrorView（共享組件）
- **empty 狀態**: 顯示 EmptyStateView（共享組件）

### 4. 共享 UI 組件

#### 4.1 ErrorView 組件
- **功能描述**: 統一的錯誤顯示組件
- **顯示內容**:
  - 錯誤圖標（感嘆號三角形）
  - 用戶友好的錯誤訊息
  - 重試按鈕
- **可配置**:
  - 接收 DomainError 參數
  - 接收重試回調函數

#### 4.2 EmptyStateView 組件
- **功能描述**: 統一的空狀態顯示組件
- **顯示內容**:
  - 空狀態圖標（托盤圖示）
  - 空狀態提示訊息
- **可配置**: 接收自定義訊息參數

#### 4.3 組件設計原則
- **可重用**: 適用於所有 View
- **可配置**: 支援自定義文字和回調
- **一致性**: 統一的視覺設計語言

---

## 非功能需求

### 代碼質量
- 狀態轉換邏輯清晰，無複雜分支
- ViewModel 測試覆蓋率 > 80%
- UI 組件可重用性 > 90%

### 用戶體驗
- 載入狀態顯示流暢，無閃爍
- 錯誤訊息清晰易懂
- 重試操作響應及時

### 可維護性
- 新增 ViewModel 遵循統一狀態模式
- 錯誤和空狀態 UI 集中管理
- 狀態轉換邏輯易於調試

---

## 驗收標準

### 功能驗收
- [ ] ViewState<T> 枚舉已定義並支援泛型
- [ ] ViewState 提供便利方法（isLoading, data, error）
- [ ] ViewState 支援 Equatable（用於測試）
- [ ] TrainingPlanViewModel 遷移到單一狀態管理
- [ ] TrainingPlanView 使用 switch 處理狀態分支
- [ ] ErrorView 共享組件已實作
- [ ] EmptyStateView 共享組件已實作

### 測試驗收
- [ ] ViewState 單元測試覆蓋所有狀態轉換
- [ ] ViewModel 測試覆蓋率 > 80%
- [ ] 狀態轉換測試驗證正確性
- [ ] UI 組件測試驗證顯示邏輯

### 代碼質量驗收
- [ ] ViewModel 中移除所有分散的 @Published 屬性
- [ ] 狀態轉換邏輯集中在單一賦值語句
- [ ] View 層使用 switch 處理所有狀態分支
- [ ] 編譯器無警告（exhaustive switch）

### 用戶體驗驗收
- [ ] 載入狀態顯示正常，無 UI 閃爍
- [ ] 錯誤訊息清晰，重試按鈕可用
- [ ] 空狀態提示友好

---

## 依賴關係

### 前置依賴
- ✅ Week 3 完成：Repository Pattern 已實作
- ✅ DomainError 類型系統已定義（Week 5 可能提前實作）

### 後續依賴
- Week 5 將使用統一的狀態枚舉處理錯誤
- Week 6 UseCase 層將產生 ViewState

---

## 風險與緩解措施

### 中風險

#### 風險 1: 狀態遷移過程中可能遺漏狀態更新
**影響**: UI 無法正確響應數據變化
**緩解措施**:
- 使用編譯器的 exhaustive switch 檢查
- 完整的單元測試覆蓋所有狀態轉換
- Code Review 確保所有分支被處理

#### 風險 2: 現有 UI 邏輯可能依賴多個 @Published 屬性
**影響**: 重構過程中可能破壞現有功能
**緩解措施**:
- 逐步遷移，保持功能驗證
- 充分的 UI 測試驗證視覺正確性
- 回歸測試確保無功能退化

### 低風險

#### 風險 3: 共享 UI 組件設計不夠靈活
**影響**: 特殊場景無法使用共享組件
**緩解措施**:
- 提供足夠的可配置參數
- 允許自定義外觀和行為
- 保留特殊場景使用自定義 View 的能力

---

## 實作計劃

### Phase 1: ViewState 枚舉設計 (0.5 天)
- 定義 ViewState 枚舉
- 實作便利方法（isLoading, data, error）
- 實作 Equatable conformance

### Phase 2: ViewModel 重構 (1 天)
- 重構 TrainingPlanViewModel 使用單一狀態
- 移除分散的 @Published 屬性
- 更新所有狀態轉換邏輯

### Phase 3: View 層更新 (1 天)
- 重構 TrainingPlanView 使用 switch 處理狀態
- 更新所有 UI 分支邏輯
- 確保編譯器無警告

### Phase 4: 共享 UI 組件實作 (0.5 天)
- 實作 ErrorView 組件
- 實作 EmptyStateView 組件
- 測試組件可重用性

### Phase 5: 測試與驗證 (0.5 天)
- 編寫 ViewState 單元測試
- 編寫 ViewModel 狀態轉換測試
- 執行 UI 測試驗證顯示正確性

---

## 設計決策

### 決策 1: 使用枚舉而非類型系統
**原因**:
- Swift 枚舉天然支援關聯值
- 編譯器可檢查 exhaustive switch
- 性能優於類型層級結構

### 決策 2: 保留 empty 狀態作為可選
**原因**:
- 某些場景需要區分「載入中」和「無數據」
- 提供更好的用戶體驗
- 可選使用，不強制

### 決策 3: 共享 UI 組件使用 SwiftUI
**原因**:
- 與現有 View 層技術棧一致
- 易於自定義和擴展
- 支援預覽和即時調試

---

## 參考文檔

- [ARCH-002: Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [ARCH-003: 遷移路線圖](../01-architecture/ARCH-003-Migration-Roadmap.md)
- Flutter 版本: ARCH-004 資料流設計（ViewState 模式參考）

---

**文檔版本**: 1.0
**撰寫日期**: 2025-12-30
**負責人**: iOS Team
**審核人**: Tech Lead
