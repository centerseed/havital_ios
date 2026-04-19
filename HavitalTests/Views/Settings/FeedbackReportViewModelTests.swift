import XCTest
import UIKit
@testable import paceriz_dev

@MainActor
final class FeedbackReportViewModelTests: XCTestCase {
    func testInitPreservesUserEmailAndPrepopulatesSystemInfo() {
        let sut = FeedbackReportViewModel(userEmail: "runner@example.com")

        XCTAssertEqual(sut.userEmail, "runner@example.com")
        XCTAssertFalse(sut.appVersion.isEmpty)
        XCTAssertFalse(sut.deviceInfo.isEmpty)
    }

    func testSubmitFeedbackRejectsBlankDescriptionBeforeSubmitting() async {
        let sut = FeedbackReportViewModel(userEmail: "runner@example.com")
        sut.descriptionText = "  \n  "

        await sut.submitFeedback()

        XCTAssertEqual(
            sut.error,
            NSLocalizedString("feedback.error.description_required", comment: "Description is required")
        )
        XCTAssertFalse(sut.isSubmitting)
        XCTAssertFalse(sut.showSuccess)
    }

    func testRemoveImageRemovesRequestedImageOnly() {
        let sut = FeedbackReportViewModel()
        sut.selectedImages = [makeImage(color: .red), makeImage(color: .blue)]

        sut.removeImage(at: 0)

        XCTAssertEqual(sut.selectedImages.count, 1)
    }

    func testRemoveImageIgnoresOutOfBoundsIndex() {
        let sut = FeedbackReportViewModel()
        sut.selectedImages = [makeImage(color: .green)]

        sut.removeImage(at: 3)

        XCTAssertEqual(sut.selectedImages.count, 1)
    }

    private func makeImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
