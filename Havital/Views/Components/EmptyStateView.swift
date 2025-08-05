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
                Button("重試") {
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
        case .noData(let dataType): return "無\(dataType)數據"
        case .loadingFailed: return "載入失敗"
        case .apiError: return "數據載入失敗"
        case .noPermission: return "無權限"
        case .noDataSource: return "未選擇數據來源"
        case .hrvData: return "無 HRV 數據"
        case .sleepHeartRateData: return "無睡眠心率數據"
        case .vdotData: return "無跑力數據"
        case .workoutData: return "無運動數據"
        case .healthData: return "無健康數據"
        }
    }
    
    var description: String {
        switch self {
        case .noData(let dataType): return "目前沒有可顯示的\(dataType)數據"
        case .loadingFailed: return "無法載入數據，請檢查網路連線後重試"
        case .apiError: return "伺服器暫時無法提供數據"
        case .noPermission: return "請在設定中允許存取相關數據"
        case .noDataSource: return "請選擇數據來源以查看相關資訊"
        case .hrvData: return "無法獲取心率變異性數據"
        case .sleepHeartRateData: return "無法獲取睡眠心率數據"
        case .vdotData: return "暫無跑力數據，請先完成跑步訓練"
        case .workoutData: return "尚未記錄任何運動數據"
        case .healthData: return "無法獲取健康數據"
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
                Button("重試") {
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