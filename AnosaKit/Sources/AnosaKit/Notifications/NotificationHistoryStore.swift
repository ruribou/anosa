import Foundation

/// 通知履歴を App Group の UserDefaults に JSON で保存する。
public struct NotificationHistoryStore {
    public static let defaultKey = "notificationHistory"

    public let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// App Group の suite。取れなければ `.standard`。
    public static func shared() -> NotificationHistoryStore {
        NotificationHistoryStore(defaults: SharedDefaults.make())
    }

    /// 保存がない・読めないときは空。
    public func records() -> [NotificationRecord] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([NotificationRecord].self, from: data)) ?? []
    }

    /// 追記し、判断に不要になった古い記録を刈る。
    public func append(_ record: NotificationRecord, now: Date, settings: AnosaSettings = .default) throws {
        let kept = Self.pruned(records() + [record], now: now, settings: settings)
        defaults.set(try JSONEncoder().encode(kept), forKey: key)
    }

    /// 保持期間。クールダウンと 1 日上限の判定に足りるよう、長い方に 1 日の余裕を足す。
    public static func retention(settings: AnosaSettings) -> TimeInterval {
        max(settings.cooldown, day) + day
    }

    /// `now - retention` より前の記録を除く（ちょうどの記録は残す）。
    public static func pruned(_ records: [NotificationRecord], now: Date, settings: AnosaSettings) -> [NotificationRecord] {
        let threshold = now.addingTimeInterval(-retention(settings: settings))
        return records.filter { $0.notifiedAt >= threshold }
    }

    private static let day: TimeInterval = 24 * 60 * 60
}
