import Foundation

// MARK: - Constants namespace

/// Top-level namespace for project-wide constants.
enum Constants {}

// MARK: - Constants.IAP

extension Constants {
    enum IAP {
        /// Early-bird subscription product IDs.
        /// These are independent low-priced products that permanently lock in the early-bird price.
        /// Dual-condition check: offering identifier OR product ID in this set (resilient to future
        /// RC offering identifier renames).
        static let earlyBirdProductIDs: Set<String> = [
            "paceriz.sub.monthly.eb1",
            "paceriz.sub.yearly.eb1"
        ]

        /// Standard (full-price) subscription product IDs.
        static let standardProductIDs: Set<String> = [
            "paceriz.sub.monthly",
            "paceriz.sub.yearly"
        ]

        /// RevenueCat offering identifier for the early-bird campaign offering.
        /// NOTE: Must match the exact identifier set in RevenueCat dashboard (case-sensitive, spaces preserved).
        static let earlyBirdOfferingIdentifier = "Early bird"

        /// RevenueCat offering identifier for the default (standard price) offering.
        static let defaultOfferingIdentifier = "default"
    }
}
