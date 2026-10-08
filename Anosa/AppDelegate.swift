import UIKit

/// 位置情報と通知のサービスを起動時に始める。
/// significant-location-change・リージョン・通知アクションでバックグラウンドから再起動されたときも、ここを通る。
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let notifier = PlaceNotifier()
    private(set) lazy var locationService = LocationService(notifier: notifier)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        notifier.configure()
        #if DEBUG
        DebugPlaceSeeder.seedFromLaunchArguments()
        #endif
        locationService.start()
        return true
    }
}
