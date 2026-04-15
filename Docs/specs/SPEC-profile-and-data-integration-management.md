---
type: SPEC
id: SPEC-profile-and-data-integration-management
status: Draft
ontology_entity: profile-data-integration-management
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: 個人資料與資料來源整合管理

## 背景與動機

`UserProfileView` 已承擔帳戶資訊、訓練設定、資料來源、語言/時區與帳戶操作，但目前只有訂閱區塊有較完整 spec。需要補上一份 profile shell 規格，讓未來改動不會把設定入口、整合管理與刪帳流程打散。

## 相容性

- 訂閱狀態與按鈕矩陣遵循 `SPEC-subscription-management-and-status-ui.md`
- 付費牆進入語境遵循 IAP / Subscription 相關 spec

## 需求

### AC-PROFILE-01: Profile 頁必須用穩定的區塊順序組織資訊

Given 使用者打開個人資料頁，  
When 畫面載入完成，  
Then 系統必須以帳戶、訂閱、訓練設定、資料來源、生理指標、系統設定與帳戶操作的順序呈現主要區塊。

### AC-PROFILE-02: Profile 頁必須提供明確的離開方式

Given 使用者從訓練首頁打開個人資料頁，  
When 位於頁面內，  
Then 導航列必須提供 Done 按鈕，讓使用者可關閉 profile 並返回原本上下文。

### AC-PROFILE-03: 訓練設定入口必須可編輯核心偏好

Given 使用者位於 profile，  
When 點擊每週跑量、訓練日或相關偏好設定入口，  
Then 系統必須打開對應編輯器，並在儲存後回到 profile 顯示最新值。

### AC-PROFILE-04: 資料來源區必須管理 Apple Health、Garmin、Strava 的連接狀態

Given 使用者位於資料來源區，  
When 查看或操作 Apple Health、Garmin、Strava 相關入口，  
Then 系統必須顯示目前狀態並允許連接、重新連接或切換。

### AC-PROFILE-05: 已被其他帳號綁定的整合必須提供明確提示

Given Garmin 或 Strava 帳號已被其他使用者綁定，  
When 當前使用者嘗試綁定，  
Then 系統必須顯示 already-bound 提示，而不是無聲失敗。

### AC-PROFILE-06: Profile 必須提供語言與時區設定入口

Given 使用者位於 profile，  
When 點擊語言或時區設定，  
Then 系統必須打開對應設定頁，讓使用者調整 app 的顯示語言與時區偏好。

### AC-PROFILE-07: 刪除帳戶必須經過不可逆確認

Given 使用者觸發刪除帳戶，  
When 系統展示確認流程，  
Then 必須清楚告知此操作不可復原，且只有在使用者再次確認後才可執行。

### AC-PROFILE-08: Profile 必須保留進入付費與除錯工具的受控入口

Given profile 中存在付費升級或 debug 工具入口，  
When 對應條件成立，  
Then 系統可顯示入口；不符合條件時不得讓一般使用者看到開發者工具。

## AC ID Index

本 spec 已採用穩定 AC-ID；以下索引作為派工、review 與測試引用入口。

| AC ID | 對應需求 |
|------|----------|
| AC-PROFILE-01 | Profile 以固定區塊順序呈現資訊 |
| AC-PROFILE-02 | Profile 提供明確離開方式 |
| AC-PROFILE-03 | 訓練設定入口可編輯核心偏好 |
| AC-PROFILE-04 | 資料來源區管理 Apple Health / Garmin / Strava 狀態 |
| AC-PROFILE-05 | already-bound 整合提供明確提示 |
| AC-PROFILE-06 | 提供語言與時區設定入口 |
| AC-PROFILE-07 | 刪除帳戶需不可逆確認 |
| AC-PROFILE-08 | 付費與 debug 入口受控顯示 |
