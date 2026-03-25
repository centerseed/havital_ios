import Foundation

// MARK: - TrainingSessionMapper
/// Training Session Mapper - Data Layer
/// 負責 TrainingSession 相關所有 DTO ↔ Entity 雙向轉換
enum TrainingSessionMapper {

    // MARK: - HeartRateRange

    static func toEntity(from dto: HeartRateRangeDTO) -> HeartRateRangeV2 {
        return HeartRateRangeV2(
            min: dto.min,
            max: dto.max
        )
    }

    static func toDTO(from entity: HeartRateRangeV2) -> HeartRateRangeDTO {
        return HeartRateRangeDTO(
            min: entity.min,
            max: entity.max
        )
    }

    // MARK: - RunSegment

    static func toEntity(from dto: RunSegmentDTO) -> RunSegment {
        return RunSegment(
            distanceKm: dto.distanceKm,
            distanceM: dto.distanceM,
            distanceDisplay: dto.distanceDisplay,
            distanceUnit: dto.distanceUnit,
            durationMinutes: dto.durationMinutes,
            durationSeconds: dto.durationSeconds,
            pace: dto.pace,
            heartRateRange: dto.heartRateRange.map { toEntity(from: $0) },
            intensity: dto.intensity,
            description: dto.description
        )
    }

    static func toDTO(from entity: RunSegment) -> RunSegmentDTO {
        return RunSegmentDTO(
            distanceKm: entity.distanceKm,
            distanceM: entity.distanceM,
            distanceDisplay: entity.distanceDisplay,
            distanceUnit: entity.distanceUnit,
            durationMinutes: entity.durationMinutes,
            durationSeconds: entity.durationSeconds,
            pace: entity.pace,
            heartRateRange: entity.heartRateRange.map { toDTO(from: $0) },
            intensity: entity.intensity,
            description: entity.description
        )
    }

    // MARK: - IntervalBlock

    static func toEntity(from dto: IntervalBlockDTO) -> IntervalBlock {
        return IntervalBlock(
            repeats: dto.repeats,
            workDistanceKm: dto.workDistanceKm,
            workDistanceM: dto.workDistanceM,
            workDistanceDisplay: dto.workDistanceDisplay,
            workDistanceUnit: dto.workDistanceUnit,
            workPaceUnit: dto.workPaceUnit,
            workDurationMinutes: dto.workDurationMinutes,
            workPace: dto.workPace,
            workDescription: dto.workDescription,
            recoveryDistanceKm: dto.recoveryDistanceKm,
            recoveryDistanceM: dto.recoveryDistanceM,
            recoveryDurationMinutes: dto.recoveryDurationMinutes,
            recoveryPace: dto.recoveryPace,
            recoveryDescription: dto.recoveryDescription,
            recoveryDurationSeconds: dto.recoveryDurationSeconds,
            variant: dto.variant
        )
    }

    static func toDTO(from entity: IntervalBlock) -> IntervalBlockDTO {
        return IntervalBlockDTO(
            repeats: entity.repeats,
            workDistanceKm: entity.workDistanceKm,
            workDistanceM: entity.workDistanceM,
            workDistanceDisplay: entity.workDistanceDisplay,
            workDistanceUnit: entity.workDistanceUnit,
            workPaceUnit: entity.workPaceUnit,
            workDurationMinutes: entity.workDurationMinutes,
            workPace: entity.workPace,
            workDescription: entity.workDescription,
            recoveryDistanceKm: entity.recoveryDistanceKm,
            recoveryDistanceM: entity.recoveryDistanceM,
            recoveryDurationMinutes: entity.recoveryDurationMinutes,
            recoveryPace: entity.recoveryPace,
            recoveryDescription: entity.recoveryDescription,
            recoveryDurationSeconds: entity.recoveryDurationSeconds,
            variant: entity.variant
        )
    }

    // MARK: - RunActivity

    static func toEntity(from dto: RunActivityDTO) -> RunActivity {
        return RunActivity(
            runType: dto.runType,
            distanceKm: dto.distanceKm,
            distanceDisplay: dto.distanceDisplay,
            distanceUnit: dto.distanceUnit,
            paceUnit: dto.paceUnit,
            durationMinutes: dto.durationMinutes,
            durationSeconds: dto.durationSeconds,
            pace: dto.pace,
            heartRateRange: dto.heartRateRange.map { toEntity(from: $0) },
            interval: dto.interval.map { toEntity(from: $0) },
            segments: dto.segments?.map { toEntity(from: $0) },
            description: dto.description,
            targetIntensity: dto.targetIntensity
        )
    }

    static func toDTO(from entity: RunActivity) -> RunActivityDTO {
        return RunActivityDTO(
            runType: entity.runType,
            distanceKm: entity.distanceKm,
            distanceDisplay: entity.distanceDisplay,
            distanceUnit: entity.distanceUnit,
            paceUnit: entity.paceUnit,
            durationMinutes: entity.durationMinutes,
            durationSeconds: entity.durationSeconds,
            pace: entity.pace,
            heartRateRange: entity.heartRateRange.map { toDTO(from: $0) },
            interval: entity.interval.map { toDTO(from: $0) },
            segments: entity.segments?.map { toDTO(from: $0) },
            description: entity.description,
            targetIntensity: entity.targetIntensity
        )
    }

    // MARK: - Exercise

    static func toEntity(from dto: ExerciseDTO) -> Exercise {
        // DTO reps (Int?) + repsRange (String?) → Entity reps (String?)
        let repsString: String? = dto.repsRange ?? dto.reps.map { String($0) }
        return Exercise(
            exerciseId: dto.exerciseId,
            name: dto.name,
            sets: dto.sets,
            reps: repsString,
            durationSeconds: dto.durationSeconds,
            weightKg: dto.weightKg,
            restSeconds: dto.restSeconds,
            description: dto.description
        )
    }

    static func toDTO(from entity: Exercise) -> ExerciseDTO {
        // Entity reps (String?) → DTO reps (Int?) + repsRange (String?)
        let repsInt = entity.reps.flatMap { Int($0) }
        let repsRange: String? = (repsInt == nil) ? entity.reps : nil
        return ExerciseDTO(
            exerciseId: entity.exerciseId,
            name: entity.name,
            sets: entity.sets,
            reps: repsInt,
            repsRange: repsRange,
            durationSeconds: entity.durationSeconds,
            weightKg: entity.weightKg,
            restSeconds: entity.restSeconds,
            description: entity.description
        )
    }

    // MARK: - StrengthActivity

    static func toEntity(from dto: StrengthActivityDTO) -> StrengthActivity {
        return StrengthActivity(
            strengthType: dto.strengthType,
            exercises: dto.exercises.map { toEntity(from: $0) },
            durationMinutes: dto.durationMinutes,
            description: dto.description
        )
    }

    static func toDTO(from entity: StrengthActivity) -> StrengthActivityDTO {
        return StrengthActivityDTO(
            strengthType: entity.strengthType,
            exercises: entity.exercises.map { toDTO(from: $0) },
            durationMinutes: entity.durationMinutes,
            description: entity.description
        )
    }

    // MARK: - CrossActivity

    static func toEntity(from dto: CrossActivityDTO) -> CrossActivity {
        return CrossActivity(
            crossType: dto.crossType,
            durationMinutes: dto.durationMinutes,
            distanceKm: dto.distanceKm,
            distanceDisplay: dto.distanceDisplay,
            distanceUnit: dto.distanceUnit,
            intensity: dto.intensity,
            description: dto.description
        )
    }

    static func toDTO(from entity: CrossActivity) -> CrossActivityDTO {
        return CrossActivityDTO(
            crossType: entity.crossType,
            durationMinutes: entity.durationMinutes,
            distanceKm: entity.distanceKm,
            distanceDisplay: entity.distanceDisplay,
            distanceUnit: entity.distanceUnit,
            intensity: entity.intensity,
            description: entity.description
        )
    }

    // MARK: - PrimaryActivity

    static func toEntity(from dto: PrimaryActivityDTO) -> PrimaryActivity {
        switch dto {
        case .run(let runDTO):
            return .run(toEntity(from: runDTO))
        case .strength(let strengthDTO):
            return .strength(toEntity(from: strengthDTO))
        case .cross(let crossDTO):
            return .cross(toEntity(from: crossDTO))
        }
    }

    static func toDTO(from entity: PrimaryActivity) -> PrimaryActivityDTO {
        switch entity {
        case .run(let runActivity):
            return .run(toDTO(from: runActivity))
        case .strength(let strengthActivity):
            return .strength(toDTO(from: strengthActivity))
        case .cross(let crossActivity):
            return .cross(toDTO(from: crossActivity))
        }
    }

    // MARK: - SupplementaryActivity

    static func toEntity(from dto: SupplementaryActivityDTO) -> SupplementaryActivity {
        switch dto {
        case .strength(let strengthDTO):
            return .strength(toEntity(from: strengthDTO))
        case .cross(let crossDTO):
            return .cross(toEntity(from: crossDTO))
        }
    }

    static func toDTO(from entity: SupplementaryActivity) -> SupplementaryActivityDTO {
        switch entity {
        case .strength(let strengthActivity):
            return .strength(toDTO(from: strengthActivity))
        case .cross(let crossActivity):
            return .cross(toDTO(from: crossActivity))
        }
    }

    // MARK: - TrainingSession

    static func toEntity(from dto: TrainingSessionDTO) -> TrainingSession {
        return TrainingSession(
            warmup: dto.warmup.map { toEntity(from: $0) },
            primary: toEntity(from: dto.primary),
            cooldown: dto.cooldown.map { toEntity(from: $0) },
            supplementary: dto.supplementary?.map { toEntity(from: $0) }
        )
    }

    static func toDTO(from entity: TrainingSession) -> TrainingSessionDTO {
        return TrainingSessionDTO(
            warmup: entity.warmup.map { toDTO(from: $0) },
            primary: toDTO(from: entity.primary),
            cooldown: entity.cooldown.map { toDTO(from: $0) },
            supplementary: entity.supplementary?.map { toDTO(from: $0) }
        )
    }

    // MARK: - DayDetail

    static func toEntity(from dto: DayDetailDTO) -> DayDetail {
        // DTO 扁平結構 → Entity session 結構
        let session: TrainingSession? = dto.primary.map { primary in
            TrainingSession(
                warmup: dto.warmup.map { toEntity(from: $0) },
                primary: toEntity(from: primary),
                cooldown: dto.cooldown.map { toEntity(from: $0) },
                supplementary: dto.supplementary?.map { toEntity(from: $0) }
            )
        }

        return DayDetail(
            dayIndex: dto.dayIndex,
            dayTarget: dto.dayTarget,
            reason: dto.reason,
            tips: dto.tips,
            category: dto.category.flatMap { TrainingCategory(rawValue: $0) },  // ✅ 處理可選值
            session: session
        )
    }

    static func toDTO(from entity: DayDetail) -> DayDetailDTO {
        return DayDetailDTO(
            dayIndex: entity.dayIndex,
            dayTarget: entity.dayTarget,
            reason: entity.reason,
            tips: entity.tips,
            category: entity.category?.rawValue,  // ✅ 處理可選值
            primary: entity.session.map { toDTO(from: $0.primary) },
            warmup: entity.session?.warmup.map { toDTO(from: $0) },
            cooldown: entity.session?.cooldown.map { toDTO(from: $0) },
            supplementary: entity.session?.supplementary?.map { toDTO(from: $0) }
        )
    }
}
