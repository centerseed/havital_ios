---
parent_plan: apps/ios/Havital/Docs/plans/PLAN-iap-pre-review-hardening.md
created: 2026-04-27
status: ready
purpose: TestFlight sandbox 上送審前最後一道驗證
duration: 60-90 分鐘
---

# IAP Pre-Review Sandbox 驗證 SOP

> 上 App Store 審查前**最後一道**人工驗證流程。把所有 P0 場景在真機 TestFlight 沙盒環境跑一次，確認 Apple 審查員實測時不會踩雷。

## 前置條件

- [ ] iOS 17.0+ 真機（iPhone 13 以上）
- [ ] TestFlight build 已上傳到 App Store Connect 且狀態為「測試就緒 / Ready to Test」
- [ ] 已加入 TestFlight 內部測試人員
- [ ] **Sandbox Apple ID** 已建好（**不是**你的 prod Apple ID，必須是 ASC → 使用者與存取 → Sandbox Testers 建的測試帳號）
- [ ] iPhone「設定 → App Store → 沙盒帳號」已切換到 sandbox Apple ID
- [ ] 你 Paceriz 帳號 email/password（用於跑 reset 腳本）
- [ ] Mac terminal 可執行：
  ```bash
  cd /Users/wubaizong/havital/cloud/api_service && conda activate api
  ```

## Reset 工具用法

每個場景開始前要把訂閱狀態重置到指定起點。Reset 腳本路徑：
`cloud/api_service/agent_tools/reset_iap_for_sandbox_test.py`

```bash
# 模式 1：清成全新用戶（status=expired, trial cleared）
python agent_tools/reset_iap_for_sandbox_test.py \
    --email centerseedwu@gmail.com \
    --password 'YOUR_PASSWORD' \
    --mode fresh

# 模式 2：強制 expired（paywall 必觸發）
python agent_tools/reset_iap_for_sandbox_test.py ... --mode force-expired

# 模式 3：恢復 trial 狀態（trial_end_at = now+30）
python agent_tools/reset_iap_for_sandbox_test.py ... --mode restore-trial
```

腳本會自動 backup 當前狀態到 `/tmp/iap_backup_<uid>_<timestamp>.json`，需要的話可手動還原。

---

## 場景驗證清單（10 個 P0 場景）

每個場景跑完打勾。**任何一項 FAIL 必須先解決才能送審**。

### S1：新用戶 onboarding → 看到 Free tier banner

**Reset**：`--mode fresh`

**步驟**：
1. 重裝 App（先刪除）→ 開啟
2. 用 sandbox Apple ID 登入（或 demo login + 已 reset 的 prod 帳號）
3. 完成 onboarding
4. 進入主頁

**期望結果**：
- [ ] 主頁頂部**沒有** Free tier banner（因為還沒生 Week 1 課表）
- [ ] 顯示生成 Week 1 課表的 CTA

**對應 AC**：AC-PAYWALL-35（hidden state without W1）

---

### S2：生成 Week 1 → Free tier banner 出現

**Reset**：接 S1 不重置

**步驟**：
1. 主畫面點生成 Week 1 課表
2. 等待生成完成（30-90 秒）
3. 看到 Week 1 課表內容
4. 退到主頁、再進主頁

**期望結果**：
- [ ] Week 1 課表正確生成
- [ ] 主頁頂部出現 **Free tier banner**：「免費體驗期 / 下週課表需訂閱解鎖 / 升級」
- [ ] 點 banner → paywall sheet 開啟

**對應 AC**：AC-PAYWALL-35（visible state with W1）

---

### S3：Paywall 顯示——disclosure 連結 + 試用結束日期

**Reset**：接 S2 不重置

**步驟**：
1. 從 S2 點 banner 開啟 paywall sheet
2. 確認 focus 在 Yearly card（預設應該是）
3. 把 sheet 滾到底部看 disclosure 區
4. 點「**隱私政策**」連結
5. 看 SFSafariViewController 跳出
6. swipe down 回到 paywall
7. 點「**服務條款**」連結
8. 看 SFSafariViewController 再跳出
9. 切到 **Monthly card**，再看 disclosure

**期望結果**：
- [ ] Yearly focus 時 disclosure 包含**具體試用結束日期**（如「試用至 2026 年 5 月 27 日」），日期 = 今天 + 30 天
- [ ] 「隱私政策」「服務條款」**有底線 / 高亮**（可點擊）
- [ ] 點擊隱私政策 → SFSafariViewController（**不離開 App**）開啟 paceriz.com/privacy，**HTTP 200**，看到「隱私權政策 - Paceriz」標題
- [ ] 點擊服務條款 → 同上 paceriz.com/terms，看到「服務條款 - Paceriz」
- [ ] swipe down 回到 paywall 正常顯示
- [ ] Monthly card focus → disclosure **不顯示**試用日期，只顯示「月訂閱將立即扣款並自動續訂」

**對應 AC**：AC-PAYWALL-32 / 33 / 34

---

### S4：訂閱年方案（30 天 trial）→ 解鎖

**Reset**：`--mode fresh`（重新跑一次完整訂閱流程）

**步驟**：
1. App 進主頁（已生 Week 1）→ 點 Free tier banner / 升級 CTA
2. paywall sheet → focus Yearly → 點「30 天免費試用」CTA
3. Apple StoreKit confirmation sheet 跳出
4. 確認 sandbox Apple ID 顯示（**不是** prod Apple ID）
5. 點「Subscribe」/「訂閱」→ 走完 sandbox 訂閱流程
6. 訂閱完成後 paywall sheet 自動關閉
7. **30 秒內**等 backend sync

**期望結果**：
- [ ] Apple confirmation sheet 顯示金額為 NT$0.00（因為 trial）
- [ ] 訂閱完成後跳轉回主畫面
- [ ] **30 秒內**主頁 Free tier banner 消失
- [ ] 設定頁 Subscription 區顯示「目前方案：**試用中（剩 30 天）**」
- [ ] 嘗試生 Week 2 課表 → 不會再出 paywall，正常生成

**對應 AC**：AC-PAYWALL-31 / 36 / 27（trial 用戶解鎖功能）

**⚠️ 失敗 race condition**：如果 30 秒內 banner 沒消失，**有可能** webhook 還沒處理完。再等 30 秒。如果還是不行 → 重新整理主頁（pull-to-refresh）。仍然不行 → **app bug**，記下來給 Architect。

---

### S5：Settings tier 標示——Trial / Premium / Free 三種狀態

**Reset**：S4 完成後接做（trial 中）

**步驟**：
1. 進設定頁 → Subscription 區
2. 截圖記錄當下顯示
3. 重置成 expired：`--mode force-expired`
4. 重啟 App，再進設定頁
5. 重置成 trial：`--mode restore-trial`
6. 重啟 App，再進設定頁

**期望結果**：
- [ ] Trial 中：「目前方案：**試用中（剩 X 天）**」（X 為實際剩餘天數）
- [ ] Force-expired 後：「目前方案：**Free 免費體驗版**」+「升級至完整版」CTA
- [ ] 點「升級至完整版」→ paywall sheet 開啟
- [ ] Restore-trial 後：「目前方案：**試用中（剩 30 天）**」

**對應 AC**：AC-PAYWALL-36（三種 tier label）

---

### S6：Restore Purchases

**Reset**：先 `--mode fresh`，再走 S4 訂閱

**步驟**：
1. S4 訂閱完成後，刪除 App
2. 重裝 App，登入同一個 prod 帳號
3. 完成 onboarding（如果需要）→ 進主頁
4. 主頁 banner / paywall 預期顯示「未訂閱」
5. paywall sheet → 點底部「**恢復購買**」按鈕
6. 等 1-2 秒

**期望結果**：
- [ ] 「恢復購買」按鈕在 paywall 底部明顯可見
- [ ] 點擊後出現 loading 指示
- [ ] 1-3 秒內顯示「已恢復訂閱」或類似提示
- [ ] paywall sheet 自動關閉
- [ ] 主頁 Free tier banner 消失
- [ ] 設定頁 tier 變回「試用中」或「Premium」

**對應 AC**：AC-PAYWALL-03（restore button always visible）

---

### S7：取消訂閱

**Reset**：先確保處於訂閱中（S4 完成後）

**步驟**：
1. 進設定頁 → 訂閱管理 / Manage Subscription
2. 跳轉到 Apple 系統訂閱管理頁（**離開 App**到設定）
3. 點「取消訂閱」
4. 確認取消
5. 回到 Paceriz App
6. 再進設定頁 Subscription 區

**期望結果**：
- [ ] 「管理訂閱」CTA 連到 Apple 系統頁
- [ ] Apple 訂閱管理頁顯示 Paceriz 訂閱 + 取消按鈕
- [ ] 取消後回到 App，設定頁顯示**「訂閱已取消，服務至 X 月 X 日」**或類似 wording
- [ ] 已付款週期內仍可用 premium 功能（生 Week 2 / AI 功能不被擋）

**對應 AC**：AC-SUB-02（cancellation 維持期限）+ AC-PAYWALL-36

---

### S8：Backend webhook security（搭配 backend log 看）

**Reset**：不需要

**步驟**：
1. 開瀏覽器 GCP Console → Cloud Logging → paceriz-prod
2. 過濾：`resource.labels.service_name="api-service"` AND `jsonPayload.event="webhook_auth_failed" OR jsonPayload.event="webhook_unknown_user" OR jsonPayload.event="webhook_malformed"`
3. 在 App 內走 S4 訂閱流程
4. 等 1-2 分鐘看 log
5. 額外測試：用 curl 發一個假 webhook（沒 auth）：
   ```bash
   curl -X POST https://api-service-bui2xc5qhq-de.a.run.app/api/v1/subscription/webhook/revenuecat \
     -H "Content-Type: application/json" \
     -d '{"event":{"id":"test-fake","type":"INITIAL_PURCHASE","app_user_id":"fake-uid"}}'
   ```

**期望結果**：
- [ ] 正常訂閱流程**不應該**出現 `webhook_auth_failed` log（RC 是用對的 secret）
- [ ] 上面 curl 應該出現 `webhook_auth_failed` log，含 `client_ip` 和 `auth_header_present=False`
- [ ] log 中**絕不**含 secret 內容
- [ ] 假 UID curl（如果你帶 secret）應該觸發 `webhook_unknown_user` log

**對應 AC**：P0-16 / P0-17 / P0-18（backend hardening）

---

### S9：i18n 三語驗證

**Reset**：不需要

**步驟**：
1. 切換 iPhone 系統語言為 **English**
2. 開 Paceriz App → 主頁（free tier 狀態）→ 看 banner 文案
3. 開 paywall → 看 disclosure
4. 進設定頁看 tier label
5. 切換系統語言為 **日本語**
6. 重複上述

**期望結果**：
- [ ] **English**：banner 顯示 "Free Preview" / "Next week's plan requires subscription" / "Upgrade"
- [ ] **English**：disclosure 顯示 "30-day free trial ends May 27, 2026" 之類
- [ ] **English**：設定頁顯示 "Current plan: Free Preview" 等
- [ ] **日本語**：banner 顯示 「無料体験中」「来週のプランは購読が必要です」「アップグレード」
- [ ] **日本語**：disclosure 顯示日期格式「2026年5月27日に終了」
- [ ] **日本語**：設定頁顯示「現在のプラン：無料体験版」
- [ ] **沒有出現**任何 raw key（如 `paywall.free_tier.banner.title`）

**對應 AC**：AC-PAYWALL-30（三語齊備）

---

### S10：Edge cases

**Reset**：依需要

**步驟與檢查**：
- [ ] **離線狀態**：飛航模式下開 App → 既有訂閱狀態仍能正常顯示（cached）；不會因為 API 失敗就把人 logout
- [ ] **訂閱期間網路斷**：訂閱動作完成後立刻飛航 → backend sync timeout（30 秒）後 UI 不會錯誤地說「未訂閱」（應該顯示「處理中，請稍候」）
- [ ] **Onboarding 中途斷網**：onboarding 一半關 App → 重開 → 從上次斷點繼續或重來，**不會**直接進付費頁（free tier 不該強制訂閱）
- [ ] **訂閱後立刻取消**：S4 訂閱 → 立刻 S7 取消 → 確認權限維持到期限結束
- [ ] **Sandbox 訂閱「快轉」測試**：sandbox 環境下 Apple 提供快轉功能（30 天 trial 在 sandbox 是 3 分鐘），可測 trial → paid 自動轉換的 webhook：
  - S4 訂閱後等 3 分鐘
  - 看 backend log 是否收到 `RENEWAL` 事件（trial → NORMAL 轉換）
  - 主頁 / 設定頁 tier label 是否從「試用中」變「Premium」

---

## 通過判定

- ✅ **全部 PASS**：可以送 App Store 審查
- ⚠️ **S1-S7 + S9 PASS，S8 / S10 partial**：可送審但記錄 follow-up
- ❌ **任一 S1-S7 / S9 FAIL**：**不送審**，先讓 Architect 重派 Developer 修

## 失敗處理

任何 PASS / FAIL 結果都記下來。FAIL 時**先分類**：

| 分類 | 定義 | 動作 |
|------|------|------|
| App bug | 真實的 production 邏輯錯誤 | Architect 重派 Developer 修 |
| Test bug | sandbox 環境特殊狀況（如沙盒帳號被鎖）| 換沙盒帳號重試 |
| Environment issue | 網路 / 帳號 / TestFlight build 配置問題 | 修環境 |

## 完成後

跑完所有場景，回傳一份簡短驗證報告給 Architect：

```
## Sandbox 驗證結果

S1: PASS / FAIL（簡述）
S2: PASS / FAIL
...
S10: PASS / FAIL（含 sandbox 快轉觀察結果）

阻擋送審項目：{列出，或「無」}
建議：{送審 / 修 X 後再送 / 略}
```

Architect 看完做最終 AC sign-off → 送審。

## 已知 limitation（不阻擋送審）

- **Req2 / Req3 優惠碼無法在 sandbox 完整測**：One-Time Codes 必須訂閱項目過審後才能建（你的截圖已證實）。送審通過後第一個版本上線時測即可。
- **Web Privacy / Terms 三語**：目前只有 zh-TW 內容，i18n key 已 wired，但 en/ja 翻譯下個 sprint 補。Apple 審查接受 zh-TW（送審地區為台灣）。
