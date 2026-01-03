import Foundation

// MARK: - 統一視圖狀態
/// 取代多個 @Published 變數，確保狀態互斥
/// 使用方式：@Published var state: ViewState<WeeklyPlan> = .loading
enum ViewState<T> {
    case loading
    case loaded(T)
    case error(DomainError)
    case empty
}

// MARK: - Equatable Conformance
extension ViewState: Equatable where T: Equatable {
    static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.loaded(let lhsValue), .loaded(let rhsValue)):
            return lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        case (.empty, .empty):
            return true
        default:
            return false
        }
    }
}

// MARK: - 便利計算屬性
extension ViewState {

    /// 是否正在載入
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// 獲取載入的數據（如有）
    var data: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    /// 獲取錯誤（如有）
    var error: DomainError? {
        if case .error(let err) = self { return err }
        return nil
    }

    /// 是否為空狀態
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    /// 是否有數據
    var hasData: Bool {
        return data != nil
    }

    /// 是否有錯誤
    var hasError: Bool {
        return error != nil
    }
}

// MARK: - 狀態轉換輔助
extension ViewState {

    /// 將載入的數據轉換為新類型
    func map<U>(_ transform: (T) -> U) -> ViewState<U> {
        switch self {
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .error(let error):
            return .error(error)
        case .empty:
            return .empty
        }
    }

    /// 從 Result 類型創建 ViewState
    static func from(result: Result<T, Error>) -> ViewState<T> {
        switch result {
        case .success(let value):
            return .loaded(value)
        case .failure(let error):
            return .error(error.toDomainError())
        }
    }
}

// MARK: - 列表專用擴展
extension ViewState where T: Collection {

    /// 列表是否為空（考慮 .loaded([]) 的情況）
    var isDataEmpty: Bool {
        if case .loaded(let collection) = self {
            return collection.isEmpty
        }
        return false
    }

    /// 智能狀態：如果載入的列表為空，返回 .empty
    var normalized: ViewState<T> {
        if case .loaded(let collection) = self, collection.isEmpty {
            return .empty
        }
        return self
    }
}
