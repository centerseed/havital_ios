import SwiftUI

/// 根據動作名稱或 ID 判斷是否有對應的教學圖片與說明
struct ExerciseImageMapper {
    /// 可選的動作清單（exerciseId, 本地化顯示名）
    static let catalog: [(id: String, displayName: String)] = [
        ("plank", NSLocalizedString("exercise.name.plank", comment: "棒式")),
        ("dead_bug", NSLocalizedString("exercise.name.dead_bug", comment: "死蟲式")),
        ("bird_dog", NSLocalizedString("exercise.name.bird_dog", comment: "鳥狗式")),
        ("side_plank", NSLocalizedString("exercise.name.side_plank", comment: "側棒式")),
        ("glute_bridge", NSLocalizedString("exercise.name.glute_bridge", comment: "臀橋")),
        ("clamshell", NSLocalizedString("exercise.name.clamshell", comment: "蛤蜊式")),
        ("single_leg_glute_bridge", NSLocalizedString("exercise.name.single_leg_glute_bridge", comment: "單腿臀橋")),
        ("monster_walk", NSLocalizedString("exercise.name.monster_walk", comment: "怪物走路")),
        ("squat", NSLocalizedString("exercise.name.squat", comment: "深蹲")),
        ("lunge", NSLocalizedString("exercise.name.lunge", comment: "弓步蹲")),
        ("romanian_deadlift", NSLocalizedString("exercise.name.romanian_deadlift", comment: "羅馬尼亞硬舉")),
        ("calf_raise", NSLocalizedString("exercise.name.calf_raise", comment: "提踵")),
        ("vertical_jump", NSLocalizedString("exercise.name.vertical_jump", comment: "垂直跳")),
        ("jump_rope", NSLocalizedString("exercise.name.jump_rope", comment: "跳繩")),
        ("lateral_jump", NSLocalizedString("exercise.name.lateral_jump", comment: "側向跳")),
        ("consecutive_hops", NSLocalizedString("exercise.name.consecutive_hops", comment: "連續跳")),
        ("hip_flexor_stretch", NSLocalizedString("exercise.name.hip_flexor_stretch", comment: "髖屈肌伸展")),
        ("thoracic_rotation", NSLocalizedString("exercise.name.thoracic_rotation", comment: "胸椎旋轉")),
        ("seated_forward_fold", NSLocalizedString("exercise.name.seated_forward_fold", comment: "坐姿前彎")),
        ("standing_quad_stretch", NSLocalizedString("exercise.name.standing_quad_stretch", comment: "站姿股四頭肌伸展")),
    ]

    static func localizedName(for exerciseId: String?, fallback: String) -> String {
        guard let id = exerciseId?.lowercased(), !id.isEmpty else { return fallback }
        return catalog.first { $0.id == id }?.displayName ?? fallback
    }

    static func mappedImageAndKey(for exerciseId: String?, name: String) -> (image: String, key: String)? {
        
        // 優先使用由 LLM 回傳的 standardized ID
        let id = (exerciseId ?? "").lowercased()
        switch id {
        case "plank": return ("exercise_plank", "exercise.instruction.plank.desc")
        case "dead_bug": return ("exercise_deadbug", "exercise.instruction.deadbug.desc")
        case "bird_dog": return ("exercise_bird_dog", "exercise.instruction.bird_dog.desc")
        case "side_plank": return ("exercise_side_plank", "exercise.instruction.side_plank.desc")
        case "glute_bridge": return ("exercise_glute_bridge", "exercise.instruction.glute_bridge.desc")
        case "clamshell": return ("exercise_clamshell", "exercise.instruction.clamshell.desc")
        case "single_leg_glute_bridge": return ("exercise_single_leg_glute_bridge", "exercise.instruction.single_leg_glute_bridge.desc")
        case "monster_walk": return ("exercise_monster_walk", "exercise.instruction.monster_walk.desc")
        case "squat": return ("exercise_squat", "exercise.instruction.squat.desc")
        case "lunge": return ("exercise_lunge", "exercise.instruction.lunge.desc")
        case "romanian_deadlift": return ("exercise_romanian_deadlift", "exercise.instruction.romanian_deadlift.desc")
        case "calf_raise": return ("exercise_calf_raise", "exercise.instruction.calf_raise.desc")
        case "vertical_jump": return ("exercise_vertical_jump", "exercise.instruction.vertical_jump.desc")
        case "jump_rope": return ("exercise_jump_rope", "exercise.instruction.jump_rope.desc")
        case "lateral_jump": return ("exercise_lateral_jump", "exercise.instruction.lateral_jump.desc")
        case "consecutive_hops": return ("exercise_consecutive_hops", "exercise.instruction.consecutive_hops.desc")
        case "hip_flexor_stretch": return ("exercise_hip_flexor_stretch", "exercise.instruction.hip_flexor_stretch.desc")
        case "thoracic_rotation": return ("exercise_thoracic_rotation", "exercise.instruction.thoracic_rotation.desc")
        case "seated_forward_fold": return ("exercise_seated_forward_fold", "exercise.instruction.seated_forward_fold.desc")
        case "standing_quad_stretch": return ("exercise_standing_quad_stretch", "exercise.instruction.standing_quad_stretch.desc")
        default: break
        }
        
        // 舊版或沒有 id 的情境，回退到透過字串比對
        let lowerName = name.lowercased()
        
        if lowerName.contains("plank") || lowerName.contains("棒式") || lowerName.contains("プランク") || lowerName.contains("撐體") || lowerName.contains("平板支撐") {
            return ("exercise_plank", "exercise.instruction.plank.desc")
        }
        if lowerName.contains("squat") || lowerName.contains("深蹲") || lowerName.contains("スクワット") {
            return ("exercise_squat", "exercise.instruction.squat.desc")
        }
        if lowerName.contains("deadbug") || lowerName.contains("死蟲") || lowerName.contains("デッドバグ") || lowerName.contains("死虫") || lowerName.contains("dead bug") {
            return ("exercise_deadbug", "exercise.instruction.deadbug.desc")
        }
        if lowerName.contains("bridge") || lowerName.contains("臀橋") || lowerName.contains("ブリッジ") || lowerName.contains("glute") || lowerName.contains("臀桥") {
            return ("exercise_glute_bridge", "exercise.instruction.glute_bridge.desc")
        }
        
        return nil
    }
}



/// 動作指引視圖
struct ExerciseInstructionView: View {
    let exerciseName: String
    let imageName: String
    let instructionDesc: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("exercise.instruction.title", comment: "Exercise Guide"))
                    .font(AppFont.headline())
                    .fontWeight(.bold)
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(AppFont.title3())
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    Text(exerciseName)
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    
                    Text(NSLocalizedString(instructionDesc, comment: ""))
                        .font(AppFont.body())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ExerciseInstructionView(
        exerciseName: "棒式",
        imageName: "exercise_plank",
        instructionDesc: "exercise.instruction.plank.desc"
    )
}
