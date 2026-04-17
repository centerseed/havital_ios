# Paceriz iOS 架構重構計畫

## 目標

將現有架構從**混亂的職責分配**改進為**Clean Architecture**，達成：

1. **可維護性** - 改一處不會壞多處
2. **可測試性** - 單元測試覆蓋率 >85%
3. **修復現有問題** - 解決循環依賴、race conditions
4. **為新功能鋪路** - 清晰的模組邊界

## 採用方案

**完整 Clean Architecture** (方案 A)

## 預估時間

8 週全職開發

## 文檔結構

| 文檔 | 內容 |
|------|------|
| [01-CURRENT-ISSUES.md](01-CURRENT-ISSUES.md) | 當前架構問題分析 |
| [02-TARGET-ARCHITECTURE.md](02-TARGET-ARCHITECTURE.md) | 目標架構設計 |
| [03-MIGRATION-ROADMAP.md](03-MIGRATION-ROADMAP.md) | 遷移路線圖 |
| [04-MODULE-BREAKDOWN.md](04-MODULE-BREAKDOWN.md) | God Object 拆分計畫 |

## 核心原則

1. **保留現有優點** - TaskManageable、雙軌緩存、API 追蹤
2. **漸進式遷移** - 使用 Facade 模式維持向後兼容
3. **Feature 模組化** - 按功能領域組織，非技術層
4. **Protocol 優先** - 先定義介面，再實作
5. **統一狀態管理** - ViewState<T> 取代多個 @Published 變數
