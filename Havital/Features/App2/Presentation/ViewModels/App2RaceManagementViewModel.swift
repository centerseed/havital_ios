import Foundation

// MARK: - App2RaceForm
/// 新增／編輯賽事的表單狀態（設計 **frame-13**）。
///
/// 欄位與既有的 `BaseSupportingTargetViewModel`／`EditTargetViewModel` 一致
/// （名稱／距離／日期／時分秒／race_id），只是 2.0 把「主要／支援」收成一個開關，
/// 不再是兩條分開的畫面路徑 —— 後端本來就用同一個 `is_main_race` 欄位表示。
struct App2RaceForm: Equatable {
    /// nil = 新增；有值 = 編輯既有賽事。
    var targetId: String?
    var name: String = ""
    /// 距離字串，沿用既有的 `selectedDistance` 表述（`"42.195"`）。
    var distanceKey: String = "21.0975"
    var date: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0
    var makeMain: Bool = false
    /// 賽事庫 id；手動輸入為 nil（與 1.x 同一個語意）。
    var raceId: String?
    /// 編輯時保留原時區，不因為改了別的欄位就把賽事時區換掉。
    var timezone: String = "Asia/Taipei"
    /// 這一筆目前就是主要賽事 —— 開關鎖住（要換主要賽事得從另一場設過來）。
    var isCurrentMain: Bool = false

    var distanceKm: Double { Double(distanceKey) ?? 21.0975 }

    var totalSeconds: Int { hours * 3600 + minutes * 60 + seconds }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && totalSeconds > 0
    }

    /// `5:41`／nil（還沒填完就不顯示配速卡）。與 1.x 的 `targetPace` 同一條算式。
    var paceLabel: String? {
        guard totalSeconds > 0, distanceKm > 0 else { return nil }
        let paceSeconds = Int(Double(totalSeconds) / distanceKm)
        return String(format: "%d:%02d", paceSeconds / 60, paceSeconds % 60)
    }

    /// 距離改成非標準值時要斷開賽事庫綁定（同 `BaseSupportingTargetViewModel.clearRaceSelection`）。
    mutating func clearRaceBinding() {
        raceId = nil
    }
}

// MARK: - App2RaceManagementViewModel
/// Presentation Layer — 2.0 賽事管理（設計 **frame-12／13／14**）。
///
/// **邏輯全部沿用既有實作**，這一層只有版面狀態：
///
/// | 事情 | 誰做 |
/// |---|---|
/// | 讀主要／支援賽事 | `TargetRepository.getTargets()`（dual-track 快取） |
/// | 新增／編輯／刪除 | `TargetRepository.createTarget` / `updateTarget` / `deleteTarget` |
/// | 「設為主要」 | 同一支 `updateTarget`，把 `is_main_race` 設成 true |
/// | 賽事庫搜尋 | `RaceRepository`（`GET /v2/races`），見 `App2RaceDatabaseViewModel` |
///
/// 「設定新的主要賽事時，原本的主要賽事會自動變成支援賽事」（設計 frame-12 副標）
/// **是後端的行為，不是 app 端補的**：`RaceGoalService.create_target` / `update_target`
/// 在 `is_main_race` 為真時會呼叫 `demote_other_main_race_targets`
/// （`cloud/api_service/domains/race_goal/service.py`）。所以 app 端只送一次寫入，
/// 不自己再去把舊的主要賽事改成支援 —— 那會是第二份規則。
@MainActor
final class App2RaceManagementViewModel: ObservableObject, TaskManageable {

    // MARK: - Published

    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published private(set) var mainRace: App2RaceCard?
    @Published private(set) var supportingRaces: [App2RaceCard] = []
    @Published var errorMessage: String?

    private(set) var hasLoaded = false

    nonisolated let taskRegistry = TaskRegistry()

    private let targetRepository: TargetRepository
    /// 投影過的卡片背後的原始 target，編輯時要拿回未顯示的欄位（時區、race_id…）。
    private var targetsById: [String: Target] = [:]

    // MARK: - Init

    init(targetRepository: TargetRepository? = nil) {
        if let targetRepository {
            self.targetRepository = targetRepository
        } else {
            let container = DependencyContainer.shared
            if !container.isRegistered(TargetRepository.self) {
                container.registerTargetModule()
            }
            self.targetRepository = container.resolve() as TargetRepository
        }
    }

    deinit {
        cancelAllTasks()
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        isLoading = !hasLoaded
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            apply(try await targetRepository.getTargets())
        } catch {
            guard !error.isCancellationError else { return }
            Logger.debug("[App2RaceMgmtVM] targets 取得失敗: \(error)")
            // 已經有畫面資料就保留它（SWR）；第一次就失敗才報錯。
            if !hasLoaded { errorMessage = error.localizedDescription }
        }
    }

    private func apply(_ targets: [Target]) {
        targetsById = Dictionary(targets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let cards = Self.cards(from: targets)
        mainRace = cards.first { $0.isMain }
        supportingRaces = cards.filter { !$0.isMain }
    }

    // MARK: - 表單

    /// 新增：空表單。已經有主要賽事時開關預設關閉（設計 frame-13 的預設態）。
    func newRaceForm() -> App2RaceForm {
        App2RaceForm(makeMain: mainRace == nil)
    }

    /// 編輯：把既有 target 的每一欄填回表單（含不顯示在卡片上的時區與 race_id）。
    func editForm(for id: String) -> App2RaceForm? {
        guard let target = targetsById[id] else { return nil }
        var form = App2RaceForm()
        form.targetId = target.id
        form.name = target.name
        form.distanceKey = Self.distanceKey(forKm: target.distanceKm)
        form.date = Date(timeIntervalSince1970: TimeInterval(target.raceDate))
        form.hours = target.targetTime / 3600
        form.minutes = (target.targetTime % 3600) / 60
        form.seconds = target.targetTime % 60
        form.makeMain = target.isMainRace
        form.isCurrentMain = target.isMainRace
        form.raceId = target.raceId
        form.timezone = target.timezone
        return form
    }

    // MARK: - 寫入

    /// 新增或更新一場賽事。回傳是否成功（呼叫端據此關閉表單）。
    @discardableResult
    func save(_ form: App2RaceForm) async -> Bool {
        guard form.isValid else { return false }
        isSaving = true
        defer { isSaving = false }

        let target = Self.target(from: form)
        do {
            if let id = form.targetId {
                _ = try await targetRepository.updateTarget(id: id, target: target)
            } else {
                _ = try await targetRepository.createTarget(target)
            }
            await reloadAfterWrite()
            return true
        } catch {
            guard !error.isCancellationError else { return false }
            Logger.error("[App2RaceMgmtVM] 賽事寫入失敗: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 把一場支援賽事設為主要。舊的主要賽事由後端自動降級（見檔頭）。
    func setAsMain(_ id: String) async {
        guard let existing = targetsById[id] else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await targetRepository.updateTarget(
                id: id,
                target: Self.promotedToMain(existing)
            )
            await reloadAfterWrite()
        } catch {
            guard !error.isCancellationError else { return }
            Logger.error("[App2RaceMgmtVM] 設為主要賽事失敗: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ id: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await targetRepository.deleteTarget(id: id)
            await reloadAfterWrite()
        } catch {
            guard !error.isCancellationError else { return }
            Logger.error("[App2RaceMgmtVM] 刪除賽事失敗: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// 寫入之後一律 `forceRefresh`：主要／支援的翻轉發生在後端，只讀本機快取會看到舊狀態。
    private func reloadAfterWrite() async {
        do {
            apply(try await targetRepository.forceRefresh())
        } catch {
            guard !error.isCancellationError else { return }
            Logger.debug("[App2RaceMgmtVM] 寫入後重取失敗: \(error)")
        }
    }

    #if DEBUG
    /// 測試／預覽用：直接填卡片，不打網路。
    func applyForTesting(targets: [Target]) {
        apply(targets)
        isLoading = false
        hasLoaded = true
    }
    #endif

    // MARK: - 投影（純函式，可單獨測）

    /// 主要賽事在前，支援賽事依日期由近到遠（設計 frame-12「依日期排序」）。
    static func cards(from targets: [Target], now: Date = Date()) -> [App2RaceCard] {
        let sorted = targets.sorted { lhs, rhs in
            if lhs.isMainRace != rhs.isMainRace { return lhs.isMainRace }
            return lhs.raceDate < rhs.raceDate
        }
        return sorted.map { target in
            App2RaceCard(
                id: target.id,
                name: target.name,
                dateLabel: App2PlanOverviewViewModel.localDateString(
                    fromEpochSeconds: target.raceDate,
                    timezone: target.timezone
                ),
                distanceLabel: App2OnboardingFormat.distanceLabel(km: Double(target.distanceKm)),
                countdownDays: Self.countdownDays(epochSeconds: target.raceDate, now: now),
                goalTime: target.targetTime > 0
                    ? App2OnboardingFormat.duration(target.targetTime)
                    : nil,
                isMain: target.isMainRace
            )
        }
    }

    /// 倒數天數。以裝置日曆的日起點相減 —— 比較的是「哪一天」，不是「差幾個 24 小時」。
    static func countdownDays(epochSeconds: Int, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let raceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(epochSeconds)))
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: raceDay).day ?? 0
    }

    /// 表單 → `Target`。**訓練週數由賽事日期推**（同 1.x 的 `remainingWeeks`），
    /// 後端 `create_target` / `update_target` 也會自己再算一次。
    static func target(from form: App2RaceForm, now: Date = Date()) -> Target {
        let weeks = max(
            Calendar.current.dateComponents([.weekOfYear], from: now, to: form.date).weekOfYear ?? 0,
            1
        )
        return Target(
            id: form.targetId ?? "",
            type: "race_run",
            name: form.name.trimmingCharacters(in: .whitespacesAndNewlines),
            distanceKm: Int(form.distanceKm),
            targetTime: form.totalSeconds,
            targetPace: form.paceLabel ?? "",
            raceDate: Int(form.date.timeIntervalSince1970),
            isMainRace: form.makeMain,
            trainingWeeks: weeks,
            timezone: form.timezone,
            raceId: form.raceId
        )
    }

    /// 「設為主要」＝同一筆 target，只有 `is_main_race` 換成 true。其餘欄位原樣送回，
    /// 免得 PUT 的 merge 把沒帶的欄位擦掉。
    static func promotedToMain(_ target: Target) -> Target {
        Target(
            id: target.id,
            type: target.type,
            name: target.name,
            distanceKm: target.distanceKm,
            targetTime: target.targetTime,
            targetPace: target.targetPace,
            raceDate: target.raceDate,
            isMainRace: true,
            trainingWeeks: target.trainingWeeks,
            timezone: target.timezone,
            raceId: target.raceId
        )
    }

    /// `distance_km`（整數公里）→ 表單用的距離字串。標準距離要能回到帶小數的那一個
    /// （42 → `42.195`），否則編輯一次就會把全馬存成 42.0 km。
    static func distanceKey(forKm km: Int) -> String {
        switch km {
        case 42: return "42.195"
        case 21: return "21.0975"
        case 10: return "10"
        case 5:  return "5"
        default: return String(km)
        }
    }
}
