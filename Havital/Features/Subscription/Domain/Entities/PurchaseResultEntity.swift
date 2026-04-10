import Foundation

// MARK: - PurchaseResultEntity
/// 購買結果實體 - Domain Layer
enum PurchaseResultEntity {
    case success
    case cancelled
    case pendingProcessing
    case failed(Error)
}
