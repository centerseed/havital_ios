# ADR-006 — App2（2.0 shell）的模組拓撲

- 日期：2026-08-29
- 狀態：Accepted
- 關聯：T-0306（iOS 2.0 骨架）、`DESIGN-app2-decision-chain-api.md` §3、2026-08-29 外審 C01/C03/C12

## 決定

1. **`Features/App2` 是 presentation-only 模組**：只含 `Presentation/`（views、view models、
   theme、screen projection models）與 `Debug/`（DEBUG-only fixtures 預覽）。資料存取一律
   消費既有 feature 的 domain/data 出口（`TrainingPlanV2Repository`、`WorkoutRepository`、
   `WorkoutStatsDataSourceProtocol`…），不新建自己的 data 層。
2. **Screen projection 型別放 `Presentation/Models/`**（`App2Models.swift` 等）。它們是
   view-facing 投影（含 `App2DataOrigin` 樣本徽章），不是 domain entity——先前放在
   `Features/App2/Domain/` 是命名誤導，已搬正。
3. **冷啟快照庫 `App2SnapshotStore` 住 `Core/Storage/`**：`DailyStateRepositoryImpl`
   （feature 的 data 層）也落地到它，依賴方向必須是 Features → Core。它是顯示層快取
   （SWR 的「先舊後新」），不是第二份持久化真相；owner 與退場條件寫在檔頭。
4. **`DataSourceSwitchCoordinator`（UserProfile Domain）不得持有 presentation 型別**：
   偏好寫入走 `DataSourcePreferenceWriting` 協定，`UserProfileFeatureViewModel` 在
   presentation 側 conform。它協調既有的 `GarminManager`／`StravaManager`／
   `HealthKitManager` 與兩個 disconnect service——那是 1.4 `UserProfileView.switchDataSource`
   整段行為的唯一抽取（兩個版面共用，不複製第二份），不是新的業務層。

## 取捨

- 把 coordinator 再往下拆（OAuth／授權／解綁各自成件）會更「純」，但這段流程在 1.4 已
  端到端驗證過，2.0 上 TestFlight 前重排順序的風險大於收益。protocol 反轉先把依賴方向
  修正，細拆等有第二個消費者再說。
- App2 目前仍直接使用 `WorkoutRemoteDataSource` 等具象 data source（有 protocol 就依
  protocol）。`WorkoutRepository` 補齊可同步讀的落地快取後，`App2SnapshotStore` 中
  workouts 相關 key 併過去、該檔縮編（檔頭已記）。
