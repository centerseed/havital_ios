import SwiftUI

/// 統一的空狀態顯示組件
/// 用於統一所有「無數據」顯示的樣式和文案
struct EmptyStateView: View {
    let type: EmptyStateType
    let customMessage: String?
    let showRetryButton: Bool
    let onRetry: (() -> Void)?
    
    /// 初始化空狀態視圖
    /// - Parameters:
    ///   - type: 空狀態類型，決定圖標和預設文案
    ///   - customMessage: 自定義描述文案，為 nil 時使用預設文案
    ///   - showRetryButton: 是否顯示重試按鈕
    ///   - onRetry: 重試按鈕點擊回調
    init(
        type: EmptyStateType,
        customMessage: String? = nil,
        showRetryButton: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.type = type
        self.customMessage = customMessage
        self.showRetryButton = showRetryButton
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: type.systemImage)
                .font(.system(size: 40))
                .foregroundColor(type.iconColor)
            
            VStack(spacing: 8) {
                Text(type.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(customMessage ?? type.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if showRetryButton, let onRetry = onRetry {
                Button(L10n.Misc.retry.localized) {
                    onRetry()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }
}

/// 空狀態類型定義
enum EmptyStateType {
    case noData(dataType: String)
    case loadingFailed
    case apiError
    case noPermission
    case noDataSource
    case hrvData
    case sleepHeartRateData
    case vdotData
    case workoutData
    case healthData
    
    var systemImage: String {
        switch self {
        case .noData: return "tray"
        case .loadingFailed, .apiError: return "exclamationmark.triangle"
        case .noPermission: return "lock"
        case .noDataSource: return "questionmark.circle"
        case .hrvData: return "waveform.path.ecg"
        case .sleepHeartRateData: return "heart.fill"
        case .vdotData: return "chart.line.downtrend.xyaxis"
        case .workoutData: return "figure.run"
        case .healthData: return "heart.text.square"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .loadingFailed, .apiError: return .orange
        case .noPermission: return .red
        default: return .gray
        }
    }
    
    var title: String {
        switch self {
        case .noData(let dataType): return String(format: L10n.EmptyState.noDataTitle.localized, dataType)
        case .loadingFailed: return L10n.EmptyState.loadingFailedTitle.localized
        case .apiError: return L10n.EmptyState.apiErrorTitle.localized
        case .noPermission: return L10n.EmptyState.noPermissionTitle.localized
        case .noDataSource: return L10n.EmptyState.noDataSourceTitle.localized
        case .hrvData: return L10n.EmptyState.hrvDataTitle.localized
        case .sleepHeartRateData: return L10n.EmptyState.sleepHeartRateDataTitle.localized
        case .vdotData: return L10n.EmptyState.vdotDataTitle.localized
        case .workoutData: return L10n.EmptyState.workoutDataTitle.localized
        case .healthData: return L10n.EmptyState.healthDataTitle.localized
        }
    }
    
    var description: String {
        switch self {
        case .noData(let dataType): return String(format: L10n.EmptyState.noDataDesc.localized, dataType)
        case .loadingFailed: return L10n.EmptyState.loadingFailedDesc.localized
        case .apiError: return L10n.EmptyState.apiErrorDesc.localized
        case .noPermission: return L10n.EmptyState.noPermissionDesc.localized
        case .noDataSource: return L10n.EmptyState.noDataSourceDesc.localized
        case .hrvData: return L10n.EmptyState.hrvDataDesc.localized
        case .sleepHeartRateData: return L10n.EmptyState.sleepHeartRateDataDesc.localized
        case .vdotData: return L10n.EmptyState.vdotDataDesc.localized
        case .workoutData: return L10n.EmptyState.workoutDataDesc.localized
        case .healthData: return L10n.EmptyState.healthDataDesc.localized
        }
    }
}

/// 內容不可用視圖包裝器
/// 提供與 iOS 16+ ContentUnavailableView 類似的 API
struct ContentUnavailableWrapper: View {
    let title: String
    let systemImage: String
    let description: Text?
    let showRetryButton: Bool
    let onRetry: (() -> Void)?
    
    init(
        _ title: String,
        systemImage: String, 
        description: Text? = nil,
        showRetryButton: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.showRetryButton = showRetryButton
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let description = description {
                description
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if showRetryButton, let onRetry = onRetry {
                Button(L10n.Misc.retry.localized) {
                    onRetry()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }
}

#Preview {
    VStack(spacing: 20) {
        EmptyStateView(type: .hrvData)
        
        EmptyStateView(type: .loadingFailed, showRetryButton: true) {
            print("Retry tapped")
        }
        
        EmptyStateView(
            type: .noData(dataType: "睡眠"),
            customMessage: "請確保您的設備已連接並同步數據"
        )
    }
}