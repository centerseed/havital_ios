---
parent_plan: apps/ios/Havital/Docs/plans/PLAN-iap-pre-review-hardening.md
created: 2026-04-27
status: ready
duration: 60-90 分鐘
---

# IAP 送審前 Sandbox 驗證 SOP

上 App Store 審查前最後一道人工驗證，確認 Apple 審查員實測時不會踩雷。

---

## 開始前確認（一次性）

| 項目 | 說明 |
|------|------|
| 裝置 | iOS 17.0+ 真機（iPhone 13+），已透過 TestFlight 安裝 build |
| Sandbox Apple ID | ASC → 使用者與存取 → Sandbox Testers 建的帳號（**不是**你的 prod Apple ID） |
| 裝置設定 | 設定 → App Store → 沙盒帳號 → 切換到上面那個 sandbox Apple ID |
| Terminal | `cd /Users/wubaizong/havital/cloud/api_service && conda activate api` |

---

## Reset 指令速查

```bash
# 全新用戶（trial cleared）
python agent_tools/reset_iap_for_sandbox_test.py --email centerseedwu@gmail.com --password 'YOUR_PASSWORD' --mode fresh

# 強制 expired（確保 paywall 出現）
python agent_tools/reset_iap_for_sandbox_test.py ... --mode force-expired

# 恢復 trial（trial_end_at = now+30）
python agent_tools/reset_iap_for_sandbox_test.py ... --mode restore-trial
```

腳本會自動備份當前狀態到 `/tmp/iap_backup_<uid>_<timestamp>.json`。

---

## 場景總覽

| # | 場景 | Reset | 阻擋送審 |
|---|------|-------|---------|
| S1 | 新用戶 onboarding → 主頁沒有 banner | `fresh` | ✅ |
| S2 | 生成 Week 1 → banner 出現、可點開 paywall | 接 S1 | ✅ |
| S3 | Paywall disclosure 連結 + 試用結束日期 | 接 S2 | ✅ |
| S4 | 訂閱年方案（30 天 trial）→ 解鎖、banner 消失 | `fresh` | ✅ |
| S5 | Settings 顯示 Trial / Expired / Trial 三種 tier | 接 S4 | ✅ |
| S6 | 刪除重裝 → Restore Purchases | `fresh` + S4 | ✅ |
| S7 | 取消訂閱 → 期限內仍可用 | 接 S4 | ✅ |
| S8 | Backend webhook security（curl 假請求） | 不需要 | ⚠️ |
| S9 | i18n 三語（EN / JA） | 不需要 | ✅ |
| S10 | Edge cases（離線、快轉） | 依需要 | ⚠️ |

✅ = 任一 FAIL 不送審　⚠️ = partial 可送審但記錄 follow-up

---

## S1：新用戶 onboarding

**Reset：** `fresh`

1. 刪除 App → 重裝 → 用 sandbox Apple ID 登入
2. 完成 onboarding → 進主頁

**✓ 主頁頂部沒有 Free tier banner（Week 1 尚未生成），有生成課表的 CTA**

---

## S2：生成 Week 1 → banner 出現

**Reset：** 接 S1

1. 點生成 Week 1 課表 → 等 30-90 秒
2. 退回主頁

**✓ banner 出現：「免費體驗期 / 下週課表需訂閱解鎖 / 升級」**
**✓ 點 banner → paywall sheet 開啟**

---

## S3：Paywall disclosure

**Reset：** 接 S2

1. 從 S2 開啟 paywall → 預設 focus Yearly card → 滾到底部
2. 點「隱私政策」→ 看 SFSafariViewController（不離開 App）→ swipe down 回來
3. 點「服務條款」→ 同上
4. 切到 Monthly card → 看 disclosure 文案

**✓ Yearly：disclosure 有具體試用結束日期（今天 + 30 天）**
**✓ 兩個連結可點、在 App 內開啟、頁面 HTTP 200**
**✓ Monthly：只顯示「月訂閱將立即扣款並自動續訂」，沒有試用日期**

---

## S4：訂閱年方案

**Reset：** `fresh`（重跑完整流程）

1. 進主頁（已生 Week 1）→ 點 banner → paywall
2. focus Yearly → 點「30 天免費試用」CTA
3. Apple confirmation sheet → 確認顯示的是 sandbox Apple ID → 點「訂閱」
4. 等 30 秒（backend sync）

**✓ Confirmation sheet 金額 NT$0.00**
**✓ 30 秒內 banner 消失**
**✓ 設定頁：「目前方案：試用中（剩 30 天）」**
**✓ 生 Week 2 不再出 paywall**

> **⚠️ 如果 30 秒後 banner 還在：** 再等 30 秒 → 還沒好 → pull-to-refresh → 仍然沒消 = app bug，記下來。

---

## S5：Settings tier 三種狀態

**Reset：** 接 S4（目前 trial 中）

1. 設定頁 → Subscription 區 → 截圖
2. 執行 `force-expired` → 重啟 App → 設定頁截圖
3. 執行 `restore-trial` → 重啟 App → 設定頁截圖

**✓ Trial：「試用中（剩 X 天）」**
**✓ Expired：「Free 免費體驗版」+ 「升級至完整版」CTA，點 CTA → paywall 開啟**
**✓ Restore trial：「試用中（剩 30 天）」**

---

## S6：Restore Purchases

**Reset：** `fresh` → 走 S4 訂閱

1. 訂閱完成後刪除 App → 重裝 → 登入同一個帳號
2. 進主頁（預期顯示未訂閱）→ 開 paywall → 點底部「恢復購買」

**✓ 1-3 秒內顯示「已恢復訂閱」**
**✓ paywall 關閉、banner 消失、設定頁 tier 恢復正確**

---

## S7：取消訂閱

**Reset：** 確保 S4 完成（訂閱中）

1. 設定頁 → 訂閱管理 → 跳到 Apple 系統頁
2. 取消訂閱 → 回到 App

**✓ 設定頁顯示「訂閱已取消，服務至 X 月 X 日」**
**✓ 期限截止前仍可生 Week 2（premium 功能不被擋）**

---

## S8：Backend webhook security

**Reset：** 不需要

1. GCP Console → Cloud Logging → paceriz-prod，過濾：
   ```
   resource.labels.service_name="api-service"
   jsonPayload.event=("webhook_auth_failed" OR "webhook_unknown_user" OR "webhook_malformed")
   ```
2. 在 App 跑 S4 訂閱，觀察 log（正常流程不該出現 auth_failed）
3. 用 curl 發假 webhook（無 auth header）：
   ```bash
   curl -X POST https://api-service-bui2xc5qhq-de.a.run.app/api/v1/subscription/webhook/revenuecat \
     -H "Content-Type: application/json" \
     -d '{"event":{"id":"test-fake","type":"INITIAL_PURCHASE","app_user_id":"fake-uid"}}'
   ```

**✓ 正常訂閱 → 無 webhook_auth_failed log**
**✓ 假請求 → 出現 webhook_auth_failed，含 client_ip、auth_header_present=False**
**✓ log 中不含任何 secret 內容**

---

## S9：i18n 三語

**Reset：** 不需要（確保 free tier 狀態）

1. 裝置語言切換到 **English** → 開 App → 看主頁 banner、paywall disclosure、設定頁 tier
2. 裝置語言切換到 **日本語** → 重複上述

**✓ EN banner：「Free Preview / Next week's plan requires subscription / Upgrade」**
**✓ EN disclosure：「30-day free trial ends May 27, 2026」**
**✓ JA banner：「無料体験中 / 来週のプランは購読が必要です / アップグレード」**
**✓ JA disclosure：「2026年5月27日に終了」**
**✓ 三語均無 raw key（如 `paywall.free_tier.banner.title`）**

---

## S10：Edge cases

| 場景 | 操作 | 期望 |
|------|------|------|
| 離線開 App | 飛航模式 → 開 App | 既有訂閱狀態正常顯示，不會 logout |
| 訂閱後斷網 | S4 完成後立刻飛航 | 30 秒 timeout 後不顯示「未訂閱」 |
| Onboarding 中途斷網 | Onboarding 一半關 App | 重開後從斷點繼續，不跳付費頁 |
| 訂閱後立刻取消 | S4 → 立刻 S7 | 權限維持到期限結束 |
| Sandbox 快轉（3 分鐘 trial）| S4 訂閱後等 3 分鐘 | backend log 收到 RENEWAL 事件，tier 從「試用中」變「Premium」 |

---

## 完成後回傳報告

```
## Sandbox 驗證結果

S1: PASS / FAIL（簡述）
S2: PASS / FAIL
S3: PASS / FAIL
S4: PASS / FAIL
S5: PASS / FAIL
S6: PASS / FAIL
S7: PASS / FAIL
S8: PASS / FAIL
S9: PASS / FAIL
S10: PASS / FAIL（含快轉觀察結果）

阻擋送審項目：{列出，或「無」}
結論：{送審 / 修 X 後再送}
```

---

## 已知 limitation（不阻擋送審）

- **優惠碼**：One-Time Codes 必須訂閱項目過審後才能建，sandbox 無法完整測，送審後第一版上線時補測。
- **Web Privacy / Terms 三語**：目前只有 zh-TW，en/ja 翻譯下個 sprint 補，Apple 審查接受 zh-TW（送審地區台灣）。
