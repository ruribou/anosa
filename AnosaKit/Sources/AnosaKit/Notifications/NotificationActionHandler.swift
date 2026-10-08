import Foundation

/// 通知アクションを場所の状態更新につなぐ。
@MainActor
public enum NotificationActionHandler {
    /// - 今日はやめる: `snoozedUntil` を `settings.snoozeEnd(for: .today, ...)` にして保存
    /// - もう行った: ステータスを「行った」にして保存
    /// - 行ってみる: 状態は変えず、Apple マップの徒歩ルート URL を返す
    /// 該当する場所がなければ何もせず nil を返す。
    @discardableResult
    public static func apply(
        _ action: NotificationAction,
        placeID: UUID,
        now: Date,
        store: PlaceStore,
        settings: AnosaSettings = .default,
        calendar: Calendar
    ) throws -> URL? {
        guard var place = try store.place(id: placeID) else { return nil }
        switch action {
        case .go:
            return mapsWalkingURL(for: place)
        case .dismissToday:
            place.snoozedUntil = settings.snoozeEnd(for: .today, now: now, calendar: calendar)
            try store.save(place)
            return nil
        case .visited:
            try store.setStatus(.visited, for: placeID)
            return nil
        }
    }

    /// Apple マップで目的地までの徒歩ルートを開く URL。座標は小数点以下 6 桁（約 0.1m）。
    public nonisolated static func mapsWalkingURL(for place: Place) -> URL {
        let latitude = String(format: "%.6f", place.latitude)
        let longitude = String(format: "%.6f", place.longitude)
        return URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)&dirflg=w")!
    }
}
