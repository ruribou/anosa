import Foundation

/// 通知しない時間帯。`start` を含み `end` を含まない半開区間。
/// `start > end` は日跨ぎ（例: 22:00〜8:00）、`start == end` は静音なし。
public struct QuietHours: Hashable, Codable, Sendable {
    public var start: TimeOfDay
    public var end: TimeOfDay

    public init(start: TimeOfDay, end: TimeOfDay) {
        self.start = start
        self.end = end
    }

    public var isEnabled: Bool { start != end }

    public func contains(_ time: TimeOfDay) -> Bool {
        let t = time.minutesSinceMidnight
        let s = start.minutesSinceMidnight
        let e = end.minutesSinceMidnight
        if s == e { return false }
        if s < e { return s <= t && t < e }
        return t >= s || t < e
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        contains(TimeOfDay(of: date, calendar: calendar))
    }
}
