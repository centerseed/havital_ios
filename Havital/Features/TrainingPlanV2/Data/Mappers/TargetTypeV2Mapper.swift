import Foundation

// MARK: - TargetTypeV2Mapper
/// Maps TargetTypeV2DTO (Data Layer) to TargetTypeV2 Entity (Domain Layer)
enum TargetTypeV2Mapper {

    static func toEntity(_ dto: TargetTypeV2DTO) -> TargetTypeV2 {
        TargetTypeV2(
            id: dto.id,
            name: dto.name,
            description: dto.description,
            defaultMethodology: dto.defaultMethodology,
            availableMethodologies: dto.availableMethodologies
        )
    }

    static func toEntities(_ response: TargetTypesResponseV2DTO) -> [TargetTypeV2] {
        response.targetTypes.map { toEntity($0) }
    }
}
