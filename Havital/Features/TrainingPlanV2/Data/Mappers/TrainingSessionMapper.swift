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
            durationMinutes: dto.durationMinutes,
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
            durationMinutes: entity.durationMinutes,
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
            workDurationMinutes: dto.workDurationMinutes,
            workPace: dto.workPace,
            workDescription: dto.workDescription,
            recoveryDistanceKm: dto.recoveryDistanceKm,
            recoveryDistanceM: dto.recoveryDistanceM,
            recoveryDurationMinutes: dto.recoveryDurationMinutes,
            recoveryPace: dto.recoveryPace,
            recoveryDescription: dto.recoveryDescription,
            variant: dto.variant
        )
    }

    static func toDTO(from entity: IntervalBlock) -> IntervalBlockDTO {
        return IntervalBlockDTO(
            repeats: entity.repeats,
            workDistanceKm: entity.workDistanceKm,
            workDistanceM: entity.workDistanceM,
            workDurationMinutes: entity.workDurationMinutes,
            workPace: entity.workPace,
            workDescription: entity.workDescription,
            recoveryDistanceKm: entity.recoveryDistanceKm,
            recoveryDistanceM: entity.recoveryDistanceM,
            recoveryDurationMinutes: entity.recoveryDurationMinutes,
            recoveryPace: entity.recoveryPace,
            recoveryDescription: entity.recoveryDescription,
            variant: entity.variant
        )
    }

    // MARK: - RunActivity

    static func toEntity(from dto: RunActivityDTO) -> RunActivity {
        return RunActivity(
            runType: dto.runType,
            distanceKm: dto.distanceKm,
            durationMinutes: dto.durationMinutes,
            pace: dto.pace,
            heartRateRange: dto.heartRateRange.map { toEntity(from: $0) },
            interval: dto.interval.map { toEntity(from: $0) },
            segments: dto.segments?.map { toEntity(from: $0) },
            description: dto.description
        )
    }

    static func toDTO(from entity: RunActivity) -> RunActivityDTO {
        return RunActivityDTO(
            runType: entity.runType,
            distanceKm: entity.distanceKm,
            durationMinutes: entity.durationMinutes,
            pace: entity.pace,
            heartRateRange: entity.heartRateRange.map { toDTO(from: $0) },
            interval: entity.interval.map { toDTO(from: $0) },
            segments: entity.segments?.map { toDTO(from: $0) },
            description: entity.description
        )
    }

    // MARK: - Exercise

    static func toEntity(from dto: ExerciseDTO) -> Exercise {
        return Exercise(
            name: dto.name,
            sets: dto.sets,
            reps: dto.reps,
            durationSeconds: dto.durationSeconds,
            weightKg: dto.weightKg,
            restSeconds: dto.restSeconds,
            description: dto.description
        )
    }

    static func toDTO(from entity: Exercise) -> ExerciseDTO {
        return ExerciseDTO(
            name: entity.name,
            sets: entity.sets,
            reps: entity.reps,
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
            intensity: dto.intensity,
            description: dto.description
        )
    }

    static func toDTO(from entity: CrossActivity) -> CrossActivityDTO {
        return CrossActivityDTO(
            crossType: entity.crossType,
            durationMinutes: entity.durationMinutes,
            distanceKm: entity.distanceKm,
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
        }
    }

    static func toDTO(from entity: SupplementaryActivity) -> SupplementaryActivityDTO {
        switch entity {
        case .strength(let strengthActivity):
            return .strength(toDTO(from: strengthActivity))
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
        return DayDetail(
            dayIndex: dto.dayIndex,
            dayTarget: dto.dayTarget,
            reason: dto.reason,
            tips: dto.tips,
            category: TrainingCategory(rawValue: dto.category) ?? .rest,
            session: dto.session.map { toEntity(from: $0) }
        )
    }

    static func toDTO(from entity: DayDetail) -> DayDetailDTO {
        return DayDetailDTO(
            dayIndex: entity.dayIndex,
            dayTarget: entity.dayTarget,
            reason: entity.reason,
            tips: entity.tips,
            category: entity.category.rawValue,
            session: entity.session.map { toDTO(from: $0) }
        )
    }
}
