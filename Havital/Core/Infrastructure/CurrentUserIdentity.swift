import FirebaseAuth
import Foundation

// MARK: - CurrentUserIdentity
/// 「現在登入的是誰」——本機快取要用它蓋戳，換帳號時才讀不到上一個人的資料。
///
/// **這不是新增的第二條路**：內容是從 `App2FileSnapshotStore.defaultUserID()` 搬出來的
/// 同一支（那時只有 App2 的檔案快照在用），現在 `TrainingPlanV2LocalDataSource` 也要蓋戳，
/// 兩邊必須是同一個判定，所以提到 Core，原處改為呼叫這裡。
/// 2026-08-26 全 repo 盤過：除了那一支，沒有第二個「現在登入者 uid」的既有出口，
/// 四個 LocalDataSource 的快取 key 全部不帶 uid。
///
/// Demo 登入沒有 Firebase session，所以要退到既有的 auth session 快取
/// （`AuthSessionRepositoryImpl.getCurrentUser()` 會補上持久化的 demo user）。
/// 兩者都沒有（尚未登入／auth 還沒恢復）→ nil，呼叫端一律「不讀也不寫」。
enum CurrentUserIdentity {

    /// 同步取得目前登入者的 uid。純 UserDefaults／記憶體讀取，可在任何執行緒呼叫。
    static func uid() -> String? {
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty { return uid }
        let container = DependencyContainer.shared
        guard container.isRegistered(AuthSessionRepository.self) else { return nil }
        let repository = container.resolve() as AuthSessionRepository
        guard let uid = repository.getCurrentUser()?.uid, !uid.isEmpty else { return nil }
        return uid
    }
}
