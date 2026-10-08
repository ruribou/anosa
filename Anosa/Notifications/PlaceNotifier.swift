import AnosaKit
import OSLog
import UIKit
import UserNotifications

/// 近くの場所のローカル通知を出し、通知アクションを場所の状態更新につなぐ。
@MainActor
final class PlaceNotifier: NSObject {
    private let center = UNUserNotificationCenter.current()
    private let settings: AnosaSettings

    private static let logger = Logger(subsystem: "com.example.anosa", category: "notification")

    init(settings: AnosaSettings = .default) {
        self.settings = settings
        super.init()
    }

    /// 起動のたびに、application(_:didFinishLaunchingWithOptions:) から戻る前に呼ぶ（アクションの応答を受けるため）。
    func configure() {
        center.delegate = self
        let actions = NotificationAction.allCases.map { action in
            UNNotificationAction(
                identifier: action.identifier,
                title: action.title,
                options: action.opensApp ? [.foreground] : []
            )
        }
        let category = UNNotificationCategory(
            identifier: PlaceNotification.categoryIdentifier,
            actions: actions,
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    /// まだ決めていなければ通知の許可を求める。決めてあればダイアログは出ない。
    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Self.logger.error("通知の許可を求められません: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 即時に通知する。同じ場所の通知は置き換わる。
    func post(_ candidate: NotificationCandidate) async {
        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.title()
        content.body = NotificationCopy.body(for: candidate)
        content.sound = .default
        content.categoryIdentifier = PlaceNotification.categoryIdentifier
        content.userInfo = PlaceNotification.userInfo(for: candidate.place.id)
        let request = UNNotificationRequest(
            identifier: PlaceNotification.requestIdentifier(for: candidate.place.id),
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
            Self.logger.info("通知を登録しました")
        } catch {
            Self.logger.error("通知を登録できません: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 通知本体のタップ（アクション以外）は、アプリを開くだけで何もしない。
    private func handleResponse(actionIdentifier: String, placeID: UUID?) async {
        guard let action = NotificationAction(rawValue: actionIdentifier), let placeID else { return }
        let url: URL?
        do {
            url = try NotificationActionHandler.apply(
                action,
                placeID: placeID,
                now: Date(),
                store: PlaceStore(container: AppContainer.shared),
                settings: settings,
                calendar: .autoupdatingCurrent
            )
        } catch {
            Self.logger.error("通知アクションを反映できません: \(error.localizedDescription, privacy: .public)")
            return
        }
        if let url {
            await UIApplication.shared.open(url)
        }
    }
}

extension PlaceNotifier: UNUserNotificationCenterDelegate {
    /// アプリを開いているときもバナーで出す。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let placeID = PlaceNotification.placeID(from: response.notification.request.content.userInfo)
        await handleResponse(actionIdentifier: actionIdentifier, placeID: placeID)
    }
}
