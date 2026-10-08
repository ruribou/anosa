import UIKit

/// 位置情報・通知・Watch 同期のサービスを起動時に始める。
/// significant-location-change・リージョン・通知アクションでバックグラウンドから再起動されたときも、ここを通る。
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let notifier = PlaceNotifier()
    let watchSync = WatchSyncService()
    private(set) lazy var locationService = LocationService(notifier: notifier, watchSync: watchSync)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        notifier.configure()
        #if DEBUG
        DebugPlaceSeeder.seedFromLaunchArguments()
        DebugOnboardingReset.resetFromLaunchArguments()
        #endif
        watchSync.activate()
        locationService.start()
        return true
    }
}
