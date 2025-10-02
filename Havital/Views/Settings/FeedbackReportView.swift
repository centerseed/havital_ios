import SwiftUI
import PhotosUI

@MainActor
class FeedbackReportViewModel: ObservableObject, TaskManageable {
    @Published var selectedType: FeedbackType = .issue
    @Published var selectedCategory: FeedbackCategory = .other
    @Published var descriptionText: String = ""
    @Published var contactEmail: String = ""
    @Published var hideEmail: Bool = false  // 隱藏郵箱開關
    @Published var selectedImages: [UIImage] = []
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var showSuccess = false
    @Published var showImagePicker = false

    let taskRegistry = TaskRegistry()

    // Auto-populated fields
    let userEmail: String
    let appVersion: String
    let deviceInfo: String

    init(userEmail: String = "") {
        self.userEmail = userEmail
        self.appVersion = AppVersionHelper.getAppVersion()
        self.deviceInfo = DeviceInfoHelper.getDeviceInfo()
    }

    func submitFeedback() async {
        await executeTask(id: TaskID("submit_feedback")) { [weak self] in
            guard let self = self else { return }

            // Capture values to avoid async access issues
            let descriptionText = await MainActor.run { self.descriptionText }
            let selectedImages = await MainActor.run { self.selectedImages }
            let selectedType = await MainActor.run { self.selectedType }
            let selectedCategory = await MainActor.run { self.selectedCategory }
            let contactEmail = await MainActor.run { self.contactEmail }
            let hideEmail = await MainActor.run { self.hideEmail }

            // Validation
            guard !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run {
                    self.error = NSLocalizedString("feedback.error.description_required", comment: "Description is required")
                }
                return
            }

            await MainActor.run {
                self.isSubmitting = true
                self.error = nil
            }

            do {
                // Convert images to base64
                var base64Images: [String]?
                if !selectedImages.isEmpty {
                    base64Images = selectedImages.compactMap { image -> String? in
                        // Compress image to reduce size
                        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return nil }
                        // Check size limit (5MB)
                        guard imageData.count < 5 * 1024 * 1024 else {
                            Logger.warn("圖片大小超過 5MB，已跳過")
                            return nil
                        }
                        return "data:image/jpeg;base64,\(imageData.base64EncodedString())"
                    }
                }

                // 如果是"建議"類型，category 使用 .other
                let finalCategory = selectedType == .issue ? selectedCategory : .other

                // 如果用戶選擇隱藏郵箱，發送空字串
                let finalEmail = hideEmail ? "" : contactEmail

                let response = try await FeedbackService.shared.submitFeedback(
                    type: selectedType,
                    category: finalCategory,
                    description: descriptionText,
                    email: finalEmail,
                    images: base64Images
                )

                await MainActor.run {
                    self.isSubmitting = false
                    self.showSuccess = true
                    Logger.debug("回報提交成功: issue #\(response.issueNumber) - \(response.issueUrl)")
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    Logger.debug("回報提交被取消，忽略錯誤")
                    return
                }

                await MainActor.run {
                    self.isSubmitting = false
                    self.error = error.localizedDescription
                    Logger.error("回報提交失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }

    deinit {
        cancelAllTasks()
    }
}

struct FeedbackReportView: View {
    @StateObject private var viewModel: FeedbackReportViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showImageSourcePicker = false

    init(userEmail: String = "", initialCategory: FeedbackCategory? = nil) {
        _viewModel = StateObject(wrappedValue: FeedbackReportViewModel(userEmail: userEmail))
        if let category = initialCategory {
            _viewModel.wrappedValue.selectedCategory = category
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Type Selection
                Section(header: Text(NSLocalizedString("feedback.type", comment: "Type"))) {
                    Picker(NSLocalizedString("feedback.type", comment: "Type"), selection: $viewModel.selectedType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Category Selection (only for issues)
                if viewModel.selectedType == .issue {
                    Section(header: Text(NSLocalizedString("feedback.category", comment: "Category"))) {
                        Picker(NSLocalizedString("feedback.category", comment: "Category"), selection: $viewModel.selectedCategory) {
                            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                    }
                }

                // Description
                Section(
                    header: Text(NSLocalizedString("feedback.description", comment: "Description")),
                    footer: Text(NSLocalizedString("feedback.description_hint", comment: "Please describe the issue or suggestion in detail"))
                ) {
                    TextEditor(text: $viewModel.descriptionText)
                        .frame(minHeight: 120)
                }

                // Contact Email
                Section(
                    header: Text(NSLocalizedString("feedback.contact_email", comment: "Contact Email")),
                    footer: Text(NSLocalizedString("feedback.contact_email_hint", comment: "Optional. We'll use this to follow up with you."))
                ) {
                    Toggle(NSLocalizedString("feedback.hide_email", comment: "Hide my email"), isOn: $viewModel.hideEmail)

                    if !viewModel.hideEmail {
                        if viewModel.userEmail.isEmpty || viewModel.userEmail.contains("privaterelay.appleid.com") {
                            // Apple 登入用戶可以自行輸入 email
                            TextField(NSLocalizedString("feedback.contact_email_placeholder", comment: "Default: "), text: $viewModel.contactEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        } else {
                            // 一般用戶顯示帳號 email，也可編輯
                            TextField(viewModel.userEmail, text: $viewModel.contactEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                    }
                }

                // Images
                Section(
                    header: Text(NSLocalizedString("feedback.attachments", comment: "Attachments")),
                    footer: Text(NSLocalizedString("feedback.attachments_hint", comment: "Optional. Maximum 5MB per image."))
                ) {
                    if viewModel.selectedImages.isEmpty {
                        Button(action: {
                            showImageSourcePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text(NSLocalizedString("feedback.add_image", comment: "Add Image"))
                            }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button(action: {
                                            viewModel.removeImage(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.red))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }

                                if viewModel.selectedImages.count < 5 {
                                    Button(action: {
                                        showImageSourcePicker = true
                                    }) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Auto-populated Info
                Section(header: Text(NSLocalizedString("feedback.system_info", comment: "System Info"))) {
                    HStack {
                        Text(NSLocalizedString("feedback.user_email", comment: "User Email"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.userEmail)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Text(NSLocalizedString("feedback.app_version", comment: "App Version"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Text(NSLocalizedString("feedback.device_info", comment: "Device Info"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.deviceInfo)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                // Error Display
                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("feedback.title", comment: "Feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 如果 userEmail 為空或是 Apple 匿名信箱，預設開啟隱藏
                if viewModel.userEmail.isEmpty || viewModel.userEmail.contains("privaterelay.appleid.com") {
                    viewModel.hideEmail = true
                    viewModel.contactEmail = ""
                } else {
                    viewModel.hideEmail = false
                    viewModel.contactEmail = viewModel.userEmail
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                    .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Button(NSLocalizedString("common.submit", comment: "Submit")) {
                            Task {
                                await viewModel.submitFeedback()
                            }
                        }
                        .disabled(viewModel.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .disabled(viewModel.isSubmitting)
            .sheet(isPresented: $showImageSourcePicker) {
                ImagePicker(selectedImages: $viewModel.selectedImages, maxSelection: 5)
            }
            .alert(NSLocalizedString("feedback.success_title", comment: "Success"), isPresented: $viewModel.showSuccess) {
                Button(NSLocalizedString("common.done", comment: "Done")) {
                    dismiss()
                }
            } message: {
                Text(NSLocalizedString("feedback.success_message", comment: "Thank you for your feedback!"))
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    let maxSelection: Int
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = maxSelection - selectedImages.count

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                        if let image = image as? UIImage {
                            DispatchQueue.main.async {
                                self?.parent.selectedImages.append(image)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FeedbackReportView(userEmail: "test@example.com")
}
