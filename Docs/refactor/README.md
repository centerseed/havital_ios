# Paceriz iOS App - Clean Architecture 重構計劃

**版本**: 1.0
**最後更新**: 2026-01-03
**狀態**: 🔄 進行中

---

## 概述

本文檔規劃 Paceriz iOS App 向 Clean Architecture 全面遷移的重構計劃，以 **TrainingPlan Feature** 為參考實現（詳見 [ARCH-005](../01-architecture/ARCH-005-TrainingPlan-Reference-Implementation.md)），系統化地重構其他 Features。

---

## 重構目標

### 架構目標
- **100% Clean Architecture 符合度**: 所有 Features 遵循 Presentation → Domain → Data 分層
- **統一依賴注入**: 全面使用 DependencyContainer 管理依賴
- **可測試性**: 所有業務邏輯可獨立單元測試（覆蓋率 > 85%）
- **維護性**: 清晰的職責分離，易於擴展和修改

### 質量目標
- **零編譯錯誤**: 每個階段完成後確保構建成功
- **零功能回歸**: 重構不改變現有功能行為
- **完整測試覆蓋**: 關鍵業務邏輯 100% 測試覆蓋
- **文檔完整性**: 每個 Feature 都有架構文檔

---

## 文檔結構

本目錄包含以下重構規劃文檔：

### 核心規劃文檔

1. **[總體路線圖](./REFACTOR-001-Roadmap.md)** 📋
   - 所有 Features 重構優先級排序
   - 時間線與里程碑
   - 依賴關係圖
   - 資源分配建議

2. **[Feature 重構計劃](./REFACTOR-002-Feature-Plans.md)** 🎯
   - Workout Feature 重構計劃
   - UserProfile Feature 重構計劃
   - Authentication Feature 重構計劃
   - VDOT Feature 重構計劃
   - TrainingReadiness Feature 重構計劃
   - Integration Features 重構計劃

3. **[風險評估與緩解](./REFACTOR-003-Risk-Assessment.md)** ⚠️
   - 技術風險識別
   - 業務風險評估
   - 緩解策略
   - 回滾計劃

4. **[測試策略](./REFACTOR-004-Testing-Strategy.md)** ✅
   - 單元測試規範
   - 整合測試策略
   - 回歸測試計劃
   - 測試自動化

---

## 重構原則

### 1. 漸進式重構 (Incremental Refactoring)
- **一次一個 Feature**: 避免大範圍同時修改
- **保持可構建**: 每個提交都能成功編譯運行
- **獨立分支**: 每個 Feature 在獨立分支重構
- **及時合併**: 完成測試後立即合併回主分支

### 2. 參考實現驅動 (Reference-Driven)
- **遵循 ARCH-005**: 所有 Features 遵循 TrainingPlan 的架構模式
- **模式複用**: Repository、Use Case、DI 模式一致
- **命名規範**: 統一文件和方法命名約定
- **文檔同步**: 每個 Feature 更新架構文檔

### 3. 測試優先 (Test-First)
- **先寫測試**: 重構前為現有功能添加測試
- **保持綠燈**: 重構過程中測試持續通過
- **覆蓋率優先**: Use Cases 覆蓋率 > 90%
- **自動化驗證**: CI/CD 自動運行測試

### 4. 最小風險 (Minimal Risk)
- **向後兼容**: 保留舊接口直到新接口穩定
- **Feature Flag**: 使用 Feature Flag 控制新代碼啟用
- **金絲雀發布**: 新功能先小範圍驗證
- **快速回滾**: 保持隨時回滾能力

---

## 重構階段劃分

### Phase 1: 基礎設施 (已完成 ✅)
**時間**: Week 1-2
**狀態**: ✅ 完成

- [x] Clean Architecture 架構分析 (ARCH-001)
- [x] 目標架構設計 (ARCH-002)
- [x] 遷移路線圖 (ARCH-003)
- [x] 資料流設計 (ARCH-004)
- [x] TrainingPlan 參考實現 (ARCH-005)

### Phase 2: 核心 Features (進行中 🔄)
**時間**: Week 3-6
**狀態**: 🔄 進行中

優先級排序：
1. **Workout Feature** (Week 3) - 🔥 高優先級
   - TrainingPlan 依賴 Workout 數據
   - 使用頻率最高的功能
   - 數據流複雜度高

2. **UserProfile Feature** (Week 4) - 🔥 高優先級
   - 核心用戶數據管理
   - 多處功能依賴用戶資料
   - 相對獨立，風險較低

3. **VDOT Feature** (Week 5) - ⚠️ 中優先級
   - 獨立功能模組
   - 業務邏輯清晰
   - 適合作為練習案例

4. **TrainingReadiness Feature** (Week 6) - ⚠️ 中優先級
   - 獨立健康數據分析功能
   - 依賴 HealthKit 和 Workout 數據
   - 業務邏輯相對複雜

### Phase 3: 認證與整合 (規劃中 📋)
**時間**: Week 7-8
**狀態**: 📋 規劃中

1. **Authentication Feature** (Week 7) - ⚠️ 中優先級
   - 代碼已相對簡潔
   - 需要特別注意安全性
   - 影響範圍廣

2. **Integration Features** (Week 8) - ℹ️ 低優先級
   - Garmin 整合
   - Strava 整合
   - 第三方 API 封裝

### Phase 4: 優化與完善 (規劃中 📋)
**時間**: Week 9-10
**狀態**: 📋 規劃中

- [ ] 統一錯誤處理機制
- [ ] 性能優化與緩存策略調整
- [ ] 完整回歸測試
- [ ] 架構文檔最終審查

---

## 成功指標

### 架構質量指標
| 指標 | 當前值 | 目標值 | 狀態 |
|-----|-------|-------|------|
| Clean Architecture 符合度 | 65% | 100% | 🔄 進行中 |
| Repository Pattern 覆蓋率 | 15% | 100% | 🔄 進行中 |
| Use Case 封裝率 | 10% | 80% | 🔄 進行中 |
| DI 使用率 | 20% | 100% | 🔄 進行中 |

### 測試覆蓋率指標
| 層級 | 當前值 | 目標值 | 狀態 |
|-----|-------|-------|------|
| Domain Layer (Use Cases) | N/A | > 90% | 📋 規劃中 |
| Data Layer (Repositories) | 15% | > 80% | 🔄 進行中 |
| Presentation Layer (ViewModels) | 25% | > 80% | 🔄 進行中 |
| 整合測試 | 10% | > 60% | 📋 規劃中 |

### 代碼質量指標
| 指標 | 當前值 | 目標值 | 狀態 |
|-----|-------|-------|------|
| 編譯警告數 | ~50 | 0 | 🔄 進行中 |
| 循環依賴 | 3 | 0 | 📋 規劃中 |
| 最大文件行數 | 800+ | < 400 | 🔄 進行中 |
| 平均方法長度 | ~40 行 | < 20 行 | 📋 規劃中 |

---

## 資源需求

### 人力資源
- **iOS 開發者**: 1-2 人
- **QA 測試**: 1 人（兼職）
- **架構審查**: 定期 Code Review

### 時間估算
- **Phase 2**: 4 週（核心 Features）
- **Phase 3**: 2 週（認證與整合）
- **Phase 4**: 2 週（優化與完善）
- **總計**: 8-10 週

### 風險預留
- **緩衝時間**: 每個 Phase 預留 20% 時間處理意外問題
- **回滾時間**: 每個 Feature 預留 1 天回滾測試

---

## 下一步行動

### 立即行動 (本週)
1. 閱讀 [REFACTOR-002-Feature-Plans.md](./REFACTOR-002-Feature-Plans.md) 了解各 Feature 重構細節
2. 開始 Workout Feature 重構（參考 Workout 重構計劃）
3. 建立測試基礎設施（參考 REFACTOR-004）

### 短期目標 (2-4 週)
1. 完成 Workout Feature 重構並測試
2. 完成 UserProfile Feature 重構並測試
3. 更新架構符合度至 80%+

### 長期目標 (2-3 個月)
1. 完成所有核心 Features 重構
2. 達成 100% Clean Architecture 符合度
3. 建立完整的測試套件（覆蓋率 > 85%）

---

## 相關文檔

### 架構文檔
- [ARCH-001: 現狀分析](../01-architecture/ARCH-001-Current-State-Analysis.md)
- [ARCH-002: Clean Architecture 設計](../01-architecture/ARCH-002-Clean-Architecture-Design.md)
- [ARCH-003: 遷移路線圖](../01-architecture/ARCH-003-Migration-Roadmap.md)
- [ARCH-004: 資料流設計](../01-architecture/ARCH-004-Data-Flow.md)
- [ARCH-005: TrainingPlan 參考實現](../01-architecture/ARCH-005-TrainingPlan-Reference-Implementation.md) ⭐

### 重構文檔
- [REFACTOR-001: 總體路線圖](./REFACTOR-001-Roadmap.md)
- [REFACTOR-002: Feature 重構計劃](./REFACTOR-002-Feature-Plans.md)
- [REFACTOR-003: 風險評估](./REFACTOR-003-Risk-Assessment.md)
- [REFACTOR-004: 測試策略](./REFACTOR-004-Testing-Strategy.md)

---

**文檔版本**: 1.0
**撰寫日期**: 2026-01-03
**維護者**: Paceriz iOS Team
**參考**: ARCH-005 TrainingPlan Reference Implementation
