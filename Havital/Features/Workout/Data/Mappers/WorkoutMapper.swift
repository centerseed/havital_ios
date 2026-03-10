import Foundation

// MARK: - Workout Mapper
/// 負責 Workout 數據的轉換與映射
/// Data Layer - Mapper
struct WorkoutMapper {

    // MARK: - WorkoutV2Detail → WorkoutV2

    /// 將 WorkoutV2Detail 轉換為 WorkoutV2
    /// - Parameter detail: 詳細訓練數據
    /// - Returns: 簡化的訓練數據
    static func toWorkoutV2(from detail: WorkoutV2Detail) -> WorkoutV2 {
        return WorkoutV2(
            id: detail.id,
            provider: detail.provider,
            activityType: detail.activityType,
            startTimeUtc: detail.startTime,
            endTimeUtc: detail.endTime,
            durationSeconds: Int(detail.basicMetrics?.totalDurationS ?? 0),
            distanceMeters: detail.basicMetrics?.totalDistanceM,
            distanceDisplay: nil,
            distanceUnit: nil,
            deviceName: detail.deviceInfo?.deviceName,
            basicMetrics: toBasicMetrics(from: detail.basicMetrics),
            advancedMetrics: toAdvancedMetrics(from: detail.advancedMetrics),
            createdAt: detail.createdAt,
            schemaVersion: detail.schemaVersion,
            storagePath: detail.storagePath,
            dailyPlanSummary: detail.dailyPlanSummary,
            aiSummary: detail.aiSummary,
            shareCardContent: detail.shareCardContent
        )
    }

    // MARK: - BasicMetrics Conversion

    /// 轉換基本指標：V2BasicMetrics → BasicMetrics
    static func toBasicMetrics(from v2Metrics: V2BasicMetrics?) -> BasicMetrics? {
        guard let metrics = v2Metrics else { return nil }

        return BasicMetrics(
            avgHeartRateBpm: metrics.avgHeartRateBpm,
            maxHeartRateBpm: metrics.maxHeartRateBpm,
            minHeartRateBpm: metrics.minHeartRateBpm.map { Double($0) },
            avgPaceSPerKm: metrics.avgPaceSPerKm,
            avgSpeedMPerS: metrics.avgSpeedMPerS,
            maxSpeedMPerS: metrics.maxSpeedMPerS,
            avgCadenceSpm: metrics.avgCadenceSpm,
            avgStrideLengthM: metrics.avgStrideLengthM,
            caloriesKcal: metrics.caloriesKcal.map { Double($0) },
            totalDistanceM: metrics.totalDistanceM,
            totalDurationS: metrics.totalDurationS,
            movingDurationS: metrics.movingDurationS,
            totalAscentM: metrics.totalAscentM,
            totalDescentM: metrics.totalDescentM,
            avgAltitudeM: metrics.avgAltitudeM,
            avgPowerW: metrics.avgPowerW,
            maxPowerW: metrics.maxPowerW,
            normalizedPowerW: metrics.normalizedPowerW,
            trainingLoad: metrics.trainingLoad
        )
    }

    // MARK: - AdvancedMetrics Conversion

    /// 轉換進階指標：V2AdvancedMetrics → AdvancedMetrics
    static func toAdvancedMetrics(from v2Metrics: V2AdvancedMetrics?) -> AdvancedMetrics? {
        guard let metrics = v2Metrics else { return nil }

        return AdvancedMetrics(
            dynamicVdot: metrics.dynamicVdot,
            tss: metrics.tss,
            trainingType: metrics.trainingType,
            intensityMinutes: toIntensityMinutes(from: metrics.intensityMinutes),
            intervalCount: metrics.intervalCount,
            avgHrTop20Percent: metrics.avgHrTop20Percent,
            hrZoneDistribution: toZoneDistribution(from: metrics.hrZoneDistribution),
            paceZoneDistribution: toZoneDistribution(from: metrics.paceZoneDistribution),
            rpe: metrics.rpe,
            avgStanceTimeMs: metrics.avgStanceTimeMs,
            avgVerticalRatioPercent: metrics.avgVerticalRatioPercent
        )
    }

    // MARK: - IntensityMinutes Conversion
    
    /// 轉換強度分鐘：V2IntensityMinutes → APIIntensityMinutes
    static func toIntensityMinutes(from v2: V2IntensityMinutes?) -> APIIntensityMinutes? {
        guard let v2 = v2 else { return nil }
        return APIIntensityMinutes(
            low: v2.low,
            medium: v2.medium,
            high: v2.high
        )
    }

    // MARK: - ZoneDistribution Conversion

    /// 轉換配速區間分布：V2ZoneDistribution → ZoneDistribution
    static func toZoneDistribution(from v2: V2ZoneDistribution?) -> ZoneDistribution? {
        guard let v2 = v2 else { return nil }
        return ZoneDistribution(
            marathon: v2.marathon,
            threshold: v2.threshold,
            recovery: v2.recovery,
            interval: v2.interval,
            anaerobic: v2.anaerobic,
            easy: v2.easy
        )
    }

    // MARK: - WorkoutV2 → UploadWorkoutRequest

    /// 將 WorkoutV2 轉換為上傳請求（用於同步）
    /// - Parameter workout: 訓練實體
    /// - Returns: 上傳請求數據
    static func toUploadRequest(from workout: WorkoutV2) -> UploadWorkoutRequest {
        let sourceInfo = UploadSourceInfo(
            name: workout.provider,
            importMethod: "manual"
        )

        let activityProfile = UploadActivityProfile(
            type: workout.activityType,
            startTimeUtc: workout.startTimeUtc,
            endTimeUtc: workout.endTimeUtc ?? workout.startTimeUtc ?? "",
            durationTotalSeconds: workout.durationSeconds
        )

        let summaryMetrics = UploadSummaryMetrics(
            distanceMeters: workout.distanceMeters,
            activeCaloriesKcal: workout.calories.map { Double($0) },
            avgHeartRateBpm: workout.basicMetrics?.avgHeartRateBpm,
            maxHeartRateBpm: workout.basicMetrics?.maxHeartRateBpm
        )

        // TODO: 添加時間序列數據支持
        let timeSeriesStreams: UploadTimeSeriesStreams? = nil

        return UploadWorkoutRequest(
            sourceInfo: sourceInfo,
            activityProfile: activityProfile,
            summaryMetrics: summaryMetrics,
            timeSeriesStreams: timeSeriesStreams
        )
    }

    // MARK: - Data Validation

    /// 驗證 WorkoutV2 數據是否有效
    /// - Parameter workout: 訓練實體
    /// - Returns: 是否有效
    static func isValid(_ workout: WorkoutV2) -> Bool {
        // 基本驗證：ID 和時長必須存在
        guard !workout.id.isEmpty else {
            Logger.error("[WorkoutMapper] 驗證失敗：ID 為空")
            return false
        }

        guard workout.durationSeconds > 0 else {
            Logger.error("[WorkoutMapper] 驗證失敗：時長為 0")
            return false
        }

        return true
    }

    /// 清理和標準化 WorkoutV2 數據
    /// - Parameter workout: 訓練實體
    /// - Returns: 清理後的訓練實體
    static func sanitize(_ workout: WorkoutV2) -> WorkoutV2 {
        // 目前暫時返回原始數據
        // TODO: 實現數據清理邏輯（如移除異常值、標準化格式等）
        return workout
    }
}
