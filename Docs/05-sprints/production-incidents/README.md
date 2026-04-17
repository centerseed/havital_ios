---
type: REF
id: REF-production-incidents
status: Approved
l2_entity: paceriz-ios
created: 2026-04-17
updated: 2026-04-17
---

# Production Incidents

## 用途

集中追蹤 Paceriz iOS production 實際發生的「block 用戶」事件——目的是讓「看不見的 bug」變成「可追蹤的 incident」，並持續倒逼測試覆蓋。

這不是 bug backlog（那屬於 task 系統），而是「已確認影響 production 用戶」的事件紀錄。每一筆 incident 完成後，必須有對應的**回歸測試**，避免同類問題再次漏測。

## 何時建立 incident file

符合以下任一條件就要建：

- Firebase Crashlytics 出現 crash（任何非 NSURLErrorCancelled 類的 signal）
- gcloud logging 出現 Cloud Run 5xx / client 回報的 app_error_report 中，單一錯誤連續出現 3+ 次
- 用戶回報並確認可重現的 block 情境（無法繼續使用核心流程）
- 測試環境 PASS 但 production 失敗的情境（= 測試盲區）

## 流程

```
發現 incident
    ↓
從 _TEMPLATE.md 複製，命名為 YYYY-MM-DD-NN-{short-slug}.md
    ↓
填入症狀 / 錯誤 / 關聯 log（status: investigating）
    ↓
嘗試重現；能重現 → status: reproduced
    ↓
找到根因 → 寫 root cause，提交修復 commit（status: fixed）
    ↓
補上回歸測試（單元 / Maestro / XCTest），測試能抓到這個問題才算完成
    ↓
Production 驗證修復有效 → status: verified，incident 關檔
```

## 檔案命名規則

```
{ISO-date}-{序號}-{short-slug}.md

範例：
2026-04-17-01-initial-block-inventory.md
2026-04-18-01-healthkit-protected-data.md
2026-04-18-02-background-sync-task-registration.md
```

## 欄位規範

見 `_TEMPLATE.md`。禁止簡化——沒填 root cause 不能進 `fixed`，沒填回歸測試不能進 `verified`。

## 關聯 ID（request_id）

Client 端 `.tracked(from:)` API call 必須帶 `request_id`（UUID），backend 在 log 寫入時同樣記錄這個 ID。這樣 `docs/05-sprints/production-incidents/*.md` 的「Backend 錯誤」和「Client 對應 log」兩欄就能交叉對照。

⚠️ **當前狀態**：`request_id` 關聯機制尚未實作。Follow-up spec 待撰寫（see 2026-04-17-01）。

## 與 ZenOS 的關係

每筆 incident 完成後，建議以 `mcp__zenos__journal_write(flow_type="bugfix")` 記錄一筆，讓 ontology 能追蹤 incident 與 impact chain 的關係。
