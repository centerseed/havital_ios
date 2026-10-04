---
type: SPEC
id: SPEC-ios-language-synchronization
status: Approved
layer: product
owns: iOS App 顯示語言與 backend language preference 的同步方向與失敗行為。
created: 2026-10-02
updated: 2026-10-02
approved_by: 2026-10-02 user decision; T-0858
---

# iOS language synchronization

## 語言定義

App 目前顯示的語言是 App 實際渲染用的語言。使用者在 App 內選過的語言優先；沒有選過時，App 把系統語言對到 `zh-TW`、`ja-JP` 或 `en-US`，對不到就使用預設 `zh-TW`。這個定義不因 backend 回傳的 language 改變。

## 同步規則

- App 開啟時（包含登入、重裝與換裝置），先讀 backend language，再和目前顯示語言比較；不同才把 App 語言寫回 backend，相同不寫。
- App 內改語言時，先把新語言寫回 backend；成功後才套用本地語言並重新整理畫面，失敗維持原語言並顯示錯誤。
- backend 不會反過來切換 App 顯示語言。啟動同步失敗時記錄 log、仍讓 App 繼續進入，下一次開啟再試。
- 若 App 先在未登入狀態啟動，登入成功後只執行語言 compare/write，不重跑整套用戶資料與服務初始化。
- `/auth/sync` 的 device locale 只代表裝置 metadata；登入與 session refresh 不得把過期的本機選擇旗標當成啟動同步的 authority。

## 驗法

1. backend readback 先設 `ja-JP`，讓 iOS App 顯示 `zh-TW` 開啟；確認 write 後 backend readback 為 `zh-TW`。
2. backend 與 App 都是 `zh-TW` 開啟；確認沒有 language write。
3. 在設定頁改語言；確認 PUT 成功後畫面立即使用新語言，PUT 失敗時畫面維持原語言。
4. backend 單獨改成另一語言再開啟；確認 App 畫面不被 backend 反向切換。
5. App 從未登入轉為登入；確認只發生語言 compare/write，沒有重跑整套用戶資料與服務初始化。
