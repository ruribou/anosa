import Foundation

/// 日付を持たない時刻（時・分）。
public struct TimeOfDay: Hashable, Codable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public init(of date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}
