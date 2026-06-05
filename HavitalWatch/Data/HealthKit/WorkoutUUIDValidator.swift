import Foundation

enum WorkoutUUIDValidator {
    static let metadataKey = "com.paceriz.workout_uuid"

    private static let regex = try! NSRegularExpression(
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    )

    static func isValid(_ uuid: String) -> Bool {
        guard !uuid.isEmpty else { return false }
        let range = NSRange(uuid.startIndex..., in: uuid)
        return regex.firstMatch(in: uuid, range: range) != nil
    }

    static func generate() -> String {
        UUID().uuidString.lowercased()
    }
}
