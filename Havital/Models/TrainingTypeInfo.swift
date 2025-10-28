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

        default:
            return nil
        }
    }
}
