---
type: SPEC
id: SPEC-settings-and-feedback-management
status: Draft
ontology_entity: settings-feedback-management
created: 2026-04-15
updated: 2026-04-15
---

# Feature Spec: 系統設定與 Feedback 管理

## 背景與動機

目前 `UserProfileView` 已提供語言、單位、時區與 feedback 回報入口，這些都是真實存在的產品功能，但尚未形成獨立規格。沒有文件時，後續很容易把同步邏輯、確認流程或回報欄位需求改壞。

## 相容性

- profile 入口與區塊順序遵循 `Docs/specs/SPEC-profile-and-data-integration-management.md`

## 需求

### AC-SETTINGS-01: 語言與單位設定必須在同一頁管理

Given 使用者打開語言設定頁，  
When 畫面載入完成，  
Then 系統必須同時提供語言與單位設定，不得要求使用者分別找兩個入口。

### AC-SETTINGS-02: 語言變更必須先同步成功，才套用本地並重啟

Given 使用者變更 app 語言，  
When 點擊儲存，  
Then 系統必須先完成後端同步；只有同步成功後才套用本地語言並觸發 app restart，失敗時需回滾 UI 選擇並顯示錯誤。

### AC-SETTINGS-03: 單位系統變更不得要求重啟

Given 使用者只變更公英制單位，  
When 儲存成功，  
Then 系統必須直接更新設定並返回，不得要求 restart。

### AC-SETTINGS-04: 時區設定變更前必須再次確認

Given 使用者在時區設定頁選擇新的時區，  
When 點擊儲存，  
Then 系統必須先顯示警示說明其對顯示時間與統計的影響，使用者確認後才可送出更新。

### AC-SETTINGS-05: Feedback 表單必須要求描述，並可選擇問題類型與分類

Given 使用者打開 feedback 回報頁，  
When 準備提交回報，  
Then 系統必須至少要求填寫描述，並讓使用者選擇 issue / suggestion；若是 issue，還需提供 category。

### AC-SETTINGS-06: Feedback 必須支援受控附件與聯絡資訊

Given 使用者要補充回報內容，  
When 上傳附件或填寫聯絡方式，  
Then 系統必須支援附圖、隱藏 email 開關與可編輯聯絡信箱，且單張圖片超過 5MB 時不得送出。

### AC-SETTINGS-07: Feedback 送出時必須自帶必要系統資訊

Given 使用者提交 feedback，  
When 系統建立 payload，  
Then 必須附帶 app version、device info 與使用者帳號資訊，讓後續追查不需要再次向使用者索取基本上下文。

## 明確不包含

- App Store 評分與外部客服流程
- Debug / 內部測試工具入口
