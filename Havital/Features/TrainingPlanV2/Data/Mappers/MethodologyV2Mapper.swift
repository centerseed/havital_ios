import Foundation

// MARK: - MethodologyV2Mapper
/// Maps MethodologyV2DTO (Data Layer) to MethodologyV2 Entity (Domain Layer)
enum MethodologyV2Mapper {

    static func toEntity(_ dto: MethodologyV2DTO) -> MethodologyV2 {
        MethodologyV2(
            id: dto.id,
            name: dto.name,
            description: dto.description,
            targetTypes: dto.targetTypes,
            phases: dto.phases,
            crossTrainingEnabled: dto.crossTrainingEnabled
        )
    }

    static func toEntities(_ response: MethodologiesResponseV2DTO) -> [MethodologyV2] {
        response.methodologies.map { toEntity($0) }
    }
}
