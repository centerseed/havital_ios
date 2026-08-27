import XCTest
@testable import paceriz_dev

/// 訓練詳情頁的投影（`App2SessionDetailProjection` 的純函式）。
///
/// 這一頁不打端點：首頁與課表頁手上那份 `DayDetail` 就是全部輸入，
/// 所以「payload → 畫面欄位」錯了沒有網路層擋著。482 行零測試是 2026-08-26
/// 架構紅隊點名的債，這裡把核心語意鎖住。
///
/// **不重複既有覆蓋**：`structureBars` 對「有 `segments[]`」的課已經在
/// `App2HomeProjectionTests`（趟數只算衝刺、質課展開順序）鎖住了。
/// 這裡只補那邊沒有的：`effectiveSegments` 攤平（後端對間歇課**不送**
/// `segments[]`）、10 根柱上限、配速帶邊界、`plannedSeconds` 推導、
/// 非跑步課沒有配速語意，以及逐日敘述的一致性閘門。
@MainActor
final class App2SessionDetailProjectionTests: XCTestCase {

    // MARK: - Helpers

    /// 真實 payload 形狀 → domain entity，走正式路徑上的同一支 mapper
    /// （同 `App2HomeProjectionTests` 的 `day()` 慣例）。
    private func day(_ json: String) throws -> DayDetail {
        TrainingSessionMapper.toEntity(
            from: try JSONDecoder().decode(DayDetailDTO.self, from: Data(json.utf8))
        )
    }

    /// 固定的週一（UTC），讓日期斷言不隨執行日漂移。
    private let weekStart = Date(timeIntervalSince1970: 1_754_784_000)

    /// `vdot: 0` ＝ 這個帳號沒有 VDOT（`App2SessionDetailProjection` 對 0 的處置與缺席
    /// 相同）。**測試一律明給**，不然配速帶會跟著執行機器上的 `VDOTManager` 漂。
    private func detail(
        _ json: String,
        vdot: Double = 0,
        climateDay: ClimateDay? = nil,
        isClimateAdjustmentEnabled: Bool = false
    ) throws -> App2SessionDetail? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return App2SessionDetailProjection.detail(
            day: try day(json),
            weekStart: weekStart,
            calendar: calendar,
            climateDay: climateDay,
            vdot: vdot,
            isClimateAdjustmentEnabled: isClimateAdjustmentEnabled
        )
    }

    /// 熱調整（`climate[7]` 的一天）。只有 `paceAdjustmentPct` 對配速帶有意義。
    private func climate(pct: Double) -> ClimateDay {
        ClimateDay(
            dayIndex: 2,
            date: "2026-08-11",
            feelsLikeTempC: 32,
            heatPressureLevel: "moderate",
            paceAdjustmentPct: pct,
            longRunKeepRatio: nil,
            reasonText: "體感偏熱",
            source: nil,
            warningLabel: nil,
            regionKey: nil,
            suggestedTrainingWindows: []
        )
    }

    // MARK: - Fixtures（dev `e1289e60f251_1` 的真實 payload 形狀）

    private let restDay = """
    { "day_index": 3, "day_target": "完全休息", "reason": "週三排休" }
    """

    /// 單段輕鬆跑：沒有 `segments[]`、沒有暖身緩和。`6:50` ＝ 410 秒／km。
    private let easyRunDay = """
    { "day_index": 2, "day_target": "輕鬆跑", "reason": "有氧維持", "distance_km": 8.0,
      "primary": { "run_type": "easy", "distance_km": 8.0, "pace": "6:50",
                   "duration_minutes": 55, "target_intensity": "low",
                   "description": "輕鬆跑" } }
    """

    /// 單段節奏跑：同樣是一整塊 steady，但**不是**輕鬆／恢復課。`5:00` ＝ 300 秒／km。
    private let tempoSteadyDay = """
    { "day_index": 4, "day_target": "節奏跑", "reason": "乳酸閾值", "distance_km": 8.0,
      "primary": { "run_type": "tempo", "distance_km": 8.0, "pace": "5:00",
                   "duration_minutes": 40, "target_intensity": "medium",
                   "description": "節奏跑" } }
    """

    /// **後端對間歇課不送 `segments[]`**（dev 實測）：只有 `primary.interval`。
    /// 4 × 400m @ 4:50、組間 200m @ 7:30；日層總量 5.2、`primary` 只有 2.2。
    private let intervalOnlyDay = """
    { "day_index": 3, "day_target": "間歇", "reason": "速耐力", "distance_km": 5.2,
      "warmup": { "distance_km": 2.0, "pace": "7:00" },
      "cooldown": { "distance_km": 1.0, "pace": "7:00" },
      "primary": { "run_type": "interval", "distance_km": 2.2, "target_intensity": "high",
        "interval": { "repeats": 4,
                      "work_distance_m": 400, "work_pace": "4:50",
                      "recovery_distance_m": 200, "recovery_pace": "7:30" } } }
    """

    /// 趟數多到畫不滿（柱數上限 10）。
    private let manyRepeatsDay = """
    { "day_index": 4, "day_target": "短間歇", "reason": "神經肌肉",
      "primary": { "run_type": "short_interval",
        "segments": [ { "kind": "interval", "repeats": 16,
                        "work": { "distance_m": 200, "pace": "4:20" },
                        "recovery": { "duration_seconds": 60 } } ] } }
    """

    private let strengthDay = """
    { "day_index": 6, "day_target": "肌力", "reason": "支撐跑量",
      "primary": { "strength_type": "core", "duration_minutes": 30,
        "exercises": [ { "name": "深蹲", "sets": 3, "reps": 12 },
                       { "name": "棒式", "sets": 3, "duration_seconds": 45 } ] } }
    """

    /// 輕鬆跑 ＋ 日層 `supplementary[]` 的核心穩定訓練
    /// （dev 帳號 `Cv5ADE73tiZMpEyD80Yh1BAqYch2` 本週 `day_index` 4 的形狀，
    /// 2026-08-27 實測：棒式 3×45s／死蟲式 3×12／鳥狗式 3×10／側棒式 2×30s）。
    private let runWithSupplementaryStrengthDay = """
    { "day_index": 4, "day_target": "輕鬆跑", "reason": "有氧維持", "distance_km": 6.0,
      "primary": { "run_type": "easy", "distance_km": 6.0, "pace": "6:50",
                   "duration_minutes": 41, "description": "輕鬆跑" },
      "supplementary": [ { "strength_type": "core_stability", "duration_minutes": 15,
        "description": "跑後做，維持軀幹穩定",
        "exercises": [ { "name": "棒式", "sets": 3, "duration_seconds": 45 },
                       { "name": "死蟲式", "sets": 3, "reps": 12 },
                       { "name": "鳥狗式", "sets": 3, "reps": 10 },
                       { "name": "側棒式", "sets": 2, "duration_seconds": 30 } ] } ] }
    """

    private let crossDay = """
    { "day_index": 7, "day_target": "交叉訓練", "reason": "低衝擊",
      "primary": { "cross_type": "cycling", "duration_minutes": 45,
                   "description": "騎車 45 分鐘" } }
    """

    // MARK: - 休息日不進詳情

    /// 設計沒有休息日的詳情版式；點下去只會看到一頁空卡。
    func test_detail_restDay_returnsNil() throws {
        XCTAssertNil(try detail(restDay))
    }

    // MARK: - effectiveSegments 攤平（後端不送 segments[] 的間歇課）

    /// 下游三個投影都只認 `segments[].kind == "interval"`。後端對間歇課只送
    /// `primary.interval`，攤平之後這一頁才拆得出衝刺與組間恢復
    /// —— 沒有攤平時整堂課被畫成一塊綠色穩定段（2026-08-26 使用者截圖）。
    func test_detailSegments_intervalWithoutSegmentsArray_expandsSprintRow() throws {
        let rows = App2SessionDetailProjection.detailSegments(day: try day(intervalOnlyDay))

        XCTAssertEqual(rows.count, 3, "熱身 → 衝刺 → 緩和")
        XCTAssertEqual(rows.map(\.index), [1, 2, 3])

        let sprint = try XCTUnwrap(rows.first { $0.repeatsLabel != nil })
        XCTAssertEqual(sprint.repeatsLabel, "× 4")
        XCTAssertEqual(sprint.detail, "400m @ 4:50")
        XCTAssertNotNil(sprint.note, "組間恢復掛在衝刺列的附註，不另開一列")

        XCTAssertFalse(rows[0].isWork, "熱身不是主課")
        XCTAssertFalse(rows[2].isWork, "緩和不是主課")
    }

    /// 同一份 payload 的結構圖也要拆得出趟（不攤平就只有一根穩定柱）。
    func test_structureBars_intervalWithoutSegmentsArray_drawsOneBarPerRep() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(intervalOnlyDay))
        XCTAssertEqual(bars.filter { $0.kind == .interval }.count, 4)
        XCTAssertEqual(bars.filter { $0.kind == .support }.count, 3, "趟與趟之間才有恢復柱")
        XCTAssertEqual(bars.first?.kind, .warmup)
        XCTAssertEqual(bars.last?.kind, .warmup)
    }

    /// 太多趟就不畫滿 —— 畫面上那格只有幾十 pt 寬。標註列仍講真實趟數。
    func test_structureBars_manyRepeats_capsBarsButKeepsRealCountInNote() throws {
        let bars = App2HomeViewModel.structureBars(day: try day(manyRepeatsDay))
        XCTAssertEqual(bars.filter { $0.kind == .interval }.count, 10)
        let note = try XCTUnwrap(bars.first { $0.noteDetail != nil }?.noteDetail)
        XCTAssertTrue(note.hasPrefix("16 × "), "標註列要講真實趟數，不是畫出來的根數：\(note)")
    }

    /// 單段課也有一列主課 —— 那也是結構，不是「沒有結構」；
    /// 且量與配速走與卡片同一支 `contentLine`，不另組一份字串。
    func test_detailSegments_singleSegmentRun_reusesCardContentLine() throws {
        let entity = try day(easyRunDay)
        let rows = App2SessionDetailProjection.detailSegments(day: entity)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0].isWork)
        XCTAssertEqual(
            rows[0].detail,
            App2PlanViewModel.contentLine(entity.session?.primary)
        )
    }

    // MARK: - 配速帶邊界（設計 frame-02c）

    /// 只有「整堂課就一段穩定跑」才有配速帶，邊界＝處方配速 ±15 秒。
    func test_paceBand_singleSteadyBar_bracketsPrescribedPace() throws {
        let band = try XCTUnwrap(try detail(easyRunDay)?.paceBand)
        let unitSystem = UnitManager.shared.currentUnitSystem

        XCTAssertEqual(band.paceUnitLabel, unitSystem.paceSuffix, "單位跟著用戶設定，不寫死 /km")
        XCTAssertEqual(band.paceLabel, App2SessionDetailProjection.paceLabel(410, unitSystem: unitSystem))
        XCTAssertEqual(
            band.fastLabel,
            App2SessionDetailProjection.paceLabel(410 - 15, unitSystem: unitSystem)
        )
        XCTAssertEqual(
            band.slowLabel,
            App2SessionDetailProjection.paceLabel(410 + 15, unitSystem: unitSystem)
        )
    }

    // MARK: - 配速帶：輕鬆跑取用戶配速區間（2026-08-27 走查裁決（n））

    /// 輕鬆跑的帶寬改成**用戶自己的輕鬆配速區間**，不是處方 ±15 秒的窄窗。
    ///
    /// VDOT 32 的輕鬆區間是 `6:40`–`8:00`（`PaceCalculator.getPaceRange(for:"easy",…)`，
    /// 與設定頁「配速區間」同一支），處方 `6:50` 落在區間內 —— pill 仍標處方配速。
    func test_paceBand_easyRun_usesUserEasyPaceRange() throws {
        let band = try XCTUnwrap(try detail(easyRunDay, vdot: 32)?.paceBand)
        let unitSystem = UnitManager.shared.currentUnitSystem
        let range = try XCTUnwrap(PaceCalculator.getPaceRange(for: "easy", vdot: 32))
        XCTAssertEqual(range.min, "6:40")
        XCTAssertEqual(range.max, "8:00")

        XCTAssertEqual(
            band.paceLabel,
            App2SessionDetailProjection.paceLabel(410, unitSystem: unitSystem),
            "處方配速仍標在帶上"
        )
        XCTAssertEqual(band.fastLabel, App2SessionDetailProjection.paceLabel(400, unitSystem: unitSystem))
        XCTAssertEqual(band.slowLabel, App2SessionDetailProjection.paceLabel(480, unitSystem: unitSystem))
    }

    /// 沒有 VDOT 就沒有「用戶的輕鬆區間」——退回處方 ±15 秒，不本機編一個區間。
    func test_paceBand_easyRunWithoutVDOT_fallsBackToPrescribedWindow() throws {
        let band = try XCTUnwrap(try detail(easyRunDay, vdot: 0)?.paceBand)
        let unitSystem = UnitManager.shared.currentUnitSystem
        XCTAssertEqual(band.fastLabel, App2SessionDetailProjection.paceLabel(410 - 15, unitSystem: unitSystem))
        XCTAssertEqual(band.slowLabel, App2SessionDetailProjection.paceLabel(410 + 15, unitSystem: unitSystem))
    }

    /// **只有輕鬆跑／恢復跑**適用裁決（n）。節奏跑有 VDOT 也維持處方窄窗。
    func test_paceBand_nonEasyDayType_keepsPrescribedWindow() throws {
        let band = try XCTUnwrap(try detail(tempoSteadyDay, vdot: 32)?.paceBand)
        let unitSystem = UnitManager.shared.currentUnitSystem
        XCTAssertEqual(band.fastLabel, App2SessionDetailProjection.paceLabel(300 - 15, unitSystem: unitSystem))
        XCTAssertEqual(band.slowLabel, App2SessionDetailProjection.paceLabel(300 + 15, unitSystem: unitSystem))
        XCTAssertNil(App2SessionDetailProjection.easyPaceTrainingType(.tempo))
    }

    // MARK: - 配速帶：溫度補償（2026-08-27 走查改版：帶上一律原配速）

    /// 溫度補償開啟 ＋ 當日帶 `pace_adjustment_pct` → 帶上**維持原始處方配速**，
    /// 補償額度變成「每公里可慢 N 秒」一句話（N ＝ 處方秒數 × pct%，依單位制換算）。
    func test_paceBand_climateAdjustmentEnabled_keepsOriginalPaceAndShowsSlack() throws {
        let band = try XCTUnwrap(
            try detail(
                easyRunDay,
                vdot: 32,
                climateDay: climate(pct: 5),
                isClimateAdjustmentEnabled: true
            )?.paceBand
        )
        let unitSystem = UnitManager.shared.currentUnitSystem
        XCTAssertEqual(band.paceLabel, App2SessionDetailProjection.paceLabel(410, unitSystem: unitSystem))
        XCTAssertEqual(band.fastLabel, App2SessionDetailProjection.paceLabel(400, unitSystem: unitSystem))
        XCTAssertEqual(band.slowLabel, App2SessionDetailProjection.paceLabel(480, unitSystem: unitSystem))
        let expected = try XCTUnwrap(
            App2SessionDetailProjection.climateAllowanceLabel(
                prescribedSecondsPerKm: 410, adjustmentPct: 5, unitSystem: unitSystem
            )
        )
        XCTAssertEqual(band.climateAllowanceLabel, expected)
        // 410 × 5% ≈ 21 秒（公制）；句子要含換算後的秒數。
        if unitSystem == .metric {
            XCTAssertTrue(expected.contains("21"), "實際句子：\(expected)")
        }
    }

    /// 溫度補償**關閉**時 `pace_adjustment_pct` 完全不參與。
    func test_paceBand_climateAdjustmentDisabled_ignoresAdjustment() throws {
        let band = try XCTUnwrap(
            try detail(
                easyRunDay,
                vdot: 32,
                climateDay: climate(pct: 5),
                isClimateAdjustmentEnabled: false
            )?.paceBand
        )
        let unitSystem = UnitManager.shared.currentUnitSystem
        XCTAssertEqual(band.paceLabel, App2SessionDetailProjection.paceLabel(410, unitSystem: unitSystem))
        XCTAssertNil(band.climateAllowanceLabel)
    }

    /// 涼爽日（`pace_adjustment_pct == 0`）即使開著補償也沒有東西可換算。
    func test_paceBand_comfortableDay_hasNoAdjustment() throws {
        let band = try XCTUnwrap(
            try detail(
                easyRunDay,
                vdot: 32,
                climateDay: climate(pct: 0),
                isClimateAdjustmentEnabled: true
            )?.paceBand
        )
        XCTAssertNil(band.climateAllowanceLabel)
    }

    /// 有暖身／緩和／間歇＝多段，維持長條圖，沒有配速帶。
    func test_paceBand_multiSegmentDay_isNil() throws {
        XCTAssertNil(try detail(intervalOnlyDay)?.paceBand)
    }

    /// 沒有配速就推不出邊界 —— 整格不出現，不本機編一個值。
    func test_paceBand_steadyBarWithoutPace_isNil() throws {
        let json = """
        { "day_index": 2, "day_target": "輕鬆跑", "reason": "r", "distance_km": 6.0,
          "primary": { "run_type": "easy", "distance_km": 6.0, "duration_minutes": 40 } }
        """
        XCTAssertNil(try detail(json)?.paceBand)
    }

    /// 英制用戶看到的是英里配速 ＋ `/mi`，不是公里配速掛著 `/km`。
    func test_paceLabel_convertsForImperial() {
        XCTAssertEqual(App2SessionDetailProjection.paceLabel(410, unitSystem: .metric), "6:50")
        // 410 × 1.60934 ≈ 659.8 秒／mi。
        XCTAssertEqual(App2SessionDetailProjection.paceLabel(410, unitSystem: .imperial), "11:00")
    }

    // MARK: - plannedSeconds（間歇課沒有 duration_minutes 時的推導）

    /// 熱身 ＋ 主課（含組間恢復）＋ 緩和，每一段都用**處方值**推。
    ///
    /// 4×400m @ 4:50 ＝ 4 × 0.4 × 290；組間 200m @ 7:30 ＝ 3 × 0.2 × 450；
    /// 熱身 2.0 km @ 7:00 ＝ 840；緩和 1.0 km @ 7:00 ＝ 420。
    func test_plannedSeconds_derivesFromPrescribedSegments() throws {
        let entity = try day(intervalOnlyDay)
        guard case .run(let run)? = entity.session?.primary else {
            return XCTFail("fixture 應該是跑步課")
        }
        let seconds = try XCTUnwrap(
            App2SessionDetailProjection.plannedSeconds(day: entity, run: run)
        )
        XCTAssertEqual(seconds, 4 * 0.4 * 290 + 3 * 0.2 * 450 + 840 + 420, accuracy: 1.0)
    }

    /// 主課段推不出時間就整個回 nil —— 少一格數據，不編一個數字。
    func test_plannedSeconds_mainSegmentWithoutDistance_isNil() throws {
        let json = """
        { "day_index": 3, "day_target": "間歇", "reason": "r",
          "primary": { "run_type": "interval",
            "interval": { "repeats": 4, "work_pace": "4:50" } } }
        """
        let entity = try day(json)
        guard case .run(let run)? = entity.session?.primary else {
            return XCTFail("fixture 應該是跑步課")
        }
        XCTAssertNil(App2SessionDetailProjection.plannedSeconds(day: entity, run: run))
    }

    /// hero 的「總距離」用日層 `distance_km`，不是 `primary.distance_km`
    /// —— 後者在間歇課只算主課段，拿它會跟分段列加不起來。
    func test_detail_distanceUsesDayLevelTotalNotPrimary() throws {
        XCTAssertEqual(try detail(intervalOnlyDay)?.distanceKm, 5.2)
    }

    // MARK: - 非跑步課沒有配速語意

    /// 獨立力量日：動作清單走「力量訓練」區塊（2026-08-27 晚走查裁決（d）之後
    /// 不再擠在訓練結構裡 —— 同一份內容不擺兩處）。
    func test_detail_strengthDay_hasNoPaceAndListsExercisesInStrengthSection() throws {
        let detail = try XCTUnwrap(try detail(strengthDay))
        XCTAssertFalse(detail.isRunSession)
        XCTAssertNil(detail.paceBand)
        XCTAssertNil(detail.distanceKm)
        XCTAssertTrue(detail.segments.isEmpty, "肌力課的動作不進訓練結構")
        let strength = try XCTUnwrap(detail.strength)
        XCTAssertEqual(strength.groups.count, 1)
        XCTAssertEqual(strength.groups[0].exercises.map(\.name), ["深蹲", "棒式"])
        XCTAssertEqual(strength.exerciseCount, 2)
        XCTAssertEqual(detail.durationMinutes, 30, "肌力課的時間來自 duration_minutes，不是配速推導")
        XCTAssertTrue(detail.structureBars.allSatisfy { $0.paceLabel == nil })
    }

    // MARK: - 沒有配速值就不畫配速欄（2026-08-27 晚走查裁決（j））

    /// 輕鬆跑整天沒有 `pace`：配速帶、柱上配速標籤、分段列的配速欄全部缺席，
    /// `hasPaceData` 為 false（畫面上「預計配速」卡與 hero 的配速格整個不出現）。
    /// **不畫「—」、不補樣板字、不在 app 端推算配速。**
    func test_detail_easyRunWithoutPace_hasNoPaceFields() throws {
        let json = """
        { "day_index": 2, "day_target": "輕鬆跑", "reason": "有氧維持", "distance_km": 8.0,
          "primary": { "run_type": "easy", "distance_km": 8.0,
                       "duration_minutes": 55, "description": "輕鬆跑" } }
        """
        let detail = try XCTUnwrap(try detail(json))

        XCTAssertFalse(detail.hasPaceData)
        XCTAssertNil(detail.paceBand, "沒有配速就沒有配速帶")
        XCTAssertTrue(detail.structureBars.allSatisfy { $0.paceLabel == nil })
        XCTAssertTrue(
            detail.segments.allSatisfy { !($0.detail ?? "").contains("@") },
            "分段列不得出現空的配速欄"
        )
        // 量還在：距離與時間不受影響。
        XCTAssertEqual(detail.distanceKm ?? 0, 8.0, accuracy: 0.001)
        XCTAssertEqual(detail.durationMinutes, 55)
    }

    /// 同一課型有配速時照常畫（不要為了修 A 把 B 也關掉）。
    func test_detail_easyRunWithPace_keepsPaceFields() throws {
        let detail = try XCTUnwrap(try detail(easyRunDay))
        XCTAssertTrue(detail.hasPaceData)
        XCTAssertNotNil(detail.paceBand)
    }

    // MARK: - 力量訓練（2026-08-27 晚走查裁決（d））

    /// 跑步日掛的 `supplementary[]` 肌力內容必須進投影 —— 裁決前整段被丟掉。
    func test_detail_runDay_projectsSupplementaryStrength() throws {
        let detail = try XCTUnwrap(try detail(runWithSupplementaryStrengthDay))
        let strength = try XCTUnwrap(detail.strength, "supplementary[] 不得被丟掉")

        XCTAssertEqual(strength.groups.count, 1)
        XCTAssertEqual(strength.exerciseCount, 4)

        let group = strength.groups[0]
        XCTAssertEqual(group.typeLabel, NSLocalizedString("training.strength_type.core_stability", comment: ""))
        XCTAssertEqual(group.note, "跑後做，維持軀幹穩定")
        XCTAssertEqual(group.exercises.map(\.name), ["棒式", "死蟲式", "鳥狗式", "側棒式"])

        // 組數×秒／組數×次都要格式化得出來（沿用既有 `app2.detail.strength_*`）。
        XCTAssertEqual(
            group.exercises[0].detail,
            String(format: L10n.App2.Detail.strengthSetsSeconds.localized, 3, 45)
        )
        // `reps` 是字串（後端可能給 `8-12` 範圍），格式化不得印出指標值。
        XCTAssertEqual(
            group.exercises[1].detail,
            String(format: L10n.App2.Detail.strengthSetsReps.localized, 3, "12")
        )
        XCTAssertEqual(group.exercises[1].detail?.contains("12"), true)

        // 跑步課的主課結構不受影響。
        XCTAssertTrue(detail.isRunSession)
        XCTAssertFalse(detail.segments.isEmpty)
    }

    /// 今天沒有肌力內容 → 整塊不出現。
    func test_detail_runDayWithoutStrength_hasNoStrengthSection() throws {
        XCTAssertNil(try detail(easyRunDay)?.strength)
    }

    /// 未知的 `strength_type` 不得把識別字原樣印給用戶（`NSLocalizedString`
    /// 找不到 key 會回 key 本身）。動作清單仍然要出現。
    func test_strength_unknownType_hasNoTypeLabelButKeepsExercises() throws {
        let strength = try XCTUnwrap(
            App2SessionDetailProjection.strength(day: try day(strengthDay))
        )
        XCTAssertNil(strength.groups[0].typeLabel, "`core` 不在既有的 strength_type 對照裡")
        XCTAssertEqual(strength.exerciseCount, 2)
    }

    func test_detail_crossDay_hasNoPaceAndUsesDurationAsOnlyQuantity() throws {
        let detail = try XCTUnwrap(try detail(crossDay))
        XCTAssertFalse(detail.isRunSession)
        XCTAssertNil(detail.paceBand)
        XCTAssertNil(detail.distanceKm)
        XCTAssertEqual(detail.durationMinutes, 45)
        XCTAssertEqual(detail.segments.count, 1)
        XCTAssertTrue(detail.structureBars.allSatisfy { $0.paceLabel == nil })
    }

    // MARK: - 逐日敘述的一致性閘門

    /// `day_target` 只在能證明它仍對應現在這一天時才交出去
    /// （用戶在編輯器改過課型後，後端不重生那一段）。
    func test_goalText_shownOnlyWhenPrimaryDescriptionMatchesDayTarget() throws {
        XCTAssertEqual(try detail(easyRunDay)?.goalText, "輕鬆跑", "同一次產出 → 顯示")

        let stale = """
        { "day_index": 2, "day_target": "週三休息，為接下來的訓練儲備能量。", "reason": "r",
          "primary": { "run_type": "interval", "description": "interval 4x400m" } }
        """
        XCTAssertNil(try detail(stale)?.goalText, "證明不了就不顯示，不去猜敘述在講哪一種課")
    }

    /// `reason` 一律不顯示 —— 它與 `day_target` 分開生成，payload 裡沒有欄位能
    /// 證明它對應現在這一天（後端缺陷已回報，App 端不把矛盾的話印在用戶眼前）。
    func test_reasonText_isNeverShown() throws {
        XCTAssertNil(try detail(easyRunDay)?.reasonText)
        XCTAssertNil(try detail(intervalOnlyDay)?.reasonText)
    }

    // MARK: - 補給建議（設計稿靜態文案，不是 payload 欄位）

    /// 一堂 40 分鐘的「長跑」掛「每 45 分鐘補給一次」是廢話。
    func test_showsFuelingNote_onlyForLongRunsAtOrAboveNinetyMinutes() {
        XCTAssertTrue(App2SessionDetailProjection.showsFuelingNote(dayType: .lsd, durationMinutes: 90))
        XCTAssertFalse(App2SessionDetailProjection.showsFuelingNote(dayType: .lsd, durationMinutes: 89))
        XCTAssertFalse(App2SessionDetailProjection.showsFuelingNote(dayType: .easy, durationMinutes: 120))
        XCTAssertFalse(App2SessionDetailProjection.showsFuelingNote(dayType: .lsd, durationMinutes: nil))
    }
}
