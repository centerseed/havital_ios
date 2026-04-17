import Foundation

struct TrainingTypeInfo {
    let icon: String
    let title: String
    let howToRun: String
    let whyRun: String
    let logic: String
    let role: String

    static func info(for type: DayType) -> TrainingTypeInfo? {
        switch type {
        case .recovery_run:
            return TrainingTypeInfo(
                icon: "🌿",
                title: NSLocalizedString("training_type_info.recovery_run.title", comment: "恢復跑 Recovery Run"),
                howToRun: NSLocalizedString("training_type_info.recovery_run.how_to_run", comment: "幾乎是最放鬆的跑步方式。速度慢沒關係，專注在「身體舒服」而非「數據好看」。"),
                whyRun: NSLocalizedString("training_type_info.recovery_run.why_run", comment: "恢復跑是主動恢復的一部分。跑得太快會干擾修復，跑得太慢反而無感——重點是「讓血液帶著氧氣流過疲憊的肌肉」。"),
                logic: NSLocalizedString("training_type_info.recovery_run.logic", comment: "屬於極低強度有氧訓練（<65% HRmax），幫助清除乳酸、促進代謝與神經系統恢復。相較靜態休息，能讓你更快準備好迎接下一堂課。"),
                role: NSLocalizedString("training_type_info.recovery_run.role", comment: "通常安排在高強度課或長跑後的隔天，是讓訓練成果「被吸收」的關鍵環節。")
            )

        case .tempo:
            return TrainingTypeInfo(
                icon: "⚡",
                title: NSLocalizedString("training_type_info.tempo.title", comment: "節奏跑 Tempo Run"),
                howToRun: NSLocalizedString("training_type_info.tempo.how_to_run", comment: "穩定、有點吃力但能維持的速度。應該覺得「努力，但不會崩潰」。"),
                whyRun: NSLocalizedString("training_type_info.tempo.why_run", comment: "節奏跑讓你熟悉比賽時的穩定節奏。它訓練你在中高強度下保持呼吸與配速的控制，是連結耐力與速度的橋樑。"),
                logic: NSLocalizedString("training_type_info.tempo.logic", comment: "位於乳酸閾值附近（約最大心率的80–88%），改善身體處理乳酸的能力，提升「在不爆掉的前提下維持高速度」的表現。"),
                role: NSLocalizedString("training_type_info.tempo.role", comment: "通常位於週中，作為比賽節奏的模擬課，搭配週末長跑與週初輕鬆跑，形成穩定節奏週。")
            )

        case .threshold:
            return TrainingTypeInfo(
                icon: "🔥",
                title: NSLocalizedString("training_type_info.threshold.title", comment: "閾值跑 Threshold Run"),
                howToRun: NSLocalizedString("training_type_info.threshold.how_to_run", comment: "比節奏跑再吃力一點，仍能穩定維持。感覺像「有挑戰，但能撐完」，心率高但仍可控制。"),
                whyRun: NSLocalizedString("training_type_info.threshold.why_run", comment: "閾值跑是突破耐力瓶頸的關鍵。它讓你能更久地維持高速度，也是提升馬拉松表現的重要訓練。"),
                logic: NSLocalizedString("training_type_info.threshold.logic", comment: "鎖定在乳酸閾值強度（約85–90% HRmax），訓練身體延後乳酸累積、提升疲勞耐受度。長期進行能明顯提升持續速度與競賽表現。"),
                role: NSLocalizedString("training_type_info.threshold.role", comment: "通常在訓練高峰期週中安排，週前以輕鬆跑熱身，週後以恢復跑吸收刺激。")
            )

        case .interval:
            return TrainingTypeInfo(
                icon: "💥",
                title: NSLocalizedString("training_type_info.interval.title", comment: "間歇跑 Interval Run"),
                howToRun: NSLocalizedString("training_type_info.interval.how_to_run", comment: "短時間全力衝刺與恢復交替，會喘、會累，但要能「撐完所有組」。"),
                whyRun: NSLocalizedString("training_type_info.interval.why_run", comment: "這是提升速度與心肺爆發力的關鍵課。高強度的刺激讓身體學會「更快運轉、也更快恢復」。"),
                logic: NSLocalizedString("training_type_info.interval.logic", comment: "屬於高強度間歇訓練（HIIT），刺激最大攝氧量（VO₂max）與神經肌肉反應。能提升心臟搏出量、氧氣運送與肌肉氧化能力。"),
                role: NSLocalizedString("training_type_info.interval.role", comment: "通常安排在週中，是整週的「強度主角」。前後搭配輕鬆跑或休息日，讓身體有足夠恢復時間。")
            )

        case .lsd:
            return TrainingTypeInfo(
                icon: "🏔️",
                title: NSLocalizedString("training_type_info.lsd.title", comment: "LSD（長距離輕鬆跑 Long Slow Distance）"),
                howToRun: NSLocalizedString("training_type_info.lsd.how_to_run", comment: "放慢速度、拉長時間。應該覺得可以一直跑下去，節奏穩但不吃力。"),
                whyRun: NSLocalizedString("training_type_info.lsd.why_run", comment: "長時間跑步能鍛鍊意志與耐力，讓身體學會長時間利用脂肪作為燃料，是馬拉松訓練中最經典的核心課。"),
                logic: NSLocalizedString("training_type_info.lsd.logic", comment: "屬於長時間低強度有氧訓練，強化心肺功能、肌肉耐力與能量利用效率。也促進毛細血管生長，提升肌肉對氧氣的運用能力。"),
                role: NSLocalizedString("training_type_info.lsd.role", comment: "通常安排在週末，是整週訓練的「耐力支柱」。搭配週中節奏跑或間歇跑，共同建立完整的有氧能力。")
            )

        case .longRun:
            return TrainingTypeInfo(
                icon: "🏔️",
                title: NSLocalizedString("training_type_info.long_run.title", comment: "長距離跑 Long Run"),
                howToRun: NSLocalizedString("training_type_info.long_run.how_to_run", comment: "跑得比輕鬆跑再快一點，但要能穩定維持整程。感覺像在模擬比賽配速，呼吸有節奏、專注前進。"),
                whyRun: NSLocalizedString("training_type_info.long_run.why_run", comment: "長距離跑是測試與培養耐力的課。它讓你習慣在時間拉長後仍保持穩定輸出，同時訓練身體在疲勞中持續運作。"),
                logic: NSLocalizedString("training_type_info.long_run.logic", comment: "屬於中等強度的長時間有氧訓練（約最大心率 70–80%）。在這個強度下，身體會同時使用脂肪與糖原作為能量來源，幫助提升能量利用效率與肌肉耐力。也是強化「比賽節奏穩定性」與「心理耐受力」的重要課。"),
                role: NSLocalizedString("training_type_info.long_run.role", comment: "通常安排在週末，是整週最長的一堂課。在強化期或比賽準備期中，它是模擬比賽情境的核心訓練，前後會搭配輕鬆跑或恢復跑讓身體吸收負荷。")
            )

        case .easyRun, .easy:
            return TrainingTypeInfo(
                icon: "🌱",
                title: NSLocalizedString("training_type_info.easy.title", comment: "輕鬆跑 Easy Run"),
                howToRun: NSLocalizedString("training_type_info.easy.how_to_run", comment: "非常輕鬆的速度，應該能舒服地交談、幾乎不喘氣。感覺像是「為了享受而跑」。"),
                whyRun: NSLocalizedString("training_type_info.easy.why_run", comment: "輕鬆跑是日常訓練的基礎。它讓身體適應規律運動而不造成過度疲勞，也是讓你持續愛上跑步的關鍵。"),
                logic: NSLocalizedString("training_type_info.easy.logic", comment: "屬於低強度有氧訓練（約最大心率的60–70%）。在這個強度下，身體能穩定地使用脂肪作為主要能量來源，同時鍛鍊有氧基礎與毛細血管生長。"),
                role: NSLocalizedString("training_type_info.easy.role", comment: "是訓練週的「日常主角」。在高強度課前後用輕鬆跑熱身與恢復，也能單獨作為輕鬆日，讓身體在無壓力中適應訓練節奏。")
            )

        case .combination:
            return TrainingTypeInfo(
                icon: "🔀",
                title: NSLocalizedString("training_type_info.combination.title", comment: "組合訓練 Combination Training"),
                howToRun: NSLocalizedString("training_type_info.combination.how_to_run", comment: "在單一堂課中結合多個強度段落。起初輕鬆，逐步加速或交替衝刺與恢復。"),
                whyRun: NSLocalizedString("training_type_info.combination.why_run", comment: "組合訓練在一次課中刺激多種能力。它訓練身體在變化的強度下快速適應，同時提升心肺與肌肉的綜合表現。"),
                logic: NSLocalizedString("training_type_info.combination.logic", comment: "整合有氧與無氧訓練的優勢，透過強度變化刺激多個生理系統。相比單一強度課，能更全面地提升耐力、速度與適應能力。"),
                role: NSLocalizedString("training_type_info.combination.role", comment: "可作為週中的主課，在時間有限但想要完整訓練效果時使用。也常見於賽期準備，模擬比賽中的起伏配速。")
            )

        case .rest:
            return TrainingTypeInfo(
                icon: "😴",
                title: NSLocalizedString("training_type_info.rest.title", comment: "休息日 Rest Day"),
                howToRun: NSLocalizedString("training_type_info.rest.how_to_run", comment: "不進行有組織的跑步訓練。可以選擇輕鬆散步或完全靜態休息，聆聽身體需求。"),
                whyRun: NSLocalizedString("training_type_info.rest.why_run", comment: "休息是訓練計畫中最容易被忽視、卻最關鍵的部分。完整的休息日讓肌肉修復、神經系統恢復、能量儲備補充。"),
                logic: NSLocalizedString("training_type_info.rest.logic", comment: "無訓練負荷時，身體進行深層修復。肌肉蛋白質合成加強、疲勞毒素清除、荷爾蒙與免疫系統平衡——這是「在休息中變強」的過程。"),
                role: NSLocalizedString("training_type_info.rest.role", comment: "每週安排 1–2 個完整休息日，通常在高強度訓練後。充分的休息日能避免過度訓練，維持長期表現與健康。")
            )

        // MARK: - 新增間歇訓練類型

        case .strides:
            return TrainingTypeInfo(
                icon: "🏃‍♂️",
                title: NSLocalizedString("training_type_info.strides.title", comment: "大步跑 Strides"),
                howToRun: NSLocalizedString("training_type_info.strides.how_to_run", comment: "短距離（約 80-100 公尺）的漸加速跑。從輕鬆跑開始，逐漸加速到接近衝刺，然後減速停下。保持放鬆、專注在良好的跑步姿勢。"),
                whyRun: NSLocalizedString("training_type_info.strides.why_run", comment: "大步跑能提升跑步經濟性與神經肌肉協調。它讓你的腿習慣較快的轉換頻率，也是比賽前熱身的好選擇。"),
                logic: NSLocalizedString("training_type_info.strides.logic", comment: "屬於神經肌肉訓練，透過短時間的高速度刺激，改善肌肉纖維的徵召效率與腿部協調。因為距離短、恢復完全，不會造成顯著疲勞。"),
                role: NSLocalizedString("training_type_info.strides.role", comment: "通常安排在輕鬆跑結束後，或作為高強度訓練前的熱身。每週進行 2-3 次，每次 4-8 組。")
            )

        case .hillRepeats:
            return TrainingTypeInfo(
                icon: "⛰️",
                title: NSLocalizedString("training_type_info.hill_repeats.title", comment: "山坡重複跑 Hill Repeats"),
                howToRun: NSLocalizedString("training_type_info.hill_repeats.how_to_run", comment: "找一個約 5-10% 坡度的上坡，以穩定但有挑戰的速度向上衝刺，然後慢跑或步行下坡恢復。專注在腿部發力與身體前傾。"),
                whyRun: NSLocalizedString("training_type_info.hill_repeats.why_run", comment: "上坡跑是「偽裝的重量訓練」。它能強化腿部肌力、改善跑步姿勢，同時降低因高速度帶來的衝擊傷害風險。"),
                logic: NSLocalizedString("training_type_info.hill_repeats.logic", comment: "上坡時需要更大的肌力輸出，能有效訓練臀肌、股四頭肌與小腿肌群。相比平地衝刺，關節衝擊較小但肌肉負荷更大。"),
                role: NSLocalizedString("training_type_info.hill_repeats.role", comment: "通常安排在基礎期或力量發展期，每週 1 次。是銜接有氧基礎與高強度間歇的重要過渡訓練。")
            )

        case .cruiseIntervals:
            return TrainingTypeInfo(
                icon: "🚢",
                title: NSLocalizedString("training_type_info.cruise_intervals.title", comment: "巡航間歇 Cruise Intervals"),
                howToRun: NSLocalizedString("training_type_info.cruise_intervals.how_to_run", comment: "以閾值配速（約能維持 20-30 分鐘的最快速度）進行間歇，每組之間有短暫恢復（約 1-2 分鐘慢跑）。"),
                whyRun: NSLocalizedString("training_type_info.cruise_intervals.why_run", comment: "巡航間歇讓你在閾值強度下累積更多訓練量。透過短暫恢復，你能比連續跑更長時間地維持在這個關鍵強度區間。"),
                logic: NSLocalizedString("training_type_info.cruise_intervals.logic", comment: "屬於閾值訓練的變化形式，讓身體長時間處於乳酸閾值附近。間歇的設計讓你能承受更高的總訓練量，同時維持良好的跑姿。"),
                role: NSLocalizedString("training_type_info.cruise_intervals.role", comment: "通常在比賽準備期使用，作為閾值跑的進階版本。是提升半馬與馬拉松成績的重要訓練。")
            )

        // MARK: - 新增組合訓練類型

        case .fartlek:
            return TrainingTypeInfo(
                icon: "🎲",
                title: NSLocalizedString("training_type_info.fartlek.title", comment: "法特雷克 Fartlek"),
                howToRun: NSLocalizedString("training_type_info.fartlek.how_to_run", comment: "「法特雷克」是瑞典語「速度遊戲」。在跑步中隨興變速——看到下個路燈就衝刺、到公園入口再放慢。沒有固定結構，跟著感覺跑。"),
                whyRun: NSLocalizedString("training_type_info.fartlek.why_run", comment: "法特雷克讓訓練變得有趣，同時訓練身體適應不同速度的切換。它是打破單調訓練的好方法，也能模擬比賽中的配速變化。"),
                logic: NSLocalizedString("training_type_info.fartlek.logic", comment: "屬於非結構化的混合強度訓練，同時刺激有氧與無氧系統。自由的形式能減少心理疲勞，讓跑者在享受中獲得訓練效果。"),
                role: NSLocalizedString("training_type_info.fartlek.role", comment: "可以替代結構化的間歇訓練，或作為恢復週的輕鬆變速跑。適合任何訓練階段，特別是需要調劑心情的時候。")
            )

        case .fastFinish:
            return TrainingTypeInfo(
                icon: "🚀",
                title: NSLocalizedString("training_type_info.fast_finish.title", comment: "快結尾長跑 Fast Finish Long Run"),
                howToRun: NSLocalizedString("training_type_info.fast_finish.how_to_run", comment: "前 70% 以輕鬆配速進行，最後 30% 逐漸加速到節奏跑或更快的配速。結束時應該覺得有挑戰但能完成。"),
                whyRun: NSLocalizedString("training_type_info.fast_finish.why_run", comment: "快結尾長跑訓練你在疲勞時維持或加快配速——這正是比賽後半段的挑戰。它讓身體習慣「累了還要加速」的感覺。"),
                logic: NSLocalizedString("training_type_info.fast_finish.logic", comment: "在肝醣耗竭、肌肉疲勞的狀態下進行較高強度跑步，能提升脂肪代謝能力與疲勞耐受度。也訓練維持跑姿與專注力。"),
                role: NSLocalizedString("training_type_info.fast_finish.role", comment: "通常在比賽準備期的週末長跑使用。是模擬比賽後半段的重要訓練，能建立比賽信心。")
            )

        // MARK: - 新增比賽配速訓練

        case .racePace:
            return TrainingTypeInfo(
                icon: "🏁",
                title: NSLocalizedString("training_type_info.race_pace.title", comment: "比賽配速跑 Race Pace Run"),
                howToRun: NSLocalizedString("training_type_info.race_pace.how_to_run", comment: "以你的目標比賽配速進行訓練。專注在維持穩定的節奏，熟悉這個速度下的呼吸、步頻與身體感覺。"),
                whyRun: NSLocalizedString("training_type_info.race_pace.why_run", comment: "比賽配速跑讓你的身體與大腦記住目標速度。比賽當天你會更自然地跑出這個配速，而不需要一直盯著手錶。"),
                logic: NSLocalizedString("training_type_info.race_pace.logic", comment: "透過重複練習目標配速，建立神經肌肉記憶與配速感知能力。也讓你評估當前體能是否能達成目標，適時調整訓練計畫。"),
                role: NSLocalizedString("training_type_info.race_pace.role", comment: "通常在比賽前 4-8 週開始安排，距離從短到長逐漸增加。是賽前最重要的專項訓練之一。")
            )

        // MARK: - 新增VO2max提升訓練類型

        case .norwegian4x4:
            return TrainingTypeInfo(
                icon: "🇳🇴",
                title: NSLocalizedString("training_type_info.norwegian_4x4.title", comment: "挪威4x4 Norwegian 4x4"),
                howToRun: NSLocalizedString("training_type_info.norwegian_4x4.how_to_run", comment: "進行4組4分鐘的高強度跑，每組之間休息3分鐘。保持穩定的VO₂max配速（92% 最大心率），衝刺但控制節奏——應該覺得「非常努力，但能撐完所有組」。"),
                whyRun: NSLocalizedString("training_type_info.norwegian_4x4.why_run", comment: "挪威4x4用來提升高強度下的心肺輸出，讓你更能承受接近極限的配速。它特別適合需要加強速度天花板與比賽衝刺能力的階段。"),
                logic: NSLocalizedString("training_type_info.norwegian_4x4.logic", comment: "屬於高強度間歇訓練，主打VO₂max區間。4分鐘工作時間足以把心肺系統推上來，3分鐘恢復則幫助你在後續組數維持品質，累積有效的高強度訓練量。"),
                role: NSLocalizedString("training_type_info.norwegian_4x4.role", comment: "通常安排在建強期或比賽準備期，每週最多1次。前後建議搭配輕鬆跑與恢復日，避免連續多週都維持高壓負荷。")
            )

        case .shortInterval:
            return TrainingTypeInfo(
                icon: "⚡",
                title: NSLocalizedString("training_type_info.short_interval.title", comment: "短間歇 Short Interval"),
                howToRun: NSLocalizedString("training_type_info.short_interval.how_to_run", comment: "進行 6-10 組短距離（400-600 公尺）的高強度衝刺，每組之間以輕鬆速度恢復約 1-2 分鐘。盡力衝刺，讓呼吸充分提升。"),
                whyRun: NSLocalizedString("training_type_info.short_interval.why_run", comment: "短間歇訓練速度與爆發力。較短的距離讓你能維持全力，同時完整恢復時間幫助你撐完所有組。特別適合5K賽事準備。"),
                logic: NSLocalizedString("training_type_info.short_interval.logic", comment: "屬於高強度間歇訓練，刺激VO₂max與神經肌肉反應。短距離特別有效於提升最大速度與踏頻，同時也訓練身體快速加速的能力。"),
                role: NSLocalizedString("training_type_info.short_interval.role", comment: "通常在基礎速度訓練期或5K賽事準備期使用。每週最多1次，搭配恢復跑與輕鬆日。連續進行會增加受傷風險。")
            )

        case .longInterval:
            return TrainingTypeInfo(
                icon: "🔥",
                title: NSLocalizedString("training_type_info.long_interval.title", comment: "長間歇 Long Interval"),
                howToRun: NSLocalizedString("training_type_info.long_interval.how_to_run", comment: "進行 4-6 組較長距離（1200-2000 公尺）的高強度跑，每組之間以輕鬆速度恢復 2-3 分鐘。配速應該比短間歇稍慢，但仍維持高強度。"),
                whyRun: NSLocalizedString("training_type_info.long_interval.why_run", comment: "長間歇是連結短間歇與持續跑的橋樑。它既能刺激VO₂max，又能在相對長時間內維持高配速，特別適合半馬與10K賽事準備。"),
                logic: NSLocalizedString("training_type_info.long_interval.logic", comment: "屬於高強度間歇訓練，但強度略低於短間歇。較長的持續時間讓身體適應在疲勞中維持高配速，也訓練乳酸耐受度。"),
                role: NSLocalizedString("training_type_info.long_interval.role", comment: "通常在進階速度訓練期或10K/半馬準備期使用。每週最多1次，通常在短間歇之後進行。需要充分恢復。")
            )

        case .yasso800:
            return TrainingTypeInfo(
                icon: "⚙️",
                title: NSLocalizedString("training_type_info.yasso_800.title", comment: "亞索800 Yasso 800s"),
                howToRun: NSLocalizedString("training_type_info.yasso_800.how_to_run", comment: "進行 8-10 組 800 公尺的高強度跑，每組之間以慢跑恢復 2-3 分鐘（約等於完成 800m 所需的時間）。例如若你 800m 跑 3 分鐘，恢復也約 3 分鐘。"),
                whyRun: NSLocalizedString("training_type_info.yasso_800.why_run", comment: "亞索800的特殊之處在於它能直接預測馬拉松成績。根據美國著名教練 Bart Yasso 的理論，你能在 800m 跑出的時間（分鐘秒數），對應你的預測馬拉松完賽時間（小時分鐘）。"),
                logic: NSLocalizedString("training_type_info.yasso_800.logic", comment: "800公尺的距離完美平衡速度與耐力。間歇設計刺激VO₂max與乳酸緩衝能力。等時恢復讓身體學會在部分疲勞下維持配速，是馬拉松特異性訓練。"),
                role: NSLocalizedString("training_type_info.yasso_800.role", comment: "特別適合馬拉松準備期，每週進行 1 次。是馬拉松訓練中最具預測性的課程。也常在其他距離賽事準備期使用以提升速度。")
            )

        default:
            return nil
        }
    }
}
