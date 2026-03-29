# 課表編輯功能測試報告

**日期**: 2026-03-28
**版本**: dev (dev_train_V2 branch)
**測試環境**: iPhone 17 Simulator, iOS 26.2
**課表類型**: Maintenance (aerobic_endurance), Week 1/12

## 測試結果

| # | 測試項目 | 結果 | 說明 |
|---|--------|------|------|
| E1 | 進入編輯→取消→資料不變 | ✅ | Maestro 驗證通過 |
| E2 | 改訓練類型→儲存→主畫面驗證 | ✅ (重測通過) | 後端修復後，輕鬆跑→恢復跑儲存成功且主畫面正確顯示 |
| E3 | 套用建議配速→儲存→驗證 | ✅ | 配速從 6:45 改成 6:40，儲存後再進編輯確認保留 |
| E4 | 力量訓練（補充）展開顯示 | ✅ | 棒式/死蟲式/鳥狗式/側棒式 正確顯示 |
| E5 | 訓練說明 i18n | ✅ (重測通過) | 不再顯示 i18n key |

## BUG 記錄

### BUG-E2: 訓練類型修改儲存後主畫面未更新
- **嚴重度**: Major
- **重現步驟**:
  1. 主畫面 → 更多 → 編輯課表
  2. 點星期一「輕鬆跑」dropdown → 選「恢復跑」
  3. 編輯頁面確認顯示「恢復跑」✅
  4. 點「儲存」→ 成功回到主畫面
  5. 星期一仍顯示「輕鬆跑」❌
- **預期**: 星期一顯示「恢復跑」
- **實際**: 星期一顯示「輕鬆跑」
- **額外觀察**: 週跑量從 0/14 變成 0/18，說明 API 有更新，但訓練類型沒有反映
- **截圖**: /tmp/edit_test/19_e2_fail.png
- **可能原因**:
  1. 儲存 API 回傳的 plan 沒有包含訓練類型修改
  2. 主畫面用了快取未重載
  3. DTO → Entity mapping 沒有正確傳遞 training type 變更

### BUG-E5: 訓練說明顯示 i18n key
- **嚴重度**: Minor
- **重現**: 編輯課表 → 點齒輪 → 訓練說明欄顯示 `training.descriptions.easy`
- **截圖**: /tmp/edit_test/06_gear_tap.png

## 正常項目

### E3: 配速修改成功保留
- 進編輯 sheet → 點「套用」建議配速 → 配速從 6:45 變 6:40
- 儲存 sheet → 儲存週課表 → 回到主畫面
- 再進編輯確認配速仍為 6:40 ✅

### E4: 力量訓練（補充方式）正確顯示
- Maintenance aerobic_endurance 課表的力量訓練以 supplementary 方式掛在輕鬆跑下
- 展開星期一看到：核心穩定訓練 15 分鐘 + 力量訓練（棒式/死蟲式/鳥狗式/側棒式）
- 這是 config 中 `_inject_supplementary_strength` 的設計，不是 bug

## 待測項目（需手動測試）
- E6: 換天（拖動排序）→ 儲存 → 驗證
  - 原因：SwiftUI List `.onMove` 的 drag handle 需要長按+拖動的組合操作，Maestro 和 MCP swipe 都無法觸發
  - **特別關注**：帶力量訓練（supplementary）的輕鬆跑日移動後，力量訓練是否跟著移動
- E7: 修改距離 → 儲存 → 驗證
  - 原因：距離 stepper 不是 accessibility element，Maestro 無法操作
