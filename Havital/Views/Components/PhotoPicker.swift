import SwiftUI
import PhotosUI

/// 單張照片選擇器（PHPicker 包裝）。供分享卡等需要挑照片的畫面使用。
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let result = results.first else { return }

            let itemProvider = result.itemProvider

            itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, error in
                if error != nil {
                    self?.loadImageUsingObject(itemProvider)
                    return
                }

                guard let data = data, let image = UIImage(data: data) else {
                    self?.loadImageUsingObject(itemProvider)
                    return
                }

                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                }
            }
        }

        private func loadImageUsingObject(_ itemProvider: NSItemProvider) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let image = object as? UIImage else { return }

                DispatchQueue.main.async {
                    self?.parent.selectedImage = image
                }
            }
        }
    }
}
