---
type: SPEC
id: SPEC-training-plan-v1-legacy-boundary
status: Draft
ontology_entity: training-plan-v1-legacy-boundary
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: TrainingPlan V1 Legacy Boundary

## 背景與動機

`TrainingPlanView` 仍存在於 codebase，且承擔部分既有流程、通知與資料刷新邏輯，但產品主入口已轉向 `TrainingPlanV2View`。如果沒有一份 boundary spec，後續維護很容易讓 V1 被誤認為主流程，或在 refactor 時誤砍仍需維持的兼容行為。

## 目標

- 明確定義 V1 是 legacy flow，不再作為新功能預設載體
- 定義仍需維持的能力與可移除的範圍
- 為後續 deprecation 建立邊界

## 需求

### AC-V1-01: V1 必須被視為 legacy，而非新功能預設入口

Given app 已提供 `TrainingPlanV2View` 作為主訓練首頁，  
When 團隊規劃新功能或新 UI 入口，  
Then 不得以 V1 為預設落點，除非明確標註為 legacy 相容需求。

### AC-V1-02: V1 仍需維持基本可用性直到正式下線

Given 目前 codebase 仍保留 V1，  
When 使用者或內部流程進入 V1，  
Then V1 必須維持基本的訓練首頁、週回顧、新目標入口與個人資料入口，不得處於明顯壞掉但未宣告下線的狀態。

### AC-V1-03: V1 與 V2 的共用事件必須保持一致語義

Given onboarding 完成、user logout、回前景刷新等共享事件仍會被 V1 監聽，  
When 這些事件發生，  
Then V1 不得採用與 V2 完全衝突的語義，以免同一事件在兩個訓練入口產生不同結果。

### AC-V1-04: 新的產品規格若只適用 V2，必須明確標示不要求回補 V1

Given 團隊新增一份只針對 V2 的產品 spec，  
When spec 定義實作範圍，  
Then 文件必須明確標註 V1 是否在範圍內，避免開發誤以為兩個版本都要同步交付。

### AC-V1-05: V1 的下線前提必須是替代能力已在 V2 完整覆蓋

Given 團隊要移除 V1，  
When 評估是否可下線，  
Then 必須先確認 V2 已覆蓋 V1 仍對外承擔的核心能力，至少包含主訓練首頁、週回顧流程、重新設定目標與必要的資料刷新路徑。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-V1-01 | V1 視為 legacy，而非新功能預設入口 |
| AC-V1-02 | V1 在正式下線前維持基本可用性 |
| AC-V1-03 | V1 / V2 共用事件保持一致語義 |
| AC-V1-04 | 僅適用 V2 的 spec 必須明確標示不要求回補 V1 |
| AC-V1-05 | V1 下線前提是 V2 已完整覆蓋替代能力 |
