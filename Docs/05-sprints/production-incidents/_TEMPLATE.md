---
type: REF
id: INCIDENT-YYYY-MM-DD-NN
status: Draft
l2_entity: paceriz-ios
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Incident {YYYY-MM-DD-NN}: {short title}

## Meta

| 欄位 | 內容 |
|------|------|
| Incident ID | `YYYY-MM-DD-NN`（例：`2026-04-17-01`） |
| 發現時間 | `YYYY-MM-DDTHH:MM:SS+08:00` |
| 發現來源 | Crashlytics / gcloud logging / 用戶回報 / 內部 QA |
| 用戶 ID（Firebase UID） | 例：`2LagGwHas2dRhMPJxcKmlIVIBTm1`（若涉及特定用戶） |
| 受影響用戶數 | 例：`23 unique users in 7d`（從 log 推算） |
| App 版本 | 例：`1.2.2 (build 0)` |
| OS 版本 | 例：`iOS 26.4.1` |
| Status | `investigating` / `reproduced` / `fixed` / `verified` |

## 症狀

用戶看到什麼、做了什麼就卡住。一段白話敘述，避免技術術語。

## Backend 錯誤

- **gcloud log 連結**：<建議附 Cloud Logging Query URL 或貼上 query 字串>
- **關鍵 stack / message**：

```
{貼錯誤訊息，去識別化後}
```

- **首次出現時間**：`YYYY-MM-DDTHH:MM:SSZ`
- **出現頻率**：`N 次 / M 小時`

## Client 對應 log

- **模組**：例 `WorkoutBackgroundManager`
- **action**：例 `check_upload_error`
- **源碼位置**：`AuthenticationService.swift:673`
- **request_id（若有）**：`<uuid>` — 對應 backend log 同 request_id 的 entry
- **關鍵訊息**：

```
{貼 jsonPayload.message 去識別化後}
```

## 可重現性

| 項 | 內容 |
|---|------|
| 是否可重現 | ✅ yes / ❌ no / 🟡 間歇性 |
| 重現環境 | Simulator / Device (model) / OS version |
| 重現步驟 | 1. … 2. … 3. … |
| 重現所需前置資料 | 例：用戶需先完成 onboarding + 授權 HealthKit |

## 根因（root cause）

> 沒填這欄不能進 `fixed` status。

- **是什麼層級的問題**：UI / ViewModel / Repository / Data / 外部服務 / 環境
- **為什麼發生**：具體 code path 或設計缺陷
- **為什麼測試沒抓到**：⭐ 必填 — 缺哪一種測試？盲區在哪？

## 修復

| 項 | 內容 |
|---|------|
| 修復 commit | `<sha>` |
| 修改檔案 | `path/to/file.swift` |
| 相關 PR | <URL 或 N/A> |

## 回歸測試

> 沒補測試不能進 `verified` status。

| 項 | 內容 |
|---|------|
| 測試類型 | XCTest / Maestro flow / Manual simulator |
| 測試檔案 | `HavitalTests/…` 或 `.maestro/flows/…` |
| 測試 commit | `<sha>` |
| 測試如何抓到 | 簡述測試走過什麼 path、失敗後會出現什麼 assert |

## Production 驗證

- **驗證方式**：gcloud log 連續 N 天無同類錯誤 / 用戶確認修復 / Crashlytics 停止回報
- **驗證時間**：`YYYY-MM-DDTHH:MM:SS+08:00`

## 教訓

- 這個 incident 讓我們發現什麼設計或流程的盲區？
- 下次如何更早偵測到？
- 需不需要加新的 lint rule / CI gate / CLAUDE.md hard constraint？

## 關聯

- 相關 incident：`<YYYY-MM-DD-NN>`
- 相關 ADR：`ADR-XXX`
- 相關 task：`<zenos task id>`
