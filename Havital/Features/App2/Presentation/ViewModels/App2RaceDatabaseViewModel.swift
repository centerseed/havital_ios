import Foundation

// MARK: - App2RaceDatabaseViewModel
/// Presentation Layer — 2.0 賽事資料庫（設計 **frame-14**）。
///
/// **資料路徑就是 1.x 那一條**：`RaceRepository.getRaces(...)` → `GET /v2/races`
/// （與 `RaceEventListView` 用的是同一個 repository，沒有第二條 HTTP 路徑）。
/// 這一層只有設計新增的篩選狀態：地區三段（全部／台灣／日本，1.x 的
/// `RacePickerDataSource.selectedRegion` 沒有「全部」）、距離 chip、關鍵字。
///
/// 精選範圍沿用 1.x：`curatedOnly = true`（與 onboarding 的賽事挑選同一份母體）。
@MainActor
final class App2RaceDatabaseViewModel: ObservableObject, TaskManageable {

    /// 設計 frame-14 的地區三段。
    enum Region: String, CaseIterable, Identifiable {
        case all, taiwan, japan
        var id: String { rawValue }

        /// `GET /v2/races` 的 `region` 值；`all` 不帶這個參數。
        var apiValue: String? {
            switch self {
            case .all:    return nil
            case .taiwan: return "tw"
            case .japan:  return "jp"
            }
        }

        var titleKey: String {
            switch self {
            case .all:    return L10n.App2.Races.regionAll
            case .taiwan: return L10n.App2.Races.regionTw
            case .japan:  return L10n.App2.Races.regionJp
            }
        }
    }

    /// 設計 frame-14 的距離 chip。`all` 不帶距離區間。
    enum DistanceFilter: String, CaseIterable, Identifiable {
        case all, full, half, tenK, fiveK
        var id: String { rawValue }

        /// 篩選用的公里數；`all` 為 nil。容差 ±1 km —— 賽事庫的 `distance_km`
        /// 有 `42.0` 也有 `42.195`（dev 實測），太緊的區間會把全馬濾光。
        var km: Double? {
            switch self {
            case .all:   return nil
            case .full:  return 42.195
            case .half:  return 21.0975
            case .tenK:  return 10
            case .fiveK: return 5
            }
        }

        var title: String {
            guard let km else { return L10n.App2.Races.filterAll.localized }
            return App2OnboardingFormat.distanceLabel(km: km)
        }
    }

    // MARK: - Published

    @Published var query: String = ""
    @Published var region: Region = .all
    @Published var distance: DistanceFilter = .all
    @Published private(set) var results: [RaceEvent] = []
    @Published private(set) var isLoading = false
    /// 賽事庫打不通。空結果與「讀不到」是兩件事，畫面要分得開。
    @Published private(set) var isUnavailable = false

    nonisolated let taskRegistry = TaskRegistry()

    private let raceRepository: RaceRepository
    /// 打字時每一鍵都打一次 API 不划算 —— 沿用 1.x 賽事清單的 debounce 做法。
    private var searchTask: Task<Void, Never>?

    private static let distanceTolerance: Double = 1.0
    private static let resultLimit = 60

    init(raceRepository: RaceRepository? = nil) {
        if let raceRepository {
            self.raceRepository = raceRepository
        } else {
            let container = DependencyContainer.shared
            if !container.isRegistered(RaceRepository.self) {
                container.registerRaceModule()
            }
            self.raceRepository = container.resolve() as RaceRepository
        }
    }

    deinit {
        searchTask?.cancel()
        cancelAllTasks()
    }

    // MARK: - Loading

    func load() async {
        isLoading = results.isEmpty
        defer { isLoading = false }
        do {
            let km = distance.km
            results = try await raceRepository.getRaces(
                region: region.apiValue,
                distanceMin: km.map { $0 - Self.distanceTolerance },
                distanceMax: km.map { $0 + Self.distanceTolerance },
                // 已結束超過兩週的賽事不再列出（2026-08-27 使用者裁決）：
                // 報不了名的過期賽事只是噪音；剛結束兩週內保留，補登剛跑完的賽果用。
                dateFrom: Self.endedRaceCutoff(),
                dateTo: nil,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : query,
                curatedOnly: true,
                limit: Self.resultLimit,
                offset: nil
            )
            isUnavailable = false
        } catch {
            guard !error.isCancellationError else { return }
            Logger.warn("[App2RaceDatabaseVM] 賽事庫取得失敗: \(error.localizedDescription)")
            results = []
            isUnavailable = true
        }
    }

    /// 篩選條件變動：立刻重打（chip／地區是明確的動作，不需要 debounce）。
    func filtersChanged() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in await self?.load() }
    }

    /// 關鍵字變動：延遲 300ms 再打。
    func queryChanged() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    #if DEBUG
    func applyForTesting(results: [RaceEvent], isUnavailable: Bool = false) {
        self.results = results
        self.isUnavailable = isUnavailable
        isLoading = false
    }
    #endif

    // MARK: - 挑選

    /// 從賽事庫挑一場 → 填回新增賽事的表單（設計 frame-14 每列右側的 `＋`）。
    ///
    /// 距離的挑法與 1.x 的賽事挑選一致：**優先當前 chip 指定的距離**，
    /// 沒有就取這場賽事最長的一項（大多數賽會的主項目）。
    static func fill(_ form: App2RaceForm, with event: RaceEvent, distance: DistanceFilter) -> App2RaceForm {
        var updated = form
        let picked = Self.pickedDistance(event: event, filter: distance)
        updated.name = event.name
        updated.date = event.eventDate
        updated.raceId = event.raceId
        if let picked {
            updated.distanceKey = App2RaceManagementViewModel.distanceKey(forKm: Int(picked.distanceKm))
        }
        return updated
    }

    /// 今天（用戶時區）往回 14 天的 `YYYY-MM-DD`——`dateFrom` 是伺服器端過濾，
    /// 賽事日早於這條線＝已結束超過兩週，不進列表。
    static func endedRaceCutoff(now: Date = Date()) -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: cutoff)
    }

    static func pickedDistance(event: RaceEvent, filter: DistanceFilter) -> RaceDistance? {
        if let km = filter.km,
           let matched = event.distances.first(where: { abs($0.distanceKm - km) <= distanceTolerance }) {
            return matched
        }
        return event.distances.max { $0.distanceKm < $1.distanceKm }
    }
}
