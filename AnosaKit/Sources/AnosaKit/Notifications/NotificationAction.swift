import Foundation

/// 通知アクション。`rawValue` を UNNotificationAction の identifier に使う。
public enum NotificationAction: String, CaseIterable, Hashable, Sendable {
    /// 行ってみる（Apple マップで徒歩ルートを開く）
    case go = "anosa.action.go"
    /// 今日はやめる
    case dismissToday = "anosa.action.dismissToday"
    /// もう行った
    case visited = "anosa.action.visited"

    public var identifier: String { rawValue }

    public var title: String {
        switch self {
        case .go: NotificationCopy.actionGo
        case .dismissToday: NotificationCopy.actionDismissToday
        case .visited: NotificationCopy.actionVisited
        }
    }

    /// マップを開くためアプリを前面に出す必要がある。
    public var opensApp: Bool { self == .go }
}

/// 近くの場所の通知に使う識別子。
public enum PlaceNotification {
    /// UNNotificationCategory の identifier。
    public static let categoryIdentifier = "anosa.category.nearbyPlace"
    /// userInfo に入れる場所 id（`UUID.uuidString`）のキー。
    public static let placeIDKey = "placeID"

    /// 通知の request identifier。同じ場所の通知は置き換わる。
    public static func requestIdentifier(for placeID: UUID) -> String {
        "anosa.notification." + placeID.uuidString
    }

    public static func userInfo(for placeID: UUID) -> [String: String] {
        [placeIDKey: placeID.uuidString]
    }

    /// userInfo に場所 id がない・読めないときは nil。
    public static func placeID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let value = userInfo[placeIDKey] as? String else { return nil }
        return UUID(uuidString: value)
    }
}
