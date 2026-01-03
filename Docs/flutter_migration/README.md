# Paceriz Flutter 遷移文檔庫

## 📚 文檔導覽

歡迎來到 Paceriz Flutter 遷移專案的文檔中心。本文檔庫記錄了從 Swift/SwiftUI 到 Flutter 的完整遷移計畫和技術設計。

---

## 🗺️ 文檔索引

### 核心規劃文檔

1. **[00_MIGRATION_OVERVIEW.md](./00_MIGRATION_OVERVIEW.md)** 🎯
   **遷移概覽** - 遷移目標、範圍、時程表和關鍵決策記錄

2. **[01_ARCHITECTURE_DESIGN.md](./01_ARCHITECTURE_DESIGN.md)** 🏗️
   **Flutter 架構設計** - Clean Architecture 分層設計和資料流

3. **[09_MIGRATION_CHECKLIST.md](./09_MIGRATION_CHECKLIST.md)** ✅
   **遷移檢查清單** - 16 週遷移的每週任務清單

---

### 技術設計文檔

4. **[02_CACHE_STRATEGY.md](./02_CACHE_STRATEGY.md)** 💾
   **統一快取策略** - 雙軌快取設計和版本控制

5. **[03_API_DEDUPLICATION.md](./03_API_DEDUPLICATION.md)** 🔄
   **API 去重機制** - 自動化請求去重管理器

6. **[04_FEATURE_GATE_IAP.md](./04_FEATURE_GATE_IAP.md)** 🔐
   **IAP 功能門控** - 付費功能存取控制系統

7. **[05_DATA_MODELS.md](./05_DATA_MODELS.md)** 📊
   **資料模型對照** - Swift ↔ Flutter 資料模型映射

8. **[06_TRAINING_V2_DESIGN.md](./06_TRAINING_V2_DESIGN.md)** 🏃
   **Training V2 設計** - 多運動類型和 AI 生成演算法

9. **[07_APPLE_WATCH_SYNC.md](./07_APPLE_WATCH_SYNC.md)** ⌚
   **Apple Watch 同步** - Native Module 橋接方案

---

### 實作文檔

10. **[08_FIREBASE_SETUP.md](./08_FIREBASE_SETUP.md)** 🔥
    **Firebase 設定** - Dev/Prod 環境設置指南

11. **[10_TESTING_PLAN.md](./10_TESTING_PLAN.md)** 🧪
    **測試計畫** - 單元、整合、E2E 測試策略

12. **[11_DEPLOYMENT.md](./11_DEPLOYMENT.md)** 🚀
    **部署流程** - CI/CD 和灰度發佈策略

13. **[12_MONITORING.md](./12_MONITORING.md)** 📈
    **監控設定** - Sentry、Analytics、日誌策略

---

## 🚀 快速開始

### 如果你是新加入的開發者

1. **閱讀遷移概覽**：了解專案背景和目標
   👉 [00_MIGRATION_OVERVIEW.md](./00_MIGRATION_OVERVIEW.md)

2. **理解架構設計**：學習 Flutter 分層架構
   👉 [01_ARCHITECTURE_DESIGN.md](./01_ARCHITECTURE_DESIGN.md)

3. **查看檢查清單**：了解目前進度
   👉 [09_MIGRATION_CHECKLIST.md](./09_MIGRATION_CHECKLIST.md)

### 如果你負責特定模組

- **快取和資料管理**：[02_CACHE_STRATEGY.md](./02_CACHE_STRATEGY.md)
- **API 整合**：[03_API_DEDUPLICATION.md](./03_API_DEDUPLICATION.md)
- **IAP 付費功能**：[04_FEATURE_GATE_IAP.md](./04_FEATURE_GATE_IAP.md)
- **訓練計畫模組**：[06_TRAINING_V2_DESIGN.md](./06_TRAINING_V2_DESIGN.md)
- **Apple Watch**：[07_APPLE_WATCH_SYNC.md](./07_APPLE_WATCH_SYNC.md)

---

## 📊 專案狀態

| 階段 | 時程表 | 狀態 |
|------|--------|------|
| Phase 1: 基礎架構搭建 | Week 1-4 | 🟡 規劃中 |
| Phase 2: 核心功能遷移 | Week 5-10 | ⚪ 未開始 |
| Phase 3: 進階功能 | Week 11-14 | ⚪ 未開始 |
| Phase 4: 測試和發佈 | Week 15-16 | ⚪ 未開始 |

**目前進度**：文檔階段（第一批完成）| **預計完成**：2026-04-29（16 週後）

### 文檔完成狀態
**第一批（已完成）**：
- ✅ README.md - 文檔導航
- ✅ 00_MIGRATION_OVERVIEW.md - 遷移概覽
- ✅ 01_ARCHITECTURE_DESIGN.md - 架構設計
- ✅ 09_MIGRATION_CHECKLIST.md - 遷移檢查清單

**第二批（待建立）**：
- ⏳ 02_CACHE_STRATEGY.md - 快取策略
- ⏳ 03_API_DEDUPLICATION.md - API 去重
- ⏳ 05_DATA_MODELS.md - 資料模型
- ⏳ 08_FIREBASE_SETUP.md - Firebase 配置

---

## 🎯 關鍵目標

### 技術目標
- ✅ 程式碼量減少 30%
- ✅ API 呼叫減少 50%
- ✅ 單元測試覆蓋率 > 80%
- ✅ 啟動時間 < 2 秒

### 業務目標
- ✅ 使用者遷移率 > 95%
- ✅ 7 日留存率 > 70%
- ✅ IAP 轉換率 > 5%
- ✅ App Store 評分維持 4.5+

---

## 🏗️ 架構概覽

```
┌─────────────────────────────────────────┐
│     Presentation Layer (UI/BLoC)        │  ← pages/, bloc/, widgets/
├─────────────────────────────────────────┤
│     Domain Layer (Business Logic)       │  ← entities/, usecases/, repositories/
├─────────────────────────────────────────┤
│     Data Layer (API/Cache)              │  ← models/, datasources/, repositories_impl/
├─────────────────────────────────────────┤
│     Core Layer (Utils/DI/Network)       │  ← di/, cache/, network/
└─────────────────────────────────────────┘
```

**核心原則**：
- **簡潔**：清晰的職責分離，避免過度工程
- **雙軌快取**：立即顯示快取 + 背景重新整理
- **去重自動化**：API 請求自動去重
- **高擴充性**：支援多運動類型、IAP、Apple Watch

---

## 🔗 相關資源

### 內部資源
- [CLAUDE.md](../../CLAUDE.md) - Swift 版本的架構文檔
- [IAP_IMPLEMENTATION_PLAN.md](../IAP_IMPLEMENTATION_PLAN.md) - IAP 實作計畫（Swift 版本）

### 外部資源
- [Flutter 官方文檔](https://docs.flutter.dev/)
- [BLoC 模式文檔](https://bloclibrary.dev/)
- [Hive 資料庫](https://docs.hivedb.dev/)
- [in_app_purchase 套件](https://pub.dev/packages/in_app_purchase)

---

## 📝 貢獻指南

### 文檔更新流程

1. **修改文檔**：編輯對應的 Markdown 檔案
2. **更新索引**：在本 README.md 中更新狀態
3. **通知團隊**：在 Slack #paceriz-migration 頻道通知變更

### 文檔命名規範

- `00-13` 開頭：按閱讀順序編號
- 使用大寫字母和底線：`CACHE_STRATEGY.md`
- 使用 Emoji 圖示增強可讀性

---

## 📧 聯絡方式

**專案負責人**：技術團隊
**Slack 頻道**：#paceriz-migration
**文檔維護**：開發團隊

---

**最後更新**：2025-12-29
**文檔版本**：v1.0
