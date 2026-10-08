import WatchKit

/// 起動時（バックグラウンド起動を含む）に WatchConnectivity を始め、
/// アプリを開いていなくてもスナップショットを受け取ってコンプリケーションを更新する。
@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let sync = WatchSyncModel()

    func applicationDidFinishLaunching() {
        sync.activate()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let task = task as? WKWatchConnectivityRefreshBackgroundTask {
                sync.handle(task)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
