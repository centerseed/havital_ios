import Foundation

// MARK: - RaceMapper
/// 賽事 Mapper - Data Layer
/// 負責 DTO → Entity 轉換
enum RaceMapper {

    // MARK: - RaceDTO → RaceEvent

    /// 將 RaceDTO 轉換為 RaceEvent Entity
    /// - Parameter dto: API 響應的 DTO
    /// - Returns: Domain Layer 業務實體；日期解析失敗時回傳 nil
    static func toEntity(from dto: RaceDTO) -> RaceEvent? {
        guard let eventDate = parseDate(from: dto.eventDate) else {
            Logger.error("[RaceMapper] 無法解析 event_date: \(dto.eventDate)，race_id=\(dto.raceId)")
            return nil
        }

        return RaceEvent(
            raceId: dto.raceId,
            name: dto.name,
            region: dto.region,
            eventDate: eventDate,
            city: dto.city,
            location: dto.location,
            distances: dto.distances.map { toDistanceEntity(from: $0) },
            entryStatus: dto.entryStatus,
            isCurated: dto.isCurated ?? false,
            courseType: dto.courseType,
            tags: dto.tags ?? []
        )
    }

    /// 將 [RaceDTO] 批次轉換為 [RaceEvent]，自動過濾日期解析失敗的項目
    /// - Parameter dtos: DTO 陣列
    /// - Returns: 成功轉換的 Entity 陣列
    static func toEntities(from dtos: [RaceDTO]) -> [RaceEvent] {
        dtos.compactMap { toEntity(from: $0) }
    }

    // MARK: - RaceDistanceDTO → RaceDistance

    /// 將 RaceDistanceDTO 轉換為 RaceDistance Entity
    private static func toDistanceEntity(from dto: RaceDistanceDTO) -> RaceDistance {
        RaceDistance(distanceKm: dto.distanceKm, name: dto.name)
    }

    // MARK: - Date Helpers

    /// 解析 YYYY-MM-DD 日期字串為 Date
    /// - Parameter dateString: 格式為 "YYYY-MM-DD" 的日期字串
    /// - Returns: 解析成功的 Date；失敗回傳 nil
    private static func parseDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
}
