---
type: TEST
id: TEST-dual-track-cache-and-background-refresh
status: Draft
ontology_entity: dual-track-cache-strategy
source_spec: SPEC-dual-track-cache-and-background-refresh
created: 2026-04-15
updated: 2026-04-15
---

# Test Design: Dual-Track Cache 與 Background Refresh

## 目標

驗證 repository 層的雙軌快取策略符合 `SPEC-dual-track-cache-and-background-refresh`，重點是：

1. Track A 真的優先回快取
2. Track B 真的在背景刷新
3. 背景刷新失敗不會破壞 UI 現狀
4. force refresh、空集合與事件發布行為可預期

## 測試層級策略

| 層級 | 工具 | 目的 | Gate |
|---|---|---|---|
| Unit | XCTest | 驗證 `DualTrackCacheHelper` 與 repository 行為 | P0 必過 |
| Integration | XCTest + Mock DataSource / Repository | 驗證快取、事件與使用者邊界清理 | P0 必過 |
| UI Smoke | XCUITest | 驗證有 cache 時畫面不閃白、手動刷新可更新資料 | P1 應過 |

## 覆蓋矩陣（Spec → Test）

| Spec AC | 對應案例 |
|---|---|
| AC-CACHE-01 | P0-S01, P0-S02 |
| AC-CACHE-02 | P0-S03 |
| AC-CACHE-03 | P0-S04, P0-S05 |
| AC-CACHE-04 | P0-S06 |
| AC-CACHE-05 | P0-S07 |
| AC-CACHE-06 | P0-S08 |
| AC-CACHE-07 | P0-S09 |
| AC-CACHE-08 | P0-S10, P1-S01 |

## P0 場景（必須全部通過）

### S1: 單一物件 cache hit 時立即返回快取
層級：Unit
Given: `getCached()` 有值且 `isCacheExpired == false`
When: 呼叫 `DualTrackCacheHelper.execute`
Then: 立即回傳快取值，不等待 API 結束

### S2: 集合型 cache hit 時立即返回非空集合
層級：Unit
Given: `getCached()` 回傳非空集合
When: 呼叫 `DualTrackCacheHelper.executeForCollection`
Then: 立即回傳集合，並標記為 cache hit 路徑

### S3: cache hit 後會啟動背景刷新
層級：Unit / Integration
Given: Track A 已命中快取
When: repository 完成讀取
Then: Track B 會以背景任務發起 API 請求

### S4: 背景刷新失敗不影響當前資料
層級：Integration
Given: UI 已顯示快取資料，Track B API 失敗
When: 背景刷新結束
Then: 畫面仍保留原快取內容，不轉成主錯誤畫面

### S5: 背景刷新失敗只記錄非阻斷錯誤
層級：Unit
Given: `fetchFromAPI` 在背景刷新中丟錯
When: `backgroundRefresh` 結束
Then: 不將錯誤往上拋給前景呼叫者

### S6: cache miss 時直接打 API 並寫回快取
層級：Unit / Integration
Given: 本地沒有可用快取
When: 呼叫 repository 讀取
Then: 直接取 API，成功後寫入 local cache 並返回結果

### S7: force refresh 會繞過快取
層級：Unit / Integration
Given: 本地已有快取
When: 呼叫 repository `forceRefresh` 或等效強制刷新入口
Then: 不讀 Track A，直接打 API 並覆蓋快取

### S8: 空集合不得視為有效 cache hit
層級：Unit
Given: `executeForCollection` 的 `getCached()` 回傳空集合
When: 執行讀取
Then: 系統必須向 API 取資料，而不是回傳空集合結束

### S9: 背景刷新成功會透過 repository publisher 觸發資料更新事件
層級：Integration
Given: repository 使用 `backgroundRefresh(..., onComplete:)`，成功後送出 repository publisher
When: Track B 成功
Then: ViewModel 訂閱 repository publisher 後 republish，`CacheEventBus` 收到對應 `dataChanged` 事件

### S10: 登出後快取會被清理
層級：Integration
Given: repository 已有快取資料
When: 上層發出 logout / user switch 對應的清理流程
Then: repository cache 被清空，新 session 不會看到舊資料

## P1 場景（應通過）

### S1: 使用者切換後重新讀取不會混到前一位使用者資料
層級：Integration
Given: User A 快取已存在，接著切到 User B
When: User B 首次讀取相同 repository
Then: 不會先看到 User A 的快取內容

### S2: UI 在有快取時不應出現明顯白屏或 loading 閃爍
層級：UI Smoke
Given: 本地已有快取資料
When: 使用者重新進入對應頁面
Then: 畫面以內容為主，若有刷新也應是非阻斷式指示
